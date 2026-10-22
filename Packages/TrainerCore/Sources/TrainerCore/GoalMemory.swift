import Foundation

public enum GoalEventKind: String, Codable, Sendable, CaseIterable {
    case introduced, rephrased, confirmed, replaced, withdrawn
}
public enum GoalStanding: String, Codable, Sendable {
    case mentioned, agreed, replaced, withdrawn
    public var label: String {
        switch self {
        case .mentioned: "Von Lukas genannt"
        case .agreed: "Gemeinsam bestätigt"
        case .replaced: "Durch ein anderes Ziel ersetzt"
        case .withdrawn: "Zurückgenommen"
        }
    }
}

/// Referenzen immer gegen den tatsächlich gesehenen Analysekontext prüfen.
public struct GoalUpdate: Codable, Sendable, Equatable {
    public var kind: GoalEventKind
    public var previousGoal: EvidenceReference?
    public var currentGoal: EvidenceReference?
    public var evidence: EvidenceReference
    public var proposal: EvidenceReference?
    public var isUncertain: Bool
    public init(kind: GoalEventKind, previousGoal: EvidenceReference? = nil,
                currentGoal: EvidenceReference? = nil, evidence: EvidenceReference,
                proposal: EvidenceReference? = nil, isUncertain: Bool = false) {
        self.kind = kind; self.previousGoal = previousGoal; self.currentGoal = currentGoal
        self.evidence = evidence; self.proposal = proposal; self.isUncertain = isUncertain
    }
}

public struct GoalEvent: Codable, Sendable, Equatable {
    public var kind: GoalEventKind
    public var previousGoal: CharacterEvidence?
    public var currentGoal: CharacterEvidence?
    public var evidence: CharacterEvidence
    public var proposal: CharacterEvidence?
    public var isUncertain: Bool
    public var observedInTurnID: UUID
}
public struct GoalMemory: Codable, Sendable, Equatable {
    public var aliases: [CharacterEvidence] = []
    public var standing: GoalStanding = .mentioned
    public var lastEvent: GoalEvent?
    public init() {}
}

public enum GoalTracker {
    static func index(for evidence: CharacterEvidence, in goals: [GoalDevelopment]) -> Int? {
        goals.firstIndex { $0.goal == evidence || $0.memory?.aliases.contains(evidence) == true }
    }

