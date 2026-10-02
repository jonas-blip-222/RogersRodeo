import Foundation
import Testing
@testable import TrainerCore
@testable import TrainerDesktop

private actor RoleComparisonTransport {
    private var calls = 0
    private var cost = 0.0
    private let session = URLSession(configuration: .ephemeral)
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard calls < 40, cost < 0.50 else { throw TrainerFailure.modelUnavailable }
        calls += 1
        let result = try await session.data(for: request)
        if let body = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
           let error = body["error"] as? [String: Any] {
            let secret = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? "<absent>"
            let safe = String(describing: error).replacingOccurrences(of: secret, with: "[redacted]")
            print("Providerdiagnose: HTTP \((result.1 as? HTTPURLResponse)?.statusCode ?? 0), \(safe.prefix(1200))")
        }
        if let body = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
           let usage = body["usage"] as? [String: Any], let billed = usage["cost"] as? Double {
            cost += billed
        }
        return result
    }
    func totals() -> (Int, Double) { (calls, cost) }
}
private struct RoleComparisonRow: Codable {
    var round: Int
    var sample: Int
    var model: String
    var input: String
    var originalReply: String
    var reply: ClientReply?
    var seconds: Double?
    var error: String?
}
private struct RoleComparisonReport: Codable {
    var rows: [RoleComparisonRow]
    var calls: Int
    var reportedCostUSD: Double
}

/// Opt-in: dieselben eingefrorenen Kontexte und Zustände für beide Rollenmodelle.
/// Kein Analyseaufruf, kein Schreiben in den ursprünglichen Sitzungsspeicher.
@Test(.enabled(if: ProcessInfo.processInfo.environment["RR_RUN_ROLE_COMPARISON"] == "1"))
func lukasRollenmodelleLiveVergleichen() async throws {
    let env = ProcessInfo.processInfo.environment
    let input = try #require(env["RR_ROLE_COMPARISON_INPUT"])
    let output = try #require(env["RR_ROLE_COMPARISON_REPORT"])
    let record = try JSONDecoder().decode(SessionRecord.self, from: Data(contentsOf: URL(fileURLWithPath: input)))
    #expect(record.snapshot.turns.count <= 20)
    let transport = RoleComparisonTransport()
    var rows: [RoleComparisonRow] = []
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    for model in (env["RR_ROLE_COMPARISON_MODEL"].map { [$0] } ?? ["qwen/qwen3.8-27b", "anthropic/claude-sonnet-5.5"]) {
        var configuration = OpenRouterConfiguration(); configuration.model = model
        // Sonnet-Endpunkt verlangt Reasoning (live HTTP 400 bei enabled=false).
        // Identische Rollenvorgaben, notwendige anbieterspezifische Transporteinstellung.
        configuration.replyReasoning = model.hasPrefix("anthropic/") ? nil : false
        let provider = OpenRouterModelProvider(configuration: configuration, transport: { try await transport.send($0) })
        try await provider.prepare()
        for (index, turn) in record.snapshot.turns.prefix(Int(env["RR_ROLE_MAX_ROUNDS"] ?? "20") ?? 20).enumerated() {
            var before = record.snapshot
            before.turns = Array(before.turns.prefix(index)); before.state = turn.stateBefore
            // Dieselbe Freigabe wie nach der damaligen Reduktion, aber noch keine
            // neu offengelegten Fakten aus der zu vergleichenden Antwort markieren.
            var replyState = turn.stateBefore; replyState.openness = turn.stateAfter.openness
            let request = ReplyRequest(publicProfile: before.content.scenario.publicProfile,
                behaviorInstruction: ContextBuilder.behavior(replyState.openness),
                visibleFacts: ContextBuilder.visibleFacts(before.content.scenario, state: replyState),
                recentMessages: ContextBuilder.messages(before), currentInput: turn.input, analysis: turn.analysis)
            let samples = [0, 4, 7].contains(index) ? 2 : 1
            for sample in 1...samples {
                var row = RoleComparisonRow(round: index + 1, sample: sample, model: model,
                    input: turn.input, originalReply: turn.reply.text)
                do {
                    let result = try await RoundDeadline.run(until: .now.advanced(by: .seconds(120))) {
                        try await provider.reply(request)
                    }
                    row.reply = result.value; row.seconds = result.metrics.durationSeconds
                } catch { row.error = ModelTraceEvent.resultCode(error) }
                rows.append(row)
                let (calls, cost) = await transport.totals()
                try encoder.encode(RoleComparisonReport(rows: rows, calls: calls, reportedCostUSD: cost))
                    .write(to: URL(fileURLWithPath: output), options: .atomic)
                print("Rollenvergleich \(model) Runde \(index + 1)/\(sample): \(row.error ?? "angenommen")")
                if row.error == "modelUnavailable" { throw TrainerFailure.modelUnavailable }
            }
        }
        await provider.unload()
    }
    #expect(rows.allSatisfy { $0.reply != nil })
}
