# Architektur des ersten Implementierungsstands

> **Hinweis vom 29.09.2026.** Der Abschnitt „Nächster verbindlicher Meilenstein" am Ende dieses
> Dokuments verlangte einen lokalen Modelladapter und schloss Cloud-Inferenz aus. Das gilt nicht
> mehr; der Abschnitt ist auf den heutigen Stand umgearbeitet, der alte Text steht dort als
> Verlauf. Die Modellaufrufe laufen über die OpenRouter-API, die eingegebenen Beratungsäußerungen
> verlassen also das Gerät. Der Rest dieses Dokuments — Abhängigkeiten, Turn-Transaktion,
> Persistenz, Datumscodierung — bleibt unverändert gültig, weil er nicht an der Modellherkunft
> hängt. Begründung und Grenzen in [ENTSCHEIDUNGEN.md](ENTSCHEIDUNGEN.md), E01 bis E03.

## Abhängigkeiten

SwiftUI → AppModel → ConversationCoordinator → TrainerModelProvider und SessionRepository.
Der Coordinator verwendet deterministische Validatoren, StateReducer, ContextBuilder und TipSelector aus TrainerCore. SwiftData liegt im separaten TrainerStorage-Paket, damit echte Speicherprüfungen ohne App-Start möglich sind. Beide lokalen Pakete werden vom Xcode-Projekt eingebunden.

Die normale Oberfläche bekommt nur das gespeicherte Ergebnis. Ein Turn besteht aus Eingabe, Einordnung, geprüfter Antwort, Zuständen davor/danach, ausgewähltem Tipp und tatsächlichen Messwerten. Offenheit und verborgene Fakten werden nicht als Bewertungsdaten angezeigt oder exportiert.

## Analyseadapter ab Prompt 0.8

Der OpenRouter-Adapter führt Beratungseinordnung und Ziel-/Charakterbeobachtungen parallel aus.
Beide sehen dieselben nummerierten Originalnachrichten; die Zielanalyse erhält die aktuelle
Beratereingabe nicht. Ihre Belege werden unabhängig geprüft. Fehlerhafte Modellantworten,
Transportausfälle oder Verweigerungen dieser ergänzenden Stufe verwerfen nur deren Ergebnis.
Nach zwölf Sekunden wird eine noch laufende Zielanalyse abgebrochen. Diese Zeitgrenze ist eine
Produktentscheidung, keine gemessene fachliche Erfolgsquote. Ein globaler Abbruch wird weiterhin
propagiert, niemals als Teilerfolg gespeichert.

Die Beratungseinordnung bleibt strikt validiert: Fehlende Erlaubnisbelege, ungültige Zitate oder
fehlerhafte Segmente führen weiterhin zu Fehler und ggf. Coordinator-Wiederholung. Eine defekte
Zielanalyse allein wiederholt keine gültige Beratungseinordnung. Auch erst am vorhandenen
Zielzustand erkennbare Referenzfehler werden im Coordinator auf den Zielteil begrenzt. Der bisherige
Ziel-/Beziehungszustand bleibt dann unverändert; `memoryStatus=unavailable` und leere Ziel-/
Beobachtungslisten dokumentieren den Ausfall dauerhaft. Der Markdown-Export benennt ihn.
Alte Analysen ohne dieses optionale Metadatum bleiben lesbar. Das Modell darf den Laufzeitstatus
nicht selbst liefern. Es werden keine Zitate oder Referenzen repariert.

Die atomare Turn-Transaktion bleibt unverändert. Die frühe Rückmeldung erscheint nach der
geprüften Einordnung und vor der Rollenantwort. Der Rollenprompt erhält weiterhin sein normales
Kontextfenster und keine Zielhypothesen. Die Analysemetrik enthält die tatsächlich verstrichene
Zeit beider parallelen Aufgaben. Tokenzahlen werden nur addiert, wenn beide erfolgreichen
Teilaufrufe sie melden; bei fehlender Zielanalyse bleiben sie unbekannt. Die gesonderte Messspur
enthält auch Fehlversuche und abgebrochene Aufrufe. Keine dieser Tokenangaben ersetzt eine
vollständige Abrechnung des Anbieters, insbesondere nach Abbruch.

Prompt 0.8 und Inhaltsleitfaden 0.3 unterscheiden den neuen Stand von bisherigen Sitzungen.
Regeln 0.5 und Rückmeldungsbausteine 0.3 bleiben unverändert. Offene alte Sitzungen können wegen
der Versionsbindung weiterhin gelesen/exportiert, aber nicht unter geändertem Prompt fortgesetzt
werden. Rollenprompt und Providerbeschränkungen bleiben erhalten.

