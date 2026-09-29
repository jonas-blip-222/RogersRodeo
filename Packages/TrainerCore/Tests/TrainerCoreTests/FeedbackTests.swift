import Foundation
import Testing
@testable import TrainerCore

// Prüfungen zur Rückmeldung an die übende Person.
//
// Die Fälle stammen aus Documentation/MI-UEBERGABE.md, Abschnitt 8, beziehungsweise aus
// Evaluation/mi-faelle.json. Sie sind fachliche Arbeitsentwürfe und ausdrücklich keine
// geprüfte Goldreferenz: geprüft wird hier die deterministische Ableitung aus einer bereits
// validierten Analyse, nicht die fachliche Richtigkeit der Einordnung selbst.
//
// Die Analysen der Fixtures sind von Hand gesetzt, weil in MI-01 noch kein Modell geprüft
// ist. Ihre Zitate müssen wörtlich und in Reihenfolge in der Eingabe vorkommen, sonst weist
// `OutputValidator.locations` sie zurück — genau wie eine echte Modellausgabe.

private let figur = "Lukas"

private func befunde(_ analysis: TurnAnalysis?, _ input: String,
                     _ context: [String] = [], counselorContext: [DialogueMessage] = []) -> [FeedbackFinding] {
    let messages = context.map { DialogueMessage(speaker: .client, text: $0) } + counselorContext
    return FeedbackEngine.findings(analysis: analysis, input: input, context: messages,
                                   characterName: figur, rulesVersion: "0.1")
}

// MARK: - Warnungen

@Test func fall05KonfrontationWarntMitDemAusloesendenZitat() throws {
    let eingabe = "Wenn Ihnen Sarah wirklich wichtig wäre, würden Sie endlich mit dem Trinken aufhören."
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Wenn Ihnen Sarah wirklich wichtig wäre", code: .confrontation, isUncertain: false)])
    let findings = befunde(analyse, eingabe, ["Sarah ist mir wichtig. Aber ich will mir auch nicht jedes Wochenende vorschreiben lassen."])
    let warnung = try #require(findings.first)
    #expect(findings.count == 1)
    #expect(warnung.kind == .warning)
    #expect(warnung.ruleID == "warnung.konfrontation")
    #expect(warnung.certainty == .confirmed)
    // Die Warnung trägt das auslösende Zitat wörtlich, nicht umschrieben.
    #expect(warnung.message.contains("Wenn Ihnen Sarah wirklich wichtig wäre"))
    #expect(warnung.evidence.first?.source == .currentInput)
    #expect(warnung.reviewStatus == .draft)
}

@Test func fall04RatOhneErlaubnisWarntUndMitErlaubnisNicht() throws {
    let eingabe = "Sie könnten kurz notieren, was Ihnen bei Ihrem Versuch geholfen hat und was schwierig war."
    let kontext = ["Ich weiß nicht, wie ich beim nächsten Mal sagen soll, was daran geholfen hat."]

    // Variante B: kein Erlaubnisbeleg im vollständig bekannten Austausch.
    let ohne = befunde(TurnAnalysis(segments: [.init(quote: eingabe, code: .adviceWithoutPermission, isUncertain: false)]),
                       eingabe, kontext)
    #expect(ohne.map(\.ruleID) == ["warnung.rat_ohne_erlaubnis"])
    #expect(ohne.first?.certainty == .confirmed)

    // Variante A: Erlaubnis liegt vor, der Code ist ein anderer — keine Warnung.
    let mit = befunde(TurnAnalysis(segments: [.init(quote: eingabe, code: .adviceWithPermission, isUncertain: false)]),
                      eingabe, kontext)
    #expect(mit.isEmpty)
}

@Test func fall10ScheinbareErlaubnisWarntTrotzVorangehenderFrage() throws {
    // Erlaubnisfrage liegt vor, die Zustimmung fehlt. Die Frage im ersten Satz erteilt die
    // Erlaubnis nicht; die Warnung bezieht sich genau auf den zweiten Satz.
    let eingabe = "Darf ich Ihnen einen Tipp geben? Sie sollten Ihre Freunde am Wochenende einfach nicht mehr treffen."
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Darf ich Ihnen einen Tipp geben?", code: .closedQuestion, isUncertain: false),
        .init(quote: "Sie sollten Ihre Freunde am Wochenende einfach nicht mehr treffen.",
              code: .adviceWithoutPermission, isUncertain: false)])
    let findings = befunde(analyse, eingabe, ["Freitags läuft das halt immer gleich ab."])
    let warnung = try #require(findings.first)
    #expect(findings.count == 1)
    #expect(warnung.message.contains("Sie sollten Ihre Freunde am Wochenende einfach nicht mehr treffen."))
    #expect(!warnung.message.contains("Darf ich Ihnen einen Tipp geben?"))
}

