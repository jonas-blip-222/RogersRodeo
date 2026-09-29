import Foundation

// Rückmeldung an die übende Person (Documentation/MI-UEBERGABE.md, Abschnitt 7).
//
// Bewusst ohne jede Zahl. Der Offenheitswert misst die Bereitschaft der Figur, Persönliches
// zu erzählen, nicht die Qualität der Beratung (Abschnitt 5.3). Die Zahlenregel im Reducer
// ist ein als Entwurf gekennzeichneter Kalibrierungsversuch, und ihr Wiederholungsschutz
// unterdrückt beim zweiten Mal die Gutschrift für dieselbe gute Reflexion — als Punktzahl
// gelesen wäre das eine falsche Aussage über die Beratung. Deshalb erscheint hier weder
// Punktzahl noch Balken noch Note. Die Zahl bleibt der Entwicklerdiagnostik vorbehalten.
//
// Die Befunde entstehen deterministisch aus der bereits validierten `TurnAnalysis`.
// Kein Sprachmodell, keine Stichwortliste, keine Begründung aus der erst danach erzeugten
// Figurenantwort: eine zustimmende Figur beweist keine gute Beratung (Abschnitt 7.3).

/// Die drei Ausgaben aus Abschnitt 7.1 bleiben unterscheidbar. `suggestion` gehört zum
/// vorhandenen Tippbestand und wird von der FeedbackEngine nicht erzeugt; die Art steht
/// trotzdem im Vertrag, damit die Oberfläche die drei Dinge nicht vermischt.
public enum FeedbackKind: String, Codable, Sendable, CaseIterable {
    /// Unmittelbare Warnung zum gerade gesendeten Beitrag.
    case warning = "warnung"
    /// Rückmeldung darüber, was die Beratung in diesem Kontext getan hat.
    case observation = "rueckmeldung"
    /// Hinweis auf eine mögliche nächste Reaktion.
    case suggestion = "vorschlag"
}

/// Abschnitt 7.2: bei unklarer Bedeutung „Möglicher Druck …“ statt eines sicheren Vorwurfs.
public enum FeedbackCertainty: String, Codable, Sendable {
    case confirmed = "belegt"
    case possible = "moeglich"
}

/// Stabile Referenz auf eine tatsächlich berücksichtigte Textstelle. `DialogueMessage` trägt
/// heute keine eigene Kennung; die Referenz wird deshalb aus Herkunft, Sprecher, Position im
/// tatsächlich verwendeten Kontext und dem Vorkommen innerhalb dieser Nachricht gebildet.
/// Zitate werden nie paraphrasiert, sondern wörtlich übernommen und gegengeprüft.
public struct EvidenceReference: Codable, Sendable, Equatable {
    public enum Source: String, Codable, Sendable {
        /// Der Beitrag, der gerade gesendet wurde.
        case currentInput = "aktuelle_eingabe"
        /// Eine Nachricht aus dem Kontext, der der Analyse tatsächlich vorlag.
        case contextMessage = "kontextnachricht"
    }
    public var source: Source
    public var speaker: Speaker
    /// Position im verwendeten Kontext. Bei `currentInput` immer nil.
    public var messageIndex: Int?
    public var quote: String
    /// 1-basiertes Vorkommen des Zitats innerhalb der bezeichneten Nachricht.
    public var occurrence: Int
    public init(source: Source, speaker: Speaker, messageIndex: Int?, quote: String, occurrence: Int) {
        self.source = source; self.speaker = speaker; self.messageIndex = messageIndex
        self.quote = quote; self.occurrence = occurrence
    }
}