    static func advance(_ before: CharacterDevelopment?, updates: [GoalUpdate], input: String,
                        context: [DialogueMessage], session: SessionSnapshot, turnID: UUID) throws -> CharacterDevelopment? {
        guard !updates.isEmpty else { return before }
        var next = before ?? CharacterDevelopment()
        var touched = Set<Int>()
        for update in updates {
            let evidence = try CharacterTracker.anchored(update.evidence, input: input, context: context, session: session)
            let previous = try update.previousGoal.map { try CharacterTracker.anchored($0, input: input, context: context, session: session) }
            let current = try update.currentGoal.map { try CharacterTracker.anchored($0, input: input, context: context, session: session) }
            let proposal = try update.proposal.map { try CharacterTracker.anchored($0, input: input, context: context, session: session, speaker: .counselor) }
            let event = GoalEvent(kind: update.kind, previousGoal: previous, currentGoal: current, evidence: evidence,
                                  proposal: proposal, isUncertain: update.isUncertain, observedInTurnID: turnID)
            // Derselbe Modellbefund wird beim erneuten Analysieren nicht neu gespeichert.
            if (next.goalEvents ?? []).contains(where: {
                $0.kind == event.kind && $0.previousGoal == previous && $0.currentGoal == current
                    && $0.evidence == evidence && $0.proposal == proposal && $0.isUncertain == event.isUncertain
            }) { continue }
            if update.kind == .introduced, let current {
                if let prior = next.goalEvents?.last(where: { $0.kind == .introduced && $0.currentGoal == current }),
                   !(try CharacterTracker.isLater(evidence, than: prior.evidence, session: session)) { continue }
                if update.isUncertain {
                    next.goalEvents = (next.goalEvents ?? []) + [event]; continue
                }
            }
            let index: Int
            if update.kind == .introduced {
                guard let current else { throw TrainerFailure.invalidAnalysis }
                if let existing = Self.index(for: current, in: next.goals) { index = existing }
                else {
                    next.goals.append(.init(goal: current, memory: .init())); index = next.goals.count - 1
                }
            } else {
                guard let previous, let existing = Self.index(for: previous, in: next.goals) else {
                    throw TrainerFailure.invalidAnalysis
                }
                index = existing
            }
            guard touched.insert(index).inserted else { throw TrainerFailure.invalidAnalysis }
            var memory = next.goals[index].memory ?? GoalMemory()
            if let last = memory.lastEvent,
               !(try CharacterTracker.isLater(evidence, than: last.evidence, session: session)) { continue }
            if !update.isUncertain {
                switch update.kind {
                case .introduced: break // Eine erneute Erwähnung reaktiviert keinen Widerruf.
                case .rephrased:
                    guard let current, memory.standing != .withdrawn, memory.standing != .replaced else {
                        throw TrainerFailure.invalidAnalysis
                    }
                    if let other = Self.index(for: current, in: next.goals), other != index {
                        throw TrainerFailure.invalidAnalysis // Keine rückwirkende Vermischung zweier Zielverläufe.
                    }
                    if current != next.goals[index].goal, !memory.aliases.contains(current) { memory.aliases.append(current) }
                case .confirmed:
                    // Eine neue ausdrückliche Vereinbarung kann ein zurückgenommenes Ziel wieder aufnehmen.
                    memory.standing = .agreed
                case .withdrawn: memory.standing = .withdrawn
                case .replaced:
                    guard let current, Self.index(for: current, in: next.goals) != index else {
                        throw TrainerFailure.invalidAnalysis
                    }
                    memory.standing = .replaced
                    if let target = Self.index(for: current, in: next.goals) {
                        // Ein vorhandenes Ziel darf nicht durch einen Wechsel reaktiviert werden.
                        let standing = next.goals[target].memory?.standing ?? .mentioned
                        guard standing != .withdrawn, standing != .replaced else { throw TrainerFailure.invalidAnalysis }
                        if next.goals[target].memory == nil { next.goals[target].memory = .init() }
                    } else {
                        next.goals.append(.init(goal: current, memory: .init()))
                    }
                }
            }
            memory.lastEvent = event
            next.goals[index].memory = memory
            next.goalEvents = (next.goalEvents ?? []) + [event]
        }
        return next
    }
}

/// Nur Originalnachrichten und verifizierte Zielkennungen, keine erfundene Zusammenfassung.
public struct KnownGoal: Sendable, Equatable {
    public var goal: EvidenceReference
    public var aliases: [EvidenceReference]
    public var standing: GoalStanding
    public var lastEventEvidence: EvidenceReference?
    public var isUncertain: Bool
    public init(goal: EvidenceReference, aliases: [EvidenceReference], standing: GoalStanding,
                lastEventEvidence: EvidenceReference?, isUncertain: Bool) {
        self.goal = goal; self.aliases = aliases; self.standing = standing
        self.lastEventEvidence = lastEventEvidence; self.isUncertain = isUncertain
    }
}
public struct AnalysisMemory: Sendable {
    public var messages: [DialogueMessage]
    public var goals: [KnownGoal]
    public var omittedGoalCount: Int
    public var plans: [KnownPlan] = []
    public var omittedNarrativeCount: Int = 0
}

