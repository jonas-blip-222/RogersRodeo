import Foundation
import Testing
import TrainerCore
import TrainerStorage

// Vorgegebene fiktive Modellantworten prüfen Coordinator und echten Speicher gemeinsam.
// Der Anbieter entscheidet keine Semantik und hat insbesondere kein Erlaubnisgedächtnis.
private actor PermissionFlowProvider: TrainerModelProvider {
    static let question = "Möchten Sie eine Idee zum Festhalten hören?"
    static let firstAdvice = "Sie könnten eine kurze Notiz machen."
    static let secondAdvice = "Sie könnten zusätzlich eine Erinnerung stellen."
    static let renewedQuestion = "Möchten Sie noch eine weitere Idee hören?"
    static let renewedAdvice = "Sie könnten Ihre Notiz an die Tür hängen."
    static let consent = "Ja, gerne."
    var rejectsAdviceReply = false
    var events: [String] = []
    var contexts: [String: [DialogueMessage]] = [:]

    func descriptor() -> ModelDescriptor { DemoModelProvider.identity }
    func prepare() {}
    func unload() {}
    func rejectAdviceReply(_ value: Bool) { rejectsAdviceReply = value }
    func noteFeedback() { events.append("feedback") }

    func analyze(_ request: AnalysisRequest) throws -> ModelResult<TurnAnalysis> {
        events.append("analysis")
        contexts[request.currentInput] = request.recentMessages
        let input = request.currentInput
        let own = EvidenceReference(source: .currentInput, speaker: .counselor,
                                    messageIndex: nil, quote: input, occurrence: 1)
        func reference(_ text: String, speaker: Speaker) throws -> EvidenceReference {
            let index = try #require(request.recentMessages.lastIndex { $0.text == text && $0.speaker == speaker })
            return .init(source: .contextMessage, speaker: speaker, messageIndex: index,
                         quote: text, occurrence: 1)
        }
        let code: CounselorCode
        let entries: [PermissionAssessment]
        switch input {
        case Self.firstAdvice, Self.renewedAdvice:
            code = .adviceWithPermission
            entries = [.init(advice: own, standing: .granted,
                request: try reference(input == Self.firstAdvice ? Self.question : Self.renewedQuestion,
                                       speaker: .counselor),
                response: try reference(Self.consent, speaker: .client))]
        case Self.secondAdvice:
            code = .adviceWithoutPermission
            entries = [.init(advice: own, standing: .consumed,
                request: try reference(Self.question, speaker: .counselor),
                response: try reference(Self.consent, speaker: .client),
                consumedBy: try reference(Self.firstAdvice, speaker: .counselor))]
        case "Sie könnten es aufschreiben.":
            // Bewusst sicher behauptete Modellantwort: Der Coordinator muss die reale
            // Kontextlücke unabhängig davon erkennen und das Feedback zurücknehmen.
            code = .adviceWithoutPermission
            entries = [.init(advice: own, standing: .notRequested)]
        default:
            code = .other
            entries = []
        }
        return .init(value: .init(segments: [.init(quote: input, code: code, isUncertain: false)],
                                 permissions: entries),
                     metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }

    func reply(_ request: ReplyRequest) throws -> ModelResult<ClientReply> {
        events.append("reply")
        if rejectsAdviceReply && request.currentInput == Self.firstAdvice { throw TrainerFailure.invalidReply }
        let text = [Self.question, Self.renewedQuestion].contains(request.currentInput) ? Self.consent : "Hm."
        return .init(value: .init(text: text, primaryTag: nil, disclosedFactIDs: []),
                     metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }
}

private func permissionFlowContent() -> SessionContent {
    .init(scenario: .init(schemaVersion: 1, id: "permission-flow-test", version: "1", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Ich möchte mich an meine eigenen Ideen erinnern.", publicProfile: "Fiktive Testfigur", facts: []),
        codingGuide: "Kontrollierter Testbetrieb", tips: [])
}

@Test @MainActor func erlaubnisUndVerbrauchUeberstehenSpeicherneustartUndAntwortfehler() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("rr-permission-flow-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("sessions.store")
    let provider = PermissionFlowProvider()
    var repository: SwiftDataSessionRepository? = try .init(storeURL: url)
    var coordinator: ConversationCoordinator? = .init(repository: try #require(repository), provider: provider)
    let initial = try await #require(coordinator).create(content: permissionFlowContent(), contentHash: "test")
    let sink: FeedbackSink = { _ in await provider.noteFeedback() }
    let asked = try await #require(coordinator).send(sessionID: initial.id,
        input: PermissionFlowProvider.question, onFeedback: sink)
    #expect(asked.turns[0].reply.text == PermissionFlowProvider.consent)

    // Eine bestätigte Analyse allein darf noch keinen halben Turn speichern.
    await provider.rejectAdviceReply(true)
    await #expect(throws: TrainerFailure.invalidReply) {
        try await #require(coordinator).send(sessionID: initial.id,
            input: PermissionFlowProvider.firstAdvice, onFeedback: sink)
    }
    #expect(try #require(repository).load(id: initial.id) == asked)
    let storedPending = try #require(repository).loadPending(sessionID: initial.id)
    let pending = try #require(storedPending)
    coordinator = nil
    repository = nil

    repository = try .init(storeURL: url)
    #expect(try #require(repository).loadPending(sessionID: initial.id) == pending)
    coordinator = .init(repository: try #require(repository), provider: provider)
    await provider.rejectAdviceReply(false)
    let first = try await #require(coordinator).send(sessionID: initial.id,
        input: PermissionFlowProvider.firstAdvice, onFeedback: sink)
    let firstTurn = try #require(first.turns.last)
    #expect(firstTurn.id == pending.id)
    #expect(firstTurn.feedback.map(\.ruleID) == ["rueckmeldung.rat_mit_erlaubnis"])
    #expect(firstTurn.feedback.first?.evidence.count == 3)
    #expect(try #require(repository).loadPending(sessionID: initial.id) == nil)
    coordinator = nil
    repository = nil

    // Erneut öffnen: keine In-Memory-Vereinbarung trägt den zweiten Ratschlag.
    repository = try .init(storeURL: url)
    let loaded = try #require(repository).load(id: initial.id)
    #expect(loaded == first)
    #expect(loaded.turns.last?.analysis?.permissions == firstTurn.analysis?.permissions)
    #expect(try #require(repository).commit(sessionID: initial.id, expectedRevision: 1, turn: firstTurn) == first)
    var altered = firstTurn
    altered.analysis?.permissions?[0].standing = .unclear
    #expect(throws: TrainerFailure.revisionConflict) {
        try #require(repository).commit(sessionID: initial.id, expectedRevision: 1, turn: altered)
    }
    coordinator = .init(repository: try #require(repository), provider: provider)
    let second = try await #require(coordinator).send(sessionID: initial.id,
        input: PermissionFlowProvider.secondAdvice, onFeedback: sink)
    #expect(second.turns.last?.feedback.map(\.ruleID) == ["warnung.erlaubnis_bereits_verbraucht"])
    #expect(second.turns.last?.feedback.first?.certainty == .confirmed)

    _ = try await #require(coordinator).send(sessionID: initial.id,
        input: PermissionFlowProvider.renewedQuestion, onFeedback: sink)
    let renewed = try await #require(coordinator).send(sessionID: initial.id,
        input: PermissionFlowProvider.renewedAdvice, onFeedback: sink)
    #expect(renewed.turns.count == 5)
    #expect(renewed.turns.last?.feedback.map(\.ruleID) == ["rueckmeldung.rat_mit_erlaubnis"])
    #expect(renewed.turns.prefix(2).map(\.feedback) == first.turns.map(\.feedback))
    // Auch nach Neustart bleiben alle Herkunftsangaben gegen den gesehenen Kontext prüfbar.
    let contexts = await provider.contexts
    for turn in renewed.turns {
        let context = try #require(contexts[turn.input])
        for finding in turn.feedback {
            for evidence in finding.evidence {
                try OutputValidator.validateEvidence(evidence, input: turn.input, context: context)
            }
        }
    }
    let events = await provider.events
    #expect(Array(events.suffix(3)) == ["analysis", "feedback", "reply"])
}

@Test @MainActor func echtesKontextfensterVerhindertSicherenErlaubnisvorwurf() async throws {
    for count in [0, 7] {
        let repo = try SwiftDataSessionRepository(inMemory: true)
        let provider = PermissionFlowProvider()
        let coordinator = ConversationCoordinator(repository: repo, provider: provider)
        let initial = try await coordinator.create(content: permissionFlowContent(), contentHash: "test")
        for index in 0..<count {
            _ = try await coordinator.send(sessionID: initial.id, input: "Testbeitrag \(index)")
        }
        let result = try await coordinator.send(sessionID: initial.id, input: "Sie könnten es aufschreiben.")
        let turn = try #require(result.turns.last)
        #expect(turn.analysis?.permissions?.first?.isUncertain == false)
        #expect(turn.feedback.map(\.ruleID) == ["warnung.rat_ohne_erlaubnis"])
        #expect(turn.feedback.first?.certainty == (count == 0 ? .confirmed : .possible))
        let seen = try #require(await provider.contexts[turn.input])
        #expect(seen.count == (count == 0 ? 1 : 13))
    }
}