/// Ein einzelner Befund mit Regelkennung, Art, Unsicherheit, Belegen und den verwendeten
/// Versionen (Abschnitt 7.3 und 9.2). `reviewStatus` bleibt `.draft`, solange die fachliche
/// Prüfung der Formulierungen aussteht; die Oberfläche muss das kenntlich halten.
public struct FeedbackFinding: Codable, Sendable, Equatable {
    public var ruleID: String
    public var kind: FeedbackKind
    public var certainty: FeedbackCertainty
    public var title: String
    public var message: String
    public var evidence: [EvidenceReference]
    /// Version des Textbausteins, aus dem `message` entstanden ist.
    public var templateVersion: String
    /// Regelstand der Sitzung, unter dem der Befund entstanden ist.
    public var rulesVersion: String
    public var sourceID: String
    public var reviewStatus: ContentStatus
    public init(ruleID: String, kind: FeedbackKind, certainty: FeedbackCertainty, title: String,
                message: String, evidence: [EvidenceReference], templateVersion: String,
                rulesVersion: String, sourceID: String, reviewStatus: ContentStatus) {
        self.ruleID = ruleID; self.kind = kind; self.certainty = certainty; self.title = title
        self.message = message; self.evidence = evidence; self.templateVersion = templateVersion
        self.rulesVersion = rulesVersion; self.sourceID = sourceID; self.reviewStatus = reviewStatus
    }
}

/// Vorläufige Rückmeldung zu genau einem Ausführungsversuch. Noch kein gespeicherter Turn
/// (Abschnitt 9.3): Sie ist an Sitzung, PendingTurn, erwartete Revision und die Generation
/// des Versuchs gebunden, damit ein spätes Ergebnis nicht einem neuen Beitrag zufällt.
public struct PreliminaryFeedback: Sendable, Equatable {
    public var sessionID: UUID
    public var turnID: UUID
    public var expectedRevision: Int
    /// Generation des Ausführungsversuchs im Coordinator.
    public var attempt: UUID
    public var input: String
    /// Falsch, wenn keine Analyse vorliegt. Dann ist das ausdrücklich keine Entwarnung.
    public var analysisAvailable: Bool
    public var findings: [FeedbackFinding]
    public init(sessionID: UUID, turnID: UUID, expectedRevision: Int, attempt: UUID,
                input: String, analysisAvailable: Bool, findings: [FeedbackFinding]) {
        self.sessionID = sessionID; self.turnID = turnID; self.expectedRevision = expectedRevision
        self.attempt = attempt; self.input = input; self.analysisAvailable = analysisAvailable
        self.findings = findings
    }
}

/// Kanal für die frühe Anzeige. Bewusst ein Rückruf und kein zweiter Modelllauf.
public typealias FeedbackSink = @Sendable (PreliminaryFeedback) async -> Void

/// Versionierter Textbaustein. Die Formulierung ist Inhalt, nicht Programmlogik, und wird
/// nur mit wörtlichen Gesprächszitaten gefüllt. Kein freier Modelltext.
public struct FeedbackTemplate: Sendable, Equatable {
    public let ruleID: String
    public let kind: FeedbackKind
    public let certainty: FeedbackCertainty
    public let title: String
    /// Platzhalter: `{figur}`, `{zitat}` für die Stelle im eigenen Beitrag,
    /// `{beleg}` für das Klientenzitat.
    public let format: String
    public let sourceID: String

    public func render(character: String, quote: String, support: String?) -> String {
        format.replacingOccurrences(of: "{figur}", with: character)
            .replacingOccurrences(of: "{zitat}", with: quote)
            .replacingOccurrences(of: "{beleg}", with: support ?? "")
    }
}

/// Der Bestand der Textbausteine. Eigene Version, damit eine Formulierungsänderung nicht die
/// `rulesVersion` der Sitzung anfassen muss — die entscheidet über die Fortsetzbarkeit.
public enum FeedbackTemplates {
    public static let version = "0.3"

