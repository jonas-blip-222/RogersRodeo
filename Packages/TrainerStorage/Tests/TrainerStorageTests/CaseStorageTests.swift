import Foundation
import Testing
import TrainerCore
@testable import TrainerStorage

@Test @MainActor func folgeterminUeberstehtNeustartOhneDuplikatUndFallLoeschtAlleBelege() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("sessions.store")
    var repo: SwiftDataSessionRepository? = try .init(storeURL: url)
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "test", version: "1", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Hallo.", publicProfile: "Fiktive Testfigur", facts: [])
    let content = SessionContent(scenario: scenario, codingGuide: "Test", tips: [])
    var coordinator: ConversationCoordinator? = ConversationCoordinator(repository: repo!, provider: DemoModelProvider())
    let first = try await coordinator!.create(content: content, contentHash: "test")
    let done = try repo!.finish(sessionID: first.id, expectedRevision: 0, endedAt: Date())
    let note = try VisitBuilder.preparation(after: done)
    #expect(note.entries.isEmpty)
    #expect(try repo!.list().count == 1) // Allein Lesen der Notiz erzeugt keinen Termin.
    coordinator = nil; repo = nil

    let reopened = try SwiftDataSessionRepository(storeURL: url)
    let another = try SwiftDataSessionRepository(storeURL: url)
    _ = try another.load(id: first.id) // Zweiter Kontext hat den alten Elternstand schon gelesen.
    let next = try reopened.createFollowUp(after: first.id, identity: first.identity, at: Date())
    #expect(next.fictionalWeek == 1 && next.turns.isEmpty)
    let repeated = try another.createFollowUp(after: first.id, identity: first.identity,
                                             at: Date().addingTimeInterval(999_999))
    #expect(repeated.id == next.id && repeated.startedAt == next.startedAt)
    #expect(try another.list().count == 2)
    #expect(try another.load(id: first.id).followUpSessionID == next.id)
    #expect(repeated.continuity?.priorSessions.first?.id == first.id)
    let pending = PendingTurn(id: UUID(), sessionID: next.id, expectedRevision: 0,
                              input: "Was beschäftigt Sie heute?", createdAt: Date())
    try another.savePending(pending)
    let thirdReader = try SwiftDataSessionRepository(storeURL: url)
    #expect(try thirdReader.loadPending(sessionID: next.id) == pending)
    #expect(try thirdReader.createFollowUp(after: first.id, identity: first.identity, at: Date()).id == next.id)
    #expect(throws: TrainerFailure.sessionCompleted) {
        try thirdReader.createFollowUp(after: next.id, identity: next.identity, at: Date())
    }
    try thirdReader.delete(id: next.id)
    #expect(try thirdReader.list().isEmpty)
    #expect(throws: TrainerFailure.sessionNotFound) { try thirdReader.load(id: first.id) }
}

@Test @MainActor func abgebrochenerFolgeterminSpeichertWederKindNochElternverweis() async throws {
    let repo = try SwiftDataSessionRepository(inMemory: true)
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "test", version: "1", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Hallo.", publicProfile: "Test", facts: [])
    let coordinator = ConversationCoordinator(repository: repo, provider: DemoModelProvider())
    let first = try await coordinator.create(content: .init(scenario: scenario, codingGuide: "G", tips: []), contentHash: "H")
    _ = try repo.finish(sessionID: first.id, expectedRevision: 0, endedAt: Date())
    let task = Task { @MainActor in
        try repo.createFollowUp(after: first.id, identity: first.identity, at: Date())
    }
    task.cancel()
    await #expect(throws: CancellationError.self) { _ = try await task.value }
    #expect(try repo.list().count == 1)
    #expect(try repo.load(id: first.id).followUpSessionID == nil)
    let second = try repo.createFollowUp(after: first.id, identity: first.identity, at: Date())
    #expect(try repo.load(id: first.id).followUpSessionID == second.id)
}

