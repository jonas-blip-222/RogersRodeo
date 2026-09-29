import Foundation
import Testing
@testable import TrainerCore

private let opening = "Ich will sonntags fitter sein. Ich möchte etwas ändern, traue es mir aber nicht zu. Ich fühle mich hier unter Druck."
private let goalText = "Ich will sonntags fitter sein."
private let statement = "Ich möchte etwas ändern, traue es mir aber nicht zu."
private func reference(_ quote: String, index: Int = 0) -> EvidenceReference {
    .init(source: .contextMessage, speaker: .client, messageIndex: index, quote: quote, occurrence: 1)
}
private func observations() -> [CharacterObservation] {
    [.init(dimension: .readiness, assessment: .willing, goal: reference(goalText), evidence: reference(statement), isUncertain: false),
     .init(dimension: .confidence, assessment: .doubtful, goal: reference(goalText), evidence: reference(statement), isUncertain: false),
     .init(dimension: .rapport, assessment: .strained, goal: nil, evidence: reference("Ich fühle mich hier unter Druck."), isUncertain: false)]
}
private func snapshot() -> SessionSnapshot {
    var result = TestData.session(); result.content.scenario.openingLine = opening; return result
}
private func advance(_ session: SessionSnapshot, _ values: [CharacterObservation],
                     before: CharacterDevelopment? = nil, turnID: UUID = UUID()) throws -> CharacterDevelopment {
    let value = try CharacterTracker.advance(before, analysis: .init(segments: [], characterObservations: values),
        input: "Was beschäftigt Sie?", context: ContextBuilder.messages(session), session: session, turnID: turnID)
    return try #require(value)
}
private func append(_ text: String, to session: inout SessionSnapshot) {
    session.turns.append(.init(id: UUID(), input: "Und jetzt?", analysis: nil,
        reply: .init(text: text, primaryTag: nil, disclosedFactIDs: []), stateBefore: session.state, stateAfter: session.state,
        stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
}

@Test func bereitschaftZuversichtUndRapportSindUnabhaengig() throws {
    let session = snapshot()
    let state = try advance(session, observations())
    #expect(state.goals.count == 1)
    #expect(state.goals[0].readiness?.assessment == .willing)
    #expect(state.goals[0].confidence?.assessment == .doubtful)
    #expect(state.rapport?.assessment == .strained)
    #expect(state.goals[0].goal.origin.turnID == nil)
    var open = session; open.state.openness = 10
    let id = UUID()
    #expect(try advance(session, observations(), turnID: id) == advance(open, observations(), turnID: id))
    #expect(try JSONDecoder().decode(CharacterDevelopment.self, from: JSONEncoder().encode(state)) == state)
}

@Test func ungueltigeCharakterbeobachtungenWerdenStriktAbgewiesen() throws {
    let session = snapshot(), context = ContextBuilder.messages(session)
    let original = observations()[0]
    var variants: [[CharacterObservation]] = []
    var a = original; a.goal = nil; variants.append([a])
    a = original; a.assessment = .confident; variants.append([a])
    a = original; a.evidence.quote = "Ich kann das sicher!"; variants.append([a])
    a = original; a.evidence.speaker = .counselor; variants.append([a])
    a = original; a.evidence.source = .currentInput; variants.append([a])
    a = original; a.goal?.speaker = .counselor; variants.append([a])
    a = original; a.dimension = .rapport; a.assessment = .connected; variants.append([a])
    variants.append([original, original])
    for values in variants {
        #expect(throws: TrainerFailure.invalidAnalysis) {
            try OutputValidator.decodeAnalysis(JSONEncoder().encode(TurnAnalysis(segments: [], characterObservations: values)),
                                               input: statement, context: context)
        }
    }
    let raw = try JSONEncoder().encode(TurnAnalysis(segments: [], characterObservations: observations()))
    #expect(try OutputValidator.decodeAnalysis(raw, input: "Hallo", context: context).characterObservations == observations())
    var object = try #require(JSONSerialization.jsonObject(with: raw) as? [String: Any])
    var array = try #require(object["characterObservations"] as? [[String: Any]])
    array[0]["score"] = 10; object["characterObservations"] = array
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.decodeAnalysis(JSONSerialization.data(withJSONObject: object), input: "Hallo", context: context)
    }
}

