import Foundation
import Observation
import TrainerCore
import TrainerStorage

/// Reine Entscheidungslogik für den Anbieterwechsel: aus Schlüssellage und laufendem Betrieb
/// ergibt sich, was zu tun ist. Ohne Oberfläche und ohne Netz prüfbar. Die Ausführung bleibt
/// in `AppModel` und benutzt die vorhandene Maschinerie (`cancel()`, `close()`).
struct ProviderChange: Equatable {
    /// nil bedeutet: kein Wechsel nötig.
    var switchesToDemo: Bool?
    /// Eine laufende Operation muss zuerst über `AppModel.cancel()` beendet und abgewartet
    /// werden. Mitten in einem Turn darf der Anbieter nie getauscht werden.
    var cancelsRunningOperation = false
    /// Eine offene Sitzung gehört zur alten Modellkennung und wird mit gesichertem Entwurf
    /// geschlossen; fortsetzen ließe sie sich nach dem Wechsel ohnehin nicht.
    var closesOpenSession = false
    var changes: Bool { switchesToDemo != nil }

    static func make(hasKey: Bool, usesDemoResponses: Bool,
                     busy: Bool, hasSession: Bool) -> ProviderChange {
        let target = !hasKey
        guard target != usesDemoResponses else { return ProviderChange() }
        return ProviderChange(switchesToDemo: target,
                              cancelsRunningOperation: busy, closesOpenSession: hasSession)
    }

    /// Dieselbe Bedingung, die `ConversationCoordinator.send` prüft, nur früher gestellt.
    /// Die Speicherlogik bleibt unberührt: eine Sitzung mit fremder Modellkennung ist und
    /// bleibt nicht fortsetzbar.
    static func mayContinue(_ session: SessionSnapshot, with current: ModelDescriptor) -> Bool {
        session.status != .active || session.identity.model == current
    }
}

@MainActor @Observable final class AppModel {
    let catalog: ContentCatalog
    let contentHash: String
    let repository: SwiftDataSessionRepository
    /// Wird beim Wechsel der Antwortquelle ersetzt, deshalb `var`. Der Austausch findet
    /// ausschließlich in `applyKeyChange()` und nur zwischen zwei Operationen statt.
    private(set) var coordinator: ConversationCoordinator
    var history: [SessionSummary] = []
    var session: SessionSnapshot?
    var input = ""
    var busy = false
    var errorMessage: String?
    var maySkipAnalysis = false
    var showReview = false
    var showHints = true
    var showFinishConfirmation = false
    var homePortrait: HomePortrait
    /// Wahr, solange kein OpenRouter-Schlüssel vorliegt und deshalb die festen Demo-Antworten
    /// laufen. Der Hinweistext auf der Startseite richtet sich danach. Seit der
    /// Einstellungsansicht kann sich der Wert zur Laufzeit ändern; die Oberfläche folgt ihm
    /// über `@Observable`.
    private(set) var usesDemoResponses: Bool
    @ObservationIgnored private let modelSettings: OpenRouterConfiguration
    /// Derselbe Anbieter, den auch der Coordinator benutzt. Hier zusätzlich gehalten, um ihn
    /// beim Wechsel mit `unload()` zu entladen — damit der alte Schlüssel nicht im Speicher
    /// eines nicht mehr benutzten Adapters liegen bleibt.
    @ObservationIgnored private var provider: any TrainerModelProvider
    /// Kennung des aktuellen Anbieters. Wird mit der gespeicherten Sitzungsidentität
    /// verglichen, um beim Öffnen früh zu warnen.
    @ObservationIgnored private var modelIdentity: ModelDescriptor
    @ObservationIgnored private let portraitRotation: HomePortraitRotation
    @ObservationIgnored private var wasInBackground = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var operation: UUID?

    init() throws {
        let content = try ContentCatalog.load()
        catalog = content.catalog; contentHash = content.hash
        let rotation = HomePortraitRotation(pool: try HomePortrait.loadPool())
        portraitRotation = rotation
        homePortrait = rotation.next()
        let root: URL
        #if DEBUG
        if let path = ProcessInfo.processInfo.environment["ROGERS_RODEO_TEST_STORAGE"] {
            root = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        }
        #else
        root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        #endif
        let storeURL = root.appendingPathComponent("RogersRodeo/Conversations/sessions.store")
        repository = try SwiftDataSessionRepository(storeURL: storeURL)
        // Echte Modellaufrufe laufen über OpenRouter (Documentation/ENTSCHEIDUNGEN.md, E01).
        // Ohne hinterlegten Schlüssel bleibt es bei den festen Demo-Antworten, statt jede
        // Sitzung mit „Modell nicht verfügbar" abzubrechen. Die beiden Wege sind
        // unterscheidbar: `usesDemoResponses` hier, die abweichende Modellkennung in der
        // Sitzungsidentität und der Demo-Hinweis im Rückblick.
        let settings = OpenRouterConfiguration()
        modelSettings = settings
        let demo = OpenRouterKey.lookup(service: settings.keychainService) == nil
        usesDemoResponses = demo
        let built = Self.makeProvider(demo: demo, settings: settings)
        provider = built.provider
        modelIdentity = built.identity
        coordinator = ConversationCoordinator(repository: repository, provider: built.provider)
        history = try repository.list()
    }

