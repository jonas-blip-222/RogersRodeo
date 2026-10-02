import Foundation
import Testing
@testable import TrainerCore
@testable import TrainerDesktop

// Ausschließlich ausdrücklich aktivierter Diagnoselauf mit freigegebenem fiktivem
// Gespräch. Kein Rollenaufruf, keine Schlüssel-/Headerausgabe, keine automatische CI-Aktivierung.
private actor ReplayTransport {
    let directory: URL
    let session: URLSession
    let maxCalls: Int
    var calls = 0
    var reportedCost = 0.0
    let reportedCostLimit: Double
    private enum Limit: Error { case reached }
    init(directory: URL, configuration: OpenRouterConfiguration, maxCalls: Int = 16) {
        self.directory = directory; self.maxCalls = maxCalls
        let requested = Double(ProcessInfo.processInfo.environment["RR_LIVE_COST_LIMIT_USD"] ?? "0.10") ?? 0.10
        reportedCostLimit = requested.isFinite && requested > 0 && requested <= 0.50 ? requested : 0.10
        let settings = URLSessionConfiguration.ephemeral
        settings.timeoutIntervalForRequest = configuration.idleSeconds
        settings.timeoutIntervalForResource = configuration.deadlineSeconds
        settings.urlCache = nil
        session = URLSession(configuration: settings)
    }
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // Harte Aufrufgrenze; Kostenprüfung zusätzlich anhand bereits gemeldeter Kosten.
        guard calls < maxCalls, reportedCost < reportedCostLimit else {
            try Data("Diagnosegrenze erreicht: weitere Aufrufe wurden nicht gesendet.\n".utf8)
                .write(to: directory.appendingPathComponent("limit-reached.txt"), options: .atomic)
            throw Limit.reached
        }
        calls += 1
        let index = calls
        let (data, response) = try await session.data(for: request)
        if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let usage = body["usage"] as? [String: Any], let cost = usage["cost"] as? Double {
                reportedCost += cost
            }
            // Nur Modellantwort und Abrechnungsmetadaten. Niemals Request/Authorization.
            var allowed = body.filter { ["id", "provider", "usage", "choices"].contains($0.key) }
            if let error = body["error"] as? [String: Any] {
                let message = String(describing: error["message"] ?? "")
                    .replacingOccurrences(of: ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? "<absent>", with: "[redacted]")
                var diagnostic: [String: Any] = ["code": error["code"] ?? NSNull(), "message": String(message.prefix(800))]
                if let metadata = error["metadata"] as? [String: Any] {
                    let raw = String(describing: metadata["raw"] ?? "")
                        .replacingOccurrences(of: ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? "<absent>", with: "[redacted]")
                    diagnostic["providerMessage"] = String(raw.prefix(800))
                }
                allowed["error"] = diagnostic
            }
            let safe = try JSONSerialization.data(withJSONObject: allowed, options: [.prettyPrinted, .sortedKeys])
            try safe.write(to: directory.appendingPathComponent("response-\(index).json"), options: .atomic)
        }
        return (data, response)
    }
}

private func replayConfiguration(_ env: [String: String]) throws -> OpenRouterConfiguration {
    var config = OpenRouterConfiguration()
    if let model = env["RR_ANALYSIS_REPLAY_MODEL"] {
        config.model = model; config.analysisModel = nil
    }
    if let reasoning = env["RR_ANALYSIS_REPLAY_REASONING"] {
        switch reasoning {
        case "auto": config.analysisReasoning = nil
        case "true": config.analysisReasoning = true
        case "false": config.analysisReasoning = false
        default: throw TrainerFailure.invalidInput
        }
    }
    if let raw = env["RR_ANALYSIS_REPLAY_TOKENS"] {
        guard let tokens = Int(raw), (1500...8000).contains(tokens) else { throw TrainerFailure.invalidInput }
        config.analysisTokens = tokens; config.analysisTokensRetry = max(tokens, config.analysisTokensRetry)
    }
    return config
}

