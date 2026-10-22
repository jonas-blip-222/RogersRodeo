import Foundation
import Testing
import TrainerCore
@testable import TrainerDesktop

/// Opt-in: echte Analyse, echtes Zielgedächtnis und echte Rollenantwort durch
/// dieselbe AppModel-Kette wie in der Oberfläche. Ausschließlich neuer Teststore.
@Test(.enabled(if: ProcessInfo.processInfo.environment["RR_RUN_APP_FLOW_LIVE"] == "1"))
@MainActor func appGespraechMitEchtemProviderLive() async throws {
    let env = ProcessInfo.processInfo.environment
    _ = try #require(env["ROGERS_RODEO_TEST_STORAGE"])
    let report = try #require(env["RR_APP_FLOW_REPORT"])
    let defaults = try #require(UserDefaults(suiteName: "rr-live-\(UUID().uuidString)"))
    let model = try AppModel(defaults: defaults)
    #expect(!model.usesDemoResponses)
    model.acceptDisclaimer()
    let scenario = try #require(model.catalog.scenarios.first)
    func waitForOperation() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(160))
        while model.busy && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(!model.busy)
        #expect(model.errorMessage == nil)
    }
    model.start(scenario)
    try await waitForOperation()
    let initial = try #require(model.session)
    #expect(initial.identity.promptVersion == ConversationCoordinator.promptVersion)
    #expect(initial.identity.rulesVersion == ConversationCoordinator.rulesVersion)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    func send(_ input: String) async throws {
        model.input = input
        let count = model.session?.turns.count ?? 0
        model.send()
        try await waitForOperation()
        let session = try #require(model.session)
        #expect(session.turns.count == count + 1)
        #expect(model.input.isEmpty)
        try encoder.encode(session).write(to: URL(fileURLWithPath: report), options: .atomic)
    }
    try await send("Wie schätzen Sie Ihr Trinken selbst ein?")
    let first = try #require(model.session?.turns.last)
    #expect(first.feedback.contains { $0.ruleID == "rueckmeldung.offene_frage" })
    // Wortgetreues Aufgreifen des tatsächlich generierten Textes; keine Demo-Fixture.
    try await send("Wenn ich Sie richtig verstehe: \(first.reply.text)")
    let second = try #require(model.session?.turns.last)
    #expect(second.feedback.contains { $0.ruleID == "rueckmeldung.einfache_reflexion" })
    try await send("Ich fasse unsere bisherigen Gesprächsrunden zusammen: \(initial.openingLine) \(first.reply.text) \(second.reply.text)")
    let third = try #require(model.session?.turns.last)
    #expect(third.feedback.contains { $0.ruleID == "rueckmeldung.zusammenfassung" })
}

/// Zwei echte Termine in einem neuen isolierten Teststore. Keine echten Klientendaten.
@Test(.enabled(if: ProcessInfo.processInfo.environment["RR_RUN_VISIT_FLOW_LIVE"] == "1"))
@MainActor func folgeterminMitEchtemProviderLive() async throws {
    let env = ProcessInfo.processInfo.environment
    _ = try #require(env["ROGERS_RODEO_TEST_STORAGE"])
    let report = try #require(env["RR_APP_FLOW_REPORT"])
    let name = "rr-visit-live-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = try AppModel(defaults: defaults)
    #expect(!model.usesDemoResponses)
    model.acceptDisclaimer()
    func wait() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(160))
        while model.busy && .now < deadline { try await Task.sleep(for: .milliseconds(100)) }
        try #require(!model.busy)
        try #require(model.errorMessage == nil)
    }
    model.start(try #require(model.catalog.scenarios.first))
    try await wait()
    model.input = "Hallo, was möchten Sie heute besprechen?"
    model.send(); try await wait()
    model.finish(discardDraft: false)
    let first = try #require(model.session)
    #expect(first.status == .completed && first.turns.count == 1)
    model.prepareFollowUp()
    let note = try #require(model.preparation)
    #expect(note.entries.contains { $0.quote == first.turns[0].reply.text && $0.sessionID == first.id })
    model.startFollowUp(); try await wait()
    let second = try #require(model.session)
    #expect(second.caseID == first.id && second.sessionNumber == 2 && second.fictionalWeek == 1)
    #expect(second.turns.isEmpty && second.state.openness == first.state.openness)
    model.input = "Wie möchten Sie heute an unser letztes Gespräch anknüpfen?"
    model.send(); try await wait()
    let completedRound = try #require(model.session)
    #expect(completedRound.turns.count == 1)
    #expect(!completedRound.turns[0].reply.text.isEmpty)
    model.close(); model.open(first.id); model.prepareFollowUp()
    #expect(model.session?.id == second.id && model.session?.turns.count == 1)
    #expect(model.history.count == 2)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(completedRound).write(to: URL(fileURLWithPath: report), options: .atomic)
}