    private static func makeProvider(demo: Bool, settings: OpenRouterConfiguration)
        -> (provider: any TrainerModelProvider, identity: ModelDescriptor) {
        if demo { return (DemoModelProvider(), DemoModelProvider.identity) }
        let adapter = OpenRouterModelProvider(configuration: settings)
        // `descriptor()` ist nonisolated und deshalb ohne await lesbar.
        return (adapter, adapter.descriptor())
    }

    // MARK: Zugangsschlüssel

    /// Maskierte Anzeige des hinterlegten Schlüssels, sonst nil. Die Einstellungsansicht
    /// bekommt den Schlüssel selbst nie zu sehen.
    var storedKeyDisplay: String? { OpenRouterKey.storedDisplay(service: modelSettings.keychainService) }

    /// Wahr, wenn der Schlüssel aus der Umgebungsvariablen stammt und nicht aus dem
    /// Schlüsselbund. Kommt nur bei der Mac-Prüf-App vor, erklärt dort aber den sonst
    /// widersprüchlichen Zustand „kein Eintrag, trotzdem kein Demo-Betrieb".
    var usesEnvironmentKey: Bool {
        OpenRouterKey.keychain(service: modelSettings.keychainService) == nil
            && OpenRouterKey.lookup(service: modelSettings.keychainService) != nil
    }

