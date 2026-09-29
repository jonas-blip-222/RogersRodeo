import Foundation
import Testing
@testable import TrainerCore

private let sustain = "Die Abende helfen Ihnen abzuschalten."
private let change = "Und Sie möchten sonntags fitter sein."
private let clientText = "Die Abende helfen mir abzuschalten. Ich möchte sonntags fitter sein."
private let context: [DialogueMessage] = [.init(speaker: .client, text: clientText)]
private let rule = "rueckmeldung.doppelseitige_reflexion"

private func side(_ quote: String, _ support: String) -> ReflectionSide {
    .init(input: .init(source: .currentInput, speaker: .counselor, messageIndex: nil, quote: quote, occurrence: 1),
          client: .init(source: .contextMessage, speaker: .client, messageIndex: 0, quote: support, occurrence: 1))
}
private func fixture(reverse: Bool = false, uncertain: Bool = false) -> (String, TurnAnalysis) {
    let text = reverse ? "\(change) \(sustain)" : "\(sustain) \(change)"
    return (text, .init(segments: [.init(quote: text, code: .complexReflection, isUncertain: false,
                                       supportingClientQuote: clientText)],
        doubleSidedReflection: .init(sustain: side(sustain, "Die Abende helfen mir abzuschalten."),
                                    change: side(change, "Ich möchte sonntags fitter sein."), isUncertain: uncertain)))
}
private func findings(_ analysis: TurnAnalysis, _ input: String) -> [FeedbackFinding] {
    FeedbackEngine.findings(analysis: analysis, input: input, context: context, characterName: "Lukas", rulesVersion: "0.1")
}

@Test func sustainDannChangeLobtAusdruecklichDieReihenfolge() throws {
    let (input, analysis) = fixture()
    let decoded = try OutputValidator.decodeAnalysis(JSONEncoder().encode(analysis), input: input, context: context)
    let result = findings(decoded, input)
    let praise = try #require(result.first { $0.ruleID == rule })
    #expect(praise.message.contains("Gut angeordnet"))
    #expect(praise.message.contains("Change Talk am Ende"))
    #expect(praise.evidence.count == 4)
    #expect(praise.templateVersion == "0.2")
    #expect(praise.sourceID == "E04")
    #expect(!result.contains { $0.ruleID == "rueckmeldung.komplexe_reflexion" })
    for reference in praise.evidence { try OutputValidator.validateEvidence(reference, input: input, context: context) }
    // Beobachtung und Lob ändern die Zustandsregeln nicht.
    var without = analysis; without.doubleSidedReflection = nil
    let before = SimulationState(openness: 3)
    #expect(try StateReducer.reduce(before, analysis: analysis, input: input, context: context).state
        == StateReducer.reduce(before, analysis: without, input: input, context: context).state)
}

@Test func umgekehrteReihenfolgeIstKeinFehlerAberErhaeltKeinReihenfolgelob() throws {
    let (input, analysis) = fixture(reverse: true)
    try OutputValidator.validateAnalysis(analysis, input: input, context: context)
    #expect(!findings(analysis, input).contains { $0.ruleID == rule || $0.kind == .warning })
}

@Test func unsicherheitInBeobachtungOderSegmentVerhindertReihenfolgelob() {
    let (input, uncertain) = fixture(uncertain: true)
    #expect(!findings(uncertain, input).contains { $0.ruleID == rule })
    var (_, analysis) = fixture()
    analysis.segments[0].isUncertain = true
    #expect(!findings(analysis, input).contains { $0.ruleID == rule })
}

@Test func falscheUndUeberlappendeBelegeWerdenAbgewiesen() throws {
    let (input, original) = fixture()
    var bad: [TurnAnalysis] = []
    var a = original; a.doubleSidedReflection?.change.client.quote = "Ich will sofort abstinent werden."; bad.append(a)
    a = original; a.doubleSidedReflection?.change.client.messageIndex = 1; bad.append(a)
    a = original; a.doubleSidedReflection?.change.client.speaker = .counselor; bad.append(a)
    a = original; a.doubleSidedReflection?.change.input = original.doubleSidedReflection!.sustain.input; bad.append(a)
    a = original; a.doubleSidedReflection?.change.input.occurrence = 2; bad.append(a)
    a = original; a.segments[0].code = .adviceWithoutPermission; bad.append(a)
    a = original; a.doubleSidedReflection?.change.client.occurrence = 0; bad.append(a)
    for analysis in bad {
        #expect(throws: TrainerFailure.invalidAnalysis) {
            try OutputValidator.decodeAnalysis(JSONEncoder().encode(analysis), input: input, context: context)
        }
        #expect(!findings(analysis, input).contains { $0.ruleID == rule })
    }
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(original, input: input, context: [])
    }
}

