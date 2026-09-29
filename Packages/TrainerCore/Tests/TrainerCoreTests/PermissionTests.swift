import Foundation
import Testing
@testable import TrainerCore

// Erlaubnis vor einem Ratschlag: Fälle 4, 10 und 11 aus Documentation/MI-UEBERGABE.md sowie
// die beiden Festlegungen von Jonas vom 30.09.2026 — eine Erlaubnis gilt nur für die
// aktuelle Situation, und eine Zustimmung trägt genau einen Ratschlag.
//
// Geprüft wird die deterministische Seite: Herkunft, Sprecher, Reihenfolge, Zitate, die
// Zuordnung zum Ratschlagssegment, die Wiederverwendung derselben Zustimmung und die
// Formulierung der Rückmeldung. Die semantische Einschätzung selbst stammt vom Modell und
// ist hier von Hand gesetzt; diese Fixtures sind keine fachlich geprüfte Goldreferenz.

private let figur = "Lukas"
private let rat = "Sie könnten kurz notieren, was Ihnen geholfen hat."
private let zweiterRat = "Sie könnten außerdem das Handy weglegen."

private func kontext(_ texte: [(Speaker, String)]) -> [DialogueMessage] {
    texte.map { .init(speaker: $0.0, text: $0.1) }
}

/// Eröffnung, Erlaubnisfrage, Zustimmung. Danach folgt unmittelbar der eigene Beitrag.
private let zustimmung = kontext([
    (.client, "Ich weiß nicht, wie ich beim nächsten Mal sagen soll, was daran geholfen hat."),
    (.counselor, "Möchten Sie eine Idee hören, wie Sie das festhalten könnten?"),
    (.client, "Ja, gerne.")])

private func beleg(_ quote: String, _ index: Int, _ speaker: Speaker) -> EvidenceReference {
    .init(source: .contextMessage, speaker: speaker, messageIndex: index, quote: quote, occurrence: 1)
}
private func eigen(_ quote: String) -> EvidenceReference {
    .init(source: .currentInput, speaker: .counselor, messageIndex: nil, quote: quote, occurrence: 1)
}
private let frage = beleg("Möchten Sie eine Idee hören, wie Sie das festhalten könnten?", 1, .counselor)
private let ja = beleg("Ja, gerne.", 2, .client)

private func analyse(_ segmente: [(String, CounselorCode)],
                     _ permissions: [PermissionAssessment]) -> TurnAnalysis {
    .init(segments: segmente.map { .init(quote: $0.0, code: $0.1, isUncertain: false) }, permissions: permissions)
}

/// Prüft die Analyse wie im Coordinator und leitet daraus die Rückmeldung ab.
private func befunde(_ analysis: TurnAnalysis, input: String, context: [DialogueMessage],
                     contextIsComplete: Bool = true) throws -> [FeedbackFinding] {
    try OutputValidator.validateAnalysis(analysis, input: input, context: context)
    let report = PermissionReport(entries: PermissionTracker.resolve(analysis.permissions ?? [], context: context),
                                  contextIsComplete: contextIsComplete)
    return FeedbackEngine.findings(analysis: analysis, input: input, context: context,
                                   characterName: figur, rulesVersion: "0.1", permission: report)
}

// MARK: - Zustimmung, Ablehnung, Widerruf

@Test func fall04ZustimmungImVorherigenBeitragTraegtDenRatschlag() throws {
    let analysis = analyse([(rat, .adviceWithPermission)],
                           [.init(advice: eigen(rat), standing: .granted, request: frage, response: ja)])
    let findings = try befunde(analysis, input: rat, context: zustimmung)
    let lob = try #require(findings.first)
    #expect(findings.count == 1)
    #expect(lob.ruleID == "rueckmeldung.rat_mit_erlaubnis")
    #expect(lob.kind == .observation)
    #expect(lob.certainty == .confirmed)
    #expect(lob.reviewStatus == .draft)
    // Die Rückmeldung trägt die Zustimmung wörtlich und nicht umschrieben.
    #expect(lob.message.contains("Ja, gerne."))
    // „Du hast vorher gefragt" ist eine eigene Aussage und braucht die Frage als Beleg.
    #expect(lob.evidence == [eigen(rat), frage, ja])
    for reference in lob.evidence {
        try OutputValidator.validateEvidence(reference, input: rat, context: zustimmung)
    }
}

