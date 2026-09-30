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
    init(directory: URL, configuration: OpenRouterConfiguration, maxCalls: Int = 16) {
        self.directory = directory; self.maxCalls = maxCalls
        let settings = URLSessionConfiguration.ephemeral
        settings.timeoutIntervalForRequest = configuration.idleSeconds
        settings.timeoutIntervalForResource = configuration.deadlineSeconds
        settings.urlCache = nil
        session = URLSession(configuration: settings)
    }
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        // Harte Aufrufgrenze; Kostenprüfung zusätzlich anhand bereits gemeldeter Kosten.
        guard calls < maxCalls, reportedCost < 0.10 else { throw TrainerFailure.modelUnavailable }
        calls += 1
        let index = calls
        let (data, response) = try await session.data(for: request)
        if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let usage = body["usage"] as? [String: Any], let cost = usage["cost"] as? Double {
                reportedCost += cost
            }
            // Nur Modellantwort und Abrechnungsmetadaten. Niemals Request/Authorization.
            let allowed = body.filter { ["id", "provider", "usage", "choices"].contains($0.key) }
            let safe = try JSONSerialization.data(withJSONObject: allowed, options: [.prettyPrinted, .sortedKeys])
            try safe.write(to: directory.appendingPathComponent("response-\(index).json"), options: .atomic)
        }
        return (data, response)
    }
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
    let guide = try env["RR_ANALYSIS_REPLAY_GUIDE"].map { try String(contentsOfFile: $0, encoding: .utf8) }
    let config = OpenRouterConfiguration()
    let transport = ReplayTransport(directory: directory, configuration: config)
    let provider = OpenRouterModelProvider(configuration: config, transport: { request in
        try await transport.send(request)
    })
    try await provider.prepare()
    var results: [ReplayStep] = []
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    for (index, turn) in record.snapshot.turns.enumerated() {
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
    guard cases.count <= 10 else { throw TrainerFailure.invalidInput }
    let guide = try String(contentsOfFile: guidePath, encoding: .utf8)
    let config = OpenRouterConfiguration()
    let transport = ReplayTransport(directory: directory, configuration: config, maxCalls: 24)
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
        } catch { row.error = ModelTraceEvent.resultCode(error) }
        row.elapsedSeconds = ModelTraceEvent.seconds(start.duration(to: .now))
        results.append(row)
        try encoder.encode(results).write(to: directory.appendingPathComponent("report.json"), options: .atomic)
        print("Kontrast \(item.id): \(row.error ?? "angenommen"), \(row.elapsedSeconds) Sekunden")
    }
    await provider.unload()
}
