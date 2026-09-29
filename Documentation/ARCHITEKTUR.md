# Architektur des ersten Implementierungsstands

> **Hinweis vom 29.09.2026.** Der Abschnitt „Nächster verbindlicher Meilenstein" am Ende dieses
> Dokuments verlangt einen lokalen Modelladapter und schließt Cloud-Inferenz aus. Das gilt nicht
> mehr: die Modellaufrufe laufen über die OpenRouter-API, die eingegebenen Beratungsäußerungen
> verlassen also das Gerät. Der Rest dieses Dokuments — Abhängigkeiten, Turn-Transaktion,
> Persistenz, Datumscodierung — bleibt unverändert gültig, weil er nicht an der Modellherkunft
> hängt. Begründung und Grenzen in [ENTSCHEIDUNGEN.md](ENTSCHEIDUNGEN.md), E01 bis E03.

## Abhängigkeiten

SwiftUI → AppModel → ConversationCoordinator → TrainerModelProvider und SessionRepository.
Der Coordinator verwendet deterministische Validatoren, StateReducer, ContextBuilder und TipSelector aus TrainerCore. SwiftData liegt im separaten TrainerStorage-Paket, damit echte Speicherprüfungen ohne App-Start möglich sind. Beide lokalen Pakete werden vom Xcode-Projekt eingebunden.

Die normale Oberfläche bekommt nur das gespeicherte Ergebnis. Ein Turn besteht aus Eingabe, Einordnung, geprüfter Antwort, Zuständen davor/danach, ausgewähltem Tipp und tatsächlichen Messwerten. Offenheit und verborgene Fakten werden nicht als Bewertungsdaten angezeigt oder exportiert.

## Analyseadapter ab Prompt 0.5

Der OpenRouter-Adapter teilt die logische Einordnung in zwei getrennte Modellaufrufe:
Ziel-/Charakterbeobachtungen aus dem bisherigen Verlauf, danach Bewertung des aktuellen
Beratungssatzes. Die erste Stufe erhält die aktuelle Eingabe nicht. Beide nutzen dieselben
nummerierten Originalnachrichten; erst ihre geprüfte Zusammenführung wird als `TurnAnalysis`
an den Coordinator geliefert. Ohne Wiederholung sind es damit zwei Analyseaufrufe plus eine
Rollenantwort je Runde. Der höhere Aufwand ist eine bewusste Folge der Live-Befunde; Zeiten
und Prüfgrenzen stehen im neuesten [STATUS.md](STATUS.md).

Eine vollständig umschlossene einzelne JSON-Codehülle kann am Adapterrand entfernt werden.
Es werden keine Inhalte, Zitate oder Referenzen repariert; der vollständige Inhalt durchläuft
weiter die strikten Validatoren. Gedächtnis- und Beratungsschema bleiben getrennt. Neue
Charakterbeobachtungen dürfen unter dem Zielvertrag keinen neuen Zielverlauf ohne Zielereignis
anlegen. Alte optionale Daten bleiben lesbar; Fortsetzung nur mit passender Prompt-/Regelversion.

Die atomare Turn-Transaktion bleibt unverändert. Die frühe Rückmeldung erscheint nach der
geprüften logischen Einordnung und vor der Rollenantwort. Der Rollenprompt erhält weiterhin
nur sein normales Kontextfenster und keine Zielhypothesen. Die gespeicherten Analysemetriken
summieren die beiden erfolgreichen Teilaufrufe; fehlgeschlagene Versuche sind darin nicht
vollständig enthalten und dürfen nicht als vollständige Kosten- oder Wartezeitmessung gelten.

## Ausführung und Persistenz

1. Eingabe als PendingTurn mit UUID und erwarteter Revision sichern.
2. Einordnung anfordern und prüfen; höchstens ein automatischer Wiederholungsversuch.
3. Vorläufigen Zustand berechnen, ohne den gespeicherten Zustand zu verändern.
4. Nur verfügbare oder bereits erzählte Fakten an den Antwortanbieter geben.
5. Antwort prüfen; höchstens ein automatischer Wiederholungsversuch.
6. Vollständigen Turn atomar speichern und erst danach anzeigen.