@Test func ablehnungUndWiderrufErzeugenEigeneWarnungen() throws {
    let nein = kontext([
        (.client, "Ich weiß nicht weiter."),
        (.counselor, "Möchten Sie eine Idee hören?"),
        (.client, "Nein, lieber nicht.")])
    let abgelehnt = try befunde(analyse([(rat, .adviceWithoutPermission)], [
        .init(advice: eigen(rat), standing: .refused,
              request: beleg("Möchten Sie eine Idee hören?", 1, .counselor),
              response: beleg("Nein, lieber nicht.", 2, .client))]), input: rat, context: nein)
    #expect(abgelehnt.map(\.ruleID) == ["warnung.rat_trotz_ablehnung"])
    #expect(abgelehnt[0].certainty == .confirmed)
    #expect(abgelehnt[0].message.contains("Nein, lieber nicht."))

    let widerruf = kontext([
        (.counselor, "Möchten Sie eine Idee hören?"),
        (.client, "Ja, gerne."),
        (.client, "Eigentlich will ich dazu doch nichts hören.")])
    let zurueckgenommen = try befunde(analyse([(rat, .adviceWithoutPermission)], [
        .init(advice: eigen(rat), standing: .withdrawn,
              request: beleg("Möchten Sie eine Idee hören?", 0, .counselor),
              response: beleg("Eigentlich will ich dazu doch nichts hören.", 2, .client))]),
                                      input: rat, context: widerruf)
    #expect(zurueckgenommen.map(\.ruleID) == ["warnung.rat_nach_widerruf"])
    #expect(zurueckgenommen[0].kind == .warning)
}

@Test func fall10FrageUndRatImSelbenBeitragSindKeineErlaubnis() throws {
    let eingabe = "Darf ich Ihnen einen Tipp geben? Sie sollten Ihre Freunde am Wochenende einfach nicht mehr treffen."
    let tipp = "Sie sollten Ihre Freunde am Wochenende einfach nicht mehr treffen."
    let analysis = analyse([("Darf ich Ihnen einen Tipp geben?", .closedQuestion), (tipp, .adviceWithoutPermission)],
                           [.init(advice: eigen(tipp), standing: .askedInSameInput,
                                  request: eigen("Darf ich Ihnen einen Tipp geben?"))])
    let findings = try befunde(analysis, input: eingabe, context: kontext([(.client, "Hm.")]))
    #expect(findings.map(\.ruleID) == ["warnung.erlaubnis_nicht_abgewartet"])
    #expect(findings[0].certainty == .confirmed)
    #expect(findings[0].message.contains("Darf ich Ihnen einen Tipp geben?"))
    // Der Befund gilt auch ohne bekannte Vorgeschichte: er beruht allein auf dem Beitrag selbst.
    let ohneKontext = try befunde(analysis, input: eingabe, context: kontext([(.client, "Hm.")]),
                                  contextIsComplete: false)
    #expect(ohneKontext.map(\.ruleID) == ["warnung.erlaubnis_nicht_abgewartet"])
}

@Test func direkteBitteWirdNichtAlsUnerlaubtBehandelt() throws {
    // Abschnitt 13: Ob zusätzlich rückversichert werden muss, ist nicht entschieden. Bis
    // dahin darf die Rückmeldung daraus weder einen Vorwurf noch eine Regel machen.
    let bitte = kontext([(.client, "Und welchen Vorschlag haben Sie?")])
    let findings = try befunde(analyse([(rat, .adviceWithPermission)], [
        .init(advice: eigen(rat), standing: .clientRequested,
              response: beleg("Und welchen Vorschlag haben Sie?", 0, .client))]), input: rat, context: bitte)
    #expect(findings.map(\.ruleID) == ["rueckmeldung.rat_auf_bitte"])
    #expect(findings[0].kind == .observation)
    #expect(!findings.contains { $0.kind == .warning })
}