    /// Fachlicher Entwurf. Formulierungen sind an Abschnitt 7.1 angelehnt und noch nicht
    /// fachlich geprüft; Quellenkennungen verweisen auf Abschnitt 14 des MI-Nachtrags; E04 auf die Produktentscheidung.
    public static let all: [FeedbackTemplate] = [
        .init(ruleID: "rueckmeldung.doppelseitige_reflexion", kind: .observation, certainty: .confirmed,
              title: "Doppelseitige Reflexion",
              format: "Gut angeordnet: Du greifst zuerst auf, was für das Beibehalten spricht, und danach die Gründe für Veränderung. So steht der Change Talk am Ende deiner Reflexion: „{zitat}“.",
              sourceID: "E04"),
        .init(ruleID: "warnung.konfrontation", kind: .warning, certainty: .confirmed,
              title: "Konfrontation",
              format: "„{zitat}“ setzt {figur} unter Druck, statt an das Gesagte anzuknüpfen.",
              sourceID: "S3"),
        .init(ruleID: "warnung.konfrontation", kind: .warning, certainty: .possible,
              title: "Möglicher Druck",
              format: "„{zitat}“ könnte als Vorwurf ankommen. Diese Stelle ist unsicher eingeordnet.",
              sourceID: "S3"),
        .init(ruleID: "warnung.rat_ohne_erlaubnis", kind: .warning, certainty: .confirmed,
              title: "Rat ohne Erlaubnis",
              format: "Mit „{zitat}“ gibst du einen Rat, ohne dass {figur} vorher zugestimmt hat.",
              sourceID: "S3"),
        .init(ruleID: "warnung.rat_ohne_erlaubnis", kind: .warning, certainty: .possible,
              title: "Möglicher Rat ohne Erlaubnis",
              format: "„{zitat}“ wirkt wie ein Rat. Ob dafür eine Erlaubnis vorliegt, ist unsicher.",
              sourceID: "S3"),
        // Erlaubnis: ein Ja trägt genau einen Ratschlag in genau dieser Situation.
        // Alle Formulierungen sind Entwurf und fachlich ungeprüft.
        .init(ruleID: "rueckmeldung.rat_mit_erlaubnis", kind: .observation, certainty: .confirmed,
              title: "Rat mit Erlaubnis",
              format: "Du hast vorher gefragt, {figur} hat mit „{beleg}“ zugestimmt, und „{zitat}“ ist der eine Vorschlag dazu.",
              sourceID: "S3"),
        .init(ruleID: "rueckmeldung.rat_auf_bitte", kind: .observation, certainty: .confirmed,
              title: "Vorschlag auf Bitte",
              format: "{figur} hat mit „{beleg}“ selbst um einen Vorschlag gebeten. „{zitat}“ kommt damit nicht unaufgefordert.",
              sourceID: "S3"),
        .init(ruleID: "warnung.erlaubnis_nicht_abgewartet", kind: .warning, certainty: .confirmed,
              title: "Antwort nicht abgewartet",
              format: "Du fragst mit „{beleg}“ um Erlaubnis und gibst den Rat „{zitat}“ noch vor der Antwort von {figur}.",
              sourceID: "S3"),
        .init(ruleID: "warnung.rat_trotz_ablehnung", kind: .warning, certainty: .confirmed,
              title: "Rat trotz Ablehnung",
              format: "{figur} hat mit „{beleg}“ abgelehnt. „{zitat}“ gibt den Rat trotzdem.",
              sourceID: "S3"),
        .init(ruleID: "warnung.rat_nach_widerruf", kind: .warning, certainty: .confirmed,
              title: "Rat nach Widerruf",
              format: "{figur} hat die Zustimmung mit „{beleg}“ zurückgenommen. „{zitat}“ knüpft trotzdem daran an.",
              sourceID: "S3"),
        .init(ruleID: "warnung.erlaubnis_bereits_verbraucht", kind: .warning, certainty: .confirmed,
              title: "Zustimmung schon genutzt",
              format: "Die Zustimmung „{beleg}“ galt für einen Vorschlag, den du schon gegeben hast. Für „{zitat}“ brauchst du eine neue Frage und eine neue Antwort.",
              sourceID: "S3"),
        .init(ruleID: "warnung.erlaubnis_aus_frueherer_situation", kind: .warning, certainty: .confirmed,
              title: "Zustimmung aus früherer Situation",
              format: "„{beleg}“ gehört zu einer früheren Stelle im Gespräch. Für „{zitat}“ gilt sie hier nicht weiter.",
              sourceID: "S3"),
        .init(ruleID: "rueckmeldung.komplexe_reflexion", kind: .observation, certainty: .confirmed,
              title: "Komplexe Reflexion",
              format: "Deine Reflexion „{zitat}“ greift auf, was {figur} gesagt hat: „{beleg}“.",
              sourceID: "S2"),
        .init(ruleID: "rueckmeldung.wuerdigung", kind: .observation, certainty: .confirmed,
              title: "Würdigung",
              format: "Du würdigst mit „{zitat}“ etwas, das {figur} selbst berichtet hat: „{beleg}“.",
              sourceID: "S2"),
        .init(ruleID: "rueckmeldung.autonomie_betonen", kind: .observation, certainty: .confirmed,
              title: "Autonomie",
              format: "Mit „{zitat}“ lässt du die Entscheidung bei {figur}.",
              sourceID: "S2"),
        .init(ruleID: "rueckmeldung.zusammenarbeit_suchen", kind: .observation, certainty: .confirmed,
              title: "Zusammenarbeit",
              format: "Mit „{zitat}“ suchst du die Zusammenarbeit, statt die Richtung vorzugeben.",
              sourceID: "S2")
    ]

