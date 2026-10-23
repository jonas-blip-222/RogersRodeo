import Foundation

/// MI-04c (E11): vereinbarte Terminabstände, belegte Kette bis Maintenance und Fallende.
/// Alles wird aus gespeicherten Originalbelegen abgeleitet, nie aus Offenheit,
/// Beratungscodes, Gerätezeit oder der bloßen Zahl der Termine.
public enum VisitInterval {
    /// Orientierung aus E11, keine starre Stufenfolge.
    public static let options = [1, 2, 3, 4, 6, 8, 13]
    static let implementationKinds: Set<NarrativeKind> = [.attempted, .completed, .partial, .continued]

    /// Vor einer belegt berichteten Umsetzung bleibt es bei einer Woche (E11, Punkt 1).
    public static func allowed(after session: SessionSnapshot) -> [Int] {
        let reported = (session.state.narrative?.records ?? []).contains {
            !$0.isUncertain && implementationKinds.contains($0.kind)
        }
        return reported ? options : [1]
    }

    public static func label(_ weeks: Int) -> String {
        switch weeks {
        case 1: "eine Woche"
        case 4: "vier Wochen (etwa ein Monat)"
        case 8: "acht Wochen (etwa zwei Monate)"
        case 13: "13 Wochen (etwa drei Monate)"
        default: "\(weeks) Wochen"
        }
    }
}

/// Im Gespräch genannte Terminvereinbarung als Vorschlag für die Vorbereitung. Wörtlicher
/// Satz mit Herkunft; die übende Person bestätigt oder korrigiert. Kein Modellaufruf.
public struct IntervalSuggestion: Sendable, Equatable {
    public var weeks: Int
    public var quote: String
    public var turnNumber: Int
    public var speaker: Speaker