    /// Prüft den eingegebenen Schlüssel mit einem echten, kostenlosen Aufruf und legt ihn
    /// nur bei Erfolg im Schlüsselbund ab. Der Wert wird weder protokolliert noch in eine
    /// Rückmeldung übernommen; er geht ausschließlich in den Authorization-Header und in
    /// den Schlüsselbund.
    func saveKey(_ value: String) async -> OpenRouterKeyOutcome {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .missing }
        let outcome = await OpenRouterKeyProbe.check(key: trimmed)
        guard outcome.isSuccess else { return outcome }
        guard OpenRouterKey.save(trimmed, service: modelSettings.keychainService) else { return .notStored }
        await applyKeyChange()
        return .accepted
    }

    /// Entfernt den Schlüssel und schaltet auf die Demo-Antworten zurück.
    @discardableResult
    func removeKey() async -> Bool {
        let removed = OpenRouterKey.remove(service: modelSettings.keychainService)
        await applyKeyChange()
        return removed
    }

    /// Tauscht den Anbieter, wenn sich die Schlüssellage geändert hat.
    ///
    /// Der Tausch findet nie mitten in einer Operation statt: `cancel()` bricht eine
    /// laufende Operation ab und wartet sie ab — danach ist `busy` falsch und der
    /// Coordinator frei. Eine offene Sitzung wird über `close()` mit gesichertem Entwurf
    /// geschlossen, weil sie zur alten Modellkennung gehört und nach dem Wechsel nicht mehr
    /// fortsetzbar wäre. Erst danach werden Anbieter, Kennung und Coordinator ersetzt.
    func applyKeyChange() async {
        let hasKey = OpenRouterKey.lookup(service: modelSettings.keychainService) != nil
        let plan = ProviderChange.make(hasKey: hasKey, usesDemoResponses: usesDemoResponses,
                                       busy: busy, hasSession: session != nil)
        guard let demo = plan.switchesToDemo else { return }
        if plan.cancelsRunningOperation { await cancel() }
        if plan.closesOpenSession { close() }
        await provider.unload()
        let built = Self.makeProvider(demo: demo, settings: modelSettings)
        provider = built.provider
        modelIdentity = built.identity
        coordinator = ConversationCoordinator(repository: repository, provider: built.provider)
        usesDemoResponses = demo
        errorMessage = nil; maySkipAnalysis = false
        refresh()
    }

    private func failure(_ error: Error) {
        guard !(error is CancellationError) else { return }
        errorMessage = (error as? TrainerFailure)?.errorDescription ?? "Die Aktion konnte nicht abgeschlossen werden. Bitte versuche es erneut."
        maySkipAnalysis = (error as? TrainerFailure) == .invalidAnalysis
    }
    func refresh() {
        do { history = try repository.list() } catch { failure(error) }
    }
    func start(_ scenario: ScenarioDefinition) {
        guard !busy else { return }
        let token = UUID(); operation = token; busy = true; errorMessage = nil
        task = Task {
            do {
                let created = try await coordinator.create(content: .init(scenario: scenario, codingGuide: catalog.codingGuide, tips: catalog.tips), contentHash: contentHash)
                guard operation == token else { refresh(); return }
                session = created; input = ""; showReview = false
            } catch { if operation == token { failure(error) } }
            if operation == token { busy = false; task = nil; operation = nil; refresh() }
        }
    }
    func open(_ id: UUID) {
        guard !busy else { return }
        do {
            let loaded = try repository.load(id: id)
            let pending = try repository.loadPending(sessionID: id)
            session = loaded; input = pending?.input ?? ""
            errorMessage = nil; maySkipAnalysis = false; showReview = loaded.status == .completed
            // Gespeicherte Sitzungen tragen die Modellkennung in ihrer Identität. Nach einem
            // Wechsel der Antwortquelle verweigert `ConversationCoordinator.send` das
            // Fortsetzen mit `unsupportedVersion` — das ist gewollt und bleibt so. Der
            // Hinweis steht hier, damit er vor dem Tippen kommt und nicht erst danach.
            if !ProviderChange.mayContinue(loaded, with: modelIdentity) {
                errorMessage = TrainerFailure.unsupportedVersion.errorDescription
            }
        } catch { failure(error) }
    }
    func send(skipAnalysis: Bool = false) {
        guard !busy, let session, session.status == .active else { return }
        let token = UUID(); operation = token; busy = true; errorMessage = nil; maySkipAnalysis = false
        let text = input
        task = Task {
            do {
                let saved = try await coordinator.send(sessionID: session.id, input: text, skipAnalysis: skipAnalysis)
                guard operation == token else { return }
                self.session = saved; input = ""
            } catch { if operation == token { failure(error) } }
            if operation == token { busy = false; task = nil; operation = nil; refresh() }
        }
    }

    /// Wartet die abgebrochene Operation ab, bevor eine neue mit derselben Oberfläche startet.
    func cancel() async {
        let running = task
        operation = nil; running?.cancel()
        await coordinator.cancel()
        await running?.value
        task = nil; busy = false
        if let id = session?.id {
            do {
                let loaded = try repository.load(id: id)
                // Ein Commit, der bereits vor dem Abbruch abgeschlossen war, bleibt sichtbar.
                if loaded.revision > (session?.revision ?? -1) { input = "" }
                session = loaded
            } catch { failure(error) }
        }
        refresh()
    }
    @discardableResult func saveDraft() -> Bool {
        guard !busy, let session, session.status == .active else { return true }
        do {
            let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let pending = try repository.loadPending(sessionID: session.id)
            if pending?.input == text { return true }
            if let pending { try repository.discardPending(sessionID: session.id, turnID: pending.id) }
            if !text.isEmpty && text.count <= 1500 && session.turns.count < 20 {
                try repository.savePending(.init(id: UUID(), sessionID: session.id, expectedRevision: session.revision, input: text, createdAt: Date()))
            }
            return true
        } catch { failure(error); return false }
    }
    func close() { guard saveDraft() else { return }; session = nil; input = ""; showReview = false; refresh() }
    func requestFinish() {
        guard !busy, let session, session.status == .active else { return }
        do {
            let pending = try repository.loadPending(sessionID: session.id)
            if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pending != nil {
                showFinishConfirmation = true
            } else { finish(discardDraft: false) }
        } catch { failure(error) }
    }
    func finish(discardDraft: Bool) {
        guard !busy, let session else { return }
        do {
            if discardDraft, let pending = try repository.loadPending(sessionID: session.id) {
                try repository.discardPending(sessionID: session.id, turnID: pending.id)
            }
            self.session = try repository.finish(sessionID: session.id, expectedRevision: session.revision, endedAt: Date())
            input = ""; showReview = true; errorMessage = nil; refresh()
        } catch { failure(error) }
    }
    func delete(_ id: UUID) {
        guard !busy else { return }
        do { try repository.delete(id: id); if session?.id == id { session = nil; input = "" }; refresh() }
        catch { failure(error) }
    }
    func foreground() {
        guard wasInBackground else { return }
        wasInBackground = false
        homePortrait = portraitRotation.next()
    }
    func background() async { wasInBackground = true; await cancel(); saveDraft() }
}