@Test func gefaelschteKontextherkunftErzeugtKeinenCharakterzustand() {
    let session = snapshot()
    for origin in [MessageOrigin?.none, .some(.init(turnID: UUID(), speaker: .client))] {
        let context: [DialogueMessage] = [.init(speaker: .client, text: opening, origin: origin)]
        #expect(throws: TrainerFailure.invalidAnalysis) {
            try CharacterTracker.advance(nil, analysis: .init(segments: [], characterObservations: observations()),
                                         input: "Hallo", context: context, session: session, turnID: UUID())
        }
    }
    let altered: [DialogueMessage] = [.init(speaker: .client, text: opening + " Erfunden.", origin: .init(turnID: nil, speaker: .client))]
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try CharacterTracker.advance(nil, analysis: .init(segments: [], characterObservations: observations()),
                                     input: "Hallo", context: altered, session: session, turnID: UUID())
    }
}

@Test func spaetereZweifelErsetzenFruehereZuversichtAuchWennUnsicher() throws {
    var session = snapshot()
    var initial = observations()[1]; initial.assessment = .confident
    let before = try advance(session, [initial])
    append("Inzwischen bin ich unsicher, ob ich das schaffe.", to: &session)
    var latest = observations()[1]
    latest.evidence = reference(session.turns[0].reply.text, index: 2)
    latest.assessment = .mixed; latest.isUncertain = true
    let updated = try advance(session, [latest], before: before)
    #expect(updated.goals[0].confidence?.isUncertain == true)
    #expect(updated.goals[0].confidence?.assessment == .mixed)
    #expect(updated.goals[0].confidence?.evidence.origin.turnID == session.turns[0].id)
    // Eine erneut analysierte alte Aussage darf die neuere nicht zurückdrehen.
    #expect(try advance(session, [initial], before: updated) == updated)
    // Auch dieselbe Aussage wird nicht durch erneute Analyse zu einem Fortschritt.
    latest.assessment = .confident; latest.isUncertain = false
    #expect(try advance(session, [latest], before: updated) == updated)
}

@Test func zielwechselVermischtDieZuversichtNicht() throws {
    var session = snapshot()
    let before = try advance(session, observations())
    append("Ich möchte nüchtern Fußball spielen. Das traue ich mir zu.", to: &session)
    let next = CharacterObservation(dimension: .confidence, assessment: .confident,
        goal: reference("Ich möchte nüchtern Fußball spielen.", index: 2),
        evidence: reference("Das traue ich mir zu.", index: 2), isUncertain: false)
    let updated = try advance(session, [next], before: before)
    #expect(updated.goals.count == 2)
    #expect(updated.goals[0] == before.goals[0])
    #expect(updated.goals[1].readiness == nil)
    #expect(updated.goals[1].confidence?.assessment == .confident)
    #expect(updated.rapport == before.rapport)
}

@Test func gekuerzterKontextAendertDauerhafteBelegeNicht() throws {
    var session = snapshot()
    append("Ich fühle mich jetzt verstanden.", to: &session)
    let value = CharacterObservation(dimension: .rapport, assessment: .connected, goal: nil,
                                     evidence: reference(session.turns[0].reply.text, index: 2), isUncertain: false)
    let before = try advance(session, [value])
    for _ in 0..<8 { append("Hm.", to: &session) }
    #expect(!ContextBuilder.messages(session).contains { $0.origin?.turnID == before.rapport?.evidence.origin.turnID })
    try CharacterTracker.validate(before, session: session, currentTurnID: before.rapport!.observedInTurnID)
    #expect(try CharacterTracker.advance(before, analysis: .init(segments: [], characterObservations: []),
        input: "Hallo", context: ContextBuilder.messages(session), session: session, turnID: UUID()) == before)
}

