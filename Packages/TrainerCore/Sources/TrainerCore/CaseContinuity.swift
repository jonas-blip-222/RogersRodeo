import Foundation

/// Originaltexte früherer Termine. Analyseobjekte und verborgene Figurenfakten werden
/// nicht dupliziert. Der vollständige Nachweisbestand ist kein Modellkontext.
public struct PriorSession: Codable, Sendable, Equatable {
    public struct Turn: Codable, Sendable, Equatable {
        public var id: UUID
        public var input: String
        public var reply: String
    }
    public var id: UUID
    public var number: Int
    public var opening: String
    public var turns: [Turn]
    /// Fiktionale Woche seit Fallbeginn; ältere Archive ohne Angabe lagen wöchentlich.
    public var fictionalWeek: Int?
    public var week: Int { fictionalWeek ?? number - 1 }
    public init(_ session: SessionSnapshot) {
        id = session.id; number = session.sessionNumber; opening = session.openingLine
        turns = session.turns.map { .init(id: $0.id, input: $0.input, reply: $0.reply.text) }
        fictionalWeek = session.fictionalWeek
    }
}

public struct VisitNote: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public var heading: String
        public var quote: String
        public var sessionID: UUID
        public var sessionNumber: Int
        public var turnID: UUID?
        public var turnNumber: Int?
        public var speaker: Speaker
        public var sourceLabel: String {
            "Sitzung \(sessionNumber) · \(turnNumber.map { "Runde \($0)" } ?? "Begrüßung") · \(speaker == .client ? "Klient" : "Beratung")"
        }
    }
    public var entries: [Entry]
    public var omittedGoals: Int
    public var previousTurnCount: Int
    public var hasConfirmedGoal: Bool
}

public struct CaseContinuity: Codable, Sendable, Equatable {
    public var caseID: UUID
    public var previousSessionID: UUID
    public var number: Int
    public var priorSessions: [PriorSession]
    public var preparation: VisitNote
    public var experience: BetweenVisitExperience?
    /// MI-04c: vereinbarter Abstand zum vorherigen Termin und fiktionale Woche seit
    /// Fallbeginn. Fehlt bei älteren Terminen; dort galt eine Woche.
    public var intervalWeeks: Int?
    public var fictionalWeek: Int?
    /// Frühere Zwischenverläufe dieses Falls in Terminreihenfolge, für die Verlaufsmuster.
    public var pastExperiences: [BetweenVisitExperience]?
}

extension SessionSnapshot {
    public var caseID: UUID { continuity?.caseID ?? id }
    public var sessionNumber: Int { continuity?.number ?? 1 }
    public var fictionalWeek: Int { continuity?.fictionalWeek ?? sessionNumber - 1 }
    public var intervalWeeks: Int { continuity?.intervalWeeks ?? 1 }
    public var openingLine: String { openingMessage ?? content.scenario.openingLine }
    public var visitLabel: String { "Sitzung \(sessionNumber) · Woche \(fictionalWeek) (fiktional)" }
}

public enum VisitBuilder {
    public static func validateIdentity(_ previous: BuildIdentity, new identity: BuildIdentity) throws {
        guard previous.model == identity.model, previous.contentHash == identity.contentHash,
              previous.rulesVersion == identity.rulesVersion else { throw TrainerFailure.unsupportedVersion }
    }

    public static func preparation(after session: SessionSnapshot) throws -> VisitNote {
        guard session.status == .completed else { throw TrainerFailure.sessionCompleted }
        func entry(_ evidence: CharacterEvidence, heading: String) throws -> VisitNote.Entry {
            try sourceEntry(evidence, in: session, heading: heading)
        }
        var entries: [VisitNote.Entry] = []
        // Wörtliche Äußerungen, keine semantisch erfundenen Themenüberschriften.
        for (index, turn) in session.turns.enumerated().suffix(2) {
            entries.append(.init(heading: "Zuletzt angesprochen", quote: turn.reply.text,
                sessionID: session.id, sessionNumber: session.sessionNumber, turnID: turn.id,
                turnNumber: index + 1, speaker: .client))
        }
        let goals = session.state.development?.goals ?? []
        for goal in goals.suffix(3) {
            let standing = goal.memory?.standing ?? .mentioned
            let uncertain = goal.memory?.lastEvent?.isUncertain == true
            entries.append(try entry(goal.goal, heading: "Ziel: \(standing.label)\(uncertain ? " · letzte Einordnung unsicher" : "")"))
            if let event = goal.memory?.lastEvent {
                if let proposal = event.proposal { entries.append(try entry(proposal, heading: "Zugehöriger Vorschlag")) }
                if event.evidence != goal.goal { entries.append(try entry(event.evidence, heading: "Letzte Aussage zum Ziel")) }
            }
        }
        for record in (session.state.narrative?.records ?? []).suffix(3) {
            entries.append(try entry(record.evidence, heading: record.kind.label + (record.isUncertain ? " · unsicher" : "")))
        }
        return VisitNote(entries: entries, omittedGoals: max(0, goals.count - 3),
            previousTurnCount: session.turns.count,
            hasConfirmedGoal: goals.suffix(3).contains { $0.memory?.standing == .agreed && $0.memory?.lastEvent?.isUncertain != true })
    }