// MARK: - Situationsbezug und Verbrauch

@Test func zustimmungGiltNichtFuerEineSpaetereSituationBeimSelbenThema() throws {
    // Jonas: Eine Erlaubnis gilt nur für die aktuelle Situation. Gleiche Thematik genügt nicht.
    let spaeter = kontext([
        (.counselor, "Möchten Sie eine Idee zum Festhalten hören?"),
        (.client, "Ja, gerne."),
        (.counselor, "Sie könnten es aufschreiben."),
        (.client, "Habe ich gemacht."),
        (.counselor, "Wie war die Woche sonst?"),
        (.client, "Anstrengend. Das Festhalten ist wieder ein Thema.")])
    let findings = try befunde(analyse([(rat, .adviceWithoutPermission)], [
        .init(advice: eigen(rat), standing: .pastSituation,
              request: beleg("Möchten Sie eine Idee zum Festhalten hören?", 0, .counselor),
              response: beleg("Ja, gerne.", 1, .client))]), input: rat, context: spaeter)
    #expect(findings.map(\.ruleID) == ["warnung.erlaubnis_aus_frueherer_situation"])
    #expect(findings[0].certainty == .confirmed)
}

@Test func verbrauchteZustimmungTraegtKeinenZweitenRatschlagUeberTurns() throws {
    // Jonas: Ein Ja erlaubt genau einen Ratschlag; danach ist es verbraucht.
    let verlauf = kontext([
        (.counselor, "Möchten Sie eine Idee hören?"),
        (.client, "Ja, gerne."),
        (.counselor, "Sie könnten es kurz notieren."),
        (.client, "Okay.")])
    let findings = try befunde(analyse([(zweiterRat, .adviceWithoutPermission)], [
        .init(advice: eigen(zweiterRat), standing: .consumed,
              request: beleg("Möchten Sie eine Idee hören?", 0, .counselor),
              response: beleg("Ja, gerne.", 1, .client),
              consumedBy: beleg("Sie könnten es kurz notieren.", 2, .counselor))]),
                               input: zweiterRat, context: verlauf)
    #expect(findings.map(\.ruleID) == ["warnung.erlaubnis_bereits_verbraucht"])
    #expect(findings[0].message.contains("Ja, gerne."))
    #expect(findings[0].evidence.count == 4)
    #expect(findings[0].evidence.last == beleg("Sie könnten es kurz notieren.", 2, .counselor))
}

@Test func eineZustimmungTraegtNichtZweiRatschlaegeImSelbenBeitrag() throws {
    let eingabe = "\(rat) \(zweiterRat)"
    let analysis = analyse([(rat, .adviceWithPermission), (zweiterRat, .adviceWithoutPermission)], [
        .init(advice: eigen(rat), standing: .granted, request: frage, response: ja),
        .init(advice: eigen(zweiterRat), standing: .consumed, request: frage, response: ja,
              consumedBy: eigen(rat))])
    let findings = try befunde(analysis, input: eingabe, context: zustimmung)
    #expect(findings.map(\.ruleID) == ["warnung.erlaubnis_bereits_verbraucht", "rueckmeldung.rat_mit_erlaubnis"])
    // Warnungen stehen vor den Rückmeldungen.
    #expect(findings[0].kind == .warning && findings[1].kind == .observation)

    // Dieselbe Zustimmung zweimal als erteilt auszuweisen ist kein zulässiger Befund.
    var doppelt = analysis
    doppelt.permissions?[1] = .init(advice: eigen(zweiterRat), standing: .granted, request: frage, response: ja)
    doppelt.segments[1].code = .adviceWithPermission
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(doppelt, input: eingabe, context: zustimmung)
    }
}