    static let numbers: [String: Int] = ["einer": 1, "einem": 1, "eine": 1, "zwei": 2, "drei": 3, "vier": 4,
        "fünf": 5, "sechs": 6, "sieben": 7, "acht": 8, "zehn": 10, "zwölf": 12, "dreizehn": 13, "vierzehn": 14]
    static let patterns: [(String, @Sendable (Int) -> Int)] = [
        (#"\b(?:in|nach)\s+(\d{1,2}|einer|zwei|drei|vier|fünf|sechs|sieben|acht|zehn|zwölf|dreizehn)\s+wochen?\b"#, { $0 }),
        (#"\b(?:in|nach)\s+(\d{1,2}|einem|zwei|drei)\s+monat(?:en)?\b"#, { [1: 4, 2: 8, 3: 13][$0] ?? $0 * 4 }),
        (#"\b(?:in|nach)\s+(14|vierzehn)\s+tagen\b"#, { _ in 2 }),
        (#"\bnächste[nrs]?\s+woche\b"#, { _ in 1 }),
        (#"\b(?:vierteljahr|quartal)\b"#, { _ in 13 }),
    ]

    /// Sucht in den letzten drei Runden die zuletzt genannte, gerade erlaubte Angabe.
    public static func find(in session: SessionSnapshot) -> IntervalSuggestion? {
        let allowed = VisitInterval.allowed(after: session)
        for (index, turn) in session.turns.enumerated().reversed().prefix(3) {
            for (text, speaker) in [(turn.reply.text, Speaker.client), (turn.input, .counselor)] {
                if let match = latest(in: text), allowed.contains(match.weeks) {
                    return .init(weeks: match.weeks, quote: match.sentence, turnNumber: index + 1, speaker: speaker)
                }
            }
        }
        return nil
    }

    static func latest(in text: String) -> (weeks: Int, sentence: String)? {
        var best: (range: Range<String.Index>, weeks: Int)?
        for (pattern, convert) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range, in: text) else { continue }
                var value = 0
                if match.numberOfRanges > 1, let group = Range(match.range(at: 1), in: text) {
                    let word = text[group].lowercased()
                    value = Int(word) ?? numbers[word] ?? 0
                }
                let weeks = convert(value)
                if best == nil || range.lowerBound > best!.range.lowerBound { best = (range, weeks) }
            }
        }
        guard let best else { return nil }
        let terminators: Set<Character> = [".", "!", "?", "\n"]
        let start = text[..<best.range.lowerBound].lastIndex(where: terminators.contains).map(text.index(after:)) ?? text.startIndex
        let end = text[best.range.upperBound...].firstIndex(where: terminators.contains).map(text.index(after:)) ?? text.endIndex
        return (best.weeks, text[start..<end].trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// Belegte Kette nach dem Nachtrag zu E11: drei aufeinanderfolgende Folgetermine mit
/// berichteter fortgesetzter Umsetzung über mindestens 13 fiktionale Wochen und mindestens
/// eine bewältigte Schwierigkeit. Keine Punktzahl und keine Kompetenzbewertung.
public struct MaintenanceProgress: Sendable, Equatable {
    public struct Report: Sendable, Equatable {
        public var sessionNumber: Int
        public var week: Int
        public var evidence: CharacterEvidence
    }
    public static let requiredReports = 3
    public static let requiredWeeks = 13
    public var reports: [Report] = []
    public var difficulty: CharacterEvidence?
    public var isMet: Bool {
        guard reports.count >= Self.requiredReports, let first = reports.first, let last = reports.last else { return false }
        return last.week - first.week >= Self.requiredWeeks && difficulty != nil
    }

    public static func evaluate(_ session: SessionSnapshot) -> MaintenanceProgress {
        var weeks = Dictionary(uniqueKeysWithValues: (session.continuity?.priorSessions ?? []).map { ($0.number, $0.week) })
        weeks[session.sessionNumber] = session.fictionalWeek
        // Maßgeblich ist der Termin, in dem Lukas etwas gesagt hat, nicht der Analysezeitpunkt.
        var byVisit: [Int: [NarrativeRecord]] = [:]
        for record in session.state.narrative?.records ?? [] where !record.isUncertain {
            guard let source = try? VisitBuilder.sourceEntry(record.evidence, in: session, heading: "") else { continue }
            byVisit[source.sessionNumber, default: []].append(record)
        }
        var progress = MaintenanceProgress(), pendingDifficulty: CharacterEvidence?
        for number in byVisit.keys.sorted() {
            var continued: CharacterEvidence?, setback: CharacterEvidence?, reset = false
            for record in byVisit[number] ?? [] {
                switch record.kind {
                case .continued: continued = continued ?? record.evidence; reset = false
                case .setback: setback = setback ?? record.evidence
                case .withdrawn, .notAttempted: reset = true; continued = nil; setback = nil
                default: break
                }
            }
            if reset {
                progress = MaintenanceProgress(); pendingDifficulty = nil
            } else if let continued {
                progress.reports.append(.init(sessionNumber: number, week: weeks[number] ?? number - 1, evidence: continued))
                // Ein Ausrutscher zählt als bewältigt, sobald Lukas belegt weitermacht.
                if let found = setback ?? pendingDifficulty, progress.difficulty == nil { progress.difficulty = found }
                pendingDifficulty = nil
            } else if let setback {
                pendingDifficulty = pendingDifficulty ?? setback // Kette ruht (F4).
            }
        }
        return progress
    }
}

public enum CaseOutcome: String, Codable, Sendable {
    case maintenance, endedWithoutMaintenance
    public var label: String {
        switch self {
        case .maintenance: "Mit Maintenance abgeschlossen"
        case .endedWithoutMaintenance: "Beendet ohne Maintenance"
        }
    }
}

public struct CaseClosure: Codable, Sendable, Equatable {
    public var outcome: CaseOutcome
    public var closedAt: Date
}

/// Fallrückblick über alle Termine, gebaut aus dem letzten Termin. Er enthält bereits alle
/// früheren Originaltexte und die fallweite Erinnerung; keine Wertung und keine Note.
public struct CaseReview: Sendable {
    public struct Visit: Sendable, Equatable {
        public var number: Int
        public var week: Int
        public var turns: Int
    }
    public var scenarioName: String
    public var visits: [Visit]
    public var goals: [VisitNote.Entry]
    public var narrative: [VisitNote.Entry]
    public var progress: MaintenanceProgress
    public var closure: CaseClosure?

    public static func build(_ session: SessionSnapshot) -> CaseReview {
        let visits = (session.continuity?.priorSessions ?? []).map { Visit(number: $0.number, week: $0.week, turns: $0.turns.count) }
            + [Visit(number: session.sessionNumber, week: session.fictionalWeek, turns: session.turns.count)]
        let goals = (session.state.development?.goals ?? []).compactMap { goal in
            try? VisitBuilder.sourceEntry(goal.goal, in: session, heading: "Ziel: \((goal.memory?.standing ?? .mentioned).label)")
        }
        return .init(scenarioName: session.content.scenario.name, visits: visits, goals: goals,
                     narrative: (try? VisitBuilder.narrativeEntries(in: session)) ?? [],
                     progress: .evaluate(session), closure: session.caseClosure)
    }

    public var outcomeText: String {
        closure?.outcome.label ?? (progress.isMet ? "Kriterien für einen Abschluss mit Maintenance belegt" : "Fall läuft")
    }

    public var markdown: String {
        var lines = ["# Fallrückblick mit \(scenarioName)", "", outcomeText, "",
                     "Automatische Einordnungen können fehlerhaft sein. Keine Kompetenzbewertung.", "", "## Termine"]
        lines += visits.map { "- Sitzung \($0.number) · Woche \($0.week) (fiktional) · \($0.turns) Runden" }
        lines += ["", "## Ziele"]
        lines += goals.isEmpty ? ["Keine belegten Ziele."] : goals.map { "- \($0.heading): „\($0.quote)“ (\($0.sourceLabel))" }
        lines += ["", "## Vorhaben, Erfahrungen und Rückbewegungen"]
        lines += narrative.isEmpty ? ["Keine belegten Vorhaben."] : narrative.map { "- \($0.heading): „\($0.quote)“ (\($0.sourceLabel))" }
        lines += ["", "## Berichte über fortgesetzte Umsetzung"]
        lines += progress.reports.isEmpty ? ["Keine aufeinanderfolgenden Berichte belegt."]
            : progress.reports.map { "- Sitzung \($0.sessionNumber), Woche \($0.week): „\($0.evidence.quote)“" }
        if let difficulty = progress.difficulty { lines += ["- Bewältigte Schwierigkeit: „\(difficulty.quote)“"] }
        return lines.joined(separator: "\n")
    }
}

extension RepositoryRules {
    /// Nur der letzte, abgeschlossene Termin eines Falls kann ihn beenden. Das Ergebnis
    /// folgt allein aus den Belegen; ein manuelles Ende ist kein Maintenance-Abschluss.
    public static func closeCase(at date: Date, in record: inout SessionRecord) throws {
        if record.snapshot.caseClosure != nil { return }
        guard record.snapshot.status == .completed, record.snapshot.followUpSessionID == nil,
              record.pending == nil else { throw TrainerFailure.sessionCompleted }
        let outcome: CaseOutcome = MaintenanceProgress.evaluate(record.snapshot).isMet ? .maintenance : .endedWithoutMaintenance
        record.snapshot.caseClosure = .init(outcome: outcome, closedAt: date)
        record.snapshot.revision += 1
    }
}
