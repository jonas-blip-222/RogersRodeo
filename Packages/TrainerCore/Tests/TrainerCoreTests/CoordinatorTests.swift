import Foundation
import Testing
@testable import TrainerCore

actor ControlledProvider: TrainerModelProvider {
    enum Mode { case normal, invalidAnalysis, invalidReply, heldReply }
    let mode: Mode
    var analyses = 0
    var replies = 0
    var replyStarted = false
    var releaseReply: CheckedContinuation<Void, Never>?
    var observers: [CheckedContinuation<Void, Never>] = []
    init(_ mode: Mode = .normal) { self.mode = mode }
    func descriptor() -> ModelDescriptor { TestData.model }
    func prepare() {}
    func unload() {}
    func analyze(_ request: AnalysisRequest) throws -> ModelResult<TurnAnalysis> {
        analyses += 1
        if mode == .invalidAnalysis { throw TrainerFailure.invalidAnalysis }
        return .init(value: .init(segments: [.init(quote: request.currentInput, code: .autonomy, isUncertain: false)]),
                     metrics: .init(durationSeconds: 0.1), contextMessagesUsed: request.recentMessages)
    }
    func reply(_ request: ReplyRequest) async throws -> ModelResult<ClientReply> {
        replies += 1
        if mode == .invalidReply { throw TrainerFailure.invalidReply }
        if mode == .heldReply {
            await withCheckedContinuation { continuation in
                releaseReply = continuation; replyStarted = true
                observers.forEach { $0.resume() }; observers = []
            }
        }
        // Simuliert eine Laufzeit, die Cancellation erst verspätet oder gar nicht beachtet.
        return .init(value: .init(text: "Das entscheide ich selbst.", primaryTag: nil, disclosedFactIDs: []),
                     metrics: .init(durationSeconds: 0.1), contextMessagesUsed: request.recentMessages)
    }
    func waitUntilReply() async {
        if replyStarted { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func release() { releaseReply?.resume(); releaseReply = nil }
}

actor FailingCommitRepository: SessionRepository {
    let base = MemorySessionRepository()
    var failNext = true
    let afterCommit: Bool
    init(afterCommit: Bool) { self.afterCommit = afterCommit }
    func setFailure(_ value: Bool) { failNext = value }
    func create(_ value: SessionSnapshot) async throws { try await base.create(value) }
    func load(id: UUID) async throws -> SessionSnapshot { try await base.load(id: id) }
    func list() async throws -> [SessionSummary] { await base.list() }
    func savePending(_ value: PendingTurn) async throws { try await base.savePending(value) }
    func loadPending(sessionID: UUID) async throws -> PendingTurn? { try await base.loadPending(sessionID: sessionID) }
    func discardPending(sessionID: UUID, turnID: UUID) async throws { try await base.discardPending(sessionID: sessionID, turnID: turnID) }
    func commit(sessionID: UUID, expectedRevision: Int, turn: CompletedTurn) async throws -> SessionSnapshot {
        if failNext {
            failNext = false
            if afterCommit { _ = try await base.commit(sessionID: sessionID, expectedRevision: expectedRevision, turn: turn) }
            throw TrainerFailure.storageUnavailable
        }
        return try await base.commit(sessionID: sessionID, expectedRevision: expectedRevision, turn: turn)
    }
    func finish(sessionID: UUID, expectedRevision: Int, endedAt: Date) async throws -> SessionSnapshot {
        try await base.finish(sessionID: sessionID, expectedRevision: expectedRevision, endedAt: endedAt)
    }
    func delete(id: UUID) async { await base.delete(id: id) }
}

/// Eingabegesteuerter Prüfanbieter für den Feedbackablauf. Der `DemoModelProvider` taugt
/// dafür nicht: seine `analyze` liefert immer leere Segmente, und er trägt bewusst die
/// Demo-Kennzeichnung. Hier wird die Analyse je Eingabe vorgegeben, damit der Ablauf
/// unabhängig von jeder Modellqualität prüfbar bleibt.
actor ScriptedProvider: TrainerModelProvider {
    let script: [String: TurnAnalysis]
    let holdsReply: Bool
    var analyses = 0
    var replies = 0
    /// Reihenfolge der Ereignisse, um „Feedback vor der Figurenantwort“ nachzuweisen.
    var events: [String] = []
    var releaseReply: CheckedContinuation<Void, Never>?
    var observers: [CheckedContinuation<Void, Never>] = []
    init(script: [String: TurnAnalysis], holdsReply: Bool = false) {
        self.script = script; self.holdsReply = holdsReply
    }
    func descriptor() -> ModelDescriptor { TestData.model }
    func prepare() {}
    func unload() {}
    func note(_ event: String) { events.append(event) }
    func analyze(_ request: AnalysisRequest) throws -> ModelResult<TurnAnalysis> {
        analyses += 1
        guard let analysis = script[request.currentInput] else { throw TrainerFailure.invalidAnalysis }
        return .init(value: analysis, metrics: .init(durationSeconds: 0.1), contextMessagesUsed: request.recentMessages)
    }
    func reply(_ request: ReplyRequest) async throws -> ModelResult<ClientReply> {
        replies += 1
        events.append("antwort_beginnt")
        if holdsReply {
            await withCheckedContinuation { continuation in
                releaseReply = continuation
                observers.forEach { $0.resume() }; observers = []
            }
        }
        events.append("antwort_fertig")
        return .init(value: .init(text: "Hm.", primaryTag: nil, disclosedFactIDs: []),
                     metrics: .init(durationSeconds: 0.1), contextMessagesUsed: request.recentMessages)
    }
    func waitUntilReplyHeld() async {
        if releaseReply != nil { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func release() { releaseReply?.resume(); releaseReply = nil }
}

/// Sammelt die Meldungen der frühen Anzeige.
actor FeedbackRecorder {
    var received: [PreliminaryFeedback] = []
    func add(_ value: PreliminaryFeedback) { received.append(value) }
    var sink: FeedbackSink { { [self] value in await add(value) } }
}

private let druckEingabe = "Wenn Ihnen Sarah wirklich wichtig wäre, würden Sie endlich mit dem Trinken aufhören."
private let druckAnalyse = TurnAnalysis(segments: [
    .init(quote: "Wenn Ihnen Sarah wirklich wichtig wäre", code: .confrontation, isUncertain: false)])

@Test func warnungErscheintVorDerFertigenFigurenantwort() async throws {
    // Abnahmepunkt 11.2: die vorläufige Warnung erscheint nach der Analyse und vor dem
    // Abschluss einer künstlich verzögerten Figurenantwort.
    let repo = MemorySessionRepository()
    let provider = ScriptedProvider(script: [druckEingabe: druckAnalyse], holdsReply: true)
    let recorder = FeedbackRecorder()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let session = try await coordinator.create(content: TestData.content, contentHash: "test")
    let sink = await recorder.sink
    let task = Task { try await coordinator.send(sessionID: session.id, input: druckEingabe, onFeedback: sink) }
    await provider.waitUntilReplyHeld()

    // Die Antwort hängt noch, die Warnung steht schon.
    let früh = await recorder.received
    #expect(früh.count == 1)
    let feedback = try #require(früh.first)
    #expect(feedback.findings.map(\.ruleID) == ["warnung.konfrontation"])
    #expect(feedback.analysisAvailable)
    // Gebunden an Sitzung, PendingTurn, erwartete Revision und den Ausführungsversuch.
    let pending = try #require(await repo.loadPending(sessionID: session.id))
    #expect(feedback.sessionID == session.id)
    #expect(feedback.turnID == pending.id)
    #expect(feedback.expectedRevision == session.revision)
    #expect(feedback.input == druckEingabe)
    // Zu diesem Zeitpunkt existiert noch kein gespeicherter Turn.
    #expect(try await repo.load(id: session.id).turns.isEmpty)

    await provider.release()
    let saved = try await task.value
    #expect(saved.turns.first?.feedback == feedback.findings)
    let events = await provider.events
    #expect(events == ["antwort_beginnt", "antwort_fertig"])
}

@Test func abbruchVerhindertSpaetesFeedbackUndSpaetenCommit() async throws {
    let repo = MemorySessionRepository()
    let provider = ScriptedProvider(script: [druckEingabe: druckAnalyse], holdsReply: true)
    let recorder = FeedbackRecorder()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let session = try await coordinator.create(content: TestData.content, contentHash: "test")
    let sink = await recorder.sink
    let task = Task { try await coordinator.send(sessionID: session.id, input: druckEingabe, onFeedback: sink) }
    await provider.waitUntilReplyHeld()
    await coordinator.cancel(); task.cancel(); await provider.release()
    await #expect(throws: CancellationError.self) { try await task.value }
    // Der Abbruch lässt keinen Turn zurück; die bereits gemeldete Warnung gehört zu einem
    // Versuch, dessen Marke die Oberfläche verworfen hat.
    #expect(try await repo.load(id: session.id) == session)
    let empfangen = await recorder.received
    #expect(empfangen.count == 1)
}

@Test func commitWiederholungMeldetUndSpeichertDasselbeFeedbackOhneNeuberechnung() async throws {
    let repo = FailingCommitRepository(afterCommit: false)
    let provider = ScriptedProvider(script: [druckEingabe: druckAnalyse])
    let recorder = FeedbackRecorder()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let session = try await coordinator.create(content: TestData.content, contentHash: "test")
    let sink = await recorder.sink
    await #expect(throws: TrainerFailure.storageUnavailable) {
        try await coordinator.send(sessionID: session.id, input: druckEingabe, onFeedback: sink)
    }
    let saved = try await coordinator.send(sessionID: session.id, input: druckEingabe, onFeedback: sink)
    // Kein zweiter Modellaufruf, kein doppelter Turn, kein doppelter Feedbackeintrag.
    #expect(await provider.analyses == 1)
    #expect(await provider.replies == 1)
    #expect(saved.turns.count == 1)
    #expect(saved.turns.first?.feedback.count == 1)
    let empfangen = await recorder.received
    #expect(empfangen.count == 2)
    #expect(empfangen[0].findings == empfangen[1].findings)
    #expect(empfangen[0].turnID == empfangen[1].turnID)
    // Verschiedene Versuche, damit die Oberfläche eine alte Meldung nicht mit einer neuen
    // verwechselt.
    #expect(empfangen[0].attempt != empfangen[1].attempt)
    #expect(saved.turns.first?.feedback == empfangen[1].findings)

    // Der erneute Commit desselben Turns bleibt idempotent, jetzt einschließlich Feedback.
    let wiederholt = try await repo.commit(sessionID: session.id, expectedRevision: 0, turn: saved.turns[0])
    #expect(wiederholt == saved)
    var verfaelscht = saved.turns[0]
    verfaelscht.feedback = []
    await #expect(throws: TrainerFailure.revisionConflict) {
        try await repo.commit(sessionID: session.id, expectedRevision: 0, turn: verfaelscht)
    }
}

@Test func uebersprungeneAnalyseZeigtKeineScheinbareEntwarnung() async throws {
    let repo = MemorySessionRepository()
    let provider = ScriptedProvider(script: [:])
    let recorder = FeedbackRecorder()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let session = try await coordinator.create(content: TestData.content, contentHash: "test")
    let sink = await recorder.sink
    // Erst scheitert die Analyse zweimal und der Beitrag wird gar nicht gespeichert.
    await #expect(throws: TrainerFailure.invalidAnalysis) {
        try await coordinator.send(sessionID: session.id, input: druckEingabe, onFeedback: sink)
    }
    #expect(await recorder.received.isEmpty)
    // Beim ausdrücklichen Fortsetzen ohne Einordnung gibt es keine Befunde — und die
    // Oberfläche erfährt über `analysisAvailable`, dass das keine Entwarnung ist.
    let saved = try await coordinator.send(sessionID: session.id, input: druckEingabe,
                                           skipAnalysis: true, onFeedback: sink)
    let feedback = try #require(await recorder.received.last)
    #expect(!feedback.analysisAvailable)
    #expect(feedback.findings.isEmpty)
    #expect(saved.turns.first?.feedback.isEmpty == true)
    #expect(saved.turns.first?.analysis == nil)
}

@Test func kontextluecheLaesstDieErlaubnislageUnsicher() async throws {
    // Abschnitt 9.4: Kürzung darf aus „Zustimmung nicht mehr im Fenster“ kein sicheres
    // „Rat ohne Erlaubnis“ machen. Modelliert wird das über die Unsicherheit des Segments;
    // der Motor muss sie in die vorsichtige Formulierung übernehmen.
    let eingabe = "Sie könnten kurz notieren, was Ihnen geholfen hat."
    let unsicher = TurnAnalysis(segments: [
        .init(quote: eingabe, code: .adviceWithoutPermission, isUncertain: true)])
    let repo = MemorySessionRepository()
    let provider = ScriptedProvider(script: [eingabe: unsicher])
    let recorder = FeedbackRecorder()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let session = try await coordinator.create(content: TestData.content, contentHash: "test")
    let saved = try await coordinator.send(sessionID: session.id, input: eingabe, onFeedback: await recorder.sink)
    let finding = try #require(saved.turns.first?.feedback.first)
    #expect(finding.certainty == .possible)
    #expect(finding.title == "Möglicher Rat ohne Erlaubnis")
}

@Test func successfulTurnIsAtomicAndCommitIdempotent() async throws {
    let repo = MemorySessionRepository(), provider = ControlledProvider()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let original = try await coordinator.create(content: TestData.content, contentHash: "test")
    let saved = try await coordinator.send(sessionID: original.id, input: "Sie entscheiden selbst.")
    #expect(saved.revision == 1 && saved.turns.count == 1 && saved.state.openness == 4)
    #expect(try await repo.loadPending(sessionID: original.id) == nil)
    let repeated = try await repo.commit(sessionID: original.id, expectedRevision: 0, turn: saved.turns[0])
    #expect(repeated == saved)
    var changed = saved.turns[0]; changed.input = "Anderer Text"
    await #expect(throws: TrainerFailure.revisionConflict) { try await repo.commit(sessionID: saved.id, expectedRevision: 0, turn: changed) }
}

@Test func analysisFailureCanBeExplicitlySkipped() async throws {
    let repo = MemorySessionRepository(), provider = ControlledProvider(.invalidAnalysis)
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let original = try await coordinator.create(content: TestData.content, contentHash: "test")
    await #expect(throws: TrainerFailure.invalidAnalysis) { try await coordinator.send(sessionID: original.id, input: "Sie entscheiden.") }
    #expect(await provider.analyses == 2)
    #expect(try await repo.load(id: original.id) == original)
    let pending = try #require(await repo.loadPending(sessionID: original.id))
    let saved = try await coordinator.send(sessionID: original.id, input: pending.input, skipAnalysis: true)
    #expect(saved.turns.first?.id == pending.id && saved.turns.first?.analysis == nil)
    #expect(saved.state.openness == original.state.openness)
}

@Test func replyFailureNeverCommitsCandidateState() async throws {
    let repo = MemorySessionRepository(), provider = ControlledProvider(.invalidReply)
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let original = try await coordinator.create(content: TestData.content, contentHash: "test")
    await #expect(throws: TrainerFailure.invalidReply) { try await coordinator.send(sessionID: original.id, input: "Sie entscheiden.") }
    #expect(await provider.replies == 2)
    #expect(try await repo.load(id: original.id) == original)
    #expect(try await repo.loadPending(sessionID: original.id) != nil)
}

@Test func lateResponseAfterCancellationCannotCommit() async throws {
    let repo = MemorySessionRepository(), provider = ControlledProvider(.heldReply)
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let original = try await coordinator.create(content: TestData.content, contentHash: "test")
    let task = Task { try await coordinator.send(sessionID: original.id, input: "Sie entscheiden.") }
    await provider.waitUntilReply()
    await #expect(throws: TrainerFailure.operationInProgress) { try await coordinator.send(sessionID: original.id, input: "Doppelt") }
    await coordinator.cancel(); task.cancel(); await provider.release()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(try await repo.load(id: original.id) == original)
    #expect(try await repo.loadPending(sessionID: original.id)?.input == "Sie entscheiden.")
}

@Test(arguments: [false, true]) func storageFailureRetriesPreparedTurnWithoutAnotherModelCall(afterCommit: Bool) async throws {
    let repo = FailingCommitRepository(afterCommit: afterCommit), provider = ControlledProvider()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let original = try await coordinator.create(content: TestData.content, contentHash: "test")
    await #expect(throws: TrainerFailure.storageUnavailable) { try await coordinator.send(sessionID: original.id, input: "Sie entscheiden.") }
    let saved = try await coordinator.send(sessionID: original.id, input: "Sie entscheiden.")
    #expect(saved.revision == 1 && saved.turns.count == 1)
    #expect(await provider.analyses == 1)
    #expect(await provider.replies == 1)
}

@Test func deletionWhileReplyRunsCannotRecreateSession() async throws {
    let repo = MemorySessionRepository(), provider = ControlledProvider(.heldReply)
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let original = try await coordinator.create(content: TestData.content, contentHash: "test")
    let task = Task { try await coordinator.send(sessionID: original.id, input: "Sie entscheiden.") }
    await provider.waitUntilReply(); await repo.delete(id: original.id); await provider.release()
    await #expect(throws: TrainerFailure.sessionNotFound) { try await task.value }
    #expect(await repo.list().isEmpty)
}

@Test func lastTurnRetryWorksAfterUnknownCommitOutcome() async throws {
    let repo = FailingCommitRepository(afterCommit: true), provider = ControlledProvider()
    await repo.setFailure(false)
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let session = try await coordinator.create(content: TestData.content, contentHash: "test")
    for index in 0..<19 { _ = try await coordinator.send(sessionID: session.id, input: "Beitrag \(index)") }
    await repo.setFailure(true)
    await #expect(throws: TrainerFailure.storageUnavailable) { try await coordinator.send(sessionID: session.id, input: "Letzter Beitrag") }
    let saved = try await coordinator.send(sessionID: session.id, input: "Letzter Beitrag")
    #expect(saved.turns.count == 20 && saved.revision == 20)
    #expect(await provider.replies == 20)
    await #expect(throws: TrainerFailure.sessionCompleted) { try await coordinator.send(sessionID: session.id, input: "Einer zu viel") }
}

@Test func lockedFactCannotAuthorizeItselfDuringCommit() throws {
    var record = SessionRecord(snapshot: TestData.session())
    let pending = PendingTurn(id: UUID(), sessionID: record.snapshot.id, expectedRevision: 0, input: "Hallo", createdAt: Date())
    try RepositoryRules.savePending(pending, in: &record)
    var forged = record.snapshot.state; forged.disclosedFactIDs.insert("lukas.vater")
    let turn = CompletedTurn(id: pending.id, input: pending.input, analysis: nil,
        reply: .init(text: "Mein Vater …", primaryTag: nil, disclosedFactIDs: ["lukas.vater"]),
        stateBefore: record.snapshot.state, stateAfter: forged, stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date())
    #expect(throws: TrainerFailure.invalidReply) { try RepositoryRules.commit(turn, expectedRevision: 0, in: &record) }
    #expect(record.snapshot.revision == 0)
}

@Test func finishRequiresDiscardingPendingAndIsIdempotent() async throws {
    let repo = MemorySessionRepository(), session = TestData.session(), date = Date()
    try await repo.create(session)
    let pending = PendingTurn(id: UUID(), sessionID: session.id, expectedRevision: 0, input: "Entwurf", createdAt: date)
    try await repo.savePending(pending)
    await #expect(throws: TrainerFailure.revisionConflict) { try await repo.finish(sessionID: session.id, expectedRevision: 0, endedAt: date) }
    try await repo.discardPending(sessionID: session.id, turnID: pending.id)
    let done = try await repo.finish(sessionID: session.id, expectedRevision: 0, endedAt: date)
    #expect(try await repo.finish(sessionID: session.id, expectedRevision: 0, endedAt: date) == done)
}

// MARK: - Gesamtfrist je Gesprächsrunde

/// Anbieter, der langsam, aber abbrechbar ist. Die Frist setzt voraus, dass der Anbieter
/// Cancellation beachtet; der echte Adapter tut das über `URLSession`. Ein Anbieter, der
/// sie ignoriert (`ControlledProvider(.heldReply)`), taugt für diese Prüfung nicht.
actor SlowProvider: TrainerModelProvider {
    let delay: Duration
    var analyses = 0
    var replies = 0
    init(delay: Duration) { self.delay = delay }
    func descriptor() -> ModelDescriptor { TestData.model }
    func prepare() {}
    func unload() {}
    func analyze(_ request: AnalysisRequest) async throws -> ModelResult<TurnAnalysis> {
        analyses += 1
        try await Task.sleep(for: delay)
        return .init(value: .init(segments: [.init(quote: request.currentInput, code: .autonomy, isUncertain: false)]),
                     metrics: .init(durationSeconds: 0.1), contextMessagesUsed: request.recentMessages)
    }
    func reply(_ request: ReplyRequest) async throws -> ModelResult<ClientReply> {
        replies += 1
        try await Task.sleep(for: delay)
        return .init(value: .init(text: "Das entscheide ich selbst.", primaryTag: nil, disclosedFactIDs: []),
                     metrics: .init(durationSeconds: 0.1), contextMessagesUsed: request.recentMessages)
    }
}

@Test func rundenfristBrichtEineHaengendeRundeAbUndSpeichertNichtsHalbes() async throws {
    // Ohne Frist liefe diese Runde zehn Sekunden weiter; im Betrieb sind es bis zu zwölf
    // HTTP-Aufrufe mit je 150 Sekunden Aufruffrist.
    let repo = MemorySessionRepository(), provider = SlowProvider(delay: .seconds(10))
    let coordinator = ConversationCoordinator(repository: repo, provider: provider,
                                              roundDeadline: .milliseconds(100))
    let original = try await coordinator.create(content: TestData.content, contentHash: "test")
    let start = ContinuousClock.now
    await #expect(throws: TrainerFailure.roundDeadlineExceeded) {
        try await coordinator.send(sessionID: original.id, input: "Sie entscheiden.")
    }
    #expect(start.duration(to: .now) < .seconds(5))
    // Kein halber Zustand: die Sitzung ist unverändert, der Beitrag bleibt als Entwurf.
    #expect(try await repo.load(id: original.id) == original)
    #expect(try await repo.loadPending(sessionID: original.id)?.input == "Sie entscheiden.")
    // Die Frist hat den laufenden Aufruf abgebrochen, nicht bloß den nächsten verhindert.
    #expect(await provider.analyses == 1)
    #expect(await provider.replies == 0)
}