    public static func template(_ ruleID: String, _ certainty: FeedbackCertainty) -> FeedbackTemplate? {
        all.first { $0.ruleID == ruleID && $0.certainty == certainty }
    }
}

/// Deterministische Ableitung der Befunde. Arbeitet ausschließlich auf der bereits
/// validierten Analyse des gesendeten Beitrags und dem Kontext, der dieser Analyse
/// tatsächlich vorlag. Kein Zugriff auf die Figurenantwort, keinen Zustand, keine
/// Offenheit: derselbe Beitrag ergibt beim zweiten Mal dieselbe Rückmeldung.
public enum FeedbackEngine {
    /// Regelkennung je Code. Nur diese sechs Codes erzeugen heute eine Rückmeldung.
    static let warningRules: [(CounselorCode, String)] = [
        (.confrontation, "warnung.konfrontation"),
        (.adviceWithoutPermission, "warnung.rat_ohne_erlaubnis")
    ]
    static let observationRules: [(CounselorCode, String)] = [
        (.complexReflection, "rueckmeldung.komplexe_reflexion"),
        (.affirmation, "rueckmeldung.wuerdigung"),
        (.autonomy, "rueckmeldung.autonomie_betonen"),
        (.collaboration, "rueckmeldung.zusammenarbeit_suchen")
    ]
    /// Höchstens so viele positive Rückmeldungen je Runde, damit die Fläche kurz bleibt.
    static let observationLimit = 2

