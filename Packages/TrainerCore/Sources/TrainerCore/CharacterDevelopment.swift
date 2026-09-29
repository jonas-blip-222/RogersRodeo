import Foundation

/// Drei getrennte Beobachtungsdimensionen, keine Kompetenznoten oder Offenheitsboni.
public enum CharacterDimension: String, Codable, Sendable, CaseIterable {
    case readiness, confidence, rapport
    public var label: String {
        switch self {
        case .readiness: "Veränderungsbereitschaft"
        case .confidence: "Zuversicht"
        case .rapport: "Arbeitsbeziehung"
        }
    }
}

public enum CharacterAssessment: String, Codable, Sendable, CaseIterable {
    case notConsidering, ambivalent, willing
    case doubtful, mixed, confident
    case connected, strained, repairing
    case unclear

    public var label: String {
        switch self {
        case .notConsidering: "Derzeit keine Veränderungsabsicht"
        case .ambivalent: "Zwiespältig hinsichtlich Veränderung"
        case .willing: "Bereitschaft geäußert"
        case .doubtful: "Zweifel an der Umsetzung"
        case .mixed: "Unterschiedliche Zuversicht geäußert"
        case .confident: "Zuversicht geäußert"
        case .connected: "Verständigung erkennbar"
        case .strained: "Spannung in der Arbeitsbeziehung"
        case .repairing: "Verständigung wird wiederhergestellt"
        case .unclear: "Unklar"
        }
    }
    func belongs(to dimension: CharacterDimension) -> Bool {
        switch dimension {
        case .readiness: [.notConsidering, .ambivalent, .willing, .unclear].contains(self)
        case .confidence: [.doubtful, .mixed, .confident, .unclear].contains(self)
        case .rapport: [.connected, .strained, .repairing, .unclear].contains(self)
        }
    }
}

/// Modellbeobachtung ausschließlich zu bereits gesprochenen Klientenaussagen.
/// Ziel ist ebenfalls ein wörtlicher Klientenbeleg, keine vom Modell erfundene Überschrift.
public struct CharacterObservation: Codable, Sendable, Equatable {
    public var dimension: CharacterDimension
    public var assessment: CharacterAssessment
    public var goal: EvidenceReference?
    public var evidence: EvidenceReference
    public var isUncertain: Bool
    public init(dimension: CharacterDimension, assessment: CharacterAssessment,
                goal: EvidenceReference?, evidence: EvidenceReference, isUncertain: Bool) {
        self.dimension = dimension; self.assessment = assessment; self.goal = goal
        self.evidence = evidence; self.isUncertain = isUncertain
    }
}

/// Sitzungsrelative dauerhafte Herkunft; nil-Turn bezeichnet ausschließlich die Eröffnungszeile.
public struct MessageOrigin: Codable, Sendable, Equatable {
    public var turnID: UUID?
    public var speaker: Speaker
    public init(turnID: UUID?, speaker: Speaker) { self.turnID = turnID; self.speaker = speaker }
}

public struct CharacterEvidence: Codable, Sendable, Equatable {
    public var origin: MessageOrigin
    public var quote: String
    public var occurrence: Int
    public init(origin: MessageOrigin, quote: String, occurrence: Int) {
        self.origin = origin; self.quote = quote; self.occurrence = occurrence
    }
}

public struct CharacterRecord: Codable, Sendable, Equatable {
    public var assessment: CharacterAssessment
    public var evidence: CharacterEvidence
    public var isUncertain: Bool
    /// Runde, in deren Analyse die schon vorhandene Aussage beobachtet wurde.
    public var observedInTurnID: UUID
    public var label: String { isUncertain ? "Unsicher: \(assessment.label)" : assessment.label }
}

public struct GoalDevelopment: Codable, Sendable, Equatable {
    public var goal: CharacterEvidence
    public var readiness: CharacterRecord?
    public var confidence: CharacterRecord?
    public var memory: GoalMemory?
}

public struct CharacterDevelopment: Codable, Sendable, Equatable {
    public var goals: [GoalDevelopment] = []
    public var rapport: CharacterRecord?
    public var goalEvents: [GoalEvent]?
    public init() {}
}

public enum CharacterTracker {
    /// Speichert nur bereits belegte Äußerungen. Keine Entwicklung durch gute Beratersätze,
    /// kein SOC-Aufstieg, keine Wirkung der noch nicht erzeugten Antwort auf deren Feedback.
    public static func advance(_ before: CharacterDevelopment?, analysis: TurnAnalysis?,
                               input: String, context: [DialogueMessage], session: SessionSnapshot,
                               turnID: UUID) throws -> CharacterDevelopment? {
        guard let analysis else { return before }
        try OutputValidator.validateAnalysis(analysis, input: input, context: context)
        let updated = try GoalTracker.advance(before, updates: analysis.goalUpdates ?? [], input: input,
                                              context: context, session: session, turnID: turnID)
        guard let observations = analysis.characterObservations, !observations.isEmpty else { return updated }
        var next = updated ?? CharacterDevelopment()
        for observation in observations {
            let evidence = try anchored(observation.evidence, input: input, context: context, session: session)
            let record = CharacterRecord(assessment: observation.assessment, evidence: evidence,
                isUncertain: observation.isUncertain, observedInTurnID: turnID)
            if observation.dimension == .rapport {
                if try newer(record, than: next.rapport, session: session) { next.rapport = record }
            } else {
                guard let goalReference = observation.goal else { throw TrainerFailure.invalidAnalysis }
                let goal = try anchored(goalReference, input: input, context: context, session: session)
                let index: Int
                if let existing = GoalTracker.index(for: goal, in: next.goals) { index = existing }
                else {
                    // Im Zielgedächtnis-Vertrag entstehen Ziele ausschließlich durch belegte
                    // Zielereignisse. Eine Beobachtung darf keinen Parallelverlauf eröffnen.
                    // nil bewahrt die Lesbarkeit/Verarbeitung älterer Analysen ohne Zielvertrag.
                    guard analysis.goalUpdates == nil else { throw TrainerFailure.invalidAnalysis }
                    next.goals.append(.init(goal: goal)); index = next.goals.count - 1
                }
                if observation.dimension == .readiness {
                    if try newer(record, than: next.goals[index].readiness, session: session) {
                        next.goals[index].readiness = record
                    }
                } else if try newer(record, than: next.goals[index].confidence, session: session) {
                    next.goals[index].confidence = record
                }
            }
        }
        return next
    }

