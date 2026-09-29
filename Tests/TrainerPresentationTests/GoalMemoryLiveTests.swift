import Foundation
import Testing
import TrainerCore
@testable import TrainerDesktop

/// Kostenpflichtiger, ausdrücklich aktivierter Integrationstest. Klientenaussagen sind
/// fiktive feste Stimuli, die Analysen kommen unverändert vom produktiven Modelladapter.
/// So hängen Widerruf/Zielwechsel nicht vom Zufall einer generierten Rollenreaktion ab.
private actor GoalLiveProvider: TrainerModelProvider {
    let live: OpenRouterModelProvider
    let replies: [String]
    var index = 0
    var requests: [AnalysisRequest] = []
    var results: [TurnAnalysis] = []
    init(replies: [String]) {
        self.replies = replies
        let recorder = GoalRawRecorder()
        live = OpenRouterModelProvider(analysisDiagnostics: { data in await recorder.record(data) })
    }
    nonisolated func descriptor() -> ModelDescriptor { OpenRouterModelProvider().descriptor() }
    func prepare() async throws {
        do { try await live.prepare() }
        catch { print("Live-Zieltest: Authentifizierung lokal nicht verfügbar (vor Netzaufruf)."); throw error }
    }
    func unload() async { await live.unload() }
    func analyze(_ request: AnalysisRequest) async throws -> ModelResult<TurnAnalysis> {
        requests.append(request)
        let result = try await live.analyze(request)
        results.append(result.value)
        return result
    }
    func reply(_ request: ReplyRequest) -> ModelResult<ClientReply> {
        let text = replies[index]; index += 1
        return .init(value: .init(text: text, primaryTag: nil, disclosedFactIDs: []),
                     metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }
}

private actor GoalRawRecorder {
    var index = 0
    func record(_ data: Data) {
        index += 1
        guard let report = ProcessInfo.processInfo.environment["RR_GOAL_LIVE_REPORT"] else { return }
        // Nur fiktive Analyseinhalte; außerhalb des Repositorys oder im ignorierten Ergebnisordner.
        try? data.write(to: URL(fileURLWithPath: report + ".analysis-\(index).json"), options: .atomic)
    }
}

private struct GoalLiveStep: Codable {
    var round: Int
    var input: String
    var scriptedReply: String
    var analysis: TurnAnalysis?
    var state: CharacterDevelopment?
    var metrics: [ModelCallMetrics]
    var contextMessages: Int
    var recalledGoals: Int
    var omittedGoals: Int
    var originalGoalInContext: Bool
    var checks: [String: Bool]
}
private struct GoalLiveReport: Codable {
    var analysisTokens = OpenRouterConfiguration().analysisTokens
    var analysisTokensRetry = OpenRouterConfiguration().analysisTokensRetry
    var analysisReasoning = OpenRouterConfiguration().analysisReasoning
    var promptVersion = ConversationCoordinator.promptVersion
    var rulesVersion = ConversationCoordinator.rulesVersion
    var model = OpenRouterConfiguration().model
    var started = Date()
    var finished: Date?
    var mode = "Produktive Live-Analyse; feste fiktive Klientenantworten; keine Live-Rollenprüfung"
    var steps: [GoalLiveStep] = []
    var error: String?
    func save() throws {
        guard let path = ProcessInfo.processInfo.environment["RR_GOAL_LIVE_REPORT"] else { return }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["RR_RUN_GOAL_LIVE"] == "1"))
func zielgedaechtnisLiveMitFuenfzehnRunden() async throws {
    let goal = "Ich will ab jetzt jeden Abend höchstens zwei Bier trinken statt vier."
    let alias = "Ich meine damit: maximal zwei Bier pro Abend, nicht mehr vier."
    let newGoal = "Zwei Bier sind nicht mehr mein Ziel. Ich will stattdessen ab jetzt vollständig auf Alkohol verzichten."
    let replies = [
        goal, alias, "Das mit den zwei Bier pro Abend traue ich mir sicher zu.",
        "Ja, genau das vereinbaren wir: ab jetzt höchstens zwei Bier jeden Abend.",
        "Heute war ich mit dem Rad unterwegs.", "Die Strecke führte am Fluss entlang.",
        "Dort war es ruhig.", "Ich habe eine Pause auf einer Bank gemacht.",
        "Die Sonne kam noch einmal raus.", "Dann bin ich nach Hause gefahren.",
        "Der Ausflug hat mir gefallen.", newGoal,
        "Ich nehme das Ziel, vollständig auf Alkohol zu verzichten, ausdrücklich zurück. Das will ich nicht mehr.",
        "Vielleicht will ich doch ganz auf Alkohol verzichten. Ich bin unsicher und möchte mich gerade nicht festlegen.",
        "Ich brauche noch Zeit zum Nachdenken."
    ]
    let inputs = [
        "Was möchten Sie beim Trinken konkret verändern?", "Wie würden Sie dieses Ziel noch einmal in Ihren Worten beschreiben?",
        "Wie zuversichtlich sind Sie, dass Sie das schaffen?", "Vereinbaren wir als Ziel ab jetzt höchstens zwei Bier jeden Abend?",
        "Was möchten Sie heute noch erzählen?", "Wo sind Sie gefahren?", "Wie war es dort?",
        "Was haben Sie dann gemacht?", "Wie war das Wetter?", "Wie ging es weiter?", "Wie war der Ausflug insgesamt?",
        "Was denken Sie heute über unser früher vereinbartes Ziel?", "Was möchten Sie dazu ergänzen?",
        "Was geht Ihnen jetzt durch den Kopf?", "Sie müssen sich jetzt nicht festlegen. Was brauchen Sie gerade?"
    ]
    let provider = GoalLiveProvider(replies: replies)
    let repository = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repository, provider: provider)
    let loaded = try ContentCatalog.load()
    var scenario = try #require(loaded.catalog.scenarios.first)
    scenario.openingLine = "Ich bin hier, um über meinen Alltag zu sprechen."
    let content = SessionContent(scenario: scenario, codingGuide: loaded.catalog.codingGuide, tips: loaded.catalog.tips)
    var report = GoalLiveReport()
    try report.save()
    do {
        var saved = try await coordinator.create(content: content, contentHash: loaded.hash)
        for (index, input) in inputs.enumerated() {
            saved = try await coordinator.send(sessionID: saved.id, input: input)
            let request = try #require(await provider.requests.last)
            let turn = try #require(saved.turns.last)
            let goals = saved.state.development?.goals ?? []
            let original = goals.first { $0.goal.quote == goal || $0.goal.quote.contains("zwei Bier") }
            let abstinence = goals.first { $0.goal.quote.contains("vollständig") }
            var checks: [String: Bool] = [:]
            let round = index + 1
            if round == 2 { checks["Ziel eingeführt"] = original?.memory?.lastEvent?.kind == .introduced }
            if round == 3 {
                checks["Umformulierung als Alias"] = !(original?.memory?.aliases.isEmpty ?? true)
                checks["Kein zweiter Verlauf für gleiche Menge"] = goals.count == 1
                checks["Noch keine Vereinbarung vor Antwort"] = original?.memory?.standing != .agreed
            }
            if round == 4 { checks["Aktueller Vorschlag noch keine Vereinbarung"] = original?.memory?.standing != .agreed }
            if round == 5 { checks["Vereinbarung nach Zustimmung"] = original?.memory?.standing == .agreed }
            if round == 12 {
                checks["Alter Originalbeleg zurückgeholt"] = request.recentMessages.contains { $0.text == goal }
                checks["Original außerhalb des Rollenfensters"] = !ContextBuilder.messages(saved).contains { $0.text == goal }
                checks["Vereinbarung über Kontextlücke erhalten"] = original?.memory?.standing == .agreed
            }
            if round == 13 {
                checks["Reduktion ersetzt"] = original?.memory?.standing == .replaced
                checks["Abstinenz als getrenntes Ziel"] = abstinence != nil && goals.count == 2
            }
            if round == 14 { checks["Abstinenz widerrufen"] = abstinence?.memory?.standing == .withdrawn }
            if round == 15 {
                checks["Unsicheres Vielleicht reaktiviert nicht"] = abstinence?.memory?.standing == .withdrawn
                checks["Unsicherheit belegt"] = abstinence?.memory?.lastEvent?.isUncertain == true
                    || abstinence?.readiness?.isUncertain == true || abstinence?.readiness?.assessment == .ambivalent
                    || abstinence?.readiness?.assessment == .unclear
            }
            report.steps.append(.init(round: round, input: input, scriptedReply: replies[index], analysis: turn.analysis,
                state: saved.state.development, metrics: turn.metrics, contextMessages: request.recentMessages.count,
                recalledGoals: request.knownGoals.count, omittedGoals: request.omittedGoalCount,
                originalGoalInContext: request.recentMessages.contains { $0.text == goal }, checks: checks))
            try report.save()
            print("Live-Zieltest Runde \(round)/15: \(checks.values.filter { $0 }.count)/\(checks.count) Erwartungen erfüllt")
        }
        report.finished = Date(); try report.save()
        for step in report.steps {
            for (name, passed) in step.checks { #expect(passed, "Runde \(step.round): \(name)") }
        }
    } catch {
        report.error = "\(error); gestartete Analyseversuche: \(await provider.requests.count), decodierte Antworten: \(await provider.results.count)"; report.finished = Date(); try report.save()
        throw error
    }
}

private func liveRef(_ quote: String, _ index: Int, _ speaker: Speaker = .client) -> EvidenceReference {
    .init(source: .contextMessage, speaker: speaker, messageIndex: index, quote: quote, occurrence: 1)
}
private func fixtureAppend(_ session: inout SessionSnapshot, input: String = "Erzählen Sie weiter.", reply: String,
                           analysis: TurnAnalysis? = nil) throws {
    let id = UUID(), before = session.state
    if let analysis {
        session.state.development = try CharacterTracker.advance(before.development, analysis: analysis,
            input: input, context: ContextBuilder.analysisMemory(session).messages, session: session, turnID: id)
        try CharacterTracker.validate(session.state.development, session: session, currentTurnID: id)
    }
    session.turns.append(.init(id: id, input: input, analysis: analysis,
        reply: .init(text: reply, primaryTag: nil, disclosedFactIDs: []), stateBefore: before, stateAfter: session.state,
        stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
    session.revision += 1
}
private struct GoalProbeResult: Codable {
    var name: String
    var analysis: TurnAnalysis?
    var state: CharacterDevelopment?
    var metrics: ModelCallMetrics?
    var error: String?
    var checks: [String: Bool] = [:]
}
private struct GoalProbeReport: Codable {
    var analysisTokens = OpenRouterConfiguration().analysisTokens
    var analysisTokensRetry = OpenRouterConfiguration().analysisTokensRetry
    var analysisReasoning = OpenRouterConfiguration().analysisReasoning
    var promptVersion = ConversationCoordinator.promptVersion
    var mode = "Einzelne Live-Analysen mit technisch gesetzten, belegten Vorzuständen; keine durchgehende Live-Entwicklung"
    var started = Date()
    var finished: Date?
    var results: [GoalProbeResult] = []
    func save() throws {
        guard let path = ProcessInfo.processInfo.environment["RR_GOAL_LIVE_REPORT"] else { return }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["RR_RUN_GOAL_LIVE"] == "1"))
func zielgedaechtnisLiveEinzelneUebergaenge() async throws {
    let loaded = try ContentCatalog.load()
    var scenario = try #require(loaded.catalog.scenarios.first)
    scenario.openingLine = "Ich möchte über meinen Alltag sprechen."
    var base = SessionSnapshot(schemaVersion: 1, id: UUID(), revision: 0, approachID: "mi",
        identity: .init(contentHash: loaded.hash, rulesVersion: ConversationCoordinator.rulesVersion,
                        promptVersion: ConversationCoordinator.promptVersion, model: OpenRouterModelProvider().descriptor()),
        content: .init(scenario: scenario, codingGuide: loaded.catalog.codingGuide, tips: []),
        state: .init(openness: scenario.opennessStart), turns: [], status: .active, startedAt: Date())
    let goal = "Ich will ab jetzt jeden Abend höchstens zwei Bier trinken statt vier."
    try fixtureAppend(&base, reply: goal)
    try fixtureAppend(&base, reply: "Heute war ich spazieren.", analysis: .init(segments: [], goalUpdates: [
        .init(kind: .introduced, currentGoal: liveRef(goal, 2), evidence: liveRef(goal, 2))]))
    for _ in 0..<8 { try fixtureAppend(&base, reply: "Der Spaziergang war ruhig.") }
    let recorder = GoalRawRecorder()
    let provider = OpenRouterModelProvider(analysisDiagnostics: { data in await recorder.record(data) })
    try await provider.prepare()
    var report = GoalProbeReport(); try report.save()
    for name in ["alias", "pending", "agreement", "replacement", "withdrawal", "uncertainty", "confidence"] {
        var session = base
        var input = "Was möchten Sie dazu noch sagen?"
        switch name {
        case "alias": try fixtureAppend(&session, reply: "Ich meine dasselbe Ziel: maximal zwei Bier jeden Abend statt vier.")
        case "pending": input = "Vereinbaren wir ab jetzt höchstens zwei Bier jeden Abend?"
        case "agreement": try fixtureAppend(&session, input: "Vereinbaren wir ab jetzt höchstens zwei Bier jeden Abend?",
                                             reply: "Ja, genau das vereinbaren wir: ab jetzt höchstens zwei Bier jeden Abend.")
        case "replacement": try fixtureAppend(&session, reply: "Ich ändere mein Ziel. Statt höchstens zwei Bier jeden Abend will ich ab jetzt vollständig auf Alkohol verzichten.")
        case "withdrawal": try fixtureAppend(&session, reply: "Ich nehme mein Ziel, höchstens zwei Bier pro Abend zu trinken, ausdrücklich zurück.")
        case "uncertainty":
            let quote = "Ich nehme mein Ziel, höchstens zwei Bier pro Abend zu trinken, ausdrücklich zurück."
            try fixtureAppend(&session, reply: quote)
            let memory = try ContextBuilder.analysisMemory(session)
            let index = try #require(memory.messages.firstIndex { $0.text == quote })
            try fixtureAppend(&session, reply: "Vielleicht will ich doch auf zwei Bier reduzieren. Ich bin unsicher und lege mich nicht fest.",
                analysis: .init(segments: [], goalUpdates: [.init(kind: .withdrawn,
                    previousGoal: memory.goals[0].goal, evidence: liveRef(quote, index))]))
        case "confidence": try fixtureAppend(&session, reply: "Ich will weiterhin höchstens zwei Bier pro Abend trinken. Aber ich traue mir das überhaupt nicht zu.")
        default: break
        }
        let memory = try ContextBuilder.analysisMemory(session)
        var entry = GoalProbeResult(name: name)
        entry.checks["Alter Originalbeleg außerhalb des Sechs-Turn-Fensters zurückgeholt"] = memory.messages.contains { $0.text == goal }
            && !ContextBuilder.messages(session).contains { $0.text == goal }
        do {
            let result = try await provider.analyze(.init(codingGuide: session.content.codingGuide, recentMessages: memory.messages,
                currentInput: input, knownGoals: memory.goals, omittedGoalCount: memory.omittedGoalCount))
            entry.analysis = result.value; entry.metrics = result.metrics
            let id = UUID()
            let state = try CharacterTracker.advance(session.state.development, analysis: result.value, input: input,
                context: memory.messages, session: session, turnID: id)
            try CharacterTracker.validate(state, session: session, currentTurnID: id)
            entry.state = state
            let goals = state?.goals ?? [], original = goals.first { $0.goal.quote == goal }
            switch name {
            case "alias": entry.checks["Ein Verlauf mit Alias"] = goals.count == 1 && !(original?.memory?.aliases.isEmpty ?? true)
            case "pending": entry.checks["Keine Vereinbarung ohne Antwort"] = original?.memory?.standing == .mentioned
            case "agreement": entry.checks["Vereinbarung nach Zustimmung"] = original?.memory?.standing == .agreed
            case "replacement": entry.checks["Zwei getrennte Ziele, altes ersetzt"] = goals.count == 2 && original?.memory?.standing == .replaced
            case "withdrawal": entry.checks["Ziel zurückgenommen"] = original?.memory?.standing == .withdrawn
            case "uncertainty": entry.checks["Keine Reaktivierung aus Vielleicht"] = goals.count == 1 && original?.memory?.standing == .withdrawn
            case "confidence": entry.checks["Zweifel beim bekannten Ziel"] = goals.count == 1 && original?.confidence?.assessment == .doubtful
            default: break
            }
        } catch { entry.error = String(describing: error) }
        report.results.append(entry); try report.save()
        print("Live-Gegenprobe \(name): \(entry.error ?? "decodiert"), \(entry.checks.values.filter { $0 }.count)/\(entry.checks.count) Erwartungen")
    }
    report.finished = Date(); try report.save(); await provider.unload()
    for result in report.results {
        #expect(result.error == nil, "\(result.name): \(result.error ?? "")")
        for (name, passed) in result.checks { #expect(passed, "\(result.name): \(name)") }
    }
}