    public static func findings(analysis: TurnAnalysis?, input: String, context: [DialogueMessage],
                                characterName: String, rulesVersion: String,
                                permission: PermissionReport = .unavailable) -> [FeedbackFinding] {
        // Ohne Analyse gibt es keinen Befund — und ausdrücklich auch keine Entwarnung.
        // Den Unterschied trägt `PreliminaryFeedback.analysisAvailable` in die Oberfläche.
        guard let analysis, !analysis.segments.isEmpty,
              let ranges = try? OutputValidator.locations(analysis, input: input) else { return [] }
        let placed = Array(zip(analysis.segments, ranges))
        let doubleSided = doubleSidedFinding(analysis, input: input, context: context,
                                           characterName: characterName, rulesVersion: rulesVersion)

        var results: [(position: String.Index, finding: FeedbackFinding)] = []

        // Ratschläge mit eigener, belegter Erlaubniseinschätzung zuerst: Ihr Befund ersetzt
        // die allgemeine Warnung aus dem bloßen Segmentcode für dasselbe Segment.
        let assessed = permissionFindings(permission, placed: placed, input: input, context: context,
                                          characterName: characterName, rulesVersion: rulesVersion)
        results += assessed.results

        for (code, ruleID) in warningRules {
            // Ein sicherer Befund schlägt den unsicheren: sonst stünde „Möglicher Druck“
            // neben derselben, bereits belegten Warnung.
            let open = placed.enumerated().filter { $0.element.0.code == code && !assessed.covered.contains($0.offset) }
            guard let candidate = (open.first { !$0.element.0.isUncertain } ?? open.first)?.element else { continue }
            // Ohne Erlaubniseinschätzung und ohne vollständigen Kontext bleibt offen, ob
            // eine frühere Zustimmung außerhalb des Fensters liegt: dann kein sicherer Vorwurf.
            let unsureContext = code == .adviceWithoutPermission && !permission.contextIsComplete
            let certainty: FeedbackCertainty = candidate.0.isUncertain || unsureContext ? .possible : .confirmed
            guard let finding = build(segment: candidate.0, range: candidate.1, ruleID: ruleID,
                                      certainty: certainty, requiresSupport: false, input: input,
                                      context: context, characterName: characterName,
                                      rulesVersion: rulesVersion) else { continue }
            results.append((candidate.1.lowerBound, finding))
        }

        var observations: [(position: String.Index, finding: FeedbackFinding)] = []
        for (code, ruleID) in observationRules {
            // Das spezifische Lob ersetzt das allgemeine Reflexionslob dieser Runde.
            if doubleSided != nil && code == .complexReflection { continue }
            // Nur belegte, sichere Segmente. Eine elegante Satzform allein beweist weder
            // Empathie noch eine zutreffende komplexe Reflexion (Abschnitt 4.3).
            guard let candidate = placed.first(where: { $0.0.code == code && !$0.0.isUncertain }) else { continue }
            let needsSupport = code == .complexReflection || code == .affirmation
            guard let finding = build(segment: candidate.0, range: candidate.1, ruleID: ruleID,
                                      certainty: .confirmed, requiresSupport: needsSupport, input: input,
                                      context: context, characterName: characterName,
                                      rulesVersion: rulesVersion) else { continue }
            observations.append((candidate.1.lowerBound, finding))
        }
        observations.sort { $0.position < $1.position }
        if let doubleSided {
            // Die ausdrücklich gewünschte Reihenfolge darf nicht durch das Anzeigelimit verschwinden.
            results.append(doubleSided)
        }
        // Belegte Erlaubnis und doppelseitige Reflexion sind die spezifischeren Rückmeldungen
        // und zählen gegen dasselbe knappe Anzeigebudget.
        let reserved = (doubleSided == nil ? 0 : 1) + assessed.results.filter { $0.finding.kind == .observation }.count
        results += observations.prefix(max(0, observationLimit - reserved))

        // Warnungen zuerst, innerhalb einer Art in der Reihenfolge des eigenen Beitrags.
        return results.sorted { left, right in
            let leftWarning = left.finding.kind == .warning, rightWarning = right.finding.kind == .warning
            if leftWarning != rightWarning { return leftWarning }
            return left.position < right.position
        }.map(\.finding)
    }

