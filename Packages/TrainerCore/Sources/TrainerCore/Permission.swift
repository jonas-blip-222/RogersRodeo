import Foundation

// Erlaubnis vor einem Ratschlag (Documentation/MI-UEBERGABE.md, Abschnitt 4.2 und Fälle 4, 10, 11).
//
// Der Trainingsstandard lautet: Erlaubnis erfragen → passende Zustimmung abwarten →
// EINEN eigenen Vorschlag anbieten → Passung erkunden. Zwei Festlegungen von Jonas vom
// 30.09.2026 schärfen das und sind hier verbindlich umgesetzt:
//
// 1. **Situationsbezug.** „Generell gilt eine Erlaubnis in so einem Kontext nur für die
//    aktuelle Situation." Der gleiche Gegenstand allein trägt keine Erlaubnis in eine
//    spätere Gesprächssituation; es gibt keine pauschale oder dauerhafte Erlaubnis.
// 2. **Ein Ja, ein Ratschlag.** „Wenn ich jemanden frage, ob ich ihm einen Ratschlag geben
//    darf und er sagt ja, dann gebe ich ihm 1! Ratschlag." Danach ist die Zustimmung
//    verbraucht — auch beim selben Thema, auch in derselben Situation und auch dann, wenn
//    beide Ratschläge im selben Beraterbeitrag stehen.
//
// Arbeitsteilung wie bei Zielgedächtnis und Charakterbeobachtungen: Das Modell trifft die
// semantische Einschätzung und muss sie mit wörtlichen Belegen aus dem tatsächlich
// gesehenen Kontext ausweisen. Diese Datei prüft ausschließlich Nachprüfbares — Herkunft,
// Sprecher, Reihenfolge, Zitate, Zuordnung zum Ratschlagssegment und die Wiederverwendung
// derselben Zustimmung. Es gibt hier bewusst keine Stichwortliste, die „ja" oder „Darf ich"
// als Erlaubnisdetektor missbraucht, und keine Turnzahl als fachliche Regel.

/// Erlaubnislage genau eines Ratschlags im gerade gesendeten Beitrag.
public enum PermissionStanding: String, Codable, Sendable, CaseIterable {
    /// Frühere Erlaubnisfrage, darauf folgende Zustimmung, noch nicht verbraucht.
    case granted = "erteilt"
    /// Zustimmung liegt vor, wurde aber schon von einem früheren Ratschlag aufgebraucht.
    case consumed = "bereits_verbraucht"
    /// Zustimmung gehört zu einer abgeschlossenen früheren Gesprächssituation.
    case pastSituation = "fruehere_situation"
    /// Auf die Erlaubnisfrage folgte eine Ablehnung.
    case refused = "abgelehnt"
    /// Eine vorhandene Zustimmung wurde später zurückgenommen.
    case withdrawn = "widerrufen"
    /// Fall 10: Frage und Rat stehen im selben Beitrag, eine Antwort gibt es noch nicht.
    case askedInSameInput = "im_selben_beitrag_gefragt"
    /// Die Figur hat selbst um einen Vorschlag gebeten.
    case clientRequested = "vom_klienten_erbeten"
    /// Im verfügbaren Kontext ist keine passende Erlaubnis und keine Bitte für diesen Rat erkennbar.
    case notRequested = "nicht_eingeholt"
    /// Belege reichen für keine der Einordnungen; ausdrücklich keine Entwarnung.
    case unclear = "unklar"
}

/// Eine Einschätzung je Ratschlag. Mehrere inhaltlich verschiedene Ratschläge in einem
/// Beitrag erhalten getrennte Einträge: eine einzelne Zustimmung darf nicht beide tragen.
/// Welche Sätze einen Ratschlag bilden, entscheidet die Segmentierung des Modells — es gibt
/// hier keine Zählung von Satzzeichen.
public struct PermissionAssessment: Codable, Sendable, Equatable {
    /// Ausschnitt des eigenen Beitrags, der den Ratschlag trägt. Muss in einem Segment mit
    /// `ratschlag_mit_erlaubnis` oder `ratschlag_ohne_erlaubnis` liegen.
    public var advice: EvidenceReference
    public var standing: PermissionStanding
    /// Erlaubnisfrage der Beratung.
    public var request: EvidenceReference?
    /// Antwort der Figur: Zustimmung, Ablehnung, Widerruf oder eigene Bitte.
    public var response: EvidenceReference?
    /// Der frühere Ratschlag, der die Zustimmung bereits aufgebraucht hat.
    public var consumedBy: EvidenceReference?
    public var isUncertain: Bool
    public init(advice: EvidenceReference, standing: PermissionStanding,
                request: EvidenceReference? = nil, response: EvidenceReference? = nil,
                consumedBy: EvidenceReference? = nil, isUncertain: Bool = false) {
        self.advice = advice; self.standing = standing; self.request = request
        self.response = response; self.consumedBy = consumedBy; self.isUncertain = isUncertain
    }
}

