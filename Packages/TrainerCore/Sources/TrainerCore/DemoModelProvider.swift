import Foundation

/// Ausschließlich zum Prüfen des App-Ablaufs. Keine KI und keine fachliche Einordnung.
public actor DemoModelProvider: TrainerModelProvider {
    public static let identity = ModelDescriptor(id: "demo-fixed-responses", artifactRevision: "1", runtimeRevision: "1", effectiveContextLimit: 4096)
    public init() {}
    public func descriptor() -> ModelDescriptor { Self.identity }
    public func prepare() throws { try Task.checkCancellation() }
    public func unload() {}
    public func analyze(_ request: AnalysisRequest) throws -> ModelResult<TurnAnalysis> {
        try Task.checkCancellation()
        return .init(value: .init(segments: []), metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }
    public func reply(_ request: ReplyRequest) async throws -> ModelResult<ClientReply> {
        let start = ContinuousClock.now
        try await Task.sleep(for: .milliseconds(450))
        let lines = [
            "Ich finde halt, Sarah macht da ziemlich Druck. Unter der Woche gehe ich doch ganz normal arbeiten.",
            "Mit den Jungs am Wochenende ist es einfach entspannt. Aber klar, sonntags bin ich dann oft völlig platt.",
            "Ich will Sarah ja auch nicht verlieren. Bloß gar nicht mehr mit den anderen losziehen kann ich mir gerade nicht vorstellen.",
            "Im Urlaub war das anders. Da waren wir zwei Wochen zusammen weg, das war eigentlich richtig schön.",
            "Keine Ahnung, was ich davon heute ändern will. Erst mal wollte ich einfach sagen, wie das für mich ist."
        ]
        let previous = request.recentMessages.last(where: { $0.speaker == .client })?.text
        let next = previous.flatMap { lines.firstIndex(of: $0) }.map { ($0 + 1) % lines.count } ?? 0
        let text = lines[next]
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        return .init(value: .init(text: text, primaryTag: nil, disclosedFactIDs: []),
                     metrics: .init(durationSeconds: seconds), contextMessagesUsed: request.recentMessages)
    }
}
