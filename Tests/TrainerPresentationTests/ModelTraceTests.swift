import Foundation
import Testing
import TrainerCore
@testable import TrainerDesktop

private final class TraceCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [ModelTraceEvent] = []
    var sink: ModelTraceSink { ModelTraceSink { [self] event in
        lock.lock(); defer { lock.unlock() }; values.append(event)
    } }
    var events: [ModelTraceEvent] { lock.lock(); defer { lock.unlock() }; return values }
    var calls: [ModelTraceEvent] { events.filter { $0.kind == .callFinished } }
}

private let traceReply = #"{"text":"Vielleicht.","primaryTag":null,"disclosedFactIDs":[]}"#
private let traceMemory = #"{"goalUpdates":[],"characterObservations":[]}"#
private let traceAnalysis = #"{"segments":[{"quote":"Hallo","code":"sonstiges","isUncertain":false,"supportingClientQuote":null}],"doubleSidedReflection":null}"#
private let traceRequest = ReplyRequest(publicProfile: "PRIVATE_PROFILE", behaviorInstruction: "PRIVATE_BEHAVIOR",
    visibleFacts: [], recentMessages: [], currentInput: "PRIVATE_INPUT", analysis: nil)

private func traceEnvelope(_ text: String, finish: String = "stop", usage: Bool = true,
                           refusal: String? = nil, id: String = "gen-fixture") -> Data {
    var message: [String: Any] = ["content": text]
    if let refusal { message["refusal"] = refusal }
    var body: [String: Any] = ["id": id, "provider": "Fixture Provider",
        "choices": [["message": message, "finish_reason": finish]]]
    if usage { body["usage"] = ["prompt_tokens": 100, "completion_tokens": 20, "cost": 0.00125] }
    return try! JSONSerialization.data(withJSONObject: body)
}

private actor TraceTransport {
    enum Step: Sendable { case response(Data, Int), failure, wait }
    var steps: [Step]
    private(set) var requests: [URLRequest] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(_ steps: [Step]) { self.steps = steps }
    func waitForStart() async {
        if !requests.isEmpty { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func handle(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        for waiter in waiters { waiter.resume() }; waiters.removeAll()
        guard !steps.isEmpty else { throw URLError(.badServerResponse) }
        switch steps.removeFirst() {
        case let .response(data, status):
            return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        case .failure: throw URLError(.cannotConnectToHost, userInfo: [NSLocalizedDescriptionKey: "PRIVATE_ERROR"])
        case .wait: try await Task.sleep(for: .seconds(30)); throw URLError(.timedOut)
        }
    }
    nonisolated var transport: OpenRouterTransport { { [self] request in try await handle(request) } }
}

private func traceProvider(_ stub: TraceTransport, collector: TraceCollector? = nil, path: String? = nil) -> OpenRouterModelProvider {
    var configuration = OpenRouterConfiguration()
    configuration.environment = ["OPENROUTER_API_KEY": "PRIVATE_KEY_FIXTURE"]
    if let path { configuration.environment["RR_MODEL_TRACE_FILE"] = path }
    return OpenRouterModelProvider(configuration: configuration, transport: stub.transport, traceSink: collector?.sink)
}

private func traceSession(_ coordinator: ConversationCoordinator) async throws -> SessionSnapshot {
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "lukas", version: "0.1", status: .draft,
        name: "Lukas", age: 28, address: "Sie", approaches: ["mi"], opennessStart: 3,
        openingLine: "Hallo.", publicProfile: "Fiktiv.", facts: [])
    return try await coordinator.create(content: .init(scenario: scenario, codingGuide: "G", tips: []), contentHash: "fixture")
}

@Test func messspurBehaeltAbgeschnittenenVersuchKostenUndLeerraumOhneText() async throws {
    let whitespace = "PRIVATE_CONTENT" + String(repeating: " \n", count: 100)
    let stub = TraceTransport([.response(traceEnvelope(whitespace, finish: "length"), 200), .response(traceEnvelope(traceReply), 200)])
    let collector = TraceCollector()
    // Explizit injizierte Senke: der Prozess kann keine versehentliche Dateiaktivierung erben.
    let measured = traceProvider(stub, collector: collector)
    try await measured.prepare()
    _ = try await measured.reply(traceRequest)
    let calls = collector.calls
    #expect(calls.count == 2)
    #expect(calls.map(\.outcome) == [.truncated, .accepted])
    #expect(calls.map(\.budget) == [2000, 4000])
    #expect(calls.map(\.budgetAttempt) == [1, 2])
    #expect(calls[1].retryReason == "truncated")
    #expect(calls.allSatisfy { $0.costUSD == Decimal(string: "0.00125") && $0.provider == "Fixture Provider" })
    #expect(calls[0].generationID == "gen-fixture")
    #expect(calls.allSatisfy { ($0.startedAt ?? .infinity) <= $0.timestamp })
    #expect(calls[0].longestWhitespaceRun == 200 && calls[0].trailingWhitespaceCount == 200)
    #expect(calls[0].suspectedWhitespaceLoop == true)
    #expect(calls[0].finishReason == "length" && calls[0].httpStatus == 200)
    #expect(calls.allSatisfy { $0.coordinatorAttempt == nil && $0.roundID == nil })
    let serialized = String(decoding: try JSONEncoder().encode(collector.events), as: UTF8.self)
    #expect(!serialized.contains("PRIVATE_"))
    #expect(!serialized.contains("Authorization"))
    #expect(!serialized.contains("Vielleicht"))
    for request in await stub.requests {
        let body = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        #expect((body["usage"] as? [String: Bool])?["include"] == true)
        #expect((body["provider"] as? [String: Any])?["require_parameters"] as? Bool == true)
    }
    #expect(Set(collector.events.filter { $0.kind == .callStarted }.map(\.id)) == Set(calls.map(\.id)))
}

@Test func messspurErsteStufeBleibtBeiScheiternderZweiterErhalten() async throws {
    let stub = TraceTransport([.response(traceEnvelope(traceMemory), 200), .response(traceEnvelope("PRIVATE_INVALID"), 200)])
    let collector = TraceCollector()
    let measured = traceProvider(stub, collector: collector)
    try await measured.prepare()
    await #expect(throws: TrainerFailure.invalidAnalysis) {
        _ = try await measured.analyze(.init(codingGuide: "G", recentMessages: [], currentInput: "Hallo"))
    }
    #expect(collector.calls.map(\.stage) == [.goalMemory, .counselorAnalysis])
    #expect(collector.calls.map(\.outcome) == [.accepted, .invalidOutput])
    #expect(collector.calls.allSatisfy { $0.inputTokens == 100 && $0.outputTokens == 20 && $0.costUSD != nil })
}

