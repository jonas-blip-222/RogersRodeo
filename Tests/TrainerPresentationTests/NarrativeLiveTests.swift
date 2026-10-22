import Foundation
import Testing
import TrainerCore
@testable import TrainerDesktop

/// Begrenzter echter Verlauf: belegte Absicht, kuratierte Zwischenwoche, berichtete
/// Erfahrung. Alle Aussagen sind eigens angelegte fiktive Testdaten.
@Test(.enabled(if: ProcessInfo.processInfo.environment["RR_RUN_NARRATIVE_LIVE"] == "1"))
@MainActor func geplanterVersuchUndBerichteteErfahrungMitSonnetLive() async throws {
    let report = try #require(ProcessInfo.processInfo.environment["RR_NARRATIVE_REPORT"])
    let catalog = try ContentCatalog.load()
    let scenario = try #require(catalog.catalog.scenarios.first)
    let provider = OpenRouterModelProvider()
    let repository = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repository, provider: provider)
    let plan = "Am kommenden Samstag möchte ich ausprobieren, früher nach Hause zu gehen."
    var first = try await coordinator.create(content: .init(scenario: scenario, codingGuide: catalog.catalog.codingGuide, tips: []),
        contentHash: catalog.hash, openingLine: plan)
    first = try await coordinator.send(sessionID: first.id, input: "Was wäre Ihnen bei diesem Versuch wichtig?")
    #expect(first.state.narrative?.records.contains { $0.kind == .planned && !$0.isUncertain && $0.evidence.quote == plan } == true)
    first = try await repository.finish(sessionID: first.id, expectedRevision: first.revision, endedAt: Date())
    var second = try await coordinator.createFollowUp(after: first.id)
    let experience = try #require(second.continuity?.experience)
    #expect(second.state.openness == first.state.openness)
    second = try await coordinator.send(sessionID: second.id, input: "Sie wollten am Samstag früher nach Hause gehen. Wie ist Ihr Versuch gelaufen?")
    second = try await coordinator.send(sessionID: second.id, input: "Wie schauen Sie jetzt auf diesen einen Versuch?")
    let reported = (second.state.narrative?.records ?? []).filter {
        [.attempted, .completed, .partial, .notAttempted, .setback].contains($0.kind) && $0.plan?.quote == plan
    }
    #expect(!reported.isEmpty)
    #expect(second.continuity?.experience == experience)
    #expect(second.turns.count == 2)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode([first, second]).write(to: URL(fileURLWithPath: report), options: .atomic)
}
