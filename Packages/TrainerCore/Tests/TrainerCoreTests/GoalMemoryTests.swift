import Foundation
import Testing
@testable import TrainerCore

private func ref(_ quote: String, _ index: Int = 0, _ speaker: Speaker = .client) -> EvidenceReference {
    .init(source: .contextMessage, speaker: speaker, messageIndex: index, quote: quote, occurrence: 1)
}
private func session() -> SessionSnapshot {
    var s = TestData.session(); s.content.scenario.openingLine = "Ich möchte weniger trinken."; return s
}
private func append(_ s: inout SessionSnapshot, _ reply: String, input: String = "Und weiter?", id: UUID = UUID()) {
    s.turns.append(.init(id: id, input: input, analysis: nil,
        reply: .init(text: reply, primaryTag: nil, disclosedFactIDs: []), stateBefore: s.state, stateAfter: s.state,
        stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
}
private func apply(_ s: inout SessionSnapshot, _ updates: [GoalUpdate], observations: [CharacterObservation] = []) throws {
    let id = UUID()
    let context = [.init(speaker: Speaker.client, text: s.content.scenario.openingLine,
                         origin: MessageOrigin(turnID: nil, speaker: .client))] + s.turns.flatMap { t in
        [DialogueMessage(speaker: .counselor, text: t.input, origin: .init(turnID: t.id, speaker: .counselor)),
         DialogueMessage(speaker: .client, text: t.reply.text, origin: .init(turnID: t.id, speaker: .client))]
    }
    s.state.development = try CharacterTracker.advance(s.state.development,
        analysis: .init(segments: [], characterObservations: observations, goalUpdates: updates),
        input: "Weiter", context: context, session: s, turnID: id)
    try CharacterTracker.validate(s.state.development, session: s, currentTurnID: id)
    append(&s, "Hm.", id: id)
}
private func introduce(_ s: inout SessionSnapshot) throws {
    try apply(&s, [.init(kind: .introduced, currentGoal: ref(s.content.scenario.openingLine), evidence: ref(s.content.scenario.openingLine))])
}

@Test func zielErinnertOriginalNachMehrAlsSechsTurns() throws {
    var s = session()
    append(&s, "Ich möchte sonntags fitter sein.")
    try apply(&s, [.init(kind: .introduced, currentGoal: ref(s.turns[0].reply.text, 2), evidence: ref(s.turns[0].reply.text, 2))])
    for _ in 0..<8 { append(&s, "Hm.") }
    let memory = try ContextBuilder.analysisMemory(s)
    #expect(!ContextBuilder.messages(s).contains { $0.origin?.turnID == s.turns[0].id })
    #expect(memory.messages.contains { $0.origin?.turnID == s.turns[0].id })
    #expect(memory.goals.count == 1 && memory.omittedGoalCount == 0)
    try OutputValidator.validateEvidence(memory.goals[0].goal, input: "", context: memory.messages)
    #expect(memory.messages.count == 15)
}

@Test func umformulierungTeiltVerlaufAberAbstinenzBleibtNeuesZiel() throws {
    var s = session(); try introduce(&s)
    append(&s, "Ich will meinen Konsum reduzieren.")
    try apply(&s, [.init(kind: .rephrased, previousGoal: ref(s.content.scenario.openingLine),
        currentGoal: ref(s.turns[1].reply.text, 4), evidence: ref(s.turns[1].reply.text, 4))], observations: [
            .init(dimension: .confidence, assessment: .doubtful, goal: ref(s.turns[1].reply.text, 4),
                  evidence: ref(s.turns[1].reply.text, 4), isUncertain: true)])
    #expect(s.state.development?.goals.count == 1)
    #expect(s.state.development?.goals[0].memory?.aliases.count == 1)
    append(&s, "Statt weniger will ich gar nichts mehr trinken.")
    try apply(&s, [.init(kind: .replaced, previousGoal: ref(s.content.scenario.openingLine),
        currentGoal: ref(s.turns[3].reply.text, 8), evidence: ref(s.turns[3].reply.text, 8))])
    #expect(s.state.development?.goals.count == 2)
    #expect(s.state.development?.goals[0].memory?.standing == .replaced)
    #expect(s.state.development?.goals[1].confidence == nil)
}

@Test func vereinbarungWiderrufUnsicherheitUndWiederaufnahme() throws {
    var s = session(); try introduce(&s)
    append(&s, "Ja, weniger trinken vereinbaren wir.", input: "Vereinbaren wir weniger trinken?")
    let agreed = GoalUpdate(kind: .confirmed, previousGoal: ref(s.content.scenario.openingLine),
        evidence: ref(s.turns[1].reply.text, 4), proposal: ref(s.turns[1].input, 3, .counselor))
    try apply(&s, [agreed])
    #expect(s.state.development?.goals[0].memory?.standing == .agreed)
    append(&s, "Ich nehme das Ziel zurück.")
    try apply(&s, [.init(kind: .withdrawn, previousGoal: ref(s.content.scenario.openingLine), evidence: ref(s.turns[3].reply.text, 8))])
    append(&s, "Vielleicht doch, ich weiß es nicht.")
    try apply(&s, [.init(kind: .withdrawn, previousGoal: ref(s.content.scenario.openingLine), evidence: ref(s.turns[5].reply.text, 12), isUncertain: true)])
    let before = s.state.development
    try apply(&s, [agreed])
    #expect(s.state.development == before)
    #expect(s.state.development?.goals[0].memory?.standing == .withdrawn)
    #expect(s.state.development?.goals[0].memory?.lastEvent?.isUncertain == true)
    append(&s, "Ja, das vereinbaren wir erneut.", input: "Nehmen wir weniger trinken wieder auf?")
    let n = s.turns.count
    try apply(&s, [.init(kind: .confirmed, previousGoal: ref(s.content.scenario.openingLine),
        evidence: ref(s.turns[n-1].reply.text, n*2), proposal: ref(s.turns[n-1].input, n*2-1, .counselor))])
    #expect(s.state.development?.goals[0].memory?.standing == .agreed)
}

@Test func zielUpdatesVerwerfenFalscheRollenChronologieFelderUndDubletten() throws {
    var s = session(); append(&s, "Ja.", input: "Weniger trinken?")
    let context = ContextBuilder.messages(s)
    let valid = GoalUpdate(kind: .confirmed, previousGoal: ref(s.content.scenario.openingLine), evidence: ref("Ja.", 2), proposal: ref("Weniger trinken?", 1, .counselor))
    var variants: [[GoalUpdate]] = [[valid, valid]]
    var v = valid; v.proposal = nil; variants.append([v])
    v = valid; v.currentGoal = v.previousGoal; variants.append([v])
    v = valid; v.evidence = ref("Weniger trinken?", 1, .counselor); variants.append([v])
    v = valid; v.previousGoal = ref("Ja.", 2); variants.append([v])
    v = valid; v.proposal = .init(source: .currentInput, speaker: .counselor, messageIndex: nil, quote: "Jetzt?", occurrence: 1); variants.append([v])
    v = valid; v.evidence.quote = "Erfunden"; variants.append([v])
    for values in variants {
        #expect(throws: TrainerFailure.invalidAnalysis) {
            try OutputValidator.decodeAnalysis(JSONEncoder().encode(TurnAnalysis(segments: [], goalUpdates: values)), input: "Jetzt?", context: context)
        }
    }
    let data = try JSONEncoder().encode(TurnAnalysis(segments: [], goalUpdates: [valid]))
    #expect(try OutputValidator.decodeAnalysis(data, input: "Jetzt?", context: context).goalUpdates == [valid])
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var updates = try #require(object["goalUpdates"] as? [[String: Any]])
    updates[0]["invented"] = true; object["goalUpdates"] = updates
    #expect(throws: TrainerFailure.invalidAnalysis) { try OutputValidator.decodeAnalysis(JSONSerialization.data(withJSONObject: object), input: "", context: context) }
}

@Test func gespeicherteZielHistorieVerwirftManipuliertenStatusAliasseUndZukunft() throws {
    var s = session(); try introduce(&s)
    let state = try #require(s.state.development)
    var variants: [CharacterDevelopment] = []
    var v = state; v.goals[0].memory?.standing = .agreed; variants.append(v)
    v = state; v.goals[0].memory?.aliases = [state.goals[0].goal]; variants.append(v)
    v = state; v.goalEvents?[0].observedInTurnID = UUID(); variants.append(v)
    v = state; v.goalEvents?.append(state.goalEvents![0]); variants.append(v)
    v = state; v.goals[0].goal.origin.speaker = .counselor; variants.append(v)
    for changed in variants {
        #expect(throws: TrainerFailure.invalidAnalysis) { try CharacterTracker.validate(changed, session: s, currentTurnID: UUID()) }
    }
    #expect(try JSONDecoder().decode(CharacterDevelopment.self, from: JSONEncoder().encode(state)) == state)
}

@Test func unsicherEingefuehrtesZielBleibtNurEreignis() throws {
    var s = session()
    try apply(&s, [.init(kind: .introduced, currentGoal: ref(s.content.scenario.openingLine), evidence: ref(s.content.scenario.openingLine), isUncertain: true)])
    #expect(s.state.development?.goals.isEmpty == true)
    try introduce(&s)
    #expect(s.state.development?.goals.isEmpty == true)
    append(&s, "Ja, das möchte ich wirklich.")
    let n = s.turns.count
    try apply(&s, [.init(kind: .introduced, currentGoal: ref(s.content.scenario.openingLine),
        evidence: ref(s.turns[n-1].reply.text, n*2))])
    #expect(s.state.development?.goals.count == 1)
}

@Test func budgetLaesstGanzeZielgruppenAus() throws {
    var s = session()
    for i in 0..<4 {
        append(&s, "Ziel Nummer \(i).")
        let n = s.turns.count
        try apply(&s, [.init(kind: .introduced, currentGoal: ref(s.turns[n-1].reply.text, n*2), evidence: ref(s.turns[n-1].reply.text, n*2))])
    }
    for _ in 0..<8 { append(&s, "Hm.") }
    let memory = try ContextBuilder.analysisMemory(s)
    #expect(memory.goals.count == 3 && memory.omittedGoalCount == 1)
    #expect(memory.messages.count <= 25)
    var large = session()
    append(&large, "Ziel.", input: String(repeating: "x", count: 10_001))
    try apply(&large, [.init(kind: .introduced, currentGoal: ref("Ziel.", 2), evidence: ref("Ziel.", 2))])
    for _ in 0..<8 { append(&large, "Hm.") }
    let omitted = try ContextBuilder.analysisMemory(large)
    #expect(omitted.goals.isEmpty && omitted.omittedGoalCount == 1)
    #expect(omitted.messages == ContextBuilder.messages(large))
}

@Test func gleicheWorteInAnderenTurnsBleibenVerschiedeneBelegeUndAliaskollisionScheitert() throws {
    var s = session(); try introduce(&s)
    append(&s, s.content.scenario.openingLine)
    try apply(&s, [.init(kind: .introduced, currentGoal: ref(s.turns[1].reply.text, 4), evidence: ref(s.turns[1].reply.text, 4))])
    #expect(s.state.development?.goals.count == 2)
    let before = s.state.development
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try apply(&s, [.init(kind: .rephrased, previousGoal: ref(s.content.scenario.openingLine),
                            currentGoal: ref(s.turns[1].reply.text, 4), evidence: ref(s.turns[1].reply.text, 4))])
    }
    #expect(s.state.development == before)
}

