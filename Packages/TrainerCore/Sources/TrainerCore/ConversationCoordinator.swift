import Foundation

/// Gesamtfrist für eine Gesprächsrunde, über alle Stufen und Wiederholungen hinweg.
///
/// **Warum hier und nicht im Adapter.** Die Runde wird im `ConversationCoordinator`
/// koordiniert; der Adapter sieht nur einzelne Aufrufe. `analyze` und `reply` sind
/// getrennte Aufrufe, und die vollständige Wiederholung von `analyze` steht ebenfalls hier.
/// Eine Frist im Adapter bräuchte rundenbezogenen Zustand in einem geteilten Actor und
/// wüsste weiterhin nichts von der Wiederholung des Coordinators. Ein Wecker ist reine
/// Nebenläufigkeit — `TrainerCore` bekommt dadurch keinen Netzcode und gilt für jeden
/// Anbieter, auch für den Demo-Anbieter und spätere Adapter.
///
/// **Warum nur um die Modellaufrufe.** Die Frist umschließt ausdrücklich nicht
/// `repository.commit`. Ein Fristablauf kann deshalb nur vor dem Übergabepunkt eintreten:
/// Der Turn ist danach entweder vollständig gespeichert oder gar nicht. Die atomare
/// Turn-Transaktion und die Wiederaufnahme über `prepared` bleiben unberührt.
public enum RoundDeadline {
    /// 120 Sekunden ab Beginn der Runde.
    ///
    /// Begründung, keine eigene Messung: Der Median einer erfolgreichen Analysestufe lag in
    /// der Messreihe vom 29.09.2026 bei 5,7 Sekunden; eine gesunde Runde aus zwei
    /// Analysestufen und einer Rollenantwort bleibt weit darunter. Die größte dort
    /// beobachtete Einzellücke durch einen abgeschnittenen Erstversuch betrug 84,6 Sekunden
    /// und passt damit noch hinein — die Frist kappt also nicht den bekannten Normalfall
    /// mit Wiederholung, sondern das Weiterlaufen darüber hinaus. Ohne sie erlaubt die
    /// Aufrufkette zwölf HTTP-Aufrufe mit je 150 Sekunden Aufruffrist, also rund 30 Minuten
    /// mit der Anzeige „Antwort wird vorbereitet …".
    public static let standard = Duration.seconds(120)

    /// Führt `work` gegen die Frist aus. Läuft sie ab, wird `work` abgebrochen und
    /// `TrainerFailure.roundDeadlineExceeded` geworfen. Ein Abbruch von außen bleibt ein
    /// `CancellationError` und wird nicht in einen Fristablauf umgedeutet.
    ///
    /// **Voraussetzung:** `work` muss Cancellation beachten. Der OpenRouter-Adapter tut das
    /// (`URLSession.data(for:)` bricht ab und wird zu `CancellationError`); ein Anbieter,
    /// der sie ignoriert, verzögert die Rückkehr bis zu seinem eigenen Ende. Dieselbe
    /// Annahme trifft der Coordinator schon für die vorhandene Abbruchmöglichkeit.
    static func run<T: Sendable>(until instant: ContinuousClock.Instant,
                                 _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try Task.checkCancellation()
        guard ContinuousClock.now < instant else { throw TrainerFailure.roundDeadlineExceeded }
        return try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(until: instant, clock: ContinuousClock())
                return nil
            }
            defer { group.cancelAll() }
            // Das erste fertige Kind entscheidet: ein Wert ist das Ergebnis, `nil` ist der
            // Wecker. Der jeweils andere Zweig wird beim Verlassen der Gruppe abgebrochen.
            guard let first = try await group.next() else { throw TrainerFailure.roundDeadlineExceeded }
            guard let value = first else { throw TrainerFailure.roundDeadlineExceeded }
            return value
        }
    }
}