@Test func rundenfristGiltUeberAlleStufenHinwegUndNichtJeAufruf() async throws {
    // Jede Stufe für sich bleibt unter der Frist; zusammen überschreiten sie sie. Genau das
    // ist der Unterschied zur vorhandenen Frist je HTTP-Aufruf.
    let repo = MemorySessionRepository(), provider = SlowProvider(delay: .milliseconds(300))
    let coordinator = ConversationCoordinator(repository: repo, provider: provider,
                                              roundDeadline: .milliseconds(500))
    let original = try await coordinator.create(content: TestData.content, contentHash: "test")
    await #expect(throws: TrainerFailure.roundDeadlineExceeded) {
        try await coordinator.send(sessionID: original.id, input: "Sie entscheiden.")
    }
    #expect(await provider.analyses == 1)
    #expect(await provider.replies == 1)
    #expect(try await repo.load(id: original.id) == original)
}

@Test func rundeInnerhalbDerFristWirdGanzNormalGespeichert() async throws {
    // Gegenprobe: die Frist darf den gesunden Fall nicht kappen.
    let repo = MemorySessionRepository(), provider = SlowProvider(delay: .milliseconds(10))
    let coordinator = ConversationCoordinator(repository: repo, provider: provider,
                                              roundDeadline: .seconds(30))
    let original = try await coordinator.create(content: TestData.content, contentHash: "test")
    let saved = try await coordinator.send(sessionID: original.id, input: "Sie entscheiden selbst.")
    #expect(saved.revision == 1 && saved.turns.count == 1)
    #expect(try await repo.loadPending(sessionID: original.id) == nil)
}

@Test func fristablaufIstEinEigenerFallUndKeinModellausfall() {
    // Die Gegenseite war erreichbar; sie hat nur zu lange gebraucht. Die Meldung muss das
    // sagen und darf nicht zur Netzprüfung auffordern.
    let text = try! #require(TrainerFailure.roundDeadlineExceeded.errorDescription)
    #expect(text.contains("zu lange"))
    #expect(text != TrainerFailure.modelUnavailable.errorDescription)
}