@Test func messspurTransportfehlerHttpRefusalUndFehlendeKosten() async throws {
    let cases: [(TraceTransport.Step, ModelTraceEvent.Outcome)] = [
        (.failure, .transportError), (.response(Data("PRIVATE_ERROR".utf8), 503), .httpError),
        (.response(traceEnvelope("PRIVATE_CONTENT", refusal: "PRIVATE_REFUSAL"), 200), .refused),
        (.response(Data("PRIVATE_BAD_JSON".utf8), 200), .malformedResponse),
        (.response(traceEnvelope(traceReply, usage: false), 200), .accepted)]
    for (step, outcome) in cases {
        let collector = TraceCollector(), stub = TraceTransport([step])
        let provider = traceProvider(stub, collector: collector)
        try await provider.prepare()
        _ = try? await provider.reply(traceRequest)
        let call = try #require(collector.calls.first)
        #expect(collector.calls.count == 1 && call.outcome == outcome)
        if outcome != .refused { #expect(call.costUSD == nil) }
        #expect(call.durationSeconds != nil && call.transportSeconds != nil)
        #expect(!String(decoding: try JSONEncoder().encode(collector.events), as: UTF8.self).contains("PRIVATE_"))
    }
}

@Test func messspurAbbruchErfasstDenBereitsBegonnenenAufruf() async throws {
    let collector = TraceCollector(), stub = TraceTransport([.wait])
    let provider = traceProvider(stub, collector: collector)
    try await provider.prepare()
    let task = Task { try await provider.reply(traceRequest) }
    await stub.waitForStart()
    task.cancel()
    await #expect(throws: CancellationError.self) { _ = try await task.value }
    #expect(collector.calls.count == 1)
    #expect(collector.calls.first?.outcome == .cancelled)
    #expect(collector.calls.first?.costUSD == nil)
}

@Test func messspurCoordinatorWiederholungHatEigeneVersuchsnummerUndRundenabschluss() async throws {
    let collector = TraceCollector()
    let stub = TraceTransport([.response(traceEnvelope(traceMemory), 200), .response(traceEnvelope("invalid"), 200),
        .response(traceEnvelope(traceMemory), 200), .response(traceEnvelope(traceAnalysis), 200), .response(traceEnvelope(traceReply), 200)])
    let provider = traceProvider(stub, collector: collector)
    let coordinator = ConversationCoordinator(repository: MemorySessionRepository(), provider: provider)
    let session = try await traceSession(coordinator)
    let saved = try await coordinator.send(sessionID: session.id, input: "Hallo")
    #expect(saved.turns.count == 1)
    #expect(collector.calls.map(\.coordinatorAttempt) == [1, 1, 2, 2, 1])
    #expect(Set(collector.calls.compactMap(\.roundID)).count == 1)
    #expect(collector.events.filter { $0.kind == .coordinatorRetry }.map(\.retryReason) == ["invalidAnalysis"])
    #expect(collector.events.last?.kind == .roundFinished && collector.events.last?.result == "completed")
    #expect(saved.turns[0].metrics.count == 2) // alter Snapshot-Vertrag unverändert
}

@Test func messspurFristablaufIstRundenfehlerUndAufrufabbruch() async throws {
    let collector = TraceCollector(), stub = TraceTransport([.wait])
    let provider = traceProvider(stub, collector: collector)
    let repository = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repository, provider: provider, roundDeadline: .milliseconds(100))
    let session = try await traceSession(coordinator)
    await #expect(throws: TrainerFailure.roundDeadlineExceeded) {
        _ = try await coordinator.send(sessionID: session.id, input: "Hallo")
    }
    #expect(collector.calls.count == 1 && collector.calls.first?.outcome == .cancelled)
    #expect(collector.events.last?.result == "roundDeadlineExceeded")
    #expect(try await repository.load(id: session.id).turns.isEmpty)
}

