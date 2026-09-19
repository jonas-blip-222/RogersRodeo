import Foundation

public actor ConversationCoordinator {
    private let repository: any SessionRepository
    private let provider: any TrainerModelProvider
    private var generation: UUID?
    private var prepared: (sessionID: UUID, revision: Int, turn: CompletedTurn)?
    public init(repository: any SessionRepository, provider: any TrainerModelProvider) {
        self.repository = repository; self.provider = provider
    }
    private func check(_ token: UUID) throws {
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
    }
    public func cancel() { generation = nil; prepared = nil }

    public func create(content: SessionContent, contentHash: String) async throws -> SessionSnapshot {
        guard generation == nil else { throw TrainerFailure.operationInProgress }
        let token = UUID(); generation = token
        defer { if generation == token { generation = nil } }
        try OutputValidator.validateScenario(content.scenario, allowDrafts: true)
        try await provider.prepare(); try check(token)
        let descriptor = await provider.descriptor(); try check(token)
        let snapshot = SessionSnapshot(schemaVersion: 1, id: UUID(), revision: 0, approachID: "mi",
            identity: .init(contentHash: contentHash, rulesVersion: "0.1", promptVersion: "0.1", model: descriptor),
            content: content, state: .init(openness: content.scenario.opennessStart), turns: [], status: .active, startedAt: Date())
        try await repository.create(snapshot)
        return snapshot
    }

    public func send(sessionID: UUID, input: String, skipAnalysis: Bool = false) async throws -> SessionSnapshot {
        guard generation == nil else { throw TrainerFailure.operationInProgress }
        let token = UUID(); generation = token
        defer { if generation == token { generation = nil } }
        let session = try await repository.load(id: sessionID); try check(token)
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 1500 else { throw TrainerFailure.invalidInput }

        // Nach einem Speicherfehler denselben Turn sichern, ohne erneut zu generieren.
        if let prepared, prepared.sessionID == sessionID, prepared.turn.input == text {
            let saved = try await repository.commit(sessionID: sessionID, expectedRevision: prepared.revision, turn: prepared.turn)
            if generation == token { self.prepared = nil }
            return saved
        }
        guard session.status == .active, session.turns.count < 20 else { throw TrainerFailure.sessionCompleted }
        let descriptor = await provider.descriptor(); try check(token)
        guard session.identity.rulesVersion == "0.1", session.identity.promptVersion == "0.1",
              session.identity.model == descriptor else { throw TrainerFailure.unsupportedVersion }
        prepared = nil
        let oldPending = try await repository.loadPending(sessionID: sessionID); try check(token)
        var pending: PendingTurn
        if let oldPending, oldPending.input == text { pending = oldPending }
        else {
            if let oldPending {
                try await repository.discardPending(sessionID: sessionID, turnID: oldPending.id); try check(token)
            }
            pending = PendingTurn(id: UUID(), sessionID: sessionID, expectedRevision: session.revision, input: text, createdAt: Date())
            try await repository.savePending(pending); try check(token)
        }
        try await provider.prepare(); try check(token)
        let messages = ContextBuilder.messages(session)
        let request = AnalysisRequest(codingGuide: session.content.codingGuide, recentMessages: messages, currentInput: text)
        var analysis: TurnAnalysis?
        var analysisContext = messages
        var metrics: [ModelCallMetrics] = []
        if !skipAnalysis {
            for attempt in 0...1 {
                do {
                    let result = try await provider.analyze(request); try check(token)
                    try OutputValidator.validateAnalysis(result.value, input: text, context: result.contextMessagesUsed)
                    analysis = result.value; analysisContext = result.contextMessagesUsed; metrics.append(result.metrics)
                    break
                } catch TrainerFailure.invalidAnalysis where attempt == 0 { try check(token) }
            }
        }
        let reduction = try StateReducer.reduce(session.state, analysis: analysis, input: text, context: analysisContext)
        let visible = ContextBuilder.visibleFacts(session.content.scenario, state: reduction.state)
        let replyRequest = ReplyRequest(publicProfile: session.content.scenario.publicProfile,
            behaviorInstruction: ContextBuilder.behavior(reduction.state.openness), visibleFacts: visible,
            recentMessages: messages, currentInput: text, analysis: analysis)
        var replyResult: ModelResult<ClientReply>?
        for attempt in 0...1 {
            do {
                let result = try await provider.reply(replyRequest); try check(token)
                try OutputValidator.validateReply(result.value, visibleFacts: visible)
                replyResult = result; break
            } catch TrainerFailure.invalidReply where attempt == 0 { try check(token) }
        }
        guard let replyResult else { throw TrainerFailure.invalidReply }
        metrics.append(replyResult.metrics)
        var after = reduction.state
        after.disclosedFactIDs.formUnion(replyResult.value.disclosedFactIDs)
        let tip = TipSelector.select(tag: replyResult.value.primaryTag, approach: session.approachID,
                                     tips: session.content.tips, previousID: session.turns.last?.selectedTipID)
        let turn = CompletedTurn(id: pending.id, input: text, analysis: analysis, reply: replyResult.value,
            stateBefore: session.state, stateAfter: after, stateChangeReasons: reduction.reasons,
            selectedTipID: tip?.id, metrics: metrics, completedAt: Date())
        try check(token)
        prepared = (sessionID, session.revision, turn)
        let saved = try await repository.commit(sessionID: sessionID, expectedRevision: session.revision, turn: turn)
        // Commit ist der atomare Übergabepunkt; ein bereits gespeicherter Turn bleibt erhalten.
        if generation == token { prepared = nil }
        return saved
    }
}