    public static func sourceEntry(_ evidence: CharacterEvidence, in session: SessionSnapshot, heading: String) throws -> VisitNote.Entry {
        _ = try CharacterTracker.position(evidence, session: session)
        let transcripts = (session.continuity?.priorSessions ?? []) + [PriorSession(session)]
        let source = transcripts.first { transcript in
            if let turn = evidence.origin.turnID { return transcript.turns.contains { $0.id == turn } }
            return transcript.id == (evidence.origin.sessionID ?? session.id)
        }
        guard let source else { throw TrainerFailure.invalidAnalysis }
        return .init(heading: heading, quote: evidence.quote, sessionID: source.id,
            sessionNumber: source.number, turnID: evidence.origin.turnID,
            turnNumber: source.turns.firstIndex { $0.id == evidence.origin.turnID }.map { $0 + 1 }, speaker: evidence.origin.speaker)
    }

    public static func narrativeEntries(in session: SessionSnapshot) throws -> [VisitNote.Entry] {
        try (session.state.narrative?.records ?? []).map { record in
            try sourceEntry(record.evidence, in: session, heading: record.kind.label + (record.isUncertain ? " · unsicher" : ""))
        }
    }

    /// Nur in einer atomaren Repository-Operation aufrufen. Die Elternsitzung speichert
    /// die neue ID gleichzeitig mit dem Kind; erneutes Starten liefert dasselbe Kind.
    public static func followUp(after previous: SessionSnapshot, identity: BuildIdentity,
                                at date: Date, intervalWeeks: Int = 1) throws -> SessionSnapshot {
        guard previous.status == .completed, previous.caseClosure == nil else { throw TrainerFailure.sessionCompleted }
        guard VisitInterval.allowed(after: previous).contains(intervalWeeks) else { throw TrainerFailure.invalidInput }
        try validateIdentity(previous.identity, new: identity)
        let note = try preparation(after: previous)
        var state = previous.state
        state.closedQuestionStreak = 0; state.recentCredits = []; state.permissionMemory = nil
        state.narrative = previous.state.narrative?.anchoringOpening(to: previous.id)
        state.development = anchoredDevelopment(previous.state.development, openingSessionID: previous.id)
        var next = SessionSnapshot(schemaVersion: 1, id: UUID(), revision: 0, approachID: previous.approachID,
            identity: identity, content: previous.content, state: state, turns: [], status: .active, startedAt: date)
        next.openingMessage = "Hallo."
        next.continuity = .init(caseID: previous.caseID, previousSessionID: previous.id,
            number: previous.sessionNumber + 1,
            priorSessions: (previous.continuity?.priorSessions ?? []) + [PriorSession(previous)], preparation: note)
        next.continuity?.intervalWeeks = intervalWeeks
        next.continuity?.fictionalWeek = previous.fictionalWeek + intervalWeeks
        let past = (previous.continuity?.pastExperiences ?? []) + [previous.continuity?.experience].compactMap { $0 }
        next.continuity?.pastExperiences = past.isEmpty ? nil : past
        try CharacterTracker.validate(state.development, session: next, currentTurnID: UUID())
        try NarrativeTracker.validate(state.narrative, session: next, currentTurnID: UUID())
        let experience = try ExperienceSelector.select(after: previous, into: next)
        next.continuity?.experience = experience
        return next
    }

    /// nil als Eröffnungsherkunft bezeichnet bislang die aktuelle Sitzung. Beim Übergang
    /// wird diese Herkunft einmalig an die alte Sitzung gebunden, auch in Zielereignissen.
    private static func anchoredDevelopment(_ original: CharacterDevelopment?, openingSessionID: UUID) -> CharacterDevelopment? {
        guard var value = original else { return nil }
        func anchor(_ e: CharacterEvidence) -> CharacterEvidence {
            var e = e
            if e.origin.turnID == nil && e.origin.sessionID == nil { e.origin.sessionID = openingSessionID }
            return e
        }
        func record(_ r: CharacterRecord) -> CharacterRecord { var r = r; r.evidence = anchor(r.evidence); return r }
        func event(_ e: GoalEvent) -> GoalEvent {
            var e = e; e.evidence = anchor(e.evidence)
            e.previousGoal = e.previousGoal.map(anchor); e.currentGoal = e.currentGoal.map(anchor); e.proposal = e.proposal.map(anchor)
            return e
        }
        value.rapport = value.rapport.map(record)
        value.goals = value.goals.map { goal in
            var goal = goal; goal.goal = anchor(goal.goal)
            goal.readiness = goal.readiness.map(record); goal.confidence = goal.confidence.map(record)
            if var memory = goal.memory {
                memory.aliases = memory.aliases.map(anchor); memory.lastEvent = memory.lastEvent.map(event); goal.memory = memory
            }
            return goal
        }
        value.goalEvents = value.goalEvents?.map(event)
        return value
    }
}