/// Modelleinschätzung nach der deterministischen Nachprüfung. `standing` und `isUncertain`
/// können gegenüber der Analyse zurückhaltender sein, nie zuversichtlicher.
public struct ResolvedPermission: Sendable, Equatable {
    public var assessment: PermissionAssessment
    public var standing: PermissionStanding
    public var isUncertain: Bool
    public init(assessment: PermissionAssessment, standing: PermissionStanding, isUncertain: Bool) {
        self.assessment = assessment; self.standing = standing; self.isUncertain = isUncertain
    }
}

/// Was die Rückmeldung über die Erlaubnislage weiß. `contextIsComplete` beantwortet genau
/// eine Frage: Lag der Analyse das ganze bisherige Gespräch vor? Nur dann darf aus einer
/// fehlenden Erlaubnisfrage ein sicherer Befund werden (Abschnitt 9.4).
public struct PermissionReport: Sendable, Equatable {
    public var entries: [ResolvedPermission]
    public var contextIsComplete: Bool
    public init(entries: [ResolvedPermission] = [], contextIsComplete: Bool = false) {
        self.entries = entries; self.contextIsComplete = contextIsComplete
    }
    /// Keine Erlaubnisinformation und keine Aussage über die Kontextabdeckung.
    public static let unavailable = PermissionReport()
}

public enum PermissionTracker {
    /// Deterministische Nachprüfung der Modelleinschätzung am tatsächlich gesehenen Kontext.
    ///
    /// Die eine strukturelle Vorsichtsregel: Eine Zustimmung oder Bitte trägt sicher nur den
    /// Ratschlag im unmittelbar darauf folgenden Beitrag. Sicher ist sie deshalb nur, wenn
    /// sie die letzte Nachricht des gesehenen Kontexts ist. Steht danach noch etwas, dann ist
    /// entweder der eine erlaubte Ratschlag schon gefallen, die Situation weitergezogen oder
    /// die Zustimmung inzwischen zurückgenommen — nichts davon kann diese Ebene entscheiden,
    /// also bleibt die Einschätzung unsicher.
    ///
    /// Das deckt zugleich die Kontextlücke nach einer Zustimmung ab: Der Analysekontext
    /// enthält stets die jüngsten Runden vollständig, eine Auslassung kann also nur vor der
    /// letzten Nachricht liegen. Ist die Zustimmung die letzte Nachricht, kann zwischen ihr
    /// und diesem Beitrag nichts ausgelassen worden sein; ist sie es nicht, gilt ohnehin
    /// Unsicherheit. Das ist ausdrücklich eine Vorsichtsregel über die Gesprächsstruktur und
    /// keine fachliche Turnzahl: Sie erzeugt nie einen sicheren Vorwurf, sondern nimmt nur
    /// die Sicherheit aus einem Freispruch.
    public static func resolve(_ permissions: [PermissionAssessment],
                               context: [DialogueMessage]) -> [ResolvedPermission] {
        permissions.map { entry in
            var uncertain = entry.isUncertain
            if [.granted, .clientRequested].contains(entry.standing),
               entry.response?.messageIndex != context.count - 1 {
                uncertain = true
            }
            return .init(assessment: entry, standing: entry.standing, isUncertain: uncertain)
        }
    }
}