@Test func neueFrageUndNeueZustimmungErlaubenDenNaechstenRatschlag() throws {
    let verlauf = kontext([
        (.counselor, "Möchten Sie eine Idee hören?"),
        (.client, "Ja, gerne."),
        (.counselor, "Sie könnten es kurz notieren."),
        (.client, "Okay."),
        (.counselor, "Möchten Sie noch eine Idee ergänzen?"),
        (.client, "Ja, gern noch eine.")])
    let findings = try befunde(analyse([(zweiterRat, .adviceWithPermission)], [
        .init(advice: eigen(zweiterRat), standing: .granted,
              request: beleg("Möchten Sie noch eine Idee ergänzen?", 4, .counselor),
              response: beleg("Ja, gern noch eine.", 5, .client))]), input: zweiterRat, context: verlauf)
    #expect(findings.map(\.ruleID) == ["rueckmeldung.rat_mit_erlaubnis"])
    #expect(findings[0].certainty == .confirmed)
}

@Test func zustimmungVorEinerWeiterenBerateraeusserungBleibtUnsicher() throws {
    // Strukturelle Vorsicht: Steht nach der Zustimmung schon ein weiterer Beraterbeitrag,
    // kann diese Ebene nicht wissen, ob der eine erlaubte Ratschlag dort gefallen ist.
    // Ergebnis ist Zurückhaltung, ausdrücklich kein sicherer Vorwurf.
    let verlauf = zustimmung + kontext([(.counselor, "Und wie war die Woche sonst?"), (.client, "Ganz gut.")])
    let entries = PermissionTracker.resolve([
        .init(advice: eigen(rat), standing: .granted, request: frage, response: ja)], context: verlauf)
    #expect(entries[0].standing == .granted)
    #expect(entries[0].isUncertain)
    let findings = try befunde(analyse([(rat, .adviceWithPermission)], [
        .init(advice: eigen(rat), standing: .granted, request: frage, response: ja)]),
                               input: rat, context: verlauf)
    #expect(findings.map(\.ruleID) == ["warnung.rat_ohne_erlaubnis"])
    #expect(findings[0].certainty == .possible)
}

// MARK: - Kontextlücke

@Test func kontextlueckeErzeugtKeinenSicherenVorwurf() throws {
    let analysis = analyse([(rat, .adviceWithoutPermission)],
                           [.init(advice: eigen(rat), standing: .notRequested)])
    let vollstaendig = try befunde(analysis, input: rat, context: zustimmung, contextIsComplete: true)
    #expect(vollstaendig.map(\.certainty) == [.confirmed])
    let gekuerzt = try befunde(analysis, input: rat, context: zustimmung, contextIsComplete: false)
    #expect(gekuerzt.map(\.ruleID) == ["warnung.rat_ohne_erlaubnis"])
    #expect(gekuerzt[0].certainty == .possible)

    // Dasselbe gilt für einen Beitrag ohne jede Erlaubniseinschätzung, etwa aus einer
    // älteren Analyse: ohne vollständigen Kontext bleibt die Warnung vorsichtig.
    let ohneVertrag = TurnAnalysis(segments: [.init(quote: rat, code: .adviceWithoutPermission, isUncertain: false)])
    #expect(try befunde(ohneVertrag, input: rat, context: zustimmung, contextIsComplete: false)
        .map(\.certainty) == [.possible])
    #expect(try befunde(ohneVertrag, input: rat, context: zustimmung, contextIsComplete: true)
        .map(\.certainty) == [.confirmed])

    // „unklar" behauptet weder fehlende noch vorhandene Zustimmung.
    let unklar = try befunde(analyse([(rat, .adviceWithoutPermission)],
                                     [.init(advice: eigen(rat), standing: .unclear)]),
                             input: rat, context: zustimmung)
    #expect(unklar.map(\.certainty) == [.possible])
}

