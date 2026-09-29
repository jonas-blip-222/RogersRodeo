import Foundation
import Testing
import TrainerCore
import TrainerStorage

@Test @MainActor func diskRoundTripRetainsPendingAndIdempotency() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("sessions.store")
    var repository: SwiftDataSessionRepository? = try .init(storeURL: url)
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "test", version: "1.0", status: .draft,
        name: "Testfigur", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Hallo", publicProfile: "Test", facts: [])
    let snapshot = SessionSnapshot(schemaVersion: 1, id: UUID(), revision: 0, approachID: "mi",
        identity: .init(contentHash: "test", rulesVersion: "0.1", promptVersion: "0.1", model: DemoModelProvider.identity),
        content: .init(scenario: scenario, codingGuide: "Test", tips: []), state: .init(openness: 3), turns: [], status: .active, startedAt: Date())
    try repository?.create(snapshot)
    let pending = PendingTurn(id: UUID(), sessionID: snapshot.id, expectedRevision: 0, input: "Entwurf ä🙂", createdAt: Date())
    try repository?.savePending(pending)
    repository = nil
    repository = try .init(storeURL: url)
    let reopened = try #require(repository)
    #expect(try reopened.load(id: snapshot.id) == snapshot)
    #expect(try reopened.loadPending(sessionID: snapshot.id) == pending)
    let turn = CompletedTurn(id: pending.id, input: pending.input, analysis: nil,
        reply: .init(text: "Antwort", primaryTag: nil, disclosedFactIDs: []), stateBefore: snapshot.state,
        stateAfter: .init(openness: 3, recentCredits: [nil]), stateChangeReasons: ["analysis_unavailable"],
        selectedTipID: nil, metrics: [], completedAt: Date())
    let committed = try reopened.commit(sessionID: snapshot.id, expectedRevision: 0, turn: turn)
    let another = try SwiftDataSessionRepository(storeURL: url)
    #expect(try another.commit(sessionID: snapshot.id, expectedRevision: 0, turn: turn) == committed)
    #expect(try another.loadPending(sessionID: snapshot.id) == nil)
    #if os(iOS)
    #expect(try URL(fileURLWithPath: directory.path).resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    #endif
    #expect(committed.schemaVersion == 1)
    try another.delete(id: snapshot.id)
    #expect(try another.list().isEmpty)
    #expect(throws: TrainerFailure.sessionNotFound) { try another.commit(sessionID: snapshot.id, expectedRevision: 0, turn: turn) }
}

/// Die Rückmeldung wird gemeinsam mit dem Turn gespeichert und übersteht Neustart und
/// Wiedereinlesen. Zur Idempotenz gehört sie damit auch: ein Commit-Wiederholversuch mit
/// abweichender Rückmeldung ist ein anderer Turn und wird abgewiesen — sonst könnte eine
/// neu berechnete Rückmeldung eine bereits gespeicherte still überschreiben.
@Test @MainActor func gespeichertesFeedbackUeberstehtNeustartUndGehoertZurIdempotenz() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("sessions.store")
    var repository: SwiftDataSessionRepository? = try .init(storeURL: url)
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "test", version: "1.0", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Hallo", publicProfile: "Test", facts: [])
    let snapshot = SessionSnapshot(schemaVersion: 1, id: UUID(), revision: 0, approachID: "mi",
        identity: .init(contentHash: "test", rulesVersion: "0.1", promptVersion: "0.1", model: DemoModelProvider.identity),
        content: .init(scenario: scenario, codingGuide: "Test", tips: []), state: .init(openness: 3),
        turns: [], status: .active, startedAt: Date())
    try repository?.create(snapshot)
    let eingabe = "Wenn Ihnen Sarah wirklich wichtig wäre, würden Sie aufhören."
    let pending = PendingTurn(id: UUID(), sessionID: snapshot.id, expectedRevision: 0, input: eingabe, createdAt: Date())
    try repository?.savePending(pending)
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Wenn Ihnen Sarah wirklich wichtig wäre", code: .confrontation, isUncertain: false)])
    let findings = FeedbackEngine.findings(analysis: analyse, input: eingabe, context: [],
                                           characterName: "Lukas", rulesVersion: "0.1")
    #expect(findings.count == 1)
    let turn = CompletedTurn(id: pending.id, input: eingabe, analysis: analyse,
        reply: .init(text: "Sie kennen uns doch gar nicht.", primaryTag: nil, disclosedFactIDs: []),
        stateBefore: snapshot.state, stateAfter: .init(openness: 1, recentCredits: [nil]),
        stateChangeReasons: ["confrontation"], selectedTipID: nil, metrics: [], completedAt: Date(),
        feedback: findings)
    _ = try repository?.commit(sessionID: snapshot.id, expectedRevision: 0, turn: turn)
    repository = nil

    let wieder = try SwiftDataSessionRepository(storeURL: url)
    let geladen = try wieder.load(id: snapshot.id)
    #expect(geladen.schemaVersion == 1)
    #expect(geladen.turns.first?.feedback == findings)
    // Derselbe Turn noch einmal: unverändert idempotent.
    #expect(try wieder.commit(sessionID: snapshot.id, expectedRevision: 0, turn: turn) == geladen)
    // Mit anderer Rückmeldung: abgewiesen statt still überschrieben.
    var abweichend = turn
    abweichend.feedback = []
    #expect(throws: TrainerFailure.revisionConflict) {
        try wieder.commit(sessionID: snapshot.id, expectedRevision: 0, turn: abweichend)
    }
    #expect(try wieder.load(id: snapshot.id).turns.first?.feedback == findings)
}