extension ContextBuilder {
    /// Eröffnung + sechs letzte Turns; höchstens sechs zusätzliche Turns / 10.000 Zeichen
    /// aus höchstens drei Zielgruppen. Gruppen werden vollständig übernommen oder ausgelassen.
    /// Das Zeichenlimit ist eine technische Schranke, keine gemessene Tokenzählung.
    public static func analysisMemory(_ session: SessionSnapshot) throws -> AnalysisMemory {
        let allMessages = evidenceMessages(session)
        var selected = Set(session.turns.suffix(6).map(\.id))
        // Zu Beginn höchstens zwei letzte Runden des vorherigen Termins, innerhalb
        // desselben Grundfensters. Keine ganze Fallakte im Prompt.
        if session.turns.count < 6, let prior = session.continuity?.priorSessions.last {
            selected.formUnion(prior.turns.suffix(min(2, 6 - session.turns.count)).map(\.id))
        }
        var selectedOpenings: Set<UUID> = []
        let original = selected
        var chosen: [GoalDevelopment] = []
        let development = session.state.development
        let ranked = (development?.goals ?? []).enumerated().sorted { left, right in
            func recency(_ goal: GoalDevelopment) -> Int {
                let ids = [goal.goal.origin.turnID, goal.memory?.lastEvent?.observedInTurnID, goal.readiness?.observedInTurnID, goal.confidence?.observedInTurnID]
                return ids.compactMap { id in allMessages.firstIndex { $0.origin?.turnID == id && id != nil } }.max() ?? -1
            }
            let l = recency(left.element), r = recency(right.element)
            return l == r ? left.offset > right.offset : l > r
        }.map(\.element)
        for goal in ranked {
            guard chosen.count < 3 else { break }
            var refs = references(goal)
            // Nach unsicherer neuer Deutung muss auch die letzte sichere Statusgrundlage
            // einschließlich Vereinbarungsvorschlag im geholten Originalkontext bleiben.
            let identifiers = [goal.goal] + (goal.memory?.aliases ?? [])
            if let certain = development?.goalEvents?.last(where: {
                !$0.isUncertain && [.confirmed, .withdrawn, .replaced].contains($0.kind)
                    && identifiers.contains($0.previousGoal ?? $0.currentGoal ?? $0.evidence)
            }) {
                refs += [certain.evidence] + [certain.previousGoal, certain.currentGoal, certain.proposal].compactMap { $0 }
            }
            // Alte Daten dürfen keine erfundenen Inhalte als Gedächtnisquelle einschleusen.
            for ref in refs { _ = try CharacterTracker.position(ref, session: session) }
            let required = Set(refs.compactMap { $0.origin.turnID })
            let candidate = selected.union(required)
            let extra = candidate.subtracting(original)
            let openings = selectedOpenings.union(refs.compactMap { $0.origin.turnID == nil ? $0.origin.sessionID : nil })
            let characters = allMessages.filter {
                $0.origin?.turnID.map { extra.contains($0) } ?? $0.origin?.sessionID.map { openings.contains($0) } ?? false
            }.reduce(0) { $0 + $1.text.count }
            guard extra.count + openings.count <= 6, characters <= 10_000 else { continue }
            selected = candidate; selectedOpenings = openings; chosen.append(goal)
        }
        var chosenNarrative: [NarrativeRecord] = []
        let records = session.state.narrative?.records ?? []
        for record in records.reversed() {
            guard chosenNarrative.count < 3 else { break }
            let refs = [record.evidence, record.goal, record.plan].compactMap { $0 }
            for ref in refs { _ = try CharacterTracker.position(ref, session: session) }
            let candidate = selected.union(refs.compactMap { $0.origin.turnID })
            let openings = selectedOpenings.union(refs.compactMap { $0.origin.turnID == nil ? $0.origin.sessionID : nil })
            let extra = candidate.subtracting(original)
            let characters = allMessages.filter {
                $0.origin?.turnID.map { extra.contains($0) } ?? $0.origin?.sessionID.map { openings.contains($0) } ?? false
            }.reduce(0) { $0 + $1.text.count }
            guard extra.count + openings.count <= 6, characters <= 10_000 else { continue }
            selected = candidate; selectedOpenings = openings; chosenNarrative.append(record)
        }
        // Der Erlaubnisverlauf ist klein (höchstens Frage, Antwort und verbrauchender Rat)
        // und wird nur als Originaltext zurückgeholt. Eine offene Zustimmung wird nie
        // gespeichert und kann deshalb auch nicht aus einem alten Kontext reaktiviert werden.
        if let permission = session.state.permissionMemory {
            for evidence in [permission.request, permission.response, permission.consumedBy].compactMap({ $0 }) {
                _ = try CharacterTracker.position(evidence, session: session)
                if let turnID = evidence.origin.turnID { selected.insert(turnID) }
            }
        }
        let transcript = allMessages.filter { message in
            guard let origin = message.origin else { return false }
            if let turnID = origin.turnID { return selected.contains(turnID) }
            return origin.sessionID.map { selectedOpenings.contains($0) } ?? true
        }
        func reference(_ value: CharacterEvidence) throws -> EvidenceReference {
            guard let index = transcript.firstIndex(where: { $0.origin == value.origin }) else { throw TrainerFailure.invalidAnalysis }
            let ref = EvidenceReference(source: .contextMessage, speaker: value.origin.speaker, messageIndex: index,
                                        quote: value.quote, occurrence: value.occurrence)
            try OutputValidator.validateEvidence(ref, input: "", context: transcript)
            return ref
        }
        let goals = try chosen.map { goal in
            KnownGoal(goal: try reference(goal.goal), aliases: try (goal.memory?.aliases ?? []).map(reference),
                      standing: goal.memory?.standing ?? .mentioned,
                      lastEventEvidence: try goal.memory?.lastEvent.map { try reference($0.evidence) },
                      isUncertain: goal.memory?.lastEvent?.isUncertain ?? false)
        }
        var planEvidence: [CharacterEvidence] = []
        for record in chosenNarrative {
            let plan = record.kind == .planned ? record.evidence : record.plan
            if let plan, !planEvidence.contains(plan) { planEvidence.append(plan) }
        }
        let plans = try planEvidence.map { plan in
            KnownPlan(evidence: try reference(plan), isUncertain: records.first { $0.evidence == plan }?.isUncertain ?? true)
        }
        return .init(messages: transcript, goals: goals, omittedGoalCount: (development?.goals.count ?? 0) - chosen.count,
                     plans: plans, omittedNarrativeCount: records.count - chosenNarrative.count)
    }

