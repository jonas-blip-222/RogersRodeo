import Foundation
import Testing
import TrainerCore
@testable import TrainerDesktop

// Bindung der frühen Rückmeldung an genau einen Ausführungsversuch (MI-Nachtrag, 9.3).
//
// Die Fehler, um die es hier geht, sieht man auf dem Bildschirm kaum: eine Warnung, die
// nach einem Abbruch noch steht und beim nächsten Beitrag wie dessen Warnung wirkt; eine
// Warnung, die nach einem Sitzungswechsel im falschen Gespräch auftaucht. Deshalb ist die
// Entscheidung eine reine Funktion und wird hier ohne Oberfläche geprüft.

private func meldung(sessionID: UUID, revision: Int = 0, input: String = "Sie entscheiden selbst.",
                     attempt: UUID = UUID()) -> PreliminaryFeedback {
    PreliminaryFeedback(sessionID: sessionID, turnID: UUID(), expectedRevision: revision,
                        attempt: attempt, input: input, analysisAvailable: true, findings: [])
}

@Test func rueckmeldungWirdNurImLaufendenVersuchAngenommen() {
    let sitzung = UUID(), marke = UUID()
    let feedback = meldung(sessionID: sitzung)
    #expect(FeedbackGate.accepts(feedback, operation: marke, token: marke, sessionID: sitzung,
                                 revision: 0, currentInput: "Sie entscheiden selbst."))
    // Abbruch setzt die laufende Operation auf nil: ein spätes Ergebnis verfällt.
    #expect(!FeedbackGate.accepts(feedback, operation: nil, token: marke, sessionID: sitzung,
                                  revision: 0, currentInput: "Sie entscheiden selbst."))
    // Inzwischen läuft ein anderer Versuch.
    #expect(!FeedbackGate.accepts(feedback, operation: UUID(), token: marke, sessionID: sitzung,
                                  revision: 0, currentInput: "Sie entscheiden selbst."))
}

@Test func rueckmeldungVerschwindetBeiWechselAenderungUndCommit() {
    let sitzung = UUID()
    let feedback = meldung(sessionID: sitzung)
    #expect(FeedbackGate.keeps(feedback, sessionID: sitzung, revision: 0, currentInput: "Sie entscheiden selbst."))
    // Randzeichen zählen nicht, der Coordinator arbeitet auf dem beschnittenen Text.
    #expect(FeedbackGate.keeps(feedback, sessionID: sitzung, revision: 0, currentInput: "  Sie entscheiden selbst.  "))
    // Sitzung gewechselt oder geschlossen.
    #expect(!FeedbackGate.keeps(feedback, sessionID: UUID(), revision: 0, currentInput: "Sie entscheiden selbst."))
    #expect(!FeedbackGate.keeps(feedback, sessionID: nil, revision: nil, currentInput: "Sie entscheiden selbst."))
    // Turn gespeichert: die Revision ist erhöht, die gespeicherte Rückmeldung übernimmt.
    #expect(!FeedbackGate.keeps(feedback, sessionID: sitzung, revision: 1, currentInput: ""))
    // Text bearbeitet: die Rückmeldung gehört nicht mehr zu dem, was dasteht.
    #expect(!FeedbackGate.keeps(feedback, sessionID: sitzung, revision: 0, currentInput: "Etwas ganz anderes"))
}

@Test func eineFremdeSitzungBekommtNiemalsEineFremdeWarnung() {
    // Auch wenn Marke und Revision zufällig passen, entscheidet die Sitzungskennung.
    let marke = UUID()
    let feedback = meldung(sessionID: UUID())
    #expect(!FeedbackGate.accepts(feedback, operation: marke, token: marke, sessionID: UUID(),
                                  revision: 0, currentInput: "Sie entscheiden selbst."))
}