@Test func zweiReflexionssegmenteUndWiederholteZitateBehaltenIhrePosition() throws {
    var (input, analysis) = fixture()
    input = "\(change) \(sustain) \(change)"
    analysis.segments = [
        .init(quote: change, code: .simpleReflection, isUncertain: false),
        .init(quote: sustain, code: .simpleReflection, isUncertain: false),
        .init(quote: change, code: .simpleReflection, isUncertain: false)]
    analysis.doubleSidedReflection?.change.input.occurrence = 2
    try OutputValidator.validateAnalysis(analysis, input: input, context: context)
    #expect(findings(analysis, input).contains { $0.ruleID == rule })
    analysis.doubleSidedReflection?.change.input.occurrence = 1
    #expect(!findings(analysis, input).contains { $0.ruleID == rule })
}

@Test func alteAnalyseUndNullErfindenKeineBeobachtung() throws {
    for json in [#"{"segments":[]}"#, #"{"segments":[],"doubleSidedReflection":null}"#] {
        let decoded = try OutputValidator.decodeAnalysis(Data(json.utf8), input: "Hallo", context: [])
        #expect(decoded.doubleSidedReflection == nil)
    }
    let (input, analysis) = fixture()
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(analysis)) as? [String: Any])
    var pair = try #require(object["doubleSidedReflection"] as? [String: Any])
    pair["bonus"] = 5; object["doubleSidedReflection"] = pair
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.decodeAnalysis(JSONSerialization.data(withJSONObject: object), input: input, context: context)
    }
}

@Test func reihenfolgelobKommtFruehUndWirdMitAnalyseGespeichert() async throws {
    let (input, analysis) = fixture()
    let provider = ScriptedProvider(script: [input: analysis], holdsReply: true)
    let repo = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    var content = TestData.content; content.scenario.openingLine = clientText
    let session = try await coordinator.create(content: content, contentHash: "test")
    #expect(session.identity.promptVersion == ConversationCoordinator.promptVersion)
    let recorder = FeedbackRecorder()
    let sink = await recorder.sink
    let task = Task { try await coordinator.send(sessionID: session.id, input: input, onFeedback: sink) }
    await provider.waitUntilReplyHeld()
    let early = await recorder.received
    #expect(early.first?.findings.contains { $0.ruleID == rule } == true)
    #expect(try await repo.load(id: session.id).turns.isEmpty)
    await provider.release()
    let saved = try await task.value
    #expect(saved.turns.first?.feedback == early.first?.findings)
    let restored = try JSONDecoder().decode(SessionSnapshot.self, from: JSONEncoder().encode(saved))
    #expect(restored == saved)
    #expect(restored.turns.first?.analysis?.doubleSidedReflection == analysis.doubleSidedReflection)
}

@Test func altePromptstaendeBleibenLesbarAberWerdenNichtStillFortgesetzt() async throws {
    var old = TestData.session(); old.identity.promptVersion = "0.1"
    let repo = MemorySessionRepository(); try await repo.create(old)
    let provider = ControlledProvider()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    await #expect(throws: TrainerFailure.unsupportedVersion) {
        try await coordinator.send(sessionID: old.id, input: "Hallo")
    }
    #expect(try await repo.load(id: old.id) == old)
    #expect(await provider.analyses == 0)
}

@Test func speziellesLobBleibtBeiMehrerenBefundenSichtbarUndWarnungenZuerst() {
    var (input, analysis) = fixture()
    let prefix = "Sie entscheiden. Womit beginnen wir? Sie müssen! "
    input = prefix + input
    analysis.segments.insert(contentsOf: [
        .init(quote: "Sie entscheiden.", code: .autonomy, isUncertain: false),
        .init(quote: "Womit beginnen wir?", code: .collaboration, isUncertain: false),
        .init(quote: "Sie müssen!", code: .confrontation, isUncertain: false)], at: 0)
    let result = findings(analysis, input)
    #expect(result.first?.kind == .warning)
    #expect(result.filter { $0.kind == .observation }.count == 2)
    #expect(result.contains { $0.ruleID == rule })
}
