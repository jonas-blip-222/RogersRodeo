import Foundation

// Eigene Core-Verträge v0.1. Keine Drittanbieter-API, keine Inferenzimplementierung.
// Alle Werte sind nach Decoding zusätzlich gegen die Invarianten des Bauplans zu prüfen.

public enum CounselorCode: String, Codable, Sendable, CaseIterable {
    case openQuestion = "offene_frage"
    case closedQuestion = "geschlossene_frage"
    case simpleReflection = "einfache_reflexion"
    case complexReflection = "komplexe_reflexion"
    case affirmation = "wuerdigung"
    case autonomy = "autonomie_betonen"
    case collaboration = "zusammenarbeit_suchen"
    case information = "information"
    case adviceWithoutPermission = "ratschlag_ohne_erlaubnis"
    case adviceWithPermission = "ratschlag_mit_erlaubnis"
    case confrontation = "konfrontation"
    case other = "sonstiges"
}

public enum ClientTag: String, Codable, Sendable, CaseIterable {
    case ambivalent, change = "veraenderung", sustain = "beibehaltung"
    case discord = "abwehr", emotion = "gefuehl", exception = "ausnahme"
    case resource = "ressource", externalMandate = "fremdauftrag"
    case informationRequest = "infofrage", terse = "einsilbig", goal = "ziel"
}

public enum ContentStatus: String, Codable, Sendable { case draft, reviewed }
public enum Speaker: String, Codable, Sendable { case counselor, client }
public enum SessionStatus: String, Codable, Sendable { case active, completed }

public struct AnalysisSegment: Codable, Sendable, Equatable {
    public var quote: String
    public var code: CounselorCode
    public var isUncertain: Bool
    public var supportingClientQuote: String?
    public init(quote: String, code: CounselorCode, isUncertain: Bool,
                supportingClientQuote: String? = nil) {
        self.quote = quote; self.code = code; self.isUncertain = isUncertain
        self.supportingClientQuote = supportingClientQuote
    }
}

/// Semantische Beobachtung, getrennt von Codes und interner Offenheit.
public struct ReflectionSide: Codable, Sendable, Equatable {
    public var input: EvidenceReference
    public var client: EvidenceReference
    public init(input: EvidenceReference, client: EvidenceReference) {
        self.input = input; self.client = client
    }
}

public struct DoubleSidedReflection: Codable, Sendable, Equatable {
    public var sustain: ReflectionSide
    public var change: ReflectionSide
    public var isUncertain: Bool
    public init(sustain: ReflectionSide, change: ReflectionSide, isUncertain: Bool) {
        self.sustain = sustain; self.change = change; self.isUncertain = isUncertain
    }
}

public struct TurnAnalysis: Codable, Sendable, Equatable {
    public var segments: [AnalysisSegment]
    /// nil heißt nicht erhoben/erkannt, niemals eine negative Bewertung.
    /// Optionals bleiben beim Lesen alter gespeicherter Analysen kompatibel.
    public var doubleSidedReflection: DoubleSidedReflection?
    /// nil: alter Stand/nicht erhoben; leer: im gesehenen Kontext keine Beobachtung.
    public var characterObservations: [CharacterObservation]?
    public var goalUpdates: [GoalUpdate]?
    public init(segments: [AnalysisSegment], doubleSidedReflection: DoubleSidedReflection? = nil,
                characterObservations: [CharacterObservation]? = nil, goalUpdates: [GoalUpdate]? = nil) {
        self.segments = segments; self.doubleSidedReflection = doubleSidedReflection
        self.characterObservations = characterObservations; self.goalUpdates = goalUpdates
    }
}

public struct ClientReply: Codable, Sendable, Equatable {
    public var text: String
    public var primaryTag: ClientTag?
    public var disclosedFactIDs: [String]
    public init(text: String, primaryTag: ClientTag?, disclosedFactIDs: [String]) {
        self.text = text; self.primaryTag = primaryTag; self.disclosedFactIDs = disclosedFactIDs
    }
}

public struct ScenarioFact: Codable, Sendable, Equatable {
    public var id: String
    public var minimumOpenness: Int
    public var text: String
    public init(id: String, minimumOpenness: Int, text: String) {
        self.id = id; self.minimumOpenness = minimumOpenness; self.text = text
    }
}