    /// Auch der Speicherübergang prüft alle dauerhaften Referenzen gegen die Sitzung.
    public static func validate(_ development: CharacterDevelopment?, session: SessionSnapshot,
                                currentTurnID: UUID) throws {
        guard let development else { return }
        guard development.goals.count <= 40 else { throw TrainerFailure.invalidAnalysis }
        func check(_ record: CharacterRecord?, dimension: CharacterDimension, goal: CharacterEvidence? = nil) throws {
            guard let record else { return }
            guard record.evidence.origin.speaker == .client, record.assessment.belongs(to: dimension) else { throw TrainerFailure.invalidAnalysis }
            let latestAvailableMessage: Int
            if record.observedInTurnID == currentTurnID { latestAvailableMessage = session.turns.count }
            else if let index = session.turns.firstIndex(where: { $0.id == record.observedInTurnID }) {
                latestAvailableMessage = index
            } else { throw TrainerFailure.invalidAnalysis }
            guard try position(record.evidence, session: session).message <= latestAvailableMessage else {
                throw TrainerFailure.invalidAnalysis
            }
            if let goal, try position(goal, session: session).message > latestAvailableMessage {
                throw TrainerFailure.invalidAnalysis
            }
        }
        for (index, goal) in development.goals.enumerated() {
            guard goal.goal.origin.speaker == .client,
                  goal.readiness != nil || goal.confidence != nil || goal.memory != nil,
                  !development.goals.prefix(index).contains(where: { $0.goal == goal.goal }) else {
                throw TrainerFailure.invalidAnalysis
            }
            _ = try position(goal.goal, session: session)
            try check(goal.readiness, dimension: .readiness, goal: goal.goal)
            try check(goal.confidence, dimension: .confidence, goal: goal.goal)
        }
        try check(development.rapport, dimension: .rapport)
        try GoalTracker.validate(development, session: session, currentTurnID: currentTurnID)
    }

    private static func newer(_ record: CharacterRecord, than previous: CharacterRecord?,
                              session: SessionSnapshot) throws -> Bool {
        guard let previous else { return true }
        // Derselbe Beleg wird nicht bei jeder Modellanalyse neu umgedeutet. Ein älterer Beleg
        // darf einen späteren Widerruf oder Zweifel nicht überschreiben.
        return try isLater(record.evidence, than: previous.evidence, session: session)
    }

    static func isLater(_ evidence: CharacterEvidence, than previous: CharacterEvidence,
                        session: SessionSnapshot) throws -> Bool {
        let newPosition = try position(evidence, session: session)
        let oldPosition = try position(previous, session: session)
        return newPosition.message > oldPosition.message
            || (newPosition.message == oldPosition.message && newPosition.offset > oldPosition.offset)
    }

    static func anchored(_ reference: EvidenceReference, input: String,
                                 context: [DialogueMessage], session: SessionSnapshot, speaker: Speaker = .client) throws -> CharacterEvidence {
        try OutputValidator.validateEvidence(reference, input: input, context: context)
        guard reference.source == .contextMessage, reference.speaker == speaker,
              let index = reference.messageIndex, let origin = context[index].origin,
              origin.speaker == speaker else { throw TrainerFailure.invalidAnalysis }
        let original = try source(origin, session: session)
        guard original.text == context[index].text else { throw TrainerFailure.invalidAnalysis }
        return .init(origin: origin, quote: reference.quote, occurrence: reference.occurrence)
    }

    static func source(_ origin: MessageOrigin, session: SessionSnapshot) throws -> (text: String, position: Int) {
        guard let id = origin.turnID else {
            guard origin.speaker == .client else { throw TrainerFailure.invalidAnalysis }
            return (session.content.scenario.openingLine, 0)
        }
        guard let index = session.turns.firstIndex(where: { $0.id == id }) else { throw TrainerFailure.invalidAnalysis }
        return (origin.speaker == .client ? session.turns[index].reply.text : session.turns[index].input,
                index + 1)
    }

    static func position(_ evidence: CharacterEvidence, session: SessionSnapshot) throws -> (message: Int, offset: Int) {
        let original = try source(evidence.origin, session: session)
        let reference = EvidenceReference(source: .contextMessage, speaker: evidence.origin.speaker, messageIndex: 0,
                                           quote: evidence.quote, occurrence: evidence.occurrence)
        let range = try OutputValidator.evidenceRange(reference, input: "", context: [.init(speaker: evidence.origin.speaker, text: original.text)])
        return (original.position, original.text.distance(from: original.text.startIndex, to: range.lowerBound))
    }
}