private struct ReplayStep: Codable {
    var round: Int
    var elapsedSeconds: Double
    var analysis: TurnAnalysis?
    var error: String?
    var feedback: [FeedbackFinding]?
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["RR_RUN_ANALYSIS_REPLAY"] == "1"))
func freigegebenesFiktivesGespraechLiveNachpruefen() async throws {
    let env = ProcessInfo.processInfo.environment
    let input = try #require(env["RR_ANALYSIS_REPLAY_INPUT"])
    let destination = try #require(env["RR_ANALYSIS_REPLAY_DIRECTORY"])
    let directory = URL(fileURLWithPath: destination)
    let record = try JSONDecoder().decode(SessionRecord.self, from: Data(contentsOf: URL(fileURLWithPath: input)))
    guard record.snapshot.turns.count <= 5 else { throw TrainerFailure.invalidInput }
    let maxRounds = Int(env["RR_REPLAY_MAX_ROUNDS"] ?? "5") ?? 5
    guard (1...5).contains(maxRounds) else { throw TrainerFailure.invalidInput }
    let guide = try env["RR_ANALYSIS_REPLAY_GUIDE"].map { try String(contentsOfFile: $0, encoding: .utf8) }
    let config = try replayConfiguration(env)
    let transport = ReplayTransport(directory: directory, configuration: config)
    let provider = OpenRouterModelProvider(configuration: config, transport: { request in
        try await transport.send(request)
    })
    try await provider.prepare()
    var results: [ReplayStep] = []
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    for (index, turn) in record.snapshot.turns.prefix(maxRounds).enumerated() {
        var before = record.snapshot
        before.turns = Array(before.turns.prefix(index))
        before.state = turn.stateBefore
        before.revision = index
        let memory = try ContextBuilder.analysisMemory(before)
        let request = AnalysisRequest(codingGuide: guide ?? before.content.codingGuide,
            recentMessages: memory.messages, currentInput: turn.input,
            knownGoals: memory.goals, omittedGoalCount: memory.omittedGoalCount)
        let start = ContinuousClock.now
        var row = ReplayStep(round: index + 1, elapsedSeconds: 0)
        do {
            let result = try await ModelTraceScope.$context.withValue(.init(roundID: turn.id, coordinatorAttempt: 1)) {
                try await RoundDeadline.run(until: .now.advanced(by: .seconds(120))) {
                    try await provider.analyze(request)
                }
            }
            let accepted = try CharacterTracker.acceptingIndependentMemory(result.value,
                before: before.state.development, input: turn.input, context: result.contextMessagesUsed,
                session: before, turnID: turn.id)
            row.analysis = accepted.analysis
            row.feedback = FeedbackEngine.findings(analysis: accepted.analysis, input: turn.input,
                context: result.contextMessagesUsed, characterName: before.content.scenario.name,
                rulesVersion: ConversationCoordinator.rulesVersion,
                permission: .init(entries: PermissionTracker.resolve(accepted.analysis.permissions ?? [], context: result.contextMessagesUsed),
                                  contextIsComplete: ContextBuilder.covers(result.contextMessagesUsed, session: before)))
        } catch { row.error = ModelTraceEvent.resultCode(error) }
        row.elapsedSeconds = ModelTraceEvent.seconds(start.duration(to: .now))
        results.append(row)
        try encoder.encode(results).write(to: directory.appendingPathComponent("report.json"), options: .atomic)
        print("Analyse-Replay Runde \(index + 1): \(row.error ?? "angenommen"), \(row.elapsedSeconds) Sekunden")
        if row.error == "modelUnavailable" { break }
    }
    await provider.unload()
}


private struct ContrastCollection: Decodable {
    struct Case: Decodable {
        var id: String
        var kontext: [DialogueMessage]
        var eingabe: String
    }
    var faelle: [Case]
}
private struct ContrastResult: Encodable {
    var feedback: [FeedbackFinding]?
    var id: String
    var elapsedSeconds: Double
    var analysis: TurnAnalysis?
    var error: String?
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["RR_RUN_CONTRAST_LIVE"] == "1"))
func autonomieKontrasteLiveNachpruefen() async throws {
    let env = ProcessInfo.processInfo.environment
    let input = try #require(env["RR_CONTRAST_INPUT"])
    let guidePath = try #require(env["RR_ANALYSIS_REPLAY_GUIDE"])
    let destination = try #require(env["RR_CONTRAST_DIRECTORY"])
    let directory = URL(fileURLWithPath: destination)
    let cases = try JSONDecoder().decode(ContrastCollection.self, from: Data(contentsOf: URL(fileURLWithPath: input))).faelle
    guard cases.count <= 11 else { throw TrainerFailure.invalidInput }
    let guide = try String(contentsOfFile: guidePath, encoding: .utf8)
    let config = try replayConfiguration(env)
    let transport = ReplayTransport(directory: directory, configuration: config, maxCalls: 32)
    let provider = OpenRouterModelProvider(configuration: config, transport: { try await transport.send($0) })
    try await provider.prepare()
    var results: [ContrastResult] = []
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    for item in cases {
        // Nur Gespräch und Eingabe gelangen ins Modell, niemals die fachliche Erwartung.
        let request = AnalysisRequest(codingGuide: guide, recentMessages: item.kontext, currentInput: item.eingabe)
        let start = ContinuousClock.now
        var row = ContrastResult(id: item.id, elapsedSeconds: 0)
        do {
            let result = try await ModelTraceScope.$context.withValue(.init(roundID: UUID(), coordinatorAttempt: 1)) {
                try await RoundDeadline.run(until: .now.advanced(by: .seconds(120))) { try await provider.analyze(request) }
            }
            row.analysis = result.value
            row.feedback = FeedbackEngine.findings(analysis: result.value, input: item.eingabe,
                context: result.contextMessagesUsed, characterName: "Lukas",
                rulesVersion: ConversationCoordinator.rulesVersion)
        } catch { row.error = ModelTraceEvent.resultCode(error) }
        row.elapsedSeconds = ModelTraceEvent.seconds(start.duration(to: .now))
        results.append(row)
        try encoder.encode(results).write(to: directory.appendingPathComponent("report.json"), options: .atomic)
        print("Kontrast \(item.id): \(row.error ?? "angenommen"), \(row.elapsedSeconds) Sekunden")
        if row.error == "modelUnavailable" { break }
    }
    await provider.unload()
}
