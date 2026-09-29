import Foundation

/// Separate, optionale Messspur. Keine Änderung am gespeicherten Gesprächsvertrag:
/// ModelCallMetrics enthält weiterhin ausschließlich angenommene Ergebnisse.
public struct ModelTraceEvent: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case runStarted, roundStarted, roundFinished, coordinatorRetry, callStarted, callFinished
    }
    public enum Stage: String, Codable, Sendable { case goalMemory, counselorAnalysis, roleReply }
    public enum Outcome: String, Codable, Sendable {
        case accepted, truncated, generationError, emptyContent, refused, httpError
        case malformedResponse, invalidOutput, transportError, cancelled
    }
    public var schemaVersion = 1
    public var kind: Kind
    public var id: UUID
    public var timestamp: Double = Date().timeIntervalSince1970
    /// UTC-Unixzeit des Starts; auch im vollständigen callFinished-Datensatz erhalten.
    public var startedAt: Double?
    /// Vom Dateischreiber ergänzt; monoton relativ zum Anfang dieser Messspur.
    public var offsetSeconds: Double?
    public var runID: UUID?
    public var roundID: UUID?
    public var coordinatorAttempt: Int?
    public var stage: Stage?
    public var model: String?
    public var promptVersion: String?
    public var rulesVersion: String?
    public var temperature: Double?
    public var reasoningEnabled: Bool?
    public var budget: Int?
    public var budgetAttempt: Int?
    public var retryReason: String?
    public var outcome: Outcome?
    public var result: String?
    public var durationSeconds: Double?
    public var transportSeconds: Double?
    public var httpStatus: Int?
    public var finishReason: String?
    public var generationID: String?
    public var provider: String?
    public var inputTokens: Int?
    public var outputTokens: Int?
    /// Von der Antwort gemeldete USD-Kosten; nil heißt unbekannt, niemals kostenlos.
    public var costUSD: Decimal?
    public var contentScalarCount: Int?
    public var whitespaceScalarCount: Int?
    public var longestWhitespaceRun: Int?
    public var trailingWhitespaceCount: Int?
    public var suspectedWhitespaceLoop: Bool?

    public init(kind: Kind, id: UUID = UUID()) {
        self.kind = kind; self.id = id
        roundID = ModelTraceScope.context.roundID
        coordinatorAttempt = ModelTraceScope.context.coordinatorAttempt
    }

    public static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    /// Keine error.localizedDescription: Transportfehler können URLs/Inhalte enthalten.
    public static func resultCode(_ error: any Error) -> String {
        if error is CancellationError { return "cancelled" }
        switch error as? TrainerFailure {
        case .invalidAnalysis: return "invalidAnalysis"
        case .invalidReply: return "invalidReply"
        case .roundDeadlineExceeded: return "roundDeadlineExceeded"
        case .modelRefusal: return "modelRefusal"
        case .contextLimit: return "contextLimit"
        case .modelUnavailable: return "modelUnavailable"
        case .artifactInvalid: return "artifactInvalid"
        case .storageUnavailable: return "storageUnavailable"
        case .revisionConflict: return "revisionConflict"
        default: return "otherFailure"
        }
    }
}

public struct ModelTraceContext: Sendable {
    public var roundID: UUID?
    public var coordinatorAttempt: Int?
    public init(roundID: UUID? = nil, coordinatorAttempt: Int? = nil) {
        self.roundID = roundID; self.coordinatorAttempt = coordinatorAttempt
    }
}

/// Task-lokal statt veränderlichem Adapterzustand: parallele Sitzungen und die Kinder
/// der Rundenfrist behalten ihre eigene Zuordnung. Direkte Adapteraufrufe bleiben nil.
public enum ModelTraceScope {
    @TaskLocal public static var context = ModelTraceContext()
}

/// Synchroner, threadsicher zu implementierender Empfänger. Ein aktivierter Empfänger
/// darf Schreibfehler werfen: ein Messlauf soll nicht still ohne Nachweise weiterlaufen.
public struct ModelTraceSink: Sendable {
    private let write: @Sendable (ModelTraceEvent) throws -> Void
    public init(_ write: @escaping @Sendable (ModelTraceEvent) throws -> Void) { self.write = write }
    public func record(_ event: ModelTraceEvent) throws { try write(event) }
}