@Test func kontextabdeckungFolgtDerHerkunftUndNichtDerAnzahl() {
    var session = TestData.session()
    for text in ["Hm.", "Ja.", "Kann sein."] {
        session.turns.append(.init(id: UUID(), input: "Und weiter?", analysis: nil,
            reply: .init(text: text, primaryTag: nil, disclosedFactIDs: []), stateBefore: session.state,
            stateAfter: session.state, stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
    }
    #expect(ContextBuilder.covers(ContextBuilder.messages(session), session: session))
    // Ein gekürztes Fenster fällt durch, auch wenn die Anzahl stimmen würde.
    #expect(!ContextBuilder.covers(Array(ContextBuilder.messages(session).dropFirst(2)), session: session))
    // Nachrichten ohne dauerhafte Herkunft gelten nie als Abdeckung.
    #expect(!ContextBuilder.covers(ContextBuilder.messages(session).map {
        .init(speaker: $0.speaker, text: $0.text) }, session: session))
    for _ in 0..<5 {
        session.turns.append(.init(id: UUID(), input: "Und weiter?", analysis: nil,
            reply: .init(text: "Hm.", primaryTag: nil, disclosedFactIDs: []), stateBefore: session.state,
            stateAfter: session.state, stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
    }
    #expect(!ContextBuilder.covers(ContextBuilder.messages(session), session: session))
}

// MARK: - Belege

@Test func erfundeneUndFalschVerorteteBelegeWerdenAbgewiesen() throws {
    func ungueltig(_ entry: PermissionAssessment, input: String = rat,
                   segment: CounselorCode = .adviceWithPermission) {
        #expect(throws: TrainerFailure.invalidAnalysis) {
            try OutputValidator.validateAnalysis(analyse([(input, segment)], [entry]),
                                                 input: input, context: zustimmung)
        }
    }
    // Zustimmung wörtlich nicht vorhanden.
    ungueltig(.init(advice: eigen(rat), standing: .granted, request: frage,
                    response: beleg("Ja, unbedingt.", 2, .client)))
    // Zustimmung in der falschen Nachricht.
    ungueltig(.init(advice: eigen(rat), standing: .granted, request: frage,
                    response: beleg("Ja, gerne.", 0, .client)))
    // Zustimmung der Beratung zugeschrieben.
    ungueltig(.init(advice: eigen(rat), standing: .granted, request: frage,
                    response: beleg("Ja, gerne.", 2, .counselor)))
    // Erlaubnisfrage als Klientenaussage ausgegeben.
    ungueltig(.init(advice: eigen(rat), standing: .granted,
                    request: beleg("Möchten Sie eine Idee hören, wie Sie das festhalten könnten?", 1, .client),
                    response: ja))
    // Ratschlagsbeleg, der nicht in der Eingabe steht.
    ungueltig(.init(advice: eigen("Sie sollten das lassen."), standing: .granted, request: frage, response: ja))
    // Erteilte Erlaubnis ohne Belege.
    ungueltig(.init(advice: eigen(rat), standing: .granted))
    // Beleg außerhalb eines Ratschlagssegments.
    ungueltig(.init(advice: eigen(rat), standing: .granted, request: frage, response: ja),
              segment: .information)
    // Sichere Einschätzung im Widerspruch zum Segmentcode.
    ungueltig(.init(advice: eigen(rat), standing: .notRequested), segment: .adviceWithPermission)
    ungueltig(.init(advice: eigen(rat), standing: .granted, request: frage, response: ja),
              segment: .adviceWithoutPermission)
}

@Test func belegeWerdenZeitlichGeprueft() throws {
    let verlauf = kontext([
        (.client, "Ja, gerne."),
        (.counselor, "Möchten Sie eine Idee hören?"),
        (.client, "Hm.")])
    // Die Zustimmung steht vor der Frage: keine Erlaubnis.
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(rat, .adviceWithPermission)], [
            .init(advice: eigen(rat), standing: .granted,
                  request: beleg("Möchten Sie eine Idee hören?", 1, .counselor),
                  response: beleg("Ja, gerne.", 0, .client))]), input: rat, context: verlauf)
    }
    // Der aufbrauchende Ratschlag muss nach der Zustimmung liegen.
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(rat, .adviceWithoutPermission)], [
            .init(advice: eigen(rat), standing: .consumed, request: frage, response: ja,
                  consumedBy: beleg("Möchten Sie eine Idee hören, wie Sie das festhalten könnten?", 1, .counselor))]),
                                             input: rat, context: zustimmung)
    }
    // Im selben Beitrag muss er vor dem beurteilten Ratschlag stehen.
    let eingabe = "\(rat) \(zweiterRat)"
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(rat, .adviceWithPermission), (zweiterRat, .adviceWithoutPermission)], [
            .init(advice: eigen(rat), standing: .consumed, request: frage, response: ja,
                  consumedBy: eigen(zweiterRat))]), input: eingabe, context: zustimmung)
    }
    // Die Erlaubnisfrage im selben Beitrag steht vor dem Rat, nicht danach.
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(rat, .adviceWithoutPermission), (zweiterRat, .openQuestion)], [
            .init(advice: eigen(rat), standing: .askedInSameInput, request: eigen(zweiterRat))]),
                                             input: eingabe, context: zustimmung)
    }
}

