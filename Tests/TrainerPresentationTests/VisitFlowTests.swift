import Foundation
import Testing
import TrainerCore
import TrainerStorage
@testable import TrainerDesktop

@Test @MainActor func appZeigtVorbereitungVorDemFolgeterminUndBehaeltDenFall() async throws {
    let name = "rr-visit-test-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let repository = try SwiftDataSessionRepository(inMemory: true)
    let model = try AppModel(defaults: defaults, hasModelKey: false, repository: repository)
    model.acceptDisclaimer()
    let scenario = try #require(model.catalog.scenarios.first)
    func wait() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while model.busy && .now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(!model.busy)
        try #require(model.errorMessage == nil)
    }
    model.start(scenario)
    try await wait()
    let first = try #require(model.session)
    #expect(first.openingLine == "Hallo.")
    model.finish(discardDraft: false)
    #expect(model.showReview)
    model.prepareFollowUp()
    #expect(model.preparation != nil)
    #expect(try repository.list().count == 1)
    model.preparation = nil // Zurück ist folgenlos.
    model.prepareFollowUp()
    model.startFollowUp(); model.startFollowUp() // Schneller Doppelklick.
    try await wait()
    let second = try #require(model.session)
    #expect(second.caseID == first.id && second.sessionNumber == 2)
    #expect(model.preparation == nil && !model.showReview)
    #expect(try repository.list().count == 2)
    model.input = "Was beschäftigt Sie heute?"
    model.send()
    try await wait()
    #expect(model.session?.turns.count == 1)
    #expect(model.usesDemoResponses)
    model.close(); model.open(first.id)
    model.prepareFollowUp()
    #expect(model.session?.id == second.id)
    #expect(model.preparation == nil)
    #expect(try repository.list().count == 2)
}

@Test func folgeterminPromptsKennzeichnenHistorieOhneEinordnungslabelsInDerRolle() {
    let old = DialogueMessage(speaker: .client, text: "Ich möchte weniger trinken.", visitNumber: 1)
    let greeting = DialogueMessage(speaker: .client, text: "Hallo.", visitNumber: 2)
    let context = "Sitzung 2. Eine fiktionale Woche später. Keine erfundenen Zwischenereignisse."
    let analysis = AnalysisRequest(codingGuide: "G", recentMessages: [old, greeting], currentInput: "Wie geht es Ihnen?", visitContext: context)
    #expect(OpenRouterSchema.analysisPrompt(analysis).contains("[0] Sitzung 1 · Klient: Ich möchte weniger trinken."))
    #expect(OpenRouterSchema.memoryPrompt(analysis).contains(context))
    let reply = ReplyRequest(publicProfile: "Test", behaviorInstruction: "Test", visibleFacts: [],
        recentMessages: [old, greeting], currentInput: "Wie geht es Ihnen?",
        analysis: .init(segments: [.init(quote: "SECRET_ANALYSIS_LABEL", code: .confrontation, isUncertain: false)]), visitContext: context)
    let prompt = OpenRouterSchema.replyPrompt(reply)
    #expect(prompt.contains(context) && prompt.contains("Sitzung 1 · Du:"))
    #expect(!prompt.contains("SECRET_ANALYSIS_LABEL"))
}

@Test func neueErfahrungsanalyseIstStriktUndRollenErfahrungBleibtPrivat() throws {
    let schema = try JSONSerialization.jsonObject(with: OpenRouterSchema.memoryAnalysis.serialized()) as? [String: Any]
    let required = try #require(schema?["required"] as? [String])
    #expect(Set(required) == ["goalUpdates", "characterObservations", "narrativeObservations"])
    let missing = Data(#"{"goalUpdates":[],"characterObservations":[]}"#.utf8)
    #expect(throws: TrainerFailure.invalidAnalysis) { try OpenRouterResponse.decodeMemory(missing, context: []) }
    let invalidKind = Data(#"{"goalUpdates":[],"characterObservations":[],"narrativeObservations":[{"kind":"maintenance","evidence":{"source":"kontextnachricht","speaker":"client","messageIndex":0,"quote":"Hallo","occurrence":1},"goal":null,"plan":null,"isUncertain":false}]}"#.utf8)
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OpenRouterResponse.decodeMemory(invalidKind, context: [.init(speaker: .client, text: "Hallo")])
    }
    let request = ReplyRequest(publicProfile: "P", behaviorInstruction: "B", visibleFacts: [], recentMessages: [],
        currentInput: "Hallo", analysis: .init(segments: [], narrativeObservations: [
            .init(kind: .planned, evidence: .init(source: .contextMessage, speaker: .client, messageIndex: 0, quote: "PRIVATE_ANALYSIS_PLAN", occurrence: 1))]))
    #expect(!OpenRouterSchema.rolePrompt(request).contains("PRIVATE_ANALYSIS_PLAN"))
    #expect(!OpenRouterSchema.replyPrompt(request).contains("PRIVATE_ANALYSIS_PLAN"))
}
