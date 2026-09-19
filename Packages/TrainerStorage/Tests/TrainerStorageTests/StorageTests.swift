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
    try another.delete(id: snapshot.id)
    #expect(try another.list().isEmpty)
    #expect(throws: TrainerFailure.sessionNotFound) { try another.commit(sessionID: snapshot.id, expectedRevision: 0, turn: turn) }
}