public struct ScenarioDefinition: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var id: String
    public var version: String
    public var status: ContentStatus
    public var name: String
    public var age: Int
    public var address: String
    public var approaches: [String]
    public var opennessStart: Int
    public var openingLine: String
    public var publicProfile: String
    public var facts: [ScenarioFact]
    public init(schemaVersion: Int, id: String, version: String, status: ContentStatus,
                name: String, age: Int, address: String, approaches: [String],
                opennessStart: Int, openingLine: String, publicProfile: String,
                facts: [ScenarioFact]) {
        self.schemaVersion = schemaVersion; self.id = id; self.version = version
        self.status = status; self.name = name; self.age = age; self.address = address
        self.approaches = approaches; self.opennessStart = opennessStart
        self.openingLine = openingLine; self.publicProfile = publicProfile; self.facts = facts
    }
}

public struct Tip: Codable, Sendable, Equatable {
    public var id: String
    public var version: String
    public var approachID: String
    public var triggerTag: ClientTag
    public var title: String
    public var text: String
    public var example: String
    public var sourceID: String
    public var reviewStatus: ContentStatus
    public var priority: Int
    public init(id: String, version: String, approachID: String, triggerTag: ClientTag,
                title: String, text: String, example: String, sourceID: String,
                reviewStatus: ContentStatus, priority: Int) {
        self.id = id; self.version = version; self.approachID = approachID
        self.triggerTag = triggerTag; self.title = title; self.text = text
        self.example = example; self.sourceID = sourceID
        self.reviewStatus = reviewStatus; self.priority = priority
    }
}

public struct SimulationState: Codable, Sendable, Equatable {
    public var openness: Int
    public var closedQuestionStreak: Int
    public var disclosedFactIDs: Set<String>
    // Ältester Eintrag zuerst; maximal drei. nil bedeutet: Turn ohne Gutschrift.
    public var recentCredits: [CounselorCode?]
    public var development: CharacterDevelopment?
    public init(openness: Int, closedQuestionStreak: Int = 0,
                disclosedFactIDs: Set<String> = [], recentCredits: [CounselorCode?] = [],
                development: CharacterDevelopment? = nil) {
        self.openness = openness; self.closedQuestionStreak = closedQuestionStreak
        self.disclosedFactIDs = disclosedFactIDs; self.recentCredits = recentCredits
        self.development = development
    }
}

public struct DialogueMessage: Codable, Sendable, Equatable {
    public var speaker: Speaker
    public var text: String
    public var origin: MessageOrigin?
    public init(speaker: Speaker, text: String, origin: MessageOrigin? = nil) {
        self.speaker = speaker; self.text = text; self.origin = origin
    }
}

// Nur freigegebene Fakten passieren die Grenze zum Rollenmodell.
public struct VisibleFact: Codable, Sendable, Equatable {
    public var id: String
    public var text: String
    public var wasDisclosed: Bool
    public init(id: String, text: String, wasDisclosed: Bool) {
        self.id = id; self.text = text; self.wasDisclosed = wasDisclosed
    }
}

public struct AnalysisRequest: Sendable {
    public var codingGuide: String
    public var recentMessages: [DialogueMessage]
    public var currentInput: String
    public var knownGoals: [KnownGoal]
    public var omittedGoalCount: Int
    public init(codingGuide: String, recentMessages: [DialogueMessage], currentInput: String,
                knownGoals: [KnownGoal] = [], omittedGoalCount: Int = 0) {
        self.codingGuide = codingGuide; self.recentMessages = recentMessages
        self.currentInput = currentInput; self.knownGoals = knownGoals; self.omittedGoalCount = omittedGoalCount
    }
}

public struct ReplyRequest: Sendable {
    public var publicProfile: String
    public var behaviorInstruction: String
    public var visibleFacts: [VisibleFact]
    public var recentMessages: [DialogueMessage]
    public var currentInput: String
    public var analysis: TurnAnalysis?
    public init(publicProfile: String, behaviorInstruction: String, visibleFacts: [VisibleFact],
                recentMessages: [DialogueMessage], currentInput: String, analysis: TurnAnalysis?) {
        self.publicProfile = publicProfile; self.behaviorInstruction = behaviorInstruction
        self.visibleFacts = visibleFacts; self.recentMessages = recentMessages
        self.currentInput = currentInput; self.analysis = analysis
    }
}