@Test func jedesRatschlagssegmentTraegtHoechstensEineEinschaetzung() throws {
    let eingabe = "\(rat) \(zweiterRat)"
    // Zwei Einträge in verschiedene Teile desselben Segments hinein: ein Ratschlag bleibt
    // ein Ratschlag, auch wenn er aus mehreren Sätzen oder Teilsätzen besteht.
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(rat, .adviceWithPermission)], [
            .init(advice: eigen("Sie könnten kurz notieren"), standing: .granted, request: frage, response: ja),
            .init(advice: eigen("was Ihnen geholfen hat."), standing: .unclear)]),
                                             input: rat, context: zustimmung)
    }
    // Die Einträge folgen der Reihenfolge des eigenen Beitrags.
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(rat, .adviceWithoutPermission), (zweiterRat, .adviceWithoutPermission)], [
            .init(advice: eigen(zweiterRat), standing: .notRequested),
            .init(advice: eigen(rat), standing: .notRequested)]), input: eingabe, context: zustimmung)
    }
}

// MARK: - Gegenproben aus der unabhängigen Prüfung (30.09.2026)

@Test func zweiAusschnitteDerselbenZustimmungBleibenEineZustimmung() throws {
    // Erste Gegenprobe: „Ja, gerne." und „gerne" sind dieselbe Zusage. Ein Vergleich der
    // Belegobjekte hätte beide Ratschläge als erlaubt durchgelassen.
    let eingabe = "\(rat) \(zweiterRat)"
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(rat, .adviceWithPermission), (zweiterRat, .adviceWithPermission)], [
            .init(advice: eigen(rat), standing: .granted, request: frage, response: ja),
            .init(advice: eigen(zweiterRat), standing: .granted, request: frage,
                  response: beleg("gerne", 2, .client))]), input: eingabe, context: zustimmung)
    }
    // Auch umgekehrt: eine bereits aufgebrauchte Zustimmung wird später nicht wieder erteilt.
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(rat, .adviceWithoutPermission), (zweiterRat, .adviceWithPermission)], [
            .init(advice: eigen(rat), standing: .consumed, request: frage, response: ja,
                  consumedBy: beleg("Möchten Sie eine Idee hören, wie Sie das festhalten könnten?", 1, .counselor)),
            .init(advice: eigen(zweiterRat), standing: .granted, request: frage, response: ja)]),
                                             input: eingabe, context: zustimmung)
    }
}

@Test func nurEinRatschlagKannEineZustimmungAufbrauchen() throws {
    // Zweite Gegenprobe: Eine vorausgehende offene Frage im selben Beitrag ist kein
    // Ratschlag und verbraucht deshalb nichts.
    let nachfrage = "Was denken Sie?"
    let eingabe = "\(nachfrage) \(rat)"
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(nachfrage, .openQuestion), (rat, .adviceWithoutPermission)], [
            .init(advice: eigen(rat), standing: .consumed, request: frage, response: ja,
                  consumedBy: eigen(nachfrage))]), input: eingabe, context: zustimmung)
    }
    // Ebenso wenig ein früherer Ratschlag, der eine andere Zustimmung genutzt hat.
    let verlauf = zustimmung + kontext([
        (.counselor, "Und möchten Sie eine zweite Idee?"), (.client, "Ja, gern noch eine.")])
    let eingabeZwei = "\(rat) \(zweiterRat)"
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.validateAnalysis(analyse([(rat, .adviceWithPermission), (zweiterRat, .adviceWithoutPermission)], [
            .init(advice: eigen(rat), standing: .granted,
                  request: beleg("Und möchten Sie eine zweite Idee?", 3, .counselor),
                  response: beleg("Ja, gern noch eine.", 4, .client)),
            .init(advice: eigen(zweiterRat), standing: .consumed, request: frage, response: ja,
                  consumedBy: eigen(rat))]), input: eingabeZwei, context: verlauf)
    }
}