@Test func fall06UnsicheresSegmentWirdVorsichtigFormuliert() throws {
    // Bei fachlicher Überlappung darf kein sicherer Vorwurf entstehen. Eine unsicher
    // eingeordnete Stelle bekommt „Möglicher …“ statt einer festen Zuschreibung.
    let eingabe = "Dann legen wir jetzt fest, dass Sie ab Freitag nicht mehr mit Ihren Freunden trinken gehen."
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Dann legen wir jetzt fest", code: .adviceWithoutPermission, isUncertain: true)])
    let findings = befunde(analyse, eingabe, ["Die Filmrisse machen mir schon Gedanken. Aber ich weiß nicht, ob ich deswegen meine Wochenenden komplett ändern will."])
    let warnung = try #require(findings.first)
    #expect(warnung.certainty == .possible)
    #expect(warnung.title == "Möglicher Rat ohne Erlaubnis")
    #expect(warnung.message.contains("unsicher"))
    #expect(warnung.message.contains("Dann legen wir jetzt fest"))
}

@Test func sichererBefundVerdraengtDenUnsicherenZumSelbenCode() throws {
    let eingabe = "Das müssen Sie ändern. Wenn Ihnen Sarah wirklich wichtig wäre, würden Sie aufhören."
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Das müssen Sie ändern.", code: .confrontation, isUncertain: true),
        .init(quote: "Wenn Ihnen Sarah wirklich wichtig wäre", code: .confrontation, isUncertain: false)])
    let findings = befunde(analyse, eingabe)
    #expect(findings.count == 1)
    #expect(findings.first?.certainty == .confirmed)
}

// MARK: - Positive Rückmeldung

@Test func fall01AutonomieErzeugtRueckmeldungOhneZahl() throws {
    let eingabe = "Sie entscheiden selbst, ob Sie etwas verändern möchten. Was stört Sie daran, heute hier zu sein?"
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Sie entscheiden selbst, ob Sie etwas verändern möchten.", code: .autonomy, isUncertain: false),
        .init(quote: "Was stört Sie daran, heute hier zu sein?", code: .openQuestion, isUncertain: false)])
    let findings = befunde(analyse, eingabe, ["Sarah hat gesagt, ich soll hierher. Ich finde das völlig übertrieben."])
    let rueckmeldung = try #require(findings.first)
    #expect(findings.count == 1)
    #expect(rueckmeldung.kind == .observation)
    #expect(rueckmeldung.ruleID == "rueckmeldung.autonomie_betonen")
    #expect(rueckmeldung.message.contains("Sie entscheiden selbst, ob Sie etwas verändern möchten."))
    #expect(rueckmeldung.message.contains("Lukas"))
}

@Test func komplexeReflexionNurMitBelegAusEinerEchtenKlientennachricht() throws {
    let kontext = ["Ich würde schon gern weniger trinken. Ich möchte die Sonntage wieder mitkriegen."]
    let eingabe = "Ihnen fehlt etwas, das Ihnen wichtig ist."
    let beleg = "Ich möchte die Sonntage wieder mitkriegen"

    let mitBeleg = befunde(TurnAnalysis(segments: [
        .init(quote: eingabe, code: .complexReflection, isUncertain: false, supportingClientQuote: beleg)]),
        eingabe, kontext)
    let finding = try #require(mitBeleg.first)
    #expect(finding.ruleID == "rueckmeldung.komplexe_reflexion")
    // Vorbild aus Abschnitt 7.1: die Rückmeldung nennt, was aufgegriffen wurde — wörtlich.
    #expect(finding.message.contains(beleg))
    #expect(finding.evidence.count == 2)
    #expect(finding.evidence.last?.speaker == .client)
    #expect(finding.evidence.last?.source == .contextMessage)

    // Ohne Klientenbeleg gibt es kein Lob: eine elegante Satzform allein beweist nichts.
    let ohneBeleg = befunde(TurnAnalysis(segments: [
        .init(quote: eingabe, code: .complexReflection, isUncertain: false)]), eingabe, kontext)
    #expect(ohneBeleg.isEmpty)
}

@Test func fall12UnsichereVermutungBekommtKeinLob() {
    // „keine positive komplexe Reflexion nur wegen der Formulierung gutschreiben“.
    let eingabe = "Sie wollen gerade lieber nicht hier sein."
    let analyse = TurnAnalysis(segments: [
        .init(quote: eingabe, code: .complexReflection, isUncertain: true, supportingClientQuote: nil)])
    #expect(befunde(analyse, eingabe).isEmpty)
}