@Test func messspurSchreibfehlerVerhindertUnbeobachtetenNetzaufruf() async throws {
    var configuration = OpenRouterConfiguration()
    configuration.environment = ["OPENROUTER_API_KEY": "PRIVATE_KEY_FIXTURE"]
    let stub = TraceTransport([.response(traceEnvelope(traceReply), 200)])
    let provider = OpenRouterModelProvider(configuration: configuration, transport: stub.transport,
        traceSink: ModelTraceSink { _ in throw TrainerFailure.artifactInvalid })
    try await provider.prepare()
    await #expect(throws: TrainerFailure.artifactInvalid) { _ = try await provider.reply(traceRequest) }
    #expect(await stub.requests.isEmpty)
}

@Test func messspurBestehendeDateiWirdNichtUeberschrieben() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("rr-trace-existing-\(UUID()).jsonl")
    try Data("existing".utf8).write(to: url)
    let provider = traceProvider(TraceTransport([]), path: url.path)
    await #expect(throws: TrainerFailure.artifactInvalid) { try await provider.prepare() }
    #expect(try String(contentsOf: url, encoding: .utf8) == "existing")
}

/// Darf gezielt über Tools/model_trace.py run ausgeführt werden: ausschließlich Stubtransport.
@Test func messspurOfflineBeispiellauf() async throws {
    let path = ProcessInfo.processInfo.environment["RR_MODEL_TRACE_FILE"]
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("rr-trace-example-\(UUID()).jsonl").path
    let stub = TraceTransport([.response(traceEnvelope("{" + String(repeating: " ", count: 256), finish: "length"), 200),
        .response(traceEnvelope(traceMemory), 200), .response(traceEnvelope(traceAnalysis), 200), .response(traceEnvelope(traceReply), 200)])
    let provider = traceProvider(stub, path: path)
    let coordinator = ConversationCoordinator(repository: MemorySessionRepository(), provider: provider)
    let session = try await traceSession(coordinator)
    _ = try await coordinator.send(sessionID: session.id, input: "Hallo")
    let lines = try String(contentsOfFile: path, encoding: .utf8).split(separator: "\n")
    let events = try lines.map { try JSONDecoder().decode(ModelTraceEvent.self, from: Data($0.utf8)) }
    #expect(events.first?.kind == .runStarted)
    #expect(events.filter { $0.kind == .callFinished }.count == 4)
    #expect(events.last?.kind == .roundFinished)
    #expect(Set(events.compactMap(\.runID)).count == 1)
    #expect(events.allSatisfy { $0.offsetSeconds != nil })
    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@Test func messspurErfasstBeideBudgetstufenUndZweitenCoordinatorFehlschlag() async throws {
    let collector = TraceCollector()
    let stub = TraceTransport((0..<4).map { _ in .response(traceEnvelope(" ", finish: "error"), 200) })
    let repository = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repository, provider: traceProvider(stub, collector: collector))
    let session = try await traceSession(coordinator)
    await #expect(throws: TrainerFailure.invalidAnalysis) {
        _ = try await coordinator.send(sessionID: session.id, input: "Hallo")
    }
    #expect(collector.calls.map(\.budget) == [1500, 4000, 1500, 4000])
    #expect(collector.calls.map(\.coordinatorAttempt) == [1, 1, 2, 2])
    #expect(collector.calls.map(\.outcome) == Array(repeating: .generationError, count: 4))
    #expect(collector.events.last?.result == "invalidAnalysis")
    #expect(try await repository.load(id: session.id).turns.isEmpty)
}

