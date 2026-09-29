import Foundation
import Security
import Testing
import TrainerCore
@testable import TrainerDesktop

// Prüfungen rund um den hinterlegten OpenRouter-Schlüssel: Schlüsselbund, Maskierung der
// Anzeige, Abbildung der Prüfantwort und die Zustandslogik des Anbieterwechsels.
//
// Bewusst kein Test, der wirklich mit einem echten Schlüssel gegen OpenRouter spricht:
// Das setzte einen Schlüssel im Test voraus und hinge von der Gegenseite ab. Der
// Prüfaufruf selbst ist deshalb in eine reine Abbildung (Status beziehungsweise
// URLError-Code auf Ergebnis) und einen dünnen Netzteil getrennt.
//
// Die Schlüsselbundtests benutzen einen eigenen, pro Lauf einmaligen Dienstnamen und
// räumen ihn wieder ab. Sie fassen den echten Eintrag `rogersrodeo-openrouter` nicht an.

private func testService() -> String { "rogersrodeo-test-\(UUID().uuidString)" }

// MARK: - Schlüsselbund

@Test func schluesselbundSpeichertUeberschreibtLiestUndLoescht() {
    let service = testService()
    defer { OpenRouterKey.remove(service: service) }

    // Vorher liegt nichts da.
    #expect(OpenRouterKey.keychain(service: service) == nil)

    // Anlegen.
    #expect(OpenRouterKey.save("erster-wert-kein-echter-schluessel", service: service))
    #expect(OpenRouterKey.keychain(service: service) == "erster-wert-kein-echter-schluessel")

    // Überschreiben statt duplizieren: nach dem zweiten Sichern darf genau der neue Wert
    // gelesen werden. Läge ein zweiter Eintrag daneben, käme hier ein beliebiger von beiden.
    #expect(OpenRouterKey.save("zweiter-wert-kein-echter-schluessel", service: service))
    #expect(OpenRouterKey.keychain(service: service) == "zweiter-wert-kein-echter-schluessel")
    #expect(anzahlEintraege(service: service) == 1)

    // Löschen.
    #expect(OpenRouterKey.remove(service: service))
    #expect(OpenRouterKey.keychain(service: service) == nil)
}

/// Zählt die Einträge des Dienstes direkt über die Schlüsselbund-Schnittstelle, damit der
/// Duplikat-Fall nicht nur indirekt geprüft wird.
private func anzahlEintraege(service: String) -> Int {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecMatchLimit as String: kSecMatchLimitAll,
        kSecReturnAttributes as String: true
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return 0 }
    return (item as? [Any])?.count ?? 0
}

@Test func schluesselWirdBeimSichernBeschnittenUndLeerAbgelehnt() {
    let service = testService()
    defer { OpenRouterKey.remove(service: service) }
    #expect(!OpenRouterKey.save("   \n ", service: service))
    #expect(OpenRouterKey.keychain(service: service) == nil)
    #expect(OpenRouterKey.save("  wert-mit-rand  ", service: service))
    #expect(OpenRouterKey.keychain(service: service) == "wert-mit-rand")
}

@Test func loeschenOhneVorhandenenEintragGiltAlsErledigt() {
    // Für die nutzende Person ist „war nie da" dasselbe Ergebnis wie „jetzt weg".
    #expect(OpenRouterKey.remove(service: testService()))
}

@Test func sucheFindetDenGesichertenSchluessel() {
    let service = testService()
    defer { OpenRouterKey.remove(service: service) }
    #expect(OpenRouterKey.save("aus-dem-schluesselbund", service: service))
    // Ohne Umgebungsvariable kommt der Wert aus dem Schlüsselbund …
    #expect(OpenRouterKey.lookup(service: service, environment: [:]) == "aus-dem-schluesselbund")
    // … mit Umgebungsvariable behält diese den Vorrang.
    #expect(OpenRouterKey.lookup(service: service,
                                 environment: ["OPENROUTER_API_KEY": "aus-der-umgebung"]) == "aus-der-umgebung")
}

// MARK: - Maskierung

@Test func maskierungZeigtHoechstensDieLetztenVierZeichen() {
    let wert = "sk-or-v1-abcdefghijklmnop9xyz"
    let maske = OpenRouterKey.masked(wert)
    #expect(maske == "•••• 9xyz")
    // Der Schlüssel selbst darf nirgends mehr auftauchen.
    #expect(!maske.contains(wert))
    #expect(!maske.contains("sk-or-v1"))
    #expect(!maske.contains("abcdefghijklmnop"))
    // Kurze Werte werden vollständig verdeckt, sonst zeigte die Maske alles.
    #expect(OpenRouterKey.masked("abcd") == "••••")
    #expect(OpenRouterKey.masked("ab") == "••••")
    #expect(OpenRouterKey.masked("abcde") == "•••• bcde")
    // Randzeichen zählen nicht mit.
    #expect(OpenRouterKey.masked("  abcdefg  ") == "•••• defg")
}

@Test func angezeigterZustandKommtAusDerMaskeUndNichtAusDemWert() throws {
    let service = testService()
    defer { OpenRouterKey.remove(service: service) }
    #expect(OpenRouterKey.storedDisplay(service: service) == nil)
    #expect(OpenRouterKey.save("nicht-echt-2f7q", service: service))
    let anzeige = try #require(OpenRouterKey.storedDisplay(service: service))
    #expect(anzeige == "•••• 2f7q")
    #expect(!anzeige.contains("nicht-echt"))
}

// MARK: - Prüfung des Schlüssels