public actor ConversationCoordinator {
    public static let promptVersion = "0.5"
    public static let rulesVersion = "0.4"
    private let repository: any SessionRepository
    private let provider: any TrainerModelProvider
    private var generation: UUID?
    private var prepared: (sessionID: UUID, revision: Int, turn: CompletedTurn)?
    /// Gesamtfrist je Runde; siehe `RoundDeadline`. Als Parameter, damit Tests sie
    /// verkürzen können, ohne auf echte Wartezeiten angewiesen zu sein.
    private let roundDeadline: Duration
    public init(repository: any SessionRepository, provider: any TrainerModelProvider,
                roundDeadline: Duration = RoundDeadline.standard) {
        self.repository = repository; self.provider = provider; self.roundDeadline = roundDeadline
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
            identity: .init(contentHash: contentHash, rulesVersion: Self.rulesVersion, promptVersion: Self.promptVersion, model: descriptor),
            content: content, state: .init(openness: content.scenario.opennessStart), turns: [], status: .active, startedAt: Date())
        try await repository.create(snapshot)
        return snapshot
    }

    public func send(sessionID: UUID, input: String, skipAnalysis: Bool = false,
                     onFeedback: FeedbackSink? = nil) async throws -> SessionSnapshot {
        let sink = try await provider.modelTrace()
        let roundID = UUID()
        let context = ModelTraceContext(roundID: roundID)
        return try await ModelTraceScope.$context.withValue(context) {
            let start = ContinuousClock.now
            var event = ModelTraceEvent(kind: .roundStarted, id: roundID)
            try sink?.record(event)
            do {
                let saved = try await sendMeasured(sessionID: sessionID, input: input,
                                                   skipAnalysis: skipAnalysis, onFeedback: onFeedback)
                event.kind = .roundFinished; event.timestamp = Date().timeIntervalSince1970
                event.durationSeconds = ModelTraceEvent.seconds(start.duration(to: .now))
                event.result = "completed"
                // Der Commit ist bereits erfolgt. Ein Diagnosefehler darf daraus keinen
                // scheinbaren Speicherfehler machen und ein zweites Senden provozieren.
                do { try sink?.record(event) }
                catch { print("Messspur unvollständig: Rundenabschluss konnte nach erfolgreichem Speichern nicht geschrieben werden.") }
                return saved
            } catch {
                // Ein gescheiterter Schreibversuch wird nicht als zweiter Abschluss gemeldet.
                if event.kind != .roundFinished {
                    event.kind = .roundFinished; event.timestamp = Date().timeIntervalSince1970
                    event.durationSeconds = ModelTraceEvent.seconds(start.duration(to: .now))
                    event.result = ModelTraceEvent.resultCode(error)
                    try sink?.record(event)
                }
                throw error
            }
        }
    }

    private func sendMeasured(sessionID: UUID, input: String, skipAnalysis: Bool,
                              onFeedback: FeedbackSink?) async throws -> SessionSnapshot {
        guard generation == nil else { throw TrainerFailure.operationInProgress }
        let token = UUID(); generation = token
        defer { if generation == token { generation = nil } }
        // Beginn der Runde. Ab hier gilt eine Gesamtfrist über alle Stufen und
        // Wiederholungen hinweg; siehe `RoundDeadline`.
        let deadline = ContinuousClock.now.advanced(by: roundDeadline)
        let model = provider
        let session = try await repository.load(id: sessionID); try check(token)
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 1500 else { throw TrainerFailure.invalidInput }

        // Nach einem Speicherfehler denselben Turn sichern, ohne erneut zu generieren.
        // Die Rückmeldung wird dabei nicht neu berechnet, sondern aus dem vorbereiteten Turn
        // noch einmal gemeldet: derselbe Turn, dieselben Befunde, keine doppelten Einträge.
        if let prepared, prepared.sessionID == sessionID, prepared.turn.input == text {
            if let onFeedback {
                await onFeedback(.init(sessionID: sessionID, turnID: prepared.turn.id,
                                       expectedRevision: prepared.revision, attempt: token, input: text,
                                       analysisAvailable: prepared.turn.analysis != nil,
                                       findings: prepared.turn.feedback))
                try check(token)
            }
            let saved = try await repository.commit(sessionID: sessionID, expectedRevision: prepared.revision, turn: prepared.turn)
            if generation == token { self.prepared = nil }
            return saved
        }
        guard session.status == .active, session.turns.count < 20 else { throw TrainerFailure.sessionCompleted }
        let descriptor = await provider.descriptor(); try check(token)
        guard session.identity.rulesVersion == Self.rulesVersion, session.identity.promptVersion == Self.promptVersion,
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
        let memory = try ContextBuilder.analysisMemory(session)
        let request = AnalysisRequest(codingGuide: session.content.codingGuide, recentMessages: memory.messages,
                                      currentInput: text, knownGoals: memory.goals, omittedGoalCount: memory.omittedGoalCount)
        var analysis: TurnAnalysis?
        var analysisContext = memory.messages
        var metrics: [ModelCallMetrics] = []
        var development = session.state.development
        if !skipAnalysis {
            for attempt in 0...1 {
                do {
                    var context = ModelTraceScope.context; context.coordinatorAttempt = attempt + 1
                    let result = try await ModelTraceScope.$context.withValue(context) {
                        try await RoundDeadline.run(until: deadline) { try await model.analyze(request) }
                    }; try check(token)
                    try OutputValidator.validateAnalysis(result.value, input: text, context: result.contextMessagesUsed)
                    development = try CharacterTracker.advance(session.state.development, analysis: result.value,
                        input: text, context: result.contextMessagesUsed, session: session, turnID: pending.id)
                    try CharacterTracker.validate(development, session: session, currentTurnID: pending.id)
                    analysis = result.value; analysisContext = result.contextMessagesUsed; metrics.append(result.metrics)
                    break
                } catch TrainerFailure.invalidAnalysis where attempt == 0 {
                    try check(token)
                    var event = ModelTraceEvent(kind: .coordinatorRetry)
                    event.coordinatorAttempt = 2; event.retryReason = "invalidAnalysis"
                    try await provider.modelTrace()?.record(event)
                }
            }
        }
        // Abschnitt 9.3: sobald die Analyse validiert ist, geht die Rückmeldung an die
        // Oberfläche — vor der Figurenantwort und noch ohne gespeicherten Turn. Sie ist an
        // Sitzung, PendingTurn, erwartete Revision und diesen Ausführungsversuch gebunden.
        // Die Befunde entstehen allein aus Eingabe und bereits vorhandenem Kontext; die
        // Antwort von Lukas existiert an dieser Stelle noch nicht und kann sie nicht färben.
        let findings = FeedbackEngine.findings(analysis: analysis, input: text, context: analysisContext,
                                               characterName: session.content.scenario.name,
                                               rulesVersion: session.identity.rulesVersion)
        if let onFeedback {
            await onFeedback(.init(sessionID: sessionID, turnID: pending.id,
                                   expectedRevision: session.revision, attempt: token, input: text,
                                   analysisAvailable: analysis != nil, findings: findings))
            try check(token)
        }
        let reduction = try StateReducer.reduce(session.state, analysis: analysis, input: text, context: analysisContext)
        let visible = ContextBuilder.visibleFacts(session.content.scenario, state: reduction.state)
        let replyRequest = ReplyRequest(publicProfile: session.content.scenario.publicProfile,
            behaviorInstruction: ContextBuilder.behavior(reduction.state.openness), visibleFacts: visible,
            recentMessages: messages, currentInput: text, analysis: analysis)
        var replyResult: ModelResult<ClientReply>?
        for attempt in 0...1 {
            do {
                var context = ModelTraceScope.context; context.coordinatorAttempt = attempt + 1
                let result = try await ModelTraceScope.$context.withValue(context) {
                    try await RoundDeadline.run(until: deadline) { try await model.reply(replyRequest) }
                }; try check(token)
                try OutputValidator.validateReply(result.value, visibleFacts: visible)
                replyResult = result; break
            } catch TrainerFailure.invalidReply where attempt == 0 {
                try check(token)
                var event = ModelTraceEvent(kind: .coordinatorRetry)
                event.coordinatorAttempt = 2; event.stage = .roleReply; event.retryReason = "invalidReply"
                try await provider.modelTrace()?.record(event)
            }
        }
        guard let replyResult else { throw TrainerFailure.invalidReply }
        metrics.append(replyResult.metrics)
        var after = reduction.state
        after.development = development
        after.disclosedFactIDs.formUnion(replyResult.value.disclosedFactIDs)
        let tip = TipSelector.select(tag: replyResult.value.primaryTag, approach: session.approachID,
                                     tips: session.content.tips, previousID: session.turns.last?.selectedTipID)
        let turn = CompletedTurn(id: pending.id, input: text, analysis: analysis, reply: replyResult.value,
            stateBefore: session.state, stateAfter: after, stateChangeReasons: reduction.reasons,
            selectedTipID: tip?.id, metrics: metrics, completedAt: Date(), feedback: findings)
        try check(token)
        prepared = (sessionID, session.revision, turn)
        let saved = try await repository.commit(sessionID: sessionID, expectedRevision: session.revision, turn: turn)
        // Commit ist der atomare Übergabepunkt; ein bereits gespeicherter Turn bleibt erhalten.
        if generation == token { prepared = nil }
        return saved
    }
}
