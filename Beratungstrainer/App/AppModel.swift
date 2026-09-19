import Foundation
import Observation
import TrainerCore
import TrainerStorage

@MainActor @Observable final class AppModel {
    let catalog: ContentCatalog
    let contentHash: String
    let repository: SwiftDataSessionRepository
    let coordinator: ConversationCoordinator
    var history: [SessionSummary] = []
    var session: SessionSnapshot?
    var input = ""
    var busy = false
    var errorMessage: String?
    var maySkipAnalysis = false
    var showReview = false
    var showHints = true
    var showFinishConfirmation = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var operation: UUID?

    init() throws {
        let content = try ContentCatalog.load()
        catalog = content.catalog; contentHash = content.hash
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
        coordinator = ConversationCoordinator(repository: repository, provider: DemoModelProvider())
        history = try repository.list()
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
    func background() async { await cancel(); saveDraft() }
}