@Test func pruefungTrenntAbgelehntVonDienstproblem() {
    // Am 29.09.2026 selbst geprüft: /api/v1/key antwortet ohne gültige Anmeldung mit 401.
    #expect(OpenRouterKeyProbe.outcome(status: 200) == .accepted)
    #expect(OpenRouterKeyProbe.outcome(status: 401) == .rejected)
    #expect(OpenRouterKeyProbe.outcome(status: 403) == .rejected)
    for status in [404, 429, 500, 503] {
        #expect(OpenRouterKeyProbe.outcome(status: status) == .serviceProblem)
    }
}

@Test func fehlendeVerbindungIstEinEigenesErgebnis() {
    // „Schlüssel abgelehnt" und „kein Netz" sind für die nutzende Person verschiedene
    // Probleme und dürfen nicht dieselbe Meldung bekommen.
    for code: URLError.Code in [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                                .cannotConnectToHost, .dnsLookupFailed, .timedOut,
                                .internationalRoamingOff, .dataNotAllowed] {
        #expect(OpenRouterKeyProbe.outcome(urlErrorCode: code) == .offline)
    }
    #expect(OpenRouterKeyProbe.outcome(urlErrorCode: .badServerResponse) == .serviceProblem)
    #expect(OpenRouterKeyOutcome.offline.message != OpenRouterKeyOutcome.rejected.message)
    #expect(OpenRouterKeyOutcome.accepted.isSuccess)
    for ergebnis: OpenRouterKeyOutcome in [.rejected, .offline, .serviceProblem, .missing, .notStored] {
        #expect(!ergebnis.isSuccess)
        #expect(!ergebnis.message.isEmpty)
    }
}

@Test func keineRueckmeldungEnthaeltDenSchluessel() {
    // Die Meldungen sind feste Texte ohne eingesetzte Werte. Diese Prüfung hält das fest,
    // damit später niemand den Wert „zur besseren Diagnose" hineinschreibt.
    let wert = "sk-or-v1-geheimgeheimgeheim"
    let alle: [OpenRouterKeyOutcome] = [.accepted, .rejected, .offline, .serviceProblem, .missing, .notStored]
    for ergebnis in alle {
        #expect(!ergebnis.message.contains(wert))
        #expect(!ergebnis.message.contains("sk-or"))
    }
}

// MARK: - Zustandslogik des Umschaltens

@Test func wechselNurWennSichDieSchluessellageAendert() {
    // Demo-Betrieb und kein Schlüssel: nichts zu tun.
    #expect(!ProviderChange.make(hasKey: false, usesDemoResponses: true,
                                 busy: false, hasSession: false).changes)
    // Echtes Modell und Schlüssel vorhanden: ebenfalls nichts zu tun.
    #expect(!ProviderChange.make(hasKey: true, usesDemoResponses: false,
                                 busy: false, hasSession: false).changes)
}

@Test func neuerSchluesselWechseltAufDasEchteModell() {
    let plan = ProviderChange.make(hasKey: true, usesDemoResponses: true,
                                   busy: false, hasSession: false)
    #expect(plan == ProviderChange(switchesToDemo: false,
                                   cancelsRunningOperation: false, closesOpenSession: false))
}

@Test func entfernterSchluesselWechseltZurueckInDieDemo() {
    let plan = ProviderChange.make(hasKey: false, usesDemoResponses: false,
                                   busy: false, hasSession: false)
    #expect(plan.switchesToDemo == true)
}

@Test func laufendeOperationUndOffeneSitzungWerdenVorDemWechselBeendet() {
    // Mitten in einem Turn darf nicht getauscht werden: erst abbrechen und abwarten,
    // dann die Sitzung mit gesichertem Entwurf schließen, dann wechseln.
    let plan = ProviderChange.make(hasKey: true, usesDemoResponses: true,
                                   busy: true, hasSession: true)
    #expect(plan.switchesToDemo == false)
    #expect(plan.cancelsRunningOperation)
    #expect(plan.closesOpenSession)
    // Ohne Wechsel wird nichts abgebrochen, auch wenn gerade etwas läuft.
    let ohne = ProviderChange.make(hasKey: true, usesDemoResponses: false,
                                   busy: true, hasSession: true)
    #expect(!ohne.changes)
    #expect(!ohne.cancelsRunningOperation)
    #expect(!ohne.closesOpenSession)
}

@Test func alteSitzungMitFremderKennungGiltAlsNichtFortsetzbar() {
    let demo = schnappschuss(identity: DemoModelProvider.identity, status: .active)
    let echt = OpenRouterModelProvider().descriptor()
    // Gewollt: nach dem Wechsel lässt sich eine Demo-Sitzung nicht mehr fortsetzen.
    // Der Hinweis kommt beim Öffnen, damit er vor dem Tippen steht.
    #expect(!ProviderChange.mayContinue(demo, with: echt))
    #expect(ProviderChange.mayContinue(demo, with: DemoModelProvider.identity))
    // Eine abgeschlossene Sitzung wird nur nachgelesen und braucht keine Warnung.
    let abgeschlossen = schnappschuss(identity: DemoModelProvider.identity, status: .completed)
    #expect(ProviderChange.mayContinue(abgeschlossen, with: echt))
}

private func schnappschuss(identity: ModelDescriptor, status: SessionStatus) -> SessionSnapshot {
    let scenario = ScenarioDefinition(schemaVersion: 1, id: "lukas", version: "1", status: .draft,
                                      name: "Lukas", age: 24, address: "du", approaches: ["mi"],
                                      opennessStart: 2, openingLine: "Hallo.", publicProfile: "P",
                                      facts: [])
    return SessionSnapshot(schemaVersion: 1, id: UUID(), revision: 0, approachID: "mi",
                           identity: .init(contentHash: "h", rulesVersion: "0.1",
                                           promptVersion: "0.1", model: identity),
                           content: .init(scenario: scenario, codingGuide: "G", tips: []),
                           state: .init(openness: 2), turns: [], status: status, startedAt: Date())
}
