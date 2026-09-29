import Foundation
import Testing
@testable import TrainerCore

private struct Fixture: Decodable {
    let id: String
    let before: SimulationState
    let currentInput: String
    let clientContext: [String]
    let analysis: TurnAnalysis?
    let expectedAfterReduction: SimulationState
}
private struct FixtureFile: Decodable { let cases: [Fixture] }

@Test func reducerReferenceCases() throws {
    let url = try #require(Bundle.module.url(forResource: "regeltests", withExtension: "json", subdirectory: "Fixtures"))
    let file = try JSONDecoder().decode(FixtureFile.self, from: Data(contentsOf: url))
    #expect(file.cases.count == 18)
    for test in file.cases {
        let result = try StateReducer.reduce(test.before, analysis: test.analysis, input: test.currentInput,
            context: test.clientContext.map { .init(speaker: .client, text: $0) })
        #expect(result.state == test.expectedAfterReduction, "Referenzfall: \(test.id)")
    }
}

@Test func unicodeAndRepeatedQuotes() throws {
    let analysis = TurnAnalysis(segments: [
        .init(quote: "Wirklich?", code: .closedQuestion, isUncertain: false),
        .init(quote: "Wirklich?", code: .closedQuestion, isUncertain: false)])
    let result = try StateReducer.reduce(.init(openness: 3, closedQuestionStreak: 2), analysis: analysis,
                                          input: "🙂 Wirklich? Wirklich?", context: [])
    #expect(result.state.openness == 3) // Das nicht eingeordnete Emoji unterbricht die alte Folge.
    #expect(result.state.closedQuestionStreak == 2)
}

@Test func omittedTextBreaksQuestions() throws {
    let analysis = TurnAnalysis(segments: [.init(quote: "Ja?", code: .closedQuestion, isUncertain: false),
                                         .init(quote: "Nein?", code: .closedQuestion, isUncertain: false)])
    let result = try StateReducer.reduce(.init(openness: 4), analysis: analysis, input: "Ja? Sie entscheiden selbst. Nein?", context: [])
    #expect(result.state.closedQuestionStreak == 1)
}

@Test func inventedAndOverlappingQuotesAreRejected() {
    let analysis = TurnAnalysis(segments: [.init(quote: "Hallo Lukas", code: .other, isUncertain: false),
                                         .init(quote: "Lukas", code: .other, isUncertain: false)])
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analysis, input: "Hallo Lukas", context: [])
    }
}

@Test func unknownJSONFieldsRejected() {
    let data = Data(#"{"segments":[],"bonus":10}"#.utf8)
    #expect(throws: TrainerFailure.invalidAnalysis) { try OutputValidator.decodeAnalysis(data, input: "Hallo", context: []) }
}

@Test func missingAndUnknownEvidenceDiffer() throws {
    let analysis = TurnAnalysis(segments: [.init(quote: "Das war mutig.", code: .affirmation, isUncertain: false, supportingClientQuote: "Erfunden")])
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analysis, input: "Das war mutig.", context: [])
    }
}

@Test func hiddenFactsRemainHiddenUntilEligible() throws {
    let scenario = TestData.content.scenario
    #expect(ContextBuilder.visibleFacts(scenario, state: .init(openness: 3)).isEmpty)
    #expect(ContextBuilder.visibleFacts(scenario, state: .init(openness: 4)).map(\.id) == ["lukas.hausflur"])
    let known = ContextBuilder.visibleFacts(scenario, state: .init(openness: 1, disclosedFactIDs: ["lukas.vater"]))
    #expect(known.map(\.id) == ["lukas.vater"])
    #expect(known.first?.wasDisclosed == true)
    #expect(throws: TrainerFailure.invalidReply) {
        try OutputValidator.validateReply(.init(text: "Mein Vater …", primaryTag: .emotion, disclosedFactIDs: ["lukas.vater"]), visibleFacts: [])
    }
}

@Test func emptyReviewHasNoInventedRatiosOrSecrets() {
    let session = TestData.session()
    let review = ReviewBuilder.build(session)
    #expect(review.reflectionQuestionRatio == nil)
    #expect(review.complexReflectionShare == nil)
    let export = ReviewBuilder.markdown(session)
    #expect(!export.contains("Vater-Geheimnis"))
    #expect(!export.contains("openness"))
}

enum TestData {
    static let content = SessionContent(scenario: .init(schemaVersion: 1, id: "lukas", version: "0.2", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Sarah meint, ich soll hierherkommen.", publicProfile: "Lukas, 28, Elektriker.",
        facts: [.init(id: "lukas.hausflur", minimumOpenness: 4, text: "Hausflur-Geheimnis"),
                .init(id: "lukas.vater", minimumOpenness: 6, text: "Vater-Geheimnis")]), codingGuide: "Test", tips: [])
    static let model = ModelDescriptor(id: "test", artifactRevision: "1", runtimeRevision: "1", effectiveContextLimit: 4096)
    static func session() -> SessionSnapshot {
        .init(schemaVersion: 1, id: UUID(), revision: 0, approachID: "mi",
              identity: .init(contentHash: "test", rulesVersion: ConversationCoordinator.rulesVersion, promptVersion: ConversationCoordinator.promptVersion, model: model),
              content: content, state: .init(openness: 3), turns: [], status: .active, startedAt: Date())
    }
}