private actor PlanProvider: TrainerModelProvider {
    let plan = "Am Samstag möchte ich ausprobieren, früher nach Hause zu gehen."
    func descriptor() -> ModelDescriptor { DemoModelProvider.identity }
    func prepare() {}
    func unload() {}
    func analyze(_ request: AnalysisRequest) -> ModelResult<TurnAnalysis> {
        let index = request.recentMessages.firstIndex { $0.text == plan }
        let observations: [NarrativeObservation] = index.map { [NarrativeObservation(kind: .planned,
            evidence: .init(source: .contextMessage, speaker: .client, messageIndex: $0, quote: plan, occurrence: 1))] } ?? []
        return .init(value: .init(segments: [], characterObservations: [], goalUpdates: [], narrativeObservations: observations),
            metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }
    func reply(_ request: ReplyRequest) -> ModelResult<ClientReply> {
        .init(value: .init(text: plan, primaryTag: nil, disclosedFactIDs: []),
              metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }
}

@Test(arguments: [false, true]) @MainActor func kuratierterZwischenverlaufUndPlanbelegBleibenNachNeustartIdentisch(planBereitsAnalysiert: Bool) async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("sessions.store")
    var repo: SwiftDataSessionRepository? = try .init(storeURL: url)
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "lukas", version: "1", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Hallo.", publicProfile: "Fiktive Testfigur", facts: [])
    var coordinator: ConversationCoordinator? = ConversationCoordinator(repository: repo!, provider: PlanProvider())
    var first = try await coordinator!.create(content: .init(scenario: scenario, codingGuide: "G", tips: []), contentHash: "H")
    first = try await coordinator!.send(sessionID: first.id, input: "Was möchten Sie versuchen?")
    if planBereitsAnalysiert { first = try await coordinator!.send(sessionID: first.id, input: "Was wäre hilfreich?") }
    #expect((first.state.narrative?.records.count ?? 0) == (planBereitsAnalysiert ? 1 : 0))
    first = try repo!.finish(sessionID: first.id, expectedRevision: first.revision, endedAt: Date())
    var second = try repo!.createFollowUp(after: first.id, identity: first.identity, at: Date())
    #expect((second.continuity?.experience != nil) == planBereitsAnalysiert)
    let nextCoordinator = ConversationCoordinator(repository: repo!, provider: PlanProvider())
    second = try await nextCoordinator.send(sessionID: second.id, input: "Wie war Ihr Versuch?")
    #expect((second.turns.first?.introducedExperience != nil) == !planBereitsAnalysiert)
    let experience = try #require(second.continuity?.experience)
    #expect(experience.fromSessionID == first.id)
    #expect(second.state.narrative?.records.first?.evidence.origin.turnID == first.turns.first?.id)
    coordinator = nil; repo = nil
    let reopened = try SwiftDataSessionRepository(storeURL: url)
    let reloaded = try reopened.load(id: second.id)
    #expect(reloaded.continuity?.experience == experience)
    #expect(reloaded.state.narrative == second.state.narrative)
    let repeated = try reopened.createFollowUp(after: first.id, identity: first.identity, at: .distantFuture)
    #expect(repeated.id == second.id && repeated.continuity?.experience == experience)
    #expect(try ContextBuilder.analysisMemory(reloaded).plans.count == 1)
    #expect(!ReviewBuilder.markdown(reloaded).contains("Kuratierter fiktiver Zwischenverlauf"))
}

@Test @MainActor func fallendeUndAbstandUeberstehenNeustart() async throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("sessions.store")
    let repo = try SwiftDataSessionRepository(storeURL: url)
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "test", version: "1", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Hallo.", publicProfile: "Fiktive Testfigur", facts: [])
    let coordinator = ConversationCoordinator(repository: repo, provider: DemoModelProvider())
    let first = try await coordinator.create(content: .init(scenario: scenario, codingGuide: "Test", tips: []), contentHash: "test")
    _ = try repo.finish(sessionID: first.id, expectedRevision: 0, endedAt: Date())
    #expect(throws: TrainerFailure.invalidInput) { try repo.createFollowUp(after: first.id, identity: first.identity, at: Date(), intervalWeeks: 4) }
    let second = try repo.createFollowUp(after: first.id, identity: first.identity, at: Date(), intervalWeeks: 1)
    let done = try repo.finish(sessionID: second.id, expectedRevision: 0, endedAt: Date())
    let closed = try repo.closeCase(sessionID: done.id, at: Date())
    #expect(closed.caseClosure?.outcome == .endedWithoutMaintenance)
    let reopened = try SwiftDataSessionRepository(storeURL: url)
    let loaded = try reopened.load(id: second.id)
    #expect(loaded.caseClosure == closed.caseClosure && loaded.intervalWeeks == 1 && loaded.fictionalWeek == 1)
    #expect(try reopened.closeCase(sessionID: second.id, at: .distantFuture) == loaded)
    #expect(throws: TrainerFailure.sessionCompleted) { try reopened.createFollowUp(after: second.id, identity: second.identity, at: Date()) }
    #expect(throws: TrainerFailure.sessionCompleted) { try reopened.closeCase(sessionID: first.id, at: Date()) }
}