    private static func references(_ goal: GoalDevelopment) -> [CharacterEvidence] {
        var result = [goal.goal] + (goal.memory?.aliases ?? [])
        result += [goal.readiness?.evidence, goal.confidence?.evidence].compactMap { $0 }
        if let event = goal.memory?.lastEvent {
            result += [event.evidence] + [event.previousGoal, event.currentGoal, event.proposal].compactMap { $0 }
        }
        return result
    }
}


extension OutputValidator {
    static func validateGoalUpdates(_ updates: [GoalUpdate], input: String, context: [DialogueMessage]) throws {
        guard updates.count <= 3 else { throw TrainerFailure.invalidAnalysis }
        func beforeOrEqual(_ a: EvidenceReference, _ b: EvidenceReference) throws -> Bool {
            let ai = a.messageIndex!, bi = b.messageIndex!
            if ai != bi { return ai < bi }
            return try evidenceRange(a, input: input, context: context).lowerBound
                <= evidenceRange(b, input: input, context: context).lowerBound
        }
        for (index, update) in updates.enumerated() {
            for ref in [update.previousGoal, update.currentGoal, update.evidence].compactMap({ $0 }) {
                guard ref.source == .contextMessage, ref.speaker == .client else { throw TrainerFailure.invalidAnalysis }
                try validateEvidence(ref, input: input, context: context)
            }
            if let proposal = update.proposal {
                guard proposal.source == .contextMessage, proposal.speaker == .counselor else { throw TrainerFailure.invalidAnalysis }
                try validateEvidence(proposal, input: input, context: context)
            }
            switch update.kind {
            case .introduced:
                guard update.previousGoal == nil, update.currentGoal != nil, update.proposal == nil else { throw TrainerFailure.invalidAnalysis }
            case .rephrased, .replaced:
                guard let old = update.previousGoal, let new = update.currentGoal, old != new,
                      update.proposal == nil, try beforeOrEqual(old, new) else { throw TrainerFailure.invalidAnalysis }
            case .confirmed:
                guard let old = update.previousGoal, update.currentGoal == nil, let proposal = update.proposal,
                      try beforeOrEqual(old, proposal), proposal.messageIndex! < update.evidence.messageIndex! else { throw TrainerFailure.invalidAnalysis }
            case .withdrawn:
                guard update.previousGoal != nil, update.currentGoal == nil, update.proposal == nil else { throw TrainerFailure.invalidAnalysis }
            }
            for ref in [update.previousGoal, update.currentGoal].compactMap({ $0 }) {
                // Eine Aussage ist als Ganzes verfügbar: ein Zielausschnitt kann innerhalb
                // des längeren Ereigniszitats erst später beginnen. Kein künstliches Wort-Timing.
                guard ref.messageIndex! <= update.evidence.messageIndex! else { throw TrainerFailure.invalidAnalysis }
            }
            // Pro Ziel und pro Beleg höchstens ein Ereignis in einer Analyse.
            let target = update.previousGoal ?? update.currentGoal
            guard !updates.prefix(index).contains(where: {
                ($0.previousGoal ?? $0.currentGoal) == target || $0.evidence == update.evidence
            }) else { throw TrainerFailure.invalidAnalysis }
        }
    }
}