@Test func altformatUndFehlendeAnalyseErfindenKeineZustaende() throws {
    let state = try JSONDecoder().decode(SimulationState.self,
        from: Data(#"{"openness":3,"closedQuestionStreak":0,"disclosedFactIDs":[],"recentCredits":[]}"#.utf8))
    #expect(state.development == nil)
    let session = snapshot()
    #expect(try CharacterTracker.advance(nil, analysis: nil, input: "Hallo", context: [], session: session, turnID: UUID()) == nil)
    let before = try advance(session, observations())
    #expect(try CharacterTracker.advance(before, analysis: nil, input: "Hallo", context: [], session: session, turnID: UUID()) == before)
}

@Test func charakterzustandWirdErstMitVollstaendigemTurnGespeichert() async throws {
    let provider = ScriptedProvider(script: ["Hallo": .init(segments: [], characterObservations: observations())], holdsReply: true)
    let repo = MemorySessionRepository(), recorder = FeedbackRecorder()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    var content = TestData.content; content.scenario.openingLine = opening
    let session = try await coordinator.create(content: content, contentHash: "test")
    let sink = await recorder.sink
    let task = Task { try await coordinator.send(sessionID: session.id, input: "Hallo", onFeedback: sink) }
    await provider.waitUntilReplyHeld()
    #expect(try await repo.load(id: session.id).state.development == nil)
    #expect(await recorder.received.first?.findings.isEmpty == true)
    await provider.release()
    let saved = try await task.value
    #expect(saved.turns[0].stateBefore.development == nil)
    #expect(saved.state.development?.rapport?.assessment == .strained)
    #expect(saved.state.openness == session.state.openness)
    #expect(saved.state.development == saved.turns[0].stateAfter.development)
    #expect(try JSONDecoder().decode(SessionSnapshot.self, from: JSONEncoder().encode(saved)) == saved)
}

@Test func charakterzustandNachAbbruchBleibtUnveraendert() async throws {
    let provider = ScriptedProvider(script: ["Hallo": .init(segments: [], characterObservations: observations())], holdsReply: true)
    let repo = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    var content = TestData.content; content.scenario.openingLine = opening
    let session = try await coordinator.create(content: content, contentHash: "test")
    let task = Task { try await coordinator.send(sessionID: session.id, input: "Hallo") }
    await provider.waitUntilReplyHeld()
    await coordinator.cancel()
    await provider.release()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(try await repo.load(id: session.id) == session)
}

@Test func speicherwiederholungUebernimmtCharakterzustandNurEinmal() async throws {
    let provider = ScriptedProvider(script: ["Hallo": .init(segments: [], characterObservations: observations())])
    let repo = FailingCommitRepository(afterCommit: true)
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    var content = TestData.content; content.scenario.openingLine = opening
    let session = try await coordinator.create(content: content, contentHash: "test")
    await #expect(throws: TrainerFailure.storageUnavailable) {
        try await coordinator.send(sessionID: session.id, input: "Hallo")
    }
    let saved = try await coordinator.send(sessionID: session.id, input: "Hallo")
    #expect(saved.turns.count == 1)
    #expect(saved.state.development?.goals.count == 1)
    #expect(await provider.analyses == 1)
    #expect(await provider.replies == 1)
    var changed = saved.turns[0]
    changed.stateAfter.development?.rapport?.isUncertain = true
    await #expect(throws: TrainerFailure.revisionConflict) {
        try await repo.commit(sessionID: session.id, expectedRevision: 0, turn: changed)
    }
}

@Test func dauerhafteReferenzenWerdenAuchAnDerSpeichergrenzeGeprueft() throws {
    let session = snapshot(), turnID = UUID()
    var state = try advance(session, observations(), turnID: turnID)
    try CharacterTracker.validate(state, session: session, currentTurnID: turnID)
    state.rapport?.evidence.origin.turnID = UUID()
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try CharacterTracker.validate(state, session: session, currentTurnID: turnID)
    }
}

@Test func ohneEinordnungFortsetzenBehaeltDieLetztenBeobachtungen() async throws {
    let provider = ScriptedProvider(script: ["Hallo": .init(segments: [], characterObservations: observations())])
    let repo = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    var content = TestData.content; content.scenario.openingLine = opening
    let session = try await coordinator.create(content: content, contentHash: "test")
    let first = try await coordinator.send(sessionID: session.id, input: "Hallo")
    let second = try await coordinator.send(sessionID: session.id, input: "Weiter", skipAnalysis: true)
    #expect(second.state.development == first.state.development)
    #expect(second.turns.last?.analysis == nil)
    #expect(await provider.analyses == 1)
}

@Test func spaetereAussagenKoennenKeineFrueherenBeobachtungenBelegen() throws {
    var session = snapshot()
    append("Ich fühle mich verstanden.", to: &session)
    let observation = CharacterObservation(dimension: .rapport, assessment: .connected, goal: nil,
        evidence: reference(session.turns[0].reply.text, index: 2), isUncertain: false)
    var state = try advance(session, [observation])
    // Die Antwort der ersten Runde existierte während deren Analyse noch nicht.
    state.rapport?.observedInTurnID = session.turns[0].id
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try CharacterTracker.validate(state, session: session, currentTurnID: UUID())
    }
}

@Test func neuerPromptMitAltenZustandsregelnWirdNichtFortgesetzt() async throws {
    var old = snapshot(); old.identity.rulesVersion = "0.1"
    let repo = MemorySessionRepository(); try await repo.create(old)
    let coordinator = ConversationCoordinator(repository: repo, provider: ControlledProvider())
    await #expect(throws: TrainerFailure.unsupportedVersion) {
        try await coordinator.send(sessionID: old.id, input: "Hallo")
    }
    #expect(try await repo.load(id: old.id) == old)
}