@Test func hoechstensZweiPositiveRueckmeldungenJeRunde() throws {
    let kontext = ["Im Urlaub habe ich zwei Wochen fast nichts getrunken."]
    let eingabe = "Sie haben im Urlaub etwas geschafft. Sie entscheiden selbst, wie es weitergeht. Wir könnten das zusammen anschauen."
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Sie haben im Urlaub etwas geschafft.", code: .affirmation, isUncertain: false,
              supportingClientQuote: "Im Urlaub habe ich zwei Wochen fast nichts getrunken."),
        .init(quote: "Sie entscheiden selbst, wie es weitergeht.", code: .autonomy, isUncertain: false),
        .init(quote: "Wir könnten das zusammen anschauen.", code: .collaboration, isUncertain: false)])
    let findings = befunde(analyse, eingabe, kontext)
    #expect(findings.count == 2)
    // In der Reihenfolge des eigenen Beitrags, damit die Rückmeldung nachvollziehbar bleibt.
    #expect(findings.map(\.ruleID) == ["rueckmeldung.wuerdigung", "rueckmeldung.autonomie_betonen"])
}

@Test func warnungStehtVorDerPositivenRueckmeldung() throws {
    let eingabe = "Sie entscheiden selbst. Wenn Ihnen Sarah wichtig wäre, würden Sie aufhören."
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Sie entscheiden selbst.", code: .autonomy, isUncertain: false),
        .init(quote: "Wenn Ihnen Sarah wichtig wäre", code: .confrontation, isUncertain: false)])
    let findings = befunde(analyse, eingabe)
    #expect(findings.map(\.kind) == [.warning, .observation])
}

// MARK: - Grenzen

@Test func ohneAnalyseGibtEsKeinenBefundUndKeineEntwarnung() {
    // Ein leeres Ergebnis heißt „nichts erhoben“. Die Aussage „keine Entwarnung“ trägt
    // `PreliminaryFeedback.analysisAvailable`; der Motor selbst behauptet nichts.
    #expect(befunde(nil, "Sie entscheiden selbst.").isEmpty)
    #expect(befunde(TurnAnalysis(segments: []), "Sie entscheiden selbst.").isEmpty)
}

@Test func erfundeneZitateErzeugenKeinenBefund() {
    // Die Analyse selbst wäre hier ungültig; der Motor darf daraus trotzdem nichts bauen.
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Das habe ich nie gesagt", code: .confrontation, isUncertain: false)])
    #expect(befunde(analyse, "Sie entscheiden selbst.").isEmpty)
}

@Test func belegOhneEchteFundstelleWirdAbgewiesen() {
    let kontext = [DialogueMessage(speaker: .client, text: "Ich weiß nicht.")]
    let echt = EvidenceReference(source: .contextMessage, speaker: .client, messageIndex: 0,
                                 quote: "Ich weiß nicht.", occurrence: 1)
    #expect(throws: Never.self) { try OutputValidator.validateEvidence(echt, input: "Egal", context: kontext) }

    // Paraphrase statt Zitat.
    let erfunden = EvidenceReference(source: .contextMessage, speaker: .client, messageIndex: 0,
                                     quote: "Ich bin unsicher.", occurrence: 1)
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateEvidence(erfunden, input: "Egal", context: kontext)
    }
    // Falscher Sprecher, falscher Index, Vorkommen, das es nicht gibt.
    for falsch in [EvidenceReference(source: .contextMessage, speaker: .counselor, messageIndex: 0, quote: "Ich weiß nicht.", occurrence: 1),
                   EvidenceReference(source: .contextMessage, speaker: .client, messageIndex: 7, quote: "Ich weiß nicht.", occurrence: 1),
                   EvidenceReference(source: .contextMessage, speaker: .client, messageIndex: 0, quote: "Ich weiß nicht.", occurrence: 2),
                   EvidenceReference(source: .currentInput, speaker: .client, messageIndex: nil, quote: "Egal", occurrence: 1)] {
        #expect(throws: TrainerFailure.invalidAnalysis) {
            try OutputValidator.validateEvidence(falsch, input: "Egal", context: kontext)
        }
    }
}

@Test func mehrfachesZitatBekommtDasRichtigeVorkommen() throws {
    let eingabe = "Sie müssen. Sie müssen."
    let analyse = TurnAnalysis(segments: [
        .init(quote: "Sie müssen.", code: .other, isUncertain: false),
        .init(quote: "Sie müssen.", code: .confrontation, isUncertain: false)])
    let finding = try #require(befunde(analyse, eingabe).first)
    let beleg = try #require(finding.evidence.first)
    // Der Befund gehört zum zweiten Vorkommen, nicht zum ersten.
    #expect(beleg.occurrence == 2)
    #expect(throws: Never.self) { try OutputValidator.validateEvidence(beleg, input: eingabe, context: []) }
}