extension GoalTracker {
    /// Status und Aliasse werden aus der belegten Historie rekonstruiert, nicht vertraut.
    static func validate(_ development: CharacterDevelopment, session: SessionSnapshot, currentTurnID: UUID) throws {
        let events = development.goalEvents ?? []
        guard events.count <= 60 else { throw TrainerFailure.invalidAnalysis }
        let transcript = ContextBuilder.evidenceMessages(session)
        func reference(_ value: CharacterEvidence) throws -> EvidenceReference {
            _ = try CharacterTracker.position(value, session: session)
            guard let index = transcript.firstIndex(where: { $0.origin == value.origin }) else { throw TrainerFailure.invalidAnalysis }
            return .init(source: .contextMessage, speaker: value.origin.speaker, messageIndex: index,
                         quote: value.quote, occurrence: value.occurrence)
        }
        var seen: [CharacterEvidence] = []
        var replay = CharacterDevelopment()
        for goal in development.goals {
            for ref in [goal.goal] + (goal.memory?.aliases ?? []) {
                guard ref.origin.speaker == .client, !seen.contains(ref) else { throw TrainerFailure.invalidAnalysis }
                _ = try reference(ref); seen.append(ref)
            }
            replay.goals.append(.init(goal: goal.goal))
        }
        var lastObserved = -1
        for event in events {
            let observed = try ContextBuilder.observedPosition(event.observedInTurnID,
                currentTurnID: currentTurnID, session: session)
            guard observed >= lastObserved else { throw TrainerFailure.invalidAnalysis }
            lastObserved = observed
            for ref in [event.previousGoal, event.currentGoal, event.evidence, event.proposal].compactMap({ $0 }) {
                guard try CharacterTracker.position(ref, session: session).message <= observed else { throw TrainerFailure.invalidAnalysis }
            }
            let update = GoalUpdate(kind: event.kind, previousGoal: try event.previousGoal.map(reference),
                currentGoal: try event.currentGoal.map(reference), evidence: try reference(event.evidence),
                proposal: try event.proposal.map(reference), isUncertain: event.isUncertain)
            try OutputValidator.validateGoalUpdates([update], input: "", context: transcript)
            replay = try advance(replay, updates: [update], input: "", context: transcript,
                                 session: session, turnID: event.observedInTurnID)!
        }
        guard replay.goalEvents ?? [] == events, replay.goals.count == development.goals.count else { throw TrainerFailure.invalidAnalysis }
        for goal in development.goals {
            guard let reconstructed = replay.goals.first(where: { $0.goal == goal.goal }),
                  reconstructed.memory == goal.memory else { throw TrainerFailure.invalidAnalysis }
        }
    }
}