public struct ModelDescriptor: Codable, Sendable, Equatable {
    public var id: String
    public var artifactRevision: String
    public var runtimeRevision: String
    public var effectiveContextLimit: Int
    public init(id: String, artifactRevision: String, runtimeRevision: String,
                effectiveContextLimit: Int) {
        self.id = id; self.artifactRevision = artifactRevision
        self.runtimeRevision = runtimeRevision; self.effectiveContextLimit = effectiveContextLimit
    }
}

public struct ModelCallMetrics: Codable, Sendable, Equatable {
    public var durationSeconds: Double
    public var inputTokens: Int?
    public var outputTokens: Int?
    public init(durationSeconds: Double, inputTokens: Int? = nil, outputTokens: Int? = nil) {
        self.durationSeconds = durationSeconds; self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public struct ModelResult<Value: Sendable>: Sendable {
    public var value: Value
    public var metrics: ModelCallMetrics
    // Tatsächlich nach Tokenbudget-Kürzung verwendeter Dialogkontext.
    public var contextMessagesUsed: [DialogueMessage]
    public init(value: Value, metrics: ModelCallMetrics, contextMessagesUsed: [DialogueMessage]) {
        self.value = value; self.metrics = metrics; self.contextMessagesUsed = contextMessagesUsed
    }
}

public protocol TrainerModelProvider: Sendable {
    func descriptor() async -> ModelDescriptor
    func prepare() async throws
    func analyze(_ request: AnalysisRequest) async throws -> ModelResult<TurnAnalysis>
    func reply(_ request: ReplyRequest) async throws -> ModelResult<ClientReply>
    func unload() async
}

public struct BuildIdentity: Codable, Sendable, Equatable {
    public var contentHash: String
    public var rulesVersion: String
    public var promptVersion: String
    public var model: ModelDescriptor
    public init(contentHash: String, rulesVersion: String, promptVersion: String, model: ModelDescriptor) {
        self.contentHash = contentHash; self.rulesVersion = rulesVersion
        self.promptVersion = promptVersion; self.model = model
    }
}

public struct SessionContent: Codable, Sendable, Equatable {
    public var scenario: ScenarioDefinition
    public var codingGuide: String
    public var tips: [Tip]
    public init(scenario: ScenarioDefinition, codingGuide: String, tips: [Tip]) {
        self.scenario = scenario; self.codingGuide = codingGuide; self.tips = tips
    }
}

public struct PendingTurn: Codable, Sendable, Equatable {
    public var id: UUID
    public var sessionID: UUID
    public var expectedRevision: Int
    public var input: String
    public var createdAt: Date
    public init(id: UUID, sessionID: UUID, expectedRevision: Int, input: String, createdAt: Date) {
        self.id = id; self.sessionID = sessionID; self.expectedRevision = expectedRevision
        self.input = input; self.createdAt = createdAt
    }
}

public struct CompletedTurn: Codable, Sendable, Equatable {
    public var id: UUID
    public var input: String
    public var analysis: TurnAnalysis?
    public var reply: ClientReply
    public var stateBefore: SimulationState
    public var stateAfter: SimulationState
    public var stateChangeReasons: [String]
    public var selectedTipID: String?
    /// Endgültige Rückmeldung zu diesem Beitrag, gemeinsam mit ihm gespeichert. Sie entsteht
    /// vor der Figurenantwort und wird bei einer Commit-Wiederholung unverändert mitgeführt;
    /// deshalb gehört sie zur Idempotenzprüfung in `RepositoryRules.commit`.
    public var feedback: [FeedbackFinding]
    public var metrics: [ModelCallMetrics]
    public var completedAt: Date
    public init(id: UUID, input: String, analysis: TurnAnalysis?, reply: ClientReply,
                stateBefore: SimulationState, stateAfter: SimulationState,
                stateChangeReasons: [String], selectedTipID: String?,
                metrics: [ModelCallMetrics], completedAt: Date,
                feedback: [FeedbackFinding] = []) {
        self.id = id; self.input = input; self.analysis = analysis; self.reply = reply
        self.stateBefore = stateBefore; self.stateAfter = stateAfter
        self.stateChangeReasons = stateChangeReasons; self.selectedTipID = selectedTipID
        self.metrics = metrics; self.completedAt = completedAt; self.feedback = feedback
    }

    // Bereits gespeicherte Sitzungen kennen `feedback` nicht. Ein nicht-optionales neues Feld
    // ließe sie mit `keyNotFound` scheitern und machte über `list()` die ganze Verlaufsliste
    // unbrauchbar. Fehlendes Feedback bedeutet „nicht erhoben“, nicht „keine Befunde“ —
    // die Oberfläche unterscheidet das über das Vorhandensein der Analyse.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        input = try values.decode(String.self, forKey: .input)
        analysis = try values.decodeIfPresent(TurnAnalysis.self, forKey: .analysis)
        reply = try values.decode(ClientReply.self, forKey: .reply)
        stateBefore = try values.decode(SimulationState.self, forKey: .stateBefore)
        stateAfter = try values.decode(SimulationState.self, forKey: .stateAfter)
        stateChangeReasons = try values.decode([String].self, forKey: .stateChangeReasons)
        selectedTipID = try values.decodeIfPresent(String.self, forKey: .selectedTipID)
        feedback = try values.decodeIfPresent([FeedbackFinding].self, forKey: .feedback) ?? []
        metrics = try values.decode([ModelCallMetrics].self, forKey: .metrics)
        completedAt = try values.decode(Date.self, forKey: .completedAt)
    }
}

public struct SessionSnapshot: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var id: UUID
    public var revision: Int
    public var approachID: String
    public var identity: BuildIdentity
    public var content: SessionContent
    public var state: SimulationState
    public var turns: [CompletedTurn]
    public var status: SessionStatus
    public var startedAt: Date
    public var endedAt: Date?
    public init(schemaVersion: Int, id: UUID, revision: Int, approachID: String,
                identity: BuildIdentity, content: SessionContent, state: SimulationState,
                turns: [CompletedTurn], status: SessionStatus, startedAt: Date, endedAt: Date? = nil) {
        self.schemaVersion = schemaVersion; self.id = id; self.revision = revision
        self.approachID = approachID; self.identity = identity; self.content = content
        self.state = state; self.turns = turns; self.status = status
        self.startedAt = startedAt; self.endedAt = endedAt
    }
}