    /// Ein Befund je belegter Erlaubniseinschätzung. Die Zuordnung Lage → Textbaustein ist
    /// die einzige Stelle, an der aus der semantischen Einschätzung eine Aussage wird; sie
    /// ist bewusst vollständig und ohne Auffangzweig geschrieben.
    ///
    /// Unsicherheit — ob vom Modell gemeldet oder von `PermissionTracker` ergänzt — führt
    /// immer in dieselbe zurückhaltende Formulierung: weder Lob noch Vorwurf. Genauso wird
    /// aus einer fehlenden Erlaubnisfrage nur dann ein sicherer Befund, wenn der Analyse das
    /// ganze bisherige Gespräch vorlag. Eine Kontextlücke bleibt eine Lücke.
    private static func permissionFindings(_ report: PermissionReport,
                                           placed: [(AnalysisSegment, Range<String.Index>)],
                                           input: String, context: [DialogueMessage],
                                           characterName: String, rulesVersion: String)
        -> (covered: Set<Int>, results: [(position: String.Index, finding: FeedbackFinding)]) {
        var covered: Set<Int> = []
        var results: [(position: String.Index, finding: FeedbackFinding)] = []
        for entry in report.entries {
            let assessment = entry.assessment
            guard let advice = try? OutputValidator.evidenceRange(assessment.advice, input: input, context: context),
                  let segment = placed.enumerated().first(where: { item in
                      [.adviceWithPermission, .adviceWithoutPermission].contains(item.element.0.code)
                          && item.element.1.lowerBound <= advice.lowerBound
                          && advice.upperBound <= item.element.1.upperBound
                  }) else { continue }

            let rule: (id: String, certainty: FeedbackCertainty, support: EvidenceReference?)
            if entry.isUncertain || segment.element.0.isUncertain {
                rule = ("warnung.rat_ohne_erlaubnis", .possible, nil)
            } else {
                switch entry.standing {
                case .granted:
                    rule = ("rueckmeldung.rat_mit_erlaubnis", .confirmed, assessment.response)
                case .clientRequested:
                    rule = ("rueckmeldung.rat_auf_bitte", .confirmed, assessment.response)
                case .askedInSameInput:
                    rule = ("warnung.erlaubnis_nicht_abgewartet", .confirmed, assessment.request)
                case .refused:
                    rule = ("warnung.rat_trotz_ablehnung", .confirmed, assessment.response)
                case .withdrawn:
                    rule = ("warnung.rat_nach_widerruf", .confirmed, assessment.response)
                case .consumed:
                    rule = ("warnung.erlaubnis_bereits_verbraucht", .confirmed, assessment.response)
                case .pastSituation:
                    rule = ("warnung.erlaubnis_aus_frueherer_situation", .confirmed, assessment.response)
                case .notRequested:
                    rule = ("warnung.rat_ohne_erlaubnis", report.contextIsComplete ? .confirmed : .possible, nil)
                case .unclear:
                    rule = ("warnung.rat_ohne_erlaubnis", .possible, nil)
                }
            }
            guard let template = FeedbackTemplates.template(rule.id, rule.certainty) else { continue }
            // Jede Aussage der Formulierung muss belegt sein: „Du hast vorher gefragt“
            // trägt deshalb auch die Erlaubnisfrage, nicht nur die Zustimmung. Nur bei den
            // zurückhaltenden Formulierungen ohne Bezug bleibt es beim eigenen Zitat.
            let cited: [EvidenceReference?] = rule.support == nil
                ? [] : [assessment.request, assessment.response, assessment.consumedBy]
            let evidence = [assessment.advice] + cited.compactMap { $0 }
            // Gegenprobe gegen die tatsächlich übergebenen Texte: ein erfundener oder falsch
            // verorteter Beleg lässt den Befund entfallen, statt ihn zu tragen.
            guard evidence.allSatisfy({
                (try? OutputValidator.validateEvidence($0, input: input, context: context)) != nil
            }) else { continue }
            covered.insert(segment.offset)
            results.append((advice.lowerBound, .init(
                ruleID: template.ruleID, kind: template.kind, certainty: rule.certainty, title: template.title,
                message: template.render(character: characterName, quote: assessment.advice.quote,
                                         support: rule.support?.quote),
                evidence: evidence, templateVersion: FeedbackTemplates.version, rulesVersion: rulesVersion,
                sourceID: template.sourceID, reviewStatus: .draft)))
        }
        return (covered, results)
    }