Seit E09 verwenden Figur und beide Analysestufen `anthropic/claude-sonnet-5.5`. Sonnet benötigt internes Überlegen; das Feld wird ausgelassen,
um die Vorgabe des Endpunkts zu verwenden. Das gemessene Ausgabebudget ist 4000, bei
Abschneidung einmalig 8000 Token. Das Rollenbudget bleibt 2000/4000. Sonnet 5.5 erhält keinen `temperature`-Parameter;
der Anbieter lehnt ihn inzwischen ab (E09, Nachtrag vom 12.10.2026).
Kein stiller Modellfallback: eine nicht verfügbare Berateranalyse bleibt ein Fehler.
Die zusammengesetzte Sitzungsidentität enthält Rollen- und Analysemodell; die Messspur
nennt je HTTP-Aufruf das tatsächlich angeforderte Modell. `analysisModel=nil` aktiviert
nur für ausdrücklich konfigurierte Vergleiche wieder die historischen gemeinsamen Einstellungen.

Die Anthropic-Analyseschemata verwenden gemeinsame Belegdefinitionen (`$defs`/`$ref`).
Die wiederholten nullable Objekte überschritten sonst die Grammatikgrenze des Anbieters.
Die Anfrage serialisiert Gesprächssegmente vor den davon abhängigen Erlaubnisbelegen und
Zitate vor deren Codes. Die JSON-Bedeutung, Pflichtfelder und lokale Validierung bleiben
erhalten. Gesprächsdaten werden weiterhin durch JSONEncoder maskiert. Der Leitfaden prüft
positive Codes gegen den gesamten Beitrag und trennt eigenständige Ratschläge und Abwertungen.

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

Hinter `TrainerModelProvider` steht der OpenRouter-Adapter unter
`Beratungstrainer/Services/Models/OpenRouterModelProvider.swift`. Er ist gebaut, gegen die
Schnittstelle gemessen und in `AppModel` verdrahtet; ohne hinterlegten Schlüssel greift der
Demo-Provider. Offen bleiben: Lauf im Simulator und auf einem echten Gerät, eine Frist je Runde
statt nur je Aufruf, `provider.data_collection: "deny"` nach E06, der einmalige Disclaimer nach
E07 sowie vollständige Kosten- und Routenerfassung. Die Einzelpunkte stehen in
[TODO.md](TODO.md), der geprüfte Stand in [STATUS.md](STATUS.md).

Erst nach ausreichender Rollen-/Einordnungsqualität: fachlich geprüfte Tipps, Sprache mit
Transkription und Textkorrektur, PDF-Export, Tests auf älteren iPhones.

### Historisch: der abgelöste lokale Meilenstein

Der folgende Absatz galt bis zum 29.09.2026 und ist durch E01 vollständig abgelöst. Er bleibt als
Verlauf stehen, ist aber keine Anweisung mehr — insbesondere das Verbot am Ende gilt nicht mehr.

> Ein realer lokaler Modelladapter hinter TrainerModelProvider. Dafür zuerst passende Xcode-/SDK-Version und den Ladeversuch klären. Keine ungetestete main-Abhängigkeit und keine automatisch heruntergeladenen Gewichte beim App-Start einbauen.
>
> Vor einer Freigabe erforderlich: genaue Modellrevision und Lizenz, Datei-Hashes, lokaler Loader, gemeinsam gehaltene Gewichte für getrennte Einordnungs-/Rollenkontexte, echte Tokenzählung mit reserviertem Ausgabebudget, Cancellation, Offline-Erststart und Messungen auf iPhone 17. Ein am Mac recherchierter MLX-Release ist noch kein bestätigter Pin.
>
> Erst nach ausreichender Rollen-/Einordnungsqualität: fachlich geprüfte Tipps, Sprache mit lokaler Transkription und Textkorrektur, PDF-Export, Tests auf älteren iPhones. Keine Cloud-Inferenz als stiller Ersatz.


## MI-04a · Verknüpfte Termine (13.10.2026)

`SessionSnapshot` ergänzt optionale Felder für Eröffnungszeile, Fallfortsetzung und Folgetermin-ID.
JSON-Schema 1 und das SwiftData-Tabellenschema bleiben kompatibel lesbar. Neue App-Sitzungen
beginnen mit „Hallo.“; alte Sitzungen behalten ihre gespeicherte Eröffnung. Prompt 1.3 markiert
den Termin-Kontext. Eine abgeschlossene Sitzung mit passendem Modell, Inhalt und Regeln kann
explizit in einen neuen Termin mit aktuellem Prompt überführt werden. Eine aktive Sitzung mit
älterem Prompt wird weiterhin nicht still fortgesetzt.