@Test func unsichererSpaetbefundHoltAuchSichereVereinbarungZurueck() throws {
    var s = session(); try introduce(&s)
    append(&s, "Ja, einverstanden.", input: "Vereinbaren wir weniger trinken?")
    try apply(&s, [.init(kind: .confirmed, previousGoal: ref(s.content.scenario.openingLine),
        evidence: ref("Ja, einverstanden.", 4), proposal: ref(s.turns[1].input, 3, .counselor))])
    for _ in 0..<7 { append(&s, "Hm.") }
    append(&s, "Vielleicht möchte ich das nicht mehr.")
    let n = s.turns.count
    try apply(&s, [.init(kind: .withdrawn, previousGoal: ref(s.content.scenario.openingLine), evidence: ref(s.turns[n-1].reply.text, n*2), isUncertain: true)])
    let memory = try ContextBuilder.analysisMemory(s)
    #expect(memory.goals[0].standing == .agreed && memory.goals[0].isUncertain)
    #expect(memory.messages.contains { $0.text == "Vereinbaren wir weniger trinken?" })
    #expect(memory.messages.contains { $0.text == "Ja, einverstanden." })
}

@Test func zielEreignisseSindAtomarBeiAbbruchUndIdempotentBeiSpeicherwiederholung() async throws {
    let s = session()
    let analysis = TurnAnalysis(segments: [], goalUpdates: [.init(kind: .introduced,
        currentGoal: ref(s.content.scenario.openingLine), evidence: ref(s.content.scenario.openingLine))])
    let provider = ScriptedProvider(script: ["Hallo": analysis], holdsReply: true)
    let repo = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let created = try await coordinator.create(content: s.content, contentHash: "test")
    let task = Task { try await coordinator.send(sessionID: created.id, input: "Hallo") }
    await provider.waitUntilReplyHeld()
    #expect(try await repo.load(id: created.id).state.development == nil)
    await coordinator.cancel(); await provider.release()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(try await repo.load(id: created.id).state.development == nil)

    let retryProvider = ScriptedProvider(script: ["Hallo": analysis])
    let failing = FailingCommitRepository(afterCommit: true)
    let retry = ConversationCoordinator(repository: failing, provider: retryProvider)
    let fresh = try await retry.create(content: s.content, contentHash: "test")
    await #expect(throws: TrainerFailure.storageUnavailable) { try await retry.send(sessionID: fresh.id, input: "Hallo") }
    let saved = try await retry.send(sessionID: fresh.id, input: "Hallo")
    #expect(saved.state.development?.goalEvents?.count == 1 && saved.turns.count == 1)
    #expect(await retryProvider.analyses == 1)
    #expect(await retryProvider.replies == 1)
}

