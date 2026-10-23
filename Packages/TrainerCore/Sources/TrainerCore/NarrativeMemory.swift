import Foundation

/// Gesprächsbeobachtungen zu konkreten Vorhaben und Erfahrungen. Keine SOC-Stufen,
/// keine aus Offenheit abgeleitete Entwicklung und keine geschätzte Stabilitätsdauer.
public enum NarrativeKind: String, Codable, Sendable, CaseIterable {
    case idea, planned, attempted, completed, partial, continued, notAttempted, setback, withdrawn
    public var label: String {
        switch self {
        case .idea: "Genannte Möglichkeit"
        case .planned: "Selbst gewählter Versuch · noch nicht umgesetzt"
        case .attempted: "Versuch berichtet"
        case .completed: "Einmalige Umsetzung berichtet"
        case .partial: "Teilweise Umsetzung berichtet"
        case .continued: "Fortgesetzte Umsetzung berichtet"
        case .notAttempted: "Nicht umgesetzt berichtet"
        case .setback: "Schwierigkeit oder Rückbewegung berichtet"
        case .withdrawn: "Vorhaben zurückgenommen"
        }
    }
}

public struct NarrativeObservation: Codable, Sendable, Equatable {
    public var kind: NarrativeKind
    public var evidence: EvidenceReference
    public var goal: EvidenceReference?
    public var plan: EvidenceReference?
    public var isUncertain: Bool
    public init(kind: NarrativeKind, evidence: EvidenceReference, goal: EvidenceReference? = nil,
                plan: EvidenceReference? = nil, isUncertain: Bool = false) {
        self.kind = kind; self.evidence = evidence; self.goal = goal; self.plan = plan; self.isUncertain = isUncertain
    }
}

public struct NarrativeRecord: Codable, Sendable, Equatable {
    public var kind: NarrativeKind
    public var evidence: CharacterEvidence
    public var goal: CharacterEvidence?
    public var plan: CharacterEvidence?
    public var isUncertain: Bool
    public var observedInTurnID: UUID
    public var observedInSessionID: UUID
}

public struct NarrativeMemory: Codable, Sendable, Equatable {
    public var records: [NarrativeRecord]
    public init(records: [NarrativeRecord] = []) { self.records = records }
    public func anchoringOpening(to sessionID: UUID) -> NarrativeMemory {
        func anchor(_ e: CharacterEvidence) -> CharacterEvidence {
            var e = e
            if e.origin.turnID == nil && e.origin.sessionID == nil { e.origin.sessionID = sessionID }
            return e
        }
        return .init(records: records.map { r in
            var r = r; r.evidence = anchor(r.evidence); r.goal = r.goal.map(anchor); r.plan = r.plan.map(anchor); return r
        })
    }
}

public struct KnownPlan: Sendable, Equatable {
    public var evidence: EvidenceReference
    public var isUncertain: Bool
}

public enum NarrativeTracker {
    public static func advance(_ before: NarrativeMemory?, observations: [NarrativeObservation]?,
                               input: String, context: [DialogueMessage], session: SessionSnapshot,
                               turnID: UUID) throws -> NarrativeMemory? {
        guard let observations, !observations.isEmpty else { return before }
        try OutputValidator.validateNarrative(observations, input: input, context: context)
        var next = before ?? NarrativeMemory()
        for observation in observations {
            let e = try CharacterTracker.anchored(observation.evidence, input: input, context: context, session: session)
            // Wiederholtes Lesen desselben Originalbelegs erzeugt keine neue Erfahrung
            // und wertet auch eine unsichere Deutung nicht nachträglich sicher auf.
            if next.records.contains(where: { $0.evidence == e }) { continue }
            let plan = try observation.plan.map { try CharacterTracker.anchored($0, input: input, context: context, session: session) }
            if let plan, !next.records.contains(where: { $0.kind == .planned && $0.evidence == plan }) {
                throw TrainerFailure.invalidAnalysis
            }
            let goal = try observation.goal.map { try CharacterTracker.anchored($0, input: input, context: context, session: session) }
            next.records.append(.init(kind: observation.kind, evidence: e, goal: goal, plan: plan,
                isUncertain: observation.isUncertain, observedInTurnID: turnID, observedInSessionID: session.id))
        }
        try validate(next, session: session, currentTurnID: turnID)
        return next
    }

    public static func validate(_ memory: NarrativeMemory?, session: SessionSnapshot, currentTurnID: UUID) throws {
        guard let memory else { return }
        guard memory.records.count <= 60 else { throw TrainerFailure.invalidAnalysis }
        var seen: [CharacterEvidence] = []
        for record in memory.records {
            let observed = try ContextBuilder.observedPosition(record.observedInTurnID,
                currentTurnID: currentTurnID, session: session)
            guard record.evidence.origin.speaker == .client, !seen.contains(record.evidence),
                  record.observedInSessionID == session.id || session.continuity?.priorSessions.contains(where: { $0.id == record.observedInSessionID }) == true else {
                throw TrainerFailure.invalidAnalysis
            }
            for ref in [record.evidence, record.goal, record.plan].compactMap({ $0 }) {
                guard ref.origin.speaker == .client,
                      try CharacterTracker.position(ref, session: session).message <= observed else { throw TrainerFailure.invalidAnalysis }
            }
            if let plan = record.plan {
                guard try !CharacterTracker.isLater(plan, than: record.evidence, session: session) else { throw TrainerFailure.invalidAnalysis }
                guard memory.records.prefix(seen.count).contains(where: { $0.kind == .planned && $0.evidence == plan }) else { throw TrainerFailure.invalidAnalysis }
            }
            if record.kind == .withdrawn && record.plan == nil { throw TrainerFailure.invalidAnalysis }
            seen.append(record.evidence)
        }
    }
}

extension OutputValidator {
    static func validateNarrative(_ observations: [NarrativeObservation], input: String, context: [DialogueMessage]) throws {
        guard observations.count <= 3 else { throw TrainerFailure.invalidAnalysis }
        for observation in observations {
            for reference in [observation.evidence, observation.goal, observation.plan].compactMap({ $0 }) {
                try validateEvidence(reference, input: input, context: context)
                guard reference.source == .contextMessage, reference.speaker == .client else { throw TrainerFailure.invalidAnalysis }
            }
            guard ![NarrativeKind.planned, .idea].contains(observation.kind) || observation.plan == nil,
                  observation.kind != .withdrawn || observation.plan != nil else { throw TrainerFailure.invalidAnalysis }
        }
    }
}