`VisitBuilder` erstellt eine kurze Notiz aus den letzten zwei Originalantworten und höchstens
drei Zielgruppen mit Originalbelegen, Status, eventuellem Vorschlag und letzter Zielaussage.
Unsicherheit bleibt sichtbar, fehlende Vereinbarungen oder konkrete nächste Schritte werden
nicht ergänzt. Die Notiz erscheint vor dem Anlegen des Termins und wird im Kind gespeichert.
Die letzte Figurenantwort kann neuer als der gespeicherte Zielstand sein; sie steht deshalb
als Originalzitat in der Notiz und wird im Folgetermin erneut analysiert.

Das Repository legt Kind und Folgetermin-Verweis im abgeschlossenen Elterntermin in einer
Transaktion an. Der Elternverweis verändert weder dessen Gesprächsrunden noch dessen
Turn-Revision. Wiederholungen liefern dieselbe Kind-ID und denselben tatsächlichen Startzeitpunkt.
Sitzungsnummer und fiktionale Woche hängen allein von der Terminfolge ab, nicht von Gerätezeit.
Nach Runde 20 werden Status und Endzeit zusammen mit dem Turn gespeichert. Ein vorzeitiger
manueller Abschluss ermöglicht ebenfalls den nächsten Termin nach einer fiktionalen Woche.

Ziel-/Beziehungsbeobachtungen, Offenheit und bereits erzählte Fakten werden beibehalten.
Rundenbezogene Fragenfolgen, Bonusgedächtnis und Ratserlaubnis beginnen neu. Eine alte Zustimmung
oder direkte Bitte kann keine aktuelle Ratserlaubnis begründen; die Prüfung kontrolliert ihre
Herkunft auch dann, wenn historische Originaltexte im Kontext stehen.

Frühere Termine werden als Originaltextarchive im Kind mitgeführt, damit Zielbelege und deren
Ereignisreihenfolge weiterhin unabhängig prüfbar sind. Alte Eröffnungsbelege erhalten eine
Sitzungs-ID; Turn-UUIDs behalten ihre Herkunft. Die Archive enthalten ausschließlich bereits
sichtbare Gesprächszeilen. Der Modellkontext enthält höchstens sechs Grundrunden (zu Beginn
höchstens zwei aus dem vorherigen Termin), bis zu drei Zielgruppen und höchstens sechs zusätzliche
Beleggruppen / 10.000 Zeichen. Frühere und aktuelle Termine sind im Prompt gekennzeichnet.
Die Rolle erhält Originaltexte, keine Analyseetiketten oder Bereitschaftswerte.

Grenzen: Die Originaltextarchive werden pro Folgetermin dupliziert; der persistierte Nachweisbestand
wächst mit der Falllänge, auch wenn der Modellkontext begrenzt bleibt. Die bestehenden Grenzen
von 40 Zielgruppen und 60 Zielereignissen werden nicht angehoben. Vor längeren Fallserien braucht
es einen gesonderten Speicher-/Gedächtnisnachweis und gegebenenfalls eine normalisierte Fallablage.
Die Löschaktion benennt daher ausdrücklich den gesamten verknüpften Fall und entfernt alle
Termine samt Archivkopien. Keine automatisch erfundenen Wochenereignisse oder Maintenance.


## MI-04b · Vorhaben, Erfahrungen und kuratierte Episode (13.10.2026)

Prompt 1.4 erweitert den vorhandenen optionalen Ziel-/Charakteraufruf um die verpflichtende
Liste `narrativeObservations`. Die Beratungseinordnung und der Rollenvertrag behalten ihr
Schema. Alte gespeicherte Analysen und Zustände haben optionale Felder und bleiben lesbar;
neue Transportantworten sind strikt dreiteilig. Ein Fehler im Erfahrungsbeleg verwirft nur
die neue optionale Erinnerung, nicht die gültige Beratungseinordnung.

`NarrativeMemory` enthält belegte Ideen, selbst gewählte konkrete Vorhaben und Berichte über
Versuch, einmalige/teilweise Umsetzung, Nichtumsetzung, Schwierigkeit oder Widerruf. Herkunft,
Unsicherheit, Analyse-Turn und gegebenenfalls ein exakt bekannter Planbeleg werden gespeichert.
Beratertexte sind keine Erfahrung der Figur; Ausführung wird nicht aus Absicht abgeleitet.
Derselbe Originalbeleg erzeugt keine zweite Beobachtung und wird nicht still neu interpretiert.
Neue Records werden zusammen mit dem Turn atomar gespeichert. Bei einem Planbezug muss der
Plan bereits bekannt und zeitlich vor dem Erfahrungsbeleg sein. Die bestehenden Grenzen werden
um einen getrennten, ebenfalls begrenzten Bestand von höchstens 60 Erfahrungsrecords ergänzt.
Bis zu drei Vorhaben-/Erfahrungsgruppen teilen sich mit Zielbelegen das vorhandene zusätzliche
Kontextbudget. Die Rolle bekommt weiterhin keine Analyseetiketten oder Bereitschaftswerte.