@Test @MainActor func charakterbeobachtungenBehaltenBelegeNachNeustart() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("sessions.store")
    let opening = "Ich möchte sonntags fitter sein. Ich traue mir das noch nicht zu."
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "test", version: "1", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: opening, publicProfile: "Test", facts: [])
    let snapshot = SessionSnapshot(schemaVersion: 1, id: UUID(), revision: 0, approachID: "mi",
        identity: .init(contentHash: "test", rulesVersion: ConversationCoordinator.rulesVersion,
                        promptVersion: ConversationCoordinator.promptVersion, model: DemoModelProvider.identity),
        content: .init(scenario: scenario, codingGuide: "G", tips: []), state: .init(openness: 3),
        turns: [], status: .active, startedAt: Date())
    let pending = PendingTurn(id: UUID(), sessionID: snapshot.id, expectedRevision: 0, input: "Erzählen Sie.", createdAt: Date())
    let analysis = TurnAnalysis(segments: [], characterObservations: [
        .init(dimension: .confidence, assessment: .doubtful,
            goal: .init(source: .contextMessage, speaker: .client, messageIndex: 0,
                        quote: "Ich möchte sonntags fitter sein.", occurrence: 1),
            evidence: .init(source: .contextMessage, speaker: .client, messageIndex: 0,
                            quote: "Ich traue mir das noch nicht zu.", occurrence: 1), isUncertain: false)])
    var after = snapshot.state
    after.development = try CharacterTracker.advance(nil, analysis: analysis, input: pending.input,
        context: ContextBuilder.messages(snapshot), session: snapshot, turnID: pending.id)
    let turn = CompletedTurn(id: pending.id, input: pending.input, analysis: analysis,
        reply: .init(text: "Hm.", primaryTag: nil, disclosedFactIDs: []), stateBefore: snapshot.state, stateAfter: after,
        stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date())
    var repository: SwiftDataSessionRepository? = try .init(storeURL: url)
    try repository?.create(snapshot)
    try repository?.savePending(pending)
    _ = try repository?.commit(sessionID: snapshot.id, expectedRevision: 0, turn: turn)
    repository = nil
    let reopened = try SwiftDataSessionRepository(storeURL: url)
    let loaded = try reopened.load(id: snapshot.id)
    #expect(loaded.state.development == after.development)
    #expect(loaded.state.development?.goals.first?.confidence?.evidence.quote == "Ich traue mir das noch nicht zu.")
    #expect(loaded.turns.first?.analysis?.characterObservations == analysis.characterObservations)
    #expect(try reopened.commit(sessionID: snapshot.id, expectedRevision: 0, turn: turn) == loaded)
    var altered = turn; altered.stateAfter.development?.goals[0].confidence?.assessment = .confident
    #expect(throws: TrainerFailure.revisionConflict) {
        try reopened.commit(sessionID: snapshot.id, expectedRevision: 0, turn: altered)
    }
}
