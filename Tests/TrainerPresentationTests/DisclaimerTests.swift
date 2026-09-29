import Foundation
import Testing
import TrainerCore
@testable import TrainerDesktop

// Prüfungen zum einmaligen Aufklärungs-Disclaimer (Documentation/ENTSCHEIDUNGEN.md, E07):
// dass die Bestätigung einen Neustart übersteht, dass sie bei geänderter Textfassung
// erneut verlangt wird, und dass ohne Bestätigung kein Gespräch beginnt.
//
// Bewusst kein Test, der nach der Bestätigung wirklich ein Gespräch startet: Liegt ein
// Schlüssel im Schlüsselbund, ginge das an OpenRouter und kostete Geld. Geprüft wird
// deshalb nur die Sperre, nicht die Freigabe des Modellaufrufs.

private func testDefaults() throws -> (UserDefaults, String) {
    let domain = "DisclaimerTests.\(UUID().uuidString)"
    return (try #require(UserDefaults(suiteName: domain)), domain)
}

// MARK: - Speicherung der Bestätigung

@Test @MainActor func bestaetigungUeberstehtNeustart() throws {
    let (defaults, domain) = try testDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }

    let firstRun = DisclaimerConsent(version: "1", defaults: defaults)
    #expect(firstRun.isAccepted == false)
    #expect(firstRun.acceptedVersion == nil)
    #expect(firstRun.acceptedAt == nil)

    firstRun.accept()
    #expect(firstRun.isAccepted)

    // Ein neuer App-Prozess erzeugt eine neue Instanz und liest denselben Eintrag.
    let restarted = DisclaimerConsent(version: "1", defaults: defaults)
    #expect(restarted.isAccepted)
    #expect(restarted.acceptedVersion == "1")
    #expect(restarted.acceptedAt != nil)
}

@Test @MainActor func geaenderteTextfassungWirdErneutVorgelegt() throws {
    let (defaults, domain) = try testDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }

    let alt = DisclaimerConsent(version: "1", defaults: defaults)
    alt.accept()
    #expect(alt.isAccepted)

    // Neue Fassung des Textes: Die alte Zustimmung gilt nicht für den neuen Wortlaut.
    let neu = DisclaimerConsent(version: "2", defaults: defaults)
    #expect(neu.isAccepted == false)
    #expect(neu.acceptedVersion == "1")

    neu.accept()
    #expect(neu.isAccepted)
    // Die alte Fassung ist überschrieben, nicht zusätzlich geführt.
    #expect(DisclaimerConsent(version: "1", defaults: defaults).isAccepted == false)
    #expect(DisclaimerConsent(version: "2", defaults: defaults).isAccepted)
}

@Test @MainActor func zuruecknehmenStelltDenZustandVorDerErstenBenutzungHer() throws {
    let (defaults, domain) = try testDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }

    let consent = DisclaimerConsent(version: "1", defaults: defaults)
    consent.accept()
    consent.reset()
    #expect(consent.isAccepted == false)
    #expect(consent.acceptedVersion == nil)
    #expect(consent.acceptedAt == nil)
}

// MARK: - Sperre im AppModel

// `AppModel` wird hier bewusst nicht gebaut: Sein `init` liest den Schlüsselbund, und das
// blockiert den Testlauf mit einer Freigabeanfrage — dieselbe Einschränkung, wegen der die
// Schlüsselbundtests in `SettingsTests.swift` ausgelassen werden. Geprüft wird deshalb die
// Bedingung, die `AppModel.start`, `.open` und `.send` benutzen, zusammen mit dem
// gespeicherten Zustand, aus dem sie gespeist wird.
@Test @MainActor func ohneBestaetigungKeinGespraech() throws {
    let (defaults, domain) = try testDefaults()
    defer { defaults.removePersistentDomain(forName: domain) }
    let consent = DisclaimerConsent(version: DisclaimerText.version, defaults: defaults)

    // Zustand vor der ersten Benutzung: kein Gesprächsbeginn, kein Öffnen, kein Senden.
    #expect(consent.isAccepted == false)
    #expect(DisclaimerGate.allowsConversation(disclaimerAccepted: consent.isAccepted, busy: false) == false)

    consent.accept()
    #expect(DisclaimerGate.allowsConversation(disclaimerAccepted: consent.isAccepted, busy: false))

    // Nach einem Neustart bleibt es freigegeben, ohne erneutes Fragen.
    let restarted = DisclaimerConsent(version: DisclaimerText.version, defaults: defaults)
    #expect(DisclaimerGate.allowsConversation(disclaimerAccepted: restarted.isAccepted, busy: false))

    // Eine geänderte Textfassung sperrt wieder, obwohl schon einmal bestätigt wurde.
    let neueFassung = DisclaimerConsent(version: DisclaimerText.version + "-neu", defaults: defaults)
    #expect(DisclaimerGate.allowsConversation(disclaimerAccepted: neueFassung.isAccepted, busy: false) == false)

    // Die schon vorher geltende Bedingung bleibt erhalten: während einer laufenden
    // Operation passiert auch mit Bestätigung nichts.
    #expect(DisclaimerGate.allowsConversation(disclaimerAccepted: true, busy: true) == false)
}

// MARK: - Text

@Test @MainActor func textIstEntwurfUndBleibtBeiDemBelegten() {
    #expect(DisclaimerText.reviewStatus == .draft)
    #expect(DisclaimerText.sections.count == 2)
    #expect(!DisclaimerText.version.isEmpty)

    let text = DisclaimerText.plainText
    // Beide von E07 verlangten Teile sind vorhanden.
    #expect(text.contains("verlässt dieses Gerät"))
    #expect(text.contains("OpenRouter"))
    #expect(text.contains("auf diesem Gerät gespeichert"))
    #expect(text.contains("Mandatsmaterial"))
    #expect(text.contains("vereinfacht"))
    #expect(text.contains("weder eine Ausbildung noch ein Studium"))
    #expect(text.contains("Entwurf"))

    // Keine rechtlichen Zusicherungen. Nichts davon ist geprüft, und E06 hält
    // ausdrücklich fest, dass nur die Weitergabe eingeschränkt wird, nicht die
    // Übermittlung.
    for verboten in ["DSGVO", "garantier", "anonym", "verschlüsselt", "gelöscht", "rechtssicher"] {
        #expect(!text.lowercased().contains(verboten.lowercased()), "\(verboten) steht im Text")
    }
}