public struct SessionSummary: Codable, Sendable, Equatable {
    public var id: UUID
    public var scenarioName: String
    public var startedAt: Date
    public var status: SessionStatus
    public init(id: UUID, scenarioName: String, startedAt: Date, status: SessionStatus) {
        self.id = id; self.scenarioName = scenarioName; self.startedAt = startedAt; self.status = status
    }
}

public protocol SessionRepository: Sendable {
    func create(_ snapshot: SessionSnapshot) async throws
    func load(id: UUID) async throws -> SessionSnapshot
    func list() async throws -> [SessionSummary]
    func savePending(_ pending: PendingTurn) async throws
    func loadPending(sessionID: UUID) async throws -> PendingTurn?
    func discardPending(sessionID: UUID, turnID: UUID) async throws
    // Prüft Identität vor Revisionskonflikt; identischer Retry liefert denselben Snapshot.
    // Atomar: Turn anhängen, Zustand übernehmen, Revision +1, passenden PendingTurn löschen.
    func commit(sessionID: UUID, expectedRevision: Int, turn: CompletedTurn) async throws -> SessionSnapshot
    func finish(sessionID: UUID, expectedRevision: Int, endedAt: Date) async throws -> SessionSnapshot
    func delete(id: UUID) async throws
}

public enum TrainerFailure: Error, Sendable, Equatable {
    case invalidInput
    case operationInProgress
    case modelUnavailable
    case artifactInvalid
    case contextLimit
    case invalidAnalysis
    case invalidReply
    case modelRefusal
    case revisionConflict
    case sessionNotFound
    case sessionCompleted
    case storageUnavailable
    case unsupportedVersion
    /// Die Gesamtfrist einer Gesprächsrunde ist abgelaufen. Eigener Fall und ausdrücklich
    /// kein `modelUnavailable`: Die Gegenseite war erreichbar, sie hat nur zu lange
    /// gebraucht — meist über mehrere Wiederholungen hinweg. Siehe `RoundDeadline`.
    case roundDeadlineExceeded
}
