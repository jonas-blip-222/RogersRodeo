import Foundation
import Testing
@testable import TrainerCore

private func evidence(_ quote: String, index: Int, speaker: Speaker = .client) -> EvidenceReference {
    .init(source: .contextMessage, speaker: speaker, messageIndex: index, quote: quote, occurrence: 1)
}

private func addTurn(_ session: inout SessionSnapshot, reply: String, updates: [GoalUpdate] = []) throws {
    let id = UUID(), before = session.state
    let analysis = TurnAnalysis(segments: [], characterObservations: [], goalUpdates: updates)
    let context = ContextBuilder.evidenceMessages(session)
    session.state.development = try CharacterTracker.advance(before.development, analysis: analysis,
        input: "Weiter", context: context, session: session, turnID: id)
    try CharacterTracker.validate(session.state.development, session: session, currentTurnID: id)
    session.turns.append(.init(id: id, input: "Weiter", analysis: analysis,
        reply: .init(text: reply, primaryTag: nil, disclosedFactIDs: []), stateBefore: before,
        stateAfter: session.state, stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
    session.revision += 1
}

private func completedGoalSession() throws -> SessionSnapshot {
    var session = TestData.session()
    session.openingMessage = "Ich möchte weniger trinken."
    let goal = evidence(session.openingLine, index: 0)
    try addTurn(&session, reply: "Dafür möchte ich einen Weg finden.", updates: [
        .init(kind: .introduced, currentGoal: goal, evidence: goal)])
    session.status = .completed; session.endedAt = Date()
    return session
}

@Test func zwanzigRundenSchliessenAbUndFolgeterminIstIdempotent() async throws {
    let repo = MemorySessionRepository(), provider = ControlledProvider()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    var first = try await coordinator.create(content: TestData.content, contentHash: "test", openingLine: "Hallo.")
    for _ in 0..<20 { first = try await coordinator.send(sessionID: first.id, input: "Hallo") }
    #expect(first.status == .completed && first.endedAt != nil)
    #expect(first.turns.count == 20 && first.revision == 20)
    let calls = await provider.replies
    let completed = first
    async let a = repo.createFollowUp(after: completed.id, identity: completed.identity, at: Date())
    async let b = repo.createFollowUp(after: completed.id, identity: completed.identity, at: Date().addingTimeInterval(1_000_000))
    let (second, repeated) = try await (a, b)
    #expect(second.id == repeated.id)
    #expect(second.caseID == first.id && second.sessionNumber == 2 && second.fictionalWeek == 1)
    #expect(second.turns.isEmpty && second.revision == 0 && second.status == .active)
    #expect(second.openingLine == "Hallo.")
    #expect(second.state.openness == first.state.openness)
    #expect(second.state.permissionMemory == nil && second.state.closedQuestionStreak == 0)
    #expect(await provider.replies == calls) // Kein Modellaufruf für Notiz oder Termin.
    #expect(await repo.list().count == 2)
    #expect(try await repo.load(id: first.id).followUpSessionID == second.id)
    let reopened = ConversationCoordinator(repository: repo, provider: provider)
    let thirdAttempt = try await reopened.createFollowUp(after: first.id)
    #expect(thirdAttempt.id == second.id && thirdAttempt.fictionalWeek == 1)
    let sent = try await reopened.send(sessionID: second.id, input: "Was beschäftigt Sie heute?")
    #expect(sent.turns.count == 1)
    #expect(try await repo.load(id: first.id).turns.count == 20)
}

@Test func vorzeitigerAbschlussUndAltdatenErlaubenVorbereitetenFolgetermin() async throws {
    let repo = MemorySessionRepository(), provider = ControlledProvider()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    var old = try await coordinator.create(content: TestData.content, contentHash: "test")
    old = try await coordinator.send(sessionID: old.id, input: "Hallo")
    old = try await repo.finish(sessionID: old.id, expectedRevision: old.revision, endedAt: Date())
    let data = try JSONEncoder().encode(old)
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    for field in ["continuity", "followUpSessionID", "openingMessage"] { json.removeValue(forKey: field) }
    let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(decoded.sessionNumber == 1 && decoded.caseID == old.id)
    #expect(decoded.openingLine == old.content.scenario.openingLine)
    var identity = old.identity; identity.promptVersion = "next-prompt"
    let next = try VisitBuilder.followUp(after: decoded, identity: identity, at: Date())
    #expect(next.sessionNumber == 2 && next.continuity?.preparation.previousTurnCount == 1)
    let note = try #require(next.continuity?.preparation)
    #expect(note.entries.first?.quote == old.turns.last?.reply.text)
    #expect(note.entries.first?.sessionID == old.id)
    #expect(!note.hasConfirmedGoal)
    #expect(!note.entries.contains { $0.quote == old.content.scenario.publicProfile })
    var foreign = identity; foreign.contentHash = "other"
    #expect(throws: TrainerFailure.unsupportedVersion) { try VisitBuilder.followUp(after: old, identity: foreign, at: Date()) }
}

@Test func alteEroeffnungBleibtBelegUndWiderrufWirktImNaechstenTermin() throws {
    let first = try completedGoalSession()
    var second = try VisitBuilder.followUp(after: first, identity: first.identity, at: Date())
    let memory = try ContextBuilder.analysisMemory(second)
    let known = try #require(memory.goals.first)
    let index = try #require(known.goal.messageIndex)
    #expect(memory.messages[index].text == first.openingLine)
    #expect(memory.messages[index].origin?.sessionID == first.id)
    #expect(memory.messages[index].visitNumber == 1)
    #expect(memory.messages.last?.text == "Hallo.")
    #expect(memory.messages.last?.visitNumber == 2)
    #expect(second.state.development?.goals.first?.goal.origin.sessionID == first.id)
    try addTurn(&second, reply: "Das Ziel nehme ich zurück.")
    let context = ContextBuilder.evidenceMessages(second)
    let oldGoalIndex = try #require(context.firstIndex { $0.text == first.openingLine })
    let withdrawalIndex = try #require(context.firstIndex { $0.text == "Das Ziel nehme ich zurück." })
    try addTurn(&second, reply: "Das ist mein Stand.", updates: [
        .init(kind: .withdrawn, previousGoal: evidence(first.openingLine, index: oldGoalIndex),
              evidence: evidence("Das Ziel nehme ich zurück.", index: withdrawalIndex))])
    #expect(second.state.development?.goals.first?.memory?.standing == .withdrawn)
    second.status = .completed; second.endedAt = Date()
    let third = try VisitBuilder.followUp(after: second, identity: second.identity, at: Date())
    #expect(third.fictionalWeek == 2)
    #expect(third.state.development?.goals.first?.memory?.standing == .withdrawn)
    let note = try #require(third.continuity?.preparation)
    #expect(note.entries.contains { $0.heading.contains("Zurückgenommen") && $0.sessionID == first.id })
    #expect(note.entries.contains { $0.quote == "Das Ziel nehme ich zurück." && $0.sessionID == second.id })
    #expect(!note.hasConfirmedGoal)
    let rebuilt = try JSONDecoder().decode(SessionSnapshot.self, from: JSONEncoder().encode(third))
    #expect(try ContextBuilder.analysisMemory(rebuilt).goals.first?.standing == .withdrawn)
}

@Test func sitzungsuebergreifenderKontextBleibtBegrenzt() throws {
    var first = try completedGoalSession()
    for _ in 0..<19 { try addTurn(&first, reply: "Ein früherer Gesprächsbeitrag.") }
    var second = try VisitBuilder.followUp(after: first, identity: first.identity, at: Date())
    for _ in 0..<9 { try addTurn(&second, reply: "Ein aktueller Gesprächsbeitrag.") }
    let memory = try ContextBuilder.analysisMemory(second)
    #expect(memory.messages.count == 14) // Sechs aktuelle Runden, beide Begrüßungen.
    #expect(memory.goals.count == 1)
    #expect(memory.messages.contains { $0.text == first.openingLine })
    #expect(!memory.messages.contains { $0.text == "Ein früherer Gesprächsbeitrag." })
    #expect(ContextBuilder.messages(second) == memory.messages)
}

@Test func ratserlaubnisAusVorherigemTerminIstNichtGueltig() throws {
    var first = TestData.session()
    try addTurn(&first, reply: "Ja, gerne.")
    first.status = .completed; first.endedAt = Date()
    var second = try VisitBuilder.followUp(after: first, identity: first.identity, at: Date())
    let oldContext = ContextBuilder.messages(second)
    let oldIndex = try #require(oldContext.firstIndex { $0.text == "Ja, gerne." })
    let advice = EvidenceReference(source: .currentInput, speaker: .counselor, messageIndex: nil, quote: "Mein Vorschlag", occurrence: 1)
    let assessment = PermissionAssessment(advice: advice, standing: .granted,
        response: evidence("Ja, gerne.", index: oldIndex))
    let analysis = TurnAnalysis(segments: [], permissions: [assessment])
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try ContextBuilder.validateCurrentPermission(analysis, context: oldContext, session: second)
    }
    try addTurn(&second, reply: "Ja, gerne.")
    let current = ContextBuilder.messages(second)
    let newIndex = try #require(current.lastIndex { $0.text == "Ja, gerne." })
    var valid = analysis; valid.permissions?[0].response = evidence("Ja, gerne.", index: newIndex)
    try ContextBuilder.validateCurrentPermission(valid, context: current, session: second)
}