@Test func jederRatschlagBrauchtImNeuenVertragEineEinschaetzung() throws {
    // Dritte Gegenprobe: Eine leere Liste neben einem Ratschlag ist eine stille Enthaltung
    // und sähe in der Oberfläche wie eine Entwarnung aus.
    for code in [CounselorCode.adviceWithPermission, .adviceWithoutPermission] {
        #expect(throws: TrainerFailure.invalidAnalysis) {
            try OutputValidator.validateAnalysis(analyse([(rat, code)], []), input: rat, context: zustimmung)
        }
    }
    // Ein Beitrag ohne Ratschlag darf die Liste selbstverständlich leer lassen.
    try OutputValidator.validateAnalysis(analyse([(rat, .information)], []), input: rat, context: zustimmung)
}

@Test func zustimmungTraegtNurDenUnmittelbarFolgendenBeitrag() throws {
    // Nach der Zustimmung darf nichts mehr stehen: Ein weiterer Beitrag kann den einen
    // erlaubten Ratschlag enthalten haben, und ein Widerruf kann dort ebenfalls liegen —
    // auch dann, wenn dem Modell der Verlauf nur gekürzt vorlag.
    let spaeter = zustimmung + kontext([(.client, "Eigentlich lieber doch nicht.")])
    let entries = PermissionTracker.resolve([
        .init(advice: eigen(rat), standing: .granted, request: frage, response: ja)], context: spaeter)
    #expect(entries[0].isUncertain)
    let findings = try befunde(analyse([(rat, .adviceWithPermission)], [
        .init(advice: eigen(rat), standing: .granted, request: frage, response: ja)]),
                               input: rat, context: spaeter, contextIsComplete: false)
    #expect(findings.map(\.certainty) == [.possible])
    #expect(!findings.contains { $0.kind == .observation })
}

// MARK: - Bestandsdaten

@Test func alteAnalysenUndSnapshotsBleibenLesbar() throws {
    // Vor diesem Schritt gespeicherte Analysen kennen `permissions` nicht. Fehlend heißt
    // „nicht erhoben" und darf weder ein Scheinergebnis erzeugen noch das Lesen verhindern.
    let alt = Data(#"{"segments":[{"quote":"\#(rat)","code":"ratschlag_ohne_erlaubnis","isUncertain":false}]}"#.utf8)
    let decoded = try OutputValidator.decodeAnalysis(alt, input: rat, context: [])
    #expect(decoded.permissions == nil)

    let turn = CompletedTurn(id: UUID(), input: rat, analysis: decoded,
        reply: .init(text: "Hm.", primaryTag: nil, disclosedFactIDs: []),
        stateBefore: .init(openness: 3), stateAfter: .init(openness: 3), stateChangeReasons: [],
        selectedTipID: nil, metrics: [], completedAt: Date())
    let wieder = try JSONDecoder().decode(CompletedTurn.self, from: JSONEncoder().encode(turn))
    #expect(wieder.analysis?.permissions == nil)
    #expect(wieder == turn)

    // Unbekannte Felder bleiben unzulässig; das gilt weiter auch für den neuen Vertrag.
    let unbekannt = Data(#"{"segments":[],"permissions":[{"advice":null,"standing":"erteilt","isUncertain":false}]}"#.utf8)
    #expect(throws: TrainerFailure.invalidAnalysis) {
        try OutputValidator.decodeAnalysis(unbekannt, input: "", context: [])
    }
}