extension ContextBuilder {
    /// Ob der übergebene Kontext das gesamte bisherige Gespräch enthält. Geprüft wird die
    /// dauerhafte Herkunft jeder Nachricht, nicht ihre Anzahl: Ein gekürztes Fenster und ein
    /// selektiv aus dem Zielgedächtnis zusammengestellter Verlauf fallen beide durch.
    public static func covers(_ context: [DialogueMessage], session: SessionSnapshot) -> Bool {
        func contains(_ origin: MessageOrigin, text: String) -> Bool {
            context.contains { $0.origin == origin && $0.text == text && $0.speaker == origin.speaker }
        }
        guard contains(.init(turnID: nil, speaker: .client), text: session.content.scenario.openingLine) else {
            return false
        }
        return session.turns.allSatisfy {
            contains(.init(turnID: $0.id, speaker: .counselor), text: $0.input)
                && contains(.init(turnID: $0.id, speaker: .client), text: $0.reply.text)
        }
    }
}

extension OutputValidator {
    /// Prüft die Erlaubniseinschätzungen gegen Eingabe, Kontext und Segmentierung.
    static func validatePermissions(_ analysis: TurnAnalysis, input: String,
                                    context: [DialogueMessage],
                                    ranges: [Range<String.Index>]) throws {
        guard let permissions = analysis.permissions else { return }
        // Mehr als drei getrennte Ratschläge in einem Beitrag sind kein zu behandelnder Fall.
        guard permissions.count <= 3 else { throw TrainerFailure.invalidAnalysis }
        let adviceCodes: [CounselorCode] = [.adviceWithPermission, .adviceWithoutPermission]

        func anchored(_ reference: EvidenceReference, speaker: Speaker) throws -> Int {
            guard reference.source == .contextMessage, reference.speaker == speaker,
                  let index = reference.messageIndex else { throw TrainerFailure.invalidAnalysis }
            try validateEvidence(reference, input: input, context: context)
            return index
        }

        var usedSegments: [Int] = []
        // Zustimmungen werden über die Nachricht geführt, nicht über die Zeichenfolge des
        // Zitats: „Ja, gerne." und „gerne" sind dieselbe Zustimmung. Ein Vergleich von
        // `EvidenceReference` ließe genau diese Lücke offen.
        var spentConsents: [Int] = []
        var grantingSegments: [(consent: Int, segment: Int)] = []
        var previousAdvice: Range<String.Index>?
        for entry in permissions {
            guard entry.advice.source == .currentInput, entry.advice.speaker == .counselor else {
                throw TrainerFailure.invalidAnalysis
            }
            let advice = try evidenceRange(entry.advice, input: input, context: context)
            // Genau ein Ratschlagssegment trägt diesen Eintrag, und jedes Segment nur einmal.
            guard let segment = zip(analysis.segments, ranges).enumerated().first(where: { item in
                adviceCodes.contains(item.element.0.code)
                    && item.element.1.lowerBound <= advice.lowerBound
                    && advice.upperBound <= item.element.1.upperBound
            }) else { throw TrainerFailure.invalidAnalysis }
            guard !usedSegments.contains(segment.offset) else { throw TrainerFailure.invalidAnalysis }
            usedSegments.append(segment.offset)
            // Einträge folgen dem eigenen Beitrag; darauf beruht die Prüfung von `consumedBy`.
            if let previousAdvice, advice.lowerBound <= previousAdvice.lowerBound {
                throw TrainerFailure.invalidAnalysis
            }
            previousAdvice = advice

            // Eine sichere Einschätzung und der Segmentcode dürfen sich nicht widersprechen.
            if !entry.isUncertain {
                switch entry.standing {
                case .granted:
                    guard segment.element.0.code == .adviceWithPermission else { throw TrainerFailure.invalidAnalysis }
                case .consumed, .pastSituation, .refused, .withdrawn, .askedInSameInput, .notRequested:
                    guard segment.element.0.code == .adviceWithoutPermission else { throw TrainerFailure.invalidAnalysis }
                case .clientRequested, .unclear:
                    break
                }
            }

            switch entry.standing {
            case .granted, .pastSituation, .refused:
                guard let request = entry.request, let response = entry.response, entry.consumedBy == nil else {
                    throw TrainerFailure.invalidAnalysis
                }
                let consent = try anchored(response, speaker: .client)
                guard try consent > anchored(request, speaker: .counselor) else { throw TrainerFailure.invalidAnalysis }
                // Dieselbe Zustimmung trägt höchstens einen Ratschlag. Eine bereits
                // aufgebrauchte Zustimmung kann auch später nicht wieder erteilt sein.
                if entry.standing == .granted {
                    guard !spentConsents.contains(consent) else { throw TrainerFailure.invalidAnalysis }
                    spentConsents.append(consent)
                    grantingSegments.append((consent, segment.offset))
                }
            case .consumed:
                guard let request = entry.request, let response = entry.response, let used = entry.consumedBy else {
                    throw TrainerFailure.invalidAnalysis
                }
                let consent = try anchored(response, speaker: .client)
                guard try consent > anchored(request, speaker: .counselor) else { throw TrainerFailure.invalidAnalysis }
                // Der aufbrauchende Ratschlag liegt nach der Zustimmung und vor diesem hier —
                // entweder in einem früheren Beitrag oder weiter vorn im selben Beitrag.
                switch used.source {
                case .currentInput:
                    guard used.speaker == .counselor else { throw TrainerFailure.invalidAnalysis }
                    let earlier = try evidenceRange(used, input: input, context: context)
                    guard earlier.upperBound <= advice.lowerBound else { throw TrainerFailure.invalidAnalysis }
                    // Aufbrauchen kann nur ein Ratschlag. Eine vorangehende Frage oder
                    // Reflexion verbraucht keine Zustimmung, und der frühere Ratschlag muss
                    // im selben Beitrag genau diese Zustimmung genutzt haben.
                    guard let segmentBefore = zip(analysis.segments, ranges).enumerated().first(where: { item in
                        adviceCodes.contains(item.element.0.code)
                            && item.element.1.lowerBound <= earlier.lowerBound
                            && earlier.upperBound <= item.element.1.upperBound
                    }), segmentBefore.offset != segment.offset,
                          grantingSegments.contains(where: { $0.consent == consent && $0.segment == segmentBefore.offset }) else {
                        throw TrainerFailure.invalidAnalysis
                    }
                case .contextMessage:
                    // Frühere Beiträge liegen nur als Text vor; ihre Einordnung gehört zu
                    // ihrer eigenen Runde. Prüfbar bleibt hier die zeitliche Folge.
                    guard try anchored(used, speaker: .counselor) > consent else { throw TrainerFailure.invalidAnalysis }
                }
                if !spentConsents.contains(consent) { spentConsents.append(consent) }
            case .withdrawn:
                guard let response = entry.response, entry.consumedBy == nil else { throw TrainerFailure.invalidAnalysis }
                let withdrawal = try anchored(response, speaker: .client)
                if let request = entry.request {
                    guard try withdrawal > anchored(request, speaker: .counselor) else { throw TrainerFailure.invalidAnalysis }
                }
            case .askedInSameInput:
                // Die Frage steht im selben Beitrag vor dem Rat; eine Antwort kann es nicht geben.
                guard let request = entry.request, entry.response == nil, entry.consumedBy == nil,
                      request.source == .currentInput, request.speaker == .counselor,
                      try evidenceRange(request, input: input, context: context).upperBound <= advice.lowerBound else {
                    throw TrainerFailure.invalidAnalysis
                }
            case .clientRequested:
                guard let response = entry.response, entry.request == nil, entry.consumedBy == nil else {
                    throw TrainerFailure.invalidAnalysis
                }
                _ = try anchored(response, speaker: .client)
            case .notRequested, .unclear:
                guard entry.request == nil, entry.response == nil, entry.consumedBy == nil else {
                    throw TrainerFailure.invalidAnalysis
                }
            }
        }
        // Wer den neuen Vertrag benutzt, beantwortet ihn vollständig: Jeder Ratschlag dieses
        // Beitrags braucht eine Einschätzung. Eine leere Liste neben einem Ratschlag wäre
        // eine stille Enthaltung, die wie eine Entwarnung aussähe. Eine fehlende Liste
        // (`nil`) bleibt davon unberührt — das sind ältere Analysen ohne diesen Vertrag.
        for (index, segment) in analysis.segments.enumerated() where adviceCodes.contains(segment.code) {
            guard usedSegments.contains(index) else { throw TrainerFailure.invalidAnalysis }
        }
    }
}
