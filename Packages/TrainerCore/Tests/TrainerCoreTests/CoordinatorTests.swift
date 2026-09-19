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