private actor MemoryWindowProvider: TrainerModelProvider {
    var lastAnalysis: AnalysisRequest?
    var lastReply: ReplyRequest?
    var replies = 0
    func descriptor() -> ModelDescriptor { TestData.model }
    func prepare() {}
    func unload() {}
    func analyze(_ request: AnalysisRequest) -> ModelResult<TurnAnalysis> {
        lastAnalysis = request
        var updates: [GoalUpdate] = []
        if replies == 1, let index = request.recentMessages.firstIndex(where: { $0.text == "Ich möchte sonntags fitter sein." }) {
            let evidence = ref("Ich möchte sonntags fitter sein.", index)
            updates = [.init(kind: .introduced, currentGoal: evidence, evidence: evidence)]
        }
        return .init(value: .init(segments: [], goalUpdates: updates), metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }
    func reply(_ request: ReplyRequest) -> ModelResult<ClientReply> {
        lastReply = request; replies += 1
        return .init(value: .init(text: replies == 1 ? "Ich möchte sonntags fitter sein." : "Hm.", primaryTag: nil, disclosedFactIDs: []),
                     metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }
}

@Test func coordinatorErinnertAltesZielNurInDerAnalyse() async throws {
    let provider = MemoryWindowProvider(), repo = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    var saved = try await coordinator.create(content: session().content, contentHash: "test")
    for i in 0..<10 { saved = try await coordinator.send(sessionID: saved.id, input: "Runde \(i)") }
    let analysis = try #require(await provider.lastAnalysis)
    let reply = try #require(await provider.lastReply)
    #expect(analysis.knownGoals.count == 1)
    #expect(analysis.recentMessages.contains { $0.text == "Ich möchte sonntags fitter sein." })
    #expect(!reply.recentMessages.contains { $0.text == "Ich möchte sonntags fitter sein." })
    #expect(reply.recentMessages.count == 13)
    #expect(saved.state.development?.goalEvents?.count == 1)
}

@Test func siebenAlteAliasTurnsUeberschreitenDasGedächtnisbudget() throws {
    var s = session(); try introduce(&s)
    for i in 0..<7 {
        append(&s, "Umformulierung \(i).")
        let n = s.turns.count
        try apply(&s, [.init(kind: .rephrased, previousGoal: ref(s.content.scenario.openingLine),
            currentGoal: ref(s.turns[n-1].reply.text, n*2), evidence: ref(s.turns[n-1].reply.text, n*2))])
    }
    for _ in 0..<7 { append(&s, "Hm.") }
    let memory = try ContextBuilder.analysisMemory(s)
    #expect(memory.goals.isEmpty && memory.omittedGoalCount == 1)
    #expect(memory.messages == ContextBuilder.messages(s))
}

@Test func neuerZielvertragVerhindertParallelzielAusCharakterbeobachtung() throws {
    var s = session(); try introduce(&s)
    append(&s, "Ich nehme mein Ziel zurück.")
    try apply(&s, [.init(kind: .withdrawn, previousGoal: ref(s.content.scenario.openingLine), evidence: ref(s.turns[1].reply.text, 4))])
    append(&s, "Vielleicht möchte ich weniger trinken. Ich bin unsicher.")
    let previous = s.state.development
    let observation = CharacterObservation(dimension: .readiness, assessment: .unclear,
        goal: ref("weniger trinken", 8), evidence: ref("Ich bin unsicher.", 8), isUncertain: true)
    #expect(throws: TrainerFailure.invalidAnalysis) { try apply(&s, [], observations: [observation]) }
    #expect(s.state.development == previous)
    var anchored = observation; anchored.goal = ref(s.content.scenario.openingLine)
    try apply(&s, [], observations: [anchored])
    #expect(s.state.development?.goals.count == 1)
    #expect(s.state.development?.goals[0].memory?.standing == .withdrawn)
    #expect(s.state.development?.goals[0].readiness?.isUncertain == true)
}

@Test func zielausschnittDarfInnerhalbDesEreigniszitatsSpaeterBeginnen() throws {
    var s = session(); try introduce(&s)
    append(&s, "Ich ändere mein Ziel: vollständig auf Alkohol verzichten.")
    try apply(&s, [.init(kind: .replaced, previousGoal: ref(s.content.scenario.openingLine),
        currentGoal: ref("vollständig auf Alkohol verzichten", 4), evidence: ref(s.turns[1].reply.text, 4))])
    #expect(s.state.development?.goals.count == 2)
    #expect(s.state.development?.goals[0].memory?.standing == .replaced)
}