@Test func keineRueckmeldungEnthaeltEinePunktzahl() {
    // Jonas' Produktentscheidung: kurze Rückmeldung in Worten, keine Zahl, kein Balken,
    // keine Note. Diese Prüfung hält das für alle Bausteine fest.
    for template in FeedbackTemplates.all {
        let text = template.render(character: "Lukas", quote: "Zitat", support: "Beleg")
        let ziffern = text.filter(\.isNumber)
        #expect(ziffern.isEmpty, "Baustein \(template.ruleID)")
        for verboten in ["Punkt", "Offenheit", "Note", "Score", "%"] {
            #expect(!text.contains(verboten), "Baustein \(template.ruleID)")
        }
    }
}

@Test func gleicherBeitragErgibtZweimalDieselbeRueckmeldung() throws {
    // Der Wiederholungsschutz des Reducers unterdrückt die zweite Gutschrift für denselben
    // Code. Die Rückmeldung hängt davon ausdrücklich nicht ab: sie beschreibt, was in
    // diesem Beitrag getan wurde, und wird nicht als Punktekonto gelesen.
    let kontext = [DialogueMessage(speaker: .client, text: "Ich möchte die Sonntage wieder mitkriegen.")]
    let eingabe = "Ihnen fehlen die Sonntage."
    let analyse = TurnAnalysis(segments: [
        .init(quote: eingabe, code: .complexReflection, isUncertain: false,
              supportingClientQuote: "Ich möchte die Sonntage wieder mitkriegen.")])
    let erste = FeedbackEngine.findings(analysis: analyse, input: eingabe, context: kontext,
                                        characterName: figur, rulesVersion: "0.1")
    let zweite = FeedbackEngine.findings(analysis: analyse, input: eingabe, context: kontext,
                                         characterName: figur, rulesVersion: "0.1")
    #expect(erste == zweite && !erste.isEmpty)

    // Zur Gegenprobe: der Zustand gibt beim zweiten Mal keine Gutschrift mehr.
    let vorher = SimulationState(openness: 4, recentCredits: [.complexReflection])
    let reduktion = try StateReducer.reduce(vorher, analysis: analyse, input: eingabe, context: kontext)
    #expect(reduktion.state.openness == 4)
    #expect(reduktion.reasons.contains("repeat_credit_suppressed"))
}

// MARK: - Speicherformat

@Test func alteGespeicherteTurnsOhneFeedbackBleibenLesbar() throws {
    // Empirisch belegt: ein nicht-optionales neues Feld lässt alte Snapshots mit
    // `keyNotFound` scheitern, und `SwiftDataSessionRepository.list()` wirft dann beim
    // ersten Fehlschlag — eine einzige Sitzung machte die ganze Verlaufsliste unbrauchbar.
    let alt = """
    {"completedAt":760000000,"id":"F3A0A9D2-0000-4000-8000-000000000001","input":"Sie entscheiden selbst.",
     "metrics":[],"reply":{"disclosedFactIDs":[],"text":"Mal sehen."},
     "stateAfter":{"closedQuestionStreak":0,"disclosedFactIDs":[],"openness":3,"recentCredits":[]},
     "stateBefore":{"closedQuestionStreak":0,"disclosedFactIDs":[],"openness":3,"recentCredits":[]},
     "stateChangeReasons":["neutral"]}
    """
    let turn = try JSONDecoder().decode(CompletedTurn.self, from: Data(alt.utf8))
    #expect(turn.feedback.isEmpty)
    #expect(turn.analysis == nil)
    #expect(turn.selectedTipID == nil)
    // Und der neue Stand bleibt Schemaversion 1, damit alte Sitzungen lesbar bleiben.
    #expect(TestData.session().schemaVersion == 1)
}

@Test func feedbackUeberstehtEineCodierrunde() throws {
    let finding = FeedbackFinding(ruleID: "warnung.konfrontation", kind: .warning, certainty: .confirmed,
        title: "Konfrontation", message: "„X“ setzt Lukas unter Druck.",
        evidence: [.init(source: .currentInput, speaker: .counselor, messageIndex: nil, quote: "X", occurrence: 1)],
        templateVersion: "0.1", rulesVersion: "0.1", sourceID: "S3", reviewStatus: .draft)
    let data = try JSONEncoder().encode(finding)
    #expect(try JSONDecoder().decode(FeedbackFinding.self, from: data) == finding)
}