`BetweenVisitExperience` speichert für Lukas den konkreten Originalplan, eine Variante und
vor allem den eingefrorenen Szenariotext mit Katalogkennung `0.1-draft`. `ExperienceSelector`
wählt nur einen sicheren Plan aus dem gerade abgeschlossenen Termin, ohne bereits berichteten
Ausgang oder Widerruf. Eine bekannte Zielrücknahme/-ersetzung schließt dessen Episode aus.
Fall-ID und Originalbeleg verteilen die drei Varianten reproduzierbar; das ist keine fachliche
Wahrscheinlichkeit oder Belohnung für Beratungscodes. Der Variantenausgang ändert weder
Offenheit noch Ziel-/Beziehungsbeobachtungen. Ohne Plan gibt es keine Episode.

Ein schon analysierter Plan erzeugt die Episode in der atomaren Folgetermin-Erstellung.
Ein erst in der letzten Antwort formulierter Plan kann im ersten regulären Analyseaufruf des
Kindtermins erkannt werden. Dann erhält nur die bevorstehende Rolle den Zwischenverlauf;
`CompletedTurn.introducedExperience` und der Folgetermin sichern ihn gemeinsam beim Commit.
Antwortfehler oder Abbruch speichern keine halbe Episode. Ein identischer Commit ist weiterhin
idempotent; die Variante ist auch vor dem erfolgreichen Retry aus denselben Belegen reproduzierbar.
Das Repository validiert Quelle und Auswahl zusätzlich gegen die unveränderten Originaltexte.

Die vorbereitende Notiz und die Analyseprompts enthalten keinen unveröffentlichten Ausgang.
Die Figur erzählt die vorgegebene Erfahrung bei passender Erkundung, ohne schwere Zusatzereignisse,
Konsummengen, neue Abstinenzpflicht oder erfundene Stabilitätsdauer. Erst ihr tatsächlicher
Selbstbericht kann zur nächsten belegten Erfahrungsbeobachtung werden. Dadurch beeinflusst eine
noch ungesprochene Rollenreaktion nicht die Rückmeldung zum Beraterbeitrag. Einmalige Umsetzung
ist kein Maintenance-Status. Die Varianten und die Modellklassifikation bleiben fachliche Entwürfe.

## MI-04c · Längerer Verlauf und Fallende (24.10.2026)

Grundlage: E11 samt Nachträgen und `MI-04c-Verlaufskatalog.md`. Code in
`CaseProgression.swift` und `BetweenVisitExperience.swift`.

- **Abstand:** `CaseContinuity` speichert `intervalWeeks` und `fictionalWeek` seit Fallbeginn;
  `PriorSession` behält seine Woche. Vor einer belegt berichteten Umsetzung ist nur eine Woche
  erlaubt, danach 1, 2, 3, 4, 6, 8 oder 13 Wochen. `IntervalSuggestion` sucht in den letzten
  drei Runden wörtliche Angaben („in vier Wochen“, „in einem Monat“) als Vorschlag; die übende
  Person bestätigt in der Vorbereitung. Ältere Termine ohne Angabe gelten als wöchentlich.
- **Fortsetzungsverläufe:** Nach einer sicheren Umsetzung seit dem letzten Bruch wählt der
  Selektor aus vier festen Mustern (Katalog 0.2-draft), gebunden an Fall-ID und Zahl der Brüche,
  nie an Offenheit oder Beratungsqualität. Bezug ist das jüngste nicht zurückgenommene
  Vorhaben, auch ein verändertes. Frühere Episoden stehen in `pastExperiences`.
- **Kette bis Maintenance:** `MaintenanceProgress` wertet nur sichere Einordnungen nach dem
  Termin aus, in dem Lukas sie gesagt hat: `continued` zählt, `withdrawn` und `notAttempted`
  setzen zurück, ein `setback` ohne Weitermachen lässt die Kette ruhen und gilt als bewältigt,
  sobald Lukas weitermacht. Erfüllt bei drei Berichten über mindestens 13 Wochen mit Schwierigkeit.
- **Fallende:** `closeCase` setzt `caseClosure` am letzten abgeschlossenen Termin; das Ergebnis
  folgt allein aus der Kette. Danach keine Folgetermine. `CaseReview` baut den Fallrückblick aus
  dem letzten Termin, der alle früheren Originaltexte enthält.
- **Rolle:** Lukas erhält seinen Abstandswunsch und darf den Abschluss selbst ansprechen.
  Analyse, Vorbereitung und Rückblick kennen beides nicht.
- **Grenzen:** Jeder Termin kopiert weiterhin alle früheren Originaltexte. Für sehr lange
  Fallserien ist das nicht gemessen; die Kontextgrenzen der Analyse bleiben unverändert.