extension ContextBuilder {
    /// Archiv und laufende Sitzung in historischer Reihenfolge, ausschließlich Originaltexte.
    static func evidenceMessages(_ session: SessionSnapshot) -> [DialogueMessage] {
        var messages: [DialogueMessage] = []
        for prior in session.continuity?.priorSessions ?? [] {
            messages.append(.init(speaker: .client, text: prior.opening,
                origin: .init(turnID: nil, speaker: .client, sessionID: prior.id)))
            for turn in prior.turns {
                messages += [.init(speaker: .counselor, text: turn.input, origin: .init(turnID: turn.id, speaker: .counselor)),
                             .init(speaker: .client, text: turn.reply, origin: .init(turnID: turn.id, speaker: .client))]
            }
        }
        messages.append(.init(speaker: .client, text: session.openingLine, origin: .init(turnID: nil, speaker: .client)))
        for turn in session.turns {
            messages += [.init(speaker: .counselor, text: turn.input, origin: .init(turnID: turn.id, speaker: .counselor)),
                         .init(speaker: .client, text: turn.reply.text, origin: .init(turnID: turn.id, speaker: .client))]
        }
        return messages.map { message in
            var message = message
            if session.continuity != nil {
                message.visitNumber = session.continuity?.priorSessions.first { prior in
                    message.origin?.turnID.map { id in prior.turns.contains { $0.id == id } }
                        ?? (message.origin?.sessionID == prior.id)
                }?.number ?? session.sessionNumber
            }
            return message
        }
    }

    static func priorOffset(_ session: SessionSnapshot) -> Int {
        (session.continuity?.priorSessions ?? []).reduce(0) { $0 + $1.turns.count + 1 }
    }
    static func observedPosition(_ id: UUID, currentTurnID: UUID, session: SessionSnapshot) throws -> Int {
        if id == currentTurnID { return priorOffset(session) + session.turns.count }
        var offset = 0
        for prior in session.continuity?.priorSessions ?? [] {
            if let index = prior.turns.firstIndex(where: { $0.id == id }) { return offset + index }
            offset += prior.turns.count + 1
        }
        guard let index = session.turns.firstIndex(where: { $0.id == id }) else { throw TrainerFailure.invalidAnalysis }
        return offset + index
    }

    public static func visitContext(_ session: SessionSnapshot) -> String? {
        guard session.continuity != nil else { return nil }
        return "\(session.visitLabel). Abstand zum vorherigen Termin: fiktional \(VisitInterval.label(session.intervalWeeks)). Frühere Aussagen sind historische Belege, keine Ereignisse der Zwischenzeit. Ergänze keine zwischenzeitlichen Erlebnisse oder Fortschritte, die nicht ausdrücklich in der Szenariovorgabe stehen. Alte Ratserlaubnis gilt nicht im neuen Termin. Lass nach der Begrüßung Raum für eine offene Einstiegsfrage; andere Einstiege sind erlaubt."
    }

    public static func sourceLabel(_ message: DialogueMessage, session: SessionSnapshot) -> String {
        guard let origin = message.origin else { return "" }
        if let prior = session.continuity?.priorSessions.first(where: { prior in
            origin.turnID.map { id in prior.turns.contains { $0.id == id } } ?? (origin.sessionID == prior.id)
        }) { return "Früherer Termin, Sitzung \(prior.number): " }
        return session.continuity == nil ? "" : "Aktueller Termin: "
    }

    /// Erlaubnisse überleben keinen Terminwechsel, auch wenn das Modell historische
    /// Originalbelege im begrenzten Zielgedächtnis gesehen hat.
    static func validateCurrentPermission(_ analysis: TurnAnalysis, context: [DialogueMessage], session: SessionSnapshot) throws {
        guard session.continuity != nil else { return }
        for permission in analysis.permissions ?? [] where [.granted, .clientRequested].contains(permission.standing) {
            for ref in [permission.request, permission.response].compactMap({ $0 }) where ref.source == .contextMessage {
                guard let index = ref.messageIndex, context.indices.contains(index), let origin = context[index].origin,
                      origin.sessionID == nil,
                      origin.turnID == nil || session.turns.contains(where: { $0.id == origin.turnID }) else {
                    throw TrainerFailure.invalidAnalysis
                }
            }
        }
    }
}