    private static func doubleSidedFinding(_ analysis: TurnAnalysis, input: String,
                                            context: [DialogueMessage], characterName: String,
                                            rulesVersion: String) -> (position: String.Index, finding: FeedbackFinding)? {
        guard let pair = analysis.doubleSidedReflection, !pair.isUncertain,
              (try? OutputValidator.validateAnalysis(analysis, input: input, context: context)) != nil,
              let sustain = try? OutputValidator.evidenceRange(pair.sustain.input, input: input, context: context),
              let change = try? OutputValidator.evidenceRange(pair.change.input, input: input, context: context),
              sustain.upperBound <= change.lowerBound,
              let ranges = try? OutputValidator.locations(analysis, input: input),
              !zip(analysis.segments, ranges).contains(where: { segment, range in
                  (range.overlaps(sustain) || range.overlaps(change)) && segment.isUncertain
              }),
              let template = FeedbackTemplates.template("rueckmeldung.doppelseitige_reflexion", .confirmed)
        else { return nil }
        let quote = String(input[sustain.lowerBound..<change.upperBound])
        return (sustain.lowerBound, .init(ruleID: template.ruleID, kind: .observation, certainty: .confirmed,
            title: template.title, message: template.render(character: characterName, quote: quote, support: nil),
            evidence: [pair.sustain.input, pair.sustain.client, pair.change.input, pair.change.client],
            templateVersion: FeedbackTemplates.version, rulesVersion: rulesVersion,
            sourceID: template.sourceID, reviewStatus: .draft))
    }

    private static func build(segment: AnalysisSegment, range: Range<String.Index>, ruleID: String,
                              certainty: FeedbackCertainty, requiresSupport: Bool, input: String,
                              context: [DialogueMessage], characterName: String,
                              rulesVersion: String) -> FeedbackFinding? {
        guard let template = FeedbackTemplates.template(ruleID, certainty) else { return nil }
        var evidence = [EvidenceReference(source: .currentInput, speaker: .counselor, messageIndex: nil,
                                          quote: segment.quote,
                                          occurrence: occurrence(of: segment.quote, endingAt: range.upperBound, in: input))]
        var support: String?
        if let quote = segment.supportingClientQuote,
           let index = context.firstIndex(where: { $0.speaker == .client && $0.text.range(of: quote, options: .literal) != nil }) {
            support = quote
            evidence.append(.init(source: .contextMessage, speaker: .client, messageIndex: index,
                                  quote: quote, occurrence: 1))
        }
        // Ohne Klientenbeleg keine positive Rückmeldung für Reflexion und Würdigung.
        if requiresSupport, support == nil { return nil }
        // Gegenprobe gegen die tatsächlich übergebenen Texte. Ein Befund ohne haltbaren
        // Beleg wird verworfen statt angezeigt.
        for reference in evidence {
            guard (try? OutputValidator.validateEvidence(reference, input: input, context: context)) != nil else { return nil }
        }
        return FeedbackFinding(ruleID: ruleID, kind: template.kind, certainty: certainty,
                               title: template.title,
                               message: template.render(character: characterName, quote: segment.quote, support: support),
                               evidence: evidence, templateVersion: FeedbackTemplates.version,
                               rulesVersion: rulesVersion, sourceID: template.sourceID,
                               reviewStatus: .draft)
    }

    /// Das wievielte wörtliche Vorkommen des Zitats an dieser Stelle endet.
    static func occurrence(of quote: String, endingAt upper: String.Index, in text: String) -> Int {
        var count = 0
        var cursor = text.startIndex
        while let found = text.range(of: quote, options: .literal, range: cursor..<text.endIndex),
              found.upperBound <= upper {
            count += 1
            cursor = found.upperBound
        }
        return max(count, 1)
    }
}