Ein ungültiger Klassifikationsversuch darf nur auf ausdrückliche UI-Aktion übersprungen werden. Der Turn enthält dann keine Einordnung. Ein Speicherfehler hält den vorbereiteten Turn für einen identischen Commit-Versuch fest. Das gilt auch bei unklarem Ausgang des vorherigen Saves und für die letzte erlaubte Runde.

Der Coordinator ist ein Actor, prüft nach await-Grenzen zusätzlich seine Generation-ID und lässt höchstens eine aktuelle Operation zu. Die Oberfläche wartet beim Abbruch auf das Ende ihrer Operation, bevor sie eine neue startet. Ein verspätetes Ergebnis darf keine gelöschte Sitzung neu erzeugen.

SwiftData speichert einen versionierten SessionRecord mit eingefrorenem SessionContent, BuildIdentity und optionalem Entwurf. Der Speicher ist auf den Main Actor beschränkt und verwendet kein await innerhalb einer Transaktion; Autosave und CloudKit sind deaktiviert. Ein fehlgeschlagener Save führt zum Rollback, niemals zu einem stillen Löschen oder Neuerstellen des Stores.

## Präzisierungen gegenüber dem Bauplan

- **Speicherpaket:** SwiftData wurde aus dem App-Target in ein eigenes lokales Paket ausgelagert. TrainerCore bleibt unabhängig; der echte Store ist separat testbar.
- **Datumswerte:** Intern wird die verlustfreie JSONEncoder-Datumscodierung verwendet. ISO-8601-Text ohne präzise Bruchteile könnte Gleichheit und Commit-Idempotenz nach dem Wiederöffnen brechen. Der menschenlesbare Export nutzt ISO 8601.
- **Mac-Prüf-App:** Das Root-Swift-Paket baut dieselben UI-Quellen als Mac-Anwendung. Das ermöglicht Quell- und Ablaufprüfungen unabhängig von der iOS-Simulatorumgebung. Es belegt keine iPhone-Kompatibilität oder Modellleistung.
- **Inhalte:** Der Compiler unterstützt den tatsächlich vorhandenen Figuren-/Leitfadenbestand. Der Tippbestand ist leer. Ein zukünftiges Tippschema muss Quellen und Freigaben validieren, bevor ContentCatalog Tipps akzeptiert.
- **Lokale Daten:** Das Speicherverzeichnis wird vom Backup ausgeschlossen und auf iOS mit vollständigem Dateischutz eingerichtet. Die tatsächliche Wirkung auf einem gesperrten iPhone und in System-Backups muss noch am Gerät geprüft werden. Der Mac-Temporärordner lieferte in der Testumgebung keinen positiven Backup-Attributnachweis.

## Nächster verbindlicher Meilenstein

Ein realer lokaler Modelladapter hinter TrainerModelProvider. Dafür zuerst passende Xcode-/SDK-Version und den Ladeversuch klären. Keine ungetestete main-Abhängigkeit und keine automatisch heruntergeladenen Gewichte beim App-Start einbauen.

Vor einer Freigabe erforderlich: genaue Modellrevision und Lizenz, Datei-Hashes, lokaler Loader, gemeinsam gehaltene Gewichte für getrennte Einordnungs-/Rollenkontexte, echte Tokenzählung mit reserviertem Ausgabebudget, Cancellation, Offline-Erststart und Messungen auf iPhone 17. Ein am Mac recherchierter MLX-Release ist noch kein bestätigter Pin.

Erst nach ausreichender Rollen-/Einordnungsqualität: fachlich geprüfte Tipps, Sprache mit lokaler Transkription und Textkorrektur, PDF-Export, Tests auf älteren iPhones. Keine Cloud-Inferenz als stiller Ersatz.
