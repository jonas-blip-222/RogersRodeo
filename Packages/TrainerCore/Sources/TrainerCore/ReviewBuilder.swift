import Foundation

public struct SessionReview: Sendable {
    public let totalTurns: Int
    public let analyzedTurns: Int
    public let counts: [CounselorCode: Int]
    public let reflectionQuestionRatio: Double?
    public let complexReflectionShare: Double?
    public let characterCoverage: Double?
}

public enum ReviewBuilder {
    public static func build(_ session: SessionSnapshot) -> SessionReview {
        let segments = session.turns.flatMap { $0.analysis?.segments ?? [] }.filter { !$0.isUncertain }
        let counts = Dictionary(grouping: segments, by: \.code).mapValues(\.count)
        let questions = counts[.openQuestion, default: 0] + counts[.closedQuestion, default: 0]
        let reflections = counts[.simpleReflection, default: 0] + counts[.complexReflection, default: 0]
        let inputCharacters = session.turns.reduce(0) { $0 + $1.input.count }
        let coveredCharacters = session.turns.flatMap { $0.analysis?.segments ?? [] }.reduce(0) { $0 + $1.quote.count }
        return SessionReview(totalTurns: session.turns.count,
            analyzedTurns: session.turns.filter { $0.analysis?.segments.contains(where: { !$0.isUncertain }) == true }.count,
            counts: counts, reflectionQuestionRatio: questions == 0 ? nil : Double(reflections) / Double(questions),
            complexReflectionShare: reflections == 0 ? nil : Double(counts[.complexReflection, default: 0]) / Double(reflections),
            characterCoverage: inputCharacters == 0 ? nil : Double(coveredCharacters) / Double(inputCharacters))
    }

    public static func markdown(_ session: SessionSnapshot) -> String {
        let iso = ISO8601DateFormatter()
        func escaped(_ text: String) -> String {
            text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        var lines = ["# Übungsgespräch mit \(session.content.scenario.name)", "",
            "Beginn: \(iso.string(from: session.startedAt))", "Ansatz: MI · Figur \(session.content.scenario.version)",
            "Modell: \(session.identity.model.id) · Regeln \(session.identity.rulesVersion)",
            "Modellartefakt: \(session.identity.model.artifactRevision) · Laufzeit: \(session.identity.model.runtimeRevision)",
            "Prompt: \(session.identity.promptVersion) · Inhalt: \(session.identity.contentHash)",
            "Status: \(session.status == .completed ? "Abgeschlossen" : "Begonnen")",
            "Automatische Einordnungen können fehlerhaft sein. Dies ist keine standardisierte Kompetenzbewertung.", "",
            "**\(session.content.scenario.name)**", escaped(session.content.scenario.openingLine), ""]
        if session.identity.model.id == DemoModelProvider.identity.id {
            lines.insert("Demo mit festen Antworten. Keine KI und keine fachliche Bewertung.", at: 2)
        }
        for turn in session.turns {
            lines += ["Runde abgeschlossen: \(iso.string(from: turn.completedAt))", "", "**Beratung**", escaped(turn.input), ""]
            if let analysis = turn.analysis, !analysis.segments.isEmpty {
                lines += ["Einordnung:"]
                for segment in analysis.segments {
                    lines += ["- \(segment.isUncertain ? "Unsicher" : segment.code.label): „\(escaped(segment.quote))“"]
                }
            } else { lines += ["Keine Einordnung vorhanden."] }
            lines += ["", "**\(session.content.scenario.name)**", escaped(turn.reply.text), ""]
        }
        return lines.joined(separator: "\n")
    }
}

extension CounselorCode {
    public var label: String {
        switch self {
        case .openQuestion: "Offene Frage"
        case .closedQuestion: "Geschlossene Frage"
        case .simpleReflection: "Einfache Reflexion"
        case .complexReflection: "Komplexe Reflexion"
        case .affirmation: "Würdigung"
        case .autonomy: "Autonomie betonen"
        case .collaboration: "Zusammenarbeit suchen"
        case .information: "Information"
        case .adviceWithoutPermission: "Rat ohne Erlaubnis"
        case .adviceWithPermission: "Rat mit Erlaubnis"
        case .confrontation: "Konfrontation"
        case .other: "Sonstiges"
        }
    }
}

extension TrainerFailure: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidInput: "Bitte gib zwischen 1 und 1.500 Zeichen ein."
        case .operationInProgress: "Eine Antwort wird bereits vorbereitet."
        case .invalidAnalysis: "Deine Äußerung konnte nicht zuverlässig eingeordnet werden. Du kannst es erneut versuchen oder ohne Einordnung fortsetzen."
        case .invalidReply, .modelRefusal: "Lukas konnte gerade keine passende Antwort geben. Bitte versuche es erneut."
        case .modelUnavailable: "Das Sprachmodell ist gerade nicht erreichbar. Prüfe deine Internetverbindung."
        case .artifactInvalid: "Eine benötigte Datei ist beschädigt oder unvollständig."
        case .contextLimit: "Der Gesprächskontext ist zu groß. Bitte kürze deine Eingabe."
        case .revisionConflict: "Die Sitzung wurde inzwischen verändert. Bitte lade sie erneut."
        case .sessionNotFound: "Diese Sitzung ist nicht mehr vorhanden."
        case .sessionCompleted: "Diese Sitzung ist abgeschlossen oder hat die maximale Länge erreicht."
        case .storageUnavailable: "Die Sitzung konnte nicht gespeichert werden. Deine Eingabe bleibt erhalten."
        case .unsupportedVersion: "Diese Sitzung kann mit der aktuellen Modellversion gelesen, aber nicht fortgesetzt werden."
        }
    }
}