@Test func messspurRollenwiederholungUndParalleleRundenBleibenZugeordnet() async throws {
    let collector = TraceCollector()
    func make() -> ConversationCoordinator {
        let stub = TraceTransport([.response(traceEnvelope("invalid"), 200), .response(traceEnvelope(traceReply), 200)])
        return ConversationCoordinator(repository: MemorySessionRepository(), provider: traceProvider(stub, collector: collector))
    }
    let first = make(), second = make()
    let a = try await traceSession(first), b = try await traceSession(second)
    async let left = first.send(sessionID: a.id, input: "Hallo", skipAnalysis: true)
    async let right = second.send(sessionID: b.id, input: "Hallo", skipAnalysis: true)
    let results = try await (left, right)
    #expect(results.0.turns.count == 1 && results.1.turns.count == 1)
    let groups = Dictionary(grouping: collector.calls, by: \.roundID)
    #expect(groups.count == 2 && groups[nil] == nil)
    for calls in groups.values {
        #expect(calls.map(\.coordinatorAttempt) == [1, 2])
        #expect(calls.map(\.outcome) == [.invalidOutput, .accepted])
        #expect(calls.allSatisfy { $0.stage == .roleReply })
    }
    #expect(collector.events.filter { $0.kind == .coordinatorRetry }.map(\.retryReason) == ["invalidReply", "invalidReply"])
}

@Test func messspurAbbruchNachAntwortBewahrtBereitsGemeldeteKosten() async throws {
    var configuration = OpenRouterConfiguration()
    configuration.environment = ["OPENROUTER_API_KEY": "PRIVATE_KEY_FIXTURE"]
    let collector = TraceCollector()
    let provider = OpenRouterModelProvider(configuration: configuration, transport: { request in
        withUnsafeCurrentTask { $0?.cancel() }
        return (traceEnvelope(traceReply), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }, traceSink: collector.sink)
    try await provider.prepare()
    let task = Task { try await provider.reply(traceRequest) }
    await #expect(throws: CancellationError.self) { _ = try await task.value }
    let call = try #require(collector.calls.first)
    #expect(call.outcome == .cancelled && call.httpStatus == 200)
    #expect(call.costUSD == Decimal(string: "0.00125") && call.generationID == "gen-fixture")
}

@Test func messspurAbschlussfehlerMachtGespeicherteRundeNichtZumFehlschlag() async throws {
    var configuration = OpenRouterConfiguration()
    configuration.environment = ["OPENROUTER_API_KEY": "PRIVATE_KEY_FIXTURE"]
    let collector = TraceCollector(), stub = TraceTransport([.response(traceEnvelope(traceReply), 200)])
    let provider = OpenRouterModelProvider(configuration: configuration, transport: stub.transport,
        traceSink: ModelTraceSink { event in
            if event.kind == .roundFinished { throw TrainerFailure.artifactInvalid }
            try collector.sink.record(event)
        })
    let repository = MemorySessionRepository()
    let coordinator = ConversationCoordinator(repository: repository, provider: provider)
    let session = try await traceSession(coordinator)
    let result = try await coordinator.send(sessionID: session.id, input: "Hallo", skipAnalysis: true)
    #expect(result.turns.count == 1)
    #expect(try await repository.load(id: session.id).turns.count == 1)
    #expect(collector.calls.count == 1)
    #expect(!collector.events.contains { $0.kind == .roundFinished }) // Auswerter meldet offene Spanne.
}

@Test func messspurLeerraumHeuristikIstKeineInhaltsreparaturUndUnbekanntIstNichtNull() {
    var event = ModelTraceEvent(kind: .callFinished)
    OpenRouterTraceMetadata.fill(&event, data: traceEnvelope(String(repeating: " ", count: 256), finish: "stop", usage: false))
    #expect(event.suspectedWhitespaceLoop == false)
    #expect(event.longestWhitespaceRun == 256)
    #expect(event.costUSD == nil && event.inputTokens == nil && event.outputTokens == nil)
    OpenRouterTraceMetadata.fill(&event, data: traceEnvelope(String(repeating: "x \n", count: 100), finish: "length"))
    #expect(event.suspectedWhitespaceLoop == false) // Viele Leerzeichen, aber kein langer Lauf.
    #expect(event.longestWhitespaceRun == 2)
}
