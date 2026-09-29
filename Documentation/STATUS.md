# Tatsächlich geprüfter Stand

Neueste Prüfungen zuerst. Ältere Abschnitte bleiben als Verlauf erhalten und werden nicht
rückwirkend umgeschrieben.

## 30. September 2026 · Erlaubnisablauf mit Speicherneustart geprüft

Auf Basis `2e71356` wurde die bislang fehlende Verknüpfung von Erlaubnisanalyse,
ConversationCoordinator und echtem SwiftData-Speicher mit kontrollierten fiktiven
Modellantworten getestet. Es waren keine Änderungen am Anwendungscode erforderlich.
Neue Tests: `Packages/TrainerStorage/Tests/TrainerStorageTests/PermissionFlowTests.swift`.

Der erste Test durchläuft fünf abgeschlossene Runden: Erlaubnisfrage → ein Ratschlag →
zweiter Ratschlag mit verbrauchter Zustimmung → neue Frage → Rat nach neuer Zustimmung.
Dazwischen werden Repository und Coordinator freigegeben und gegen dieselbe Store-Datei
neu erzeugt. Eine absichtlich ungültige Figurenantwort vor dem ersten Rat darf keinen
halben Turn speichern; PendingTurn bleibt über das erneute Öffnen erhalten und wird bei
erfolgreicher Wiederholung mit derselben Kennung abgeschlossen. Gespeicherte Analyse,
Erlaubnisbelege und Rückmeldungen bleiben exakt erhalten. Der identische Commit ist
idempotent, nachträglich veränderte Erlaubnisdaten werden abgewiesen. Die frühe Rückmeldung
kommt vor der Figurenantwort. Der Prüfanbieter führt kein eigenes Erlaubnisgedächtnis.

Der zweite Test nutzt das wirkliche Sechs-Runden-Kontextfenster. Dieselbe sicher vorgegebene
Modelleinschätzung „nicht eingeholt“ ergibt bei vollständig bekanntem Gespräch eine sichere
Warnung, nach sieben Runden mit ausgelassenem Kontext dagegen nur einen möglichen Befund.
Die Testantworten sind vorgegeben; damit wird weiterhin keine semantische Modellqualität
behauptet. Auch ein neuer Prozess oder ein Start auf dem iPhone wurde nicht simuliert.

Ausgeführte Prüfungen: TrainerStorage **5 Tests**, TrainerCore **100 Tests**, `swift build`:
alle Exit 0. Volle Logs und direkt erfasste Exitcodes unter
`/private/tmp/rr-codex-permission-flow-7vh2ztch/` (`storage-2.log`, `result-2.json`,
`core.log`, `build.log`, `checks.json`). Der erste Versuch scheiterte an verschachtelten
Testmakros im neuen Testcode; nach deren Korrektur bestand der vollständige Speichertestlauf.
`RR_RUN_GOAL_LIVE` und `RR_MODEL_TRACE_FILE` waren entfernt; kein Keychain-/Netzzugriff
durch diese Prüfungen. App- und iOS-Buildnachweise des vorigen Schritts gelten unverändert
für den Anwendungscode; sie wurden hier nicht erneut als neue Läufe ausgegeben.

Jonas hat die vorgelegte Rollenprobe ausdrücklich akzeptiert. Seine Bemerkung zum etwas
ungewöhnlichen Satz „Können wir nicht einfach über meinen Konsum reden?“ ist keine
Änderungsanforderung. Rollenprompt und Rollenverhalten bleiben deshalb unverändert.
Kein Push, kein Merge ins Hauptrepo; ein dauerhaftes Erlaubnisgedächtnis bleibt offen.

## 30. September 2026 · Unabhängige Abnahme des begrenzten Erlaubnisschritts

Codex hat Claudes Commit `ea4c178` in den eigenen Prüf-Worktree übernommen
(`codex/mi03-erlaubnis-pruefung`, Übernahmecommit `f967920`). Hauptrepo unverändert auf
`claude/integration-probe` / `ab66292`; kein Push und kein Merge ins Hauptrepo.

Die drei unabhängig reproduzierten Validatorfehler aus dem ersten Entwurf wurden korrigiert.
Dieselben Gegenproben bestehen anschließend mit Exit 0; ihre geprüften Core-Quellen sind
bytegleich mit dem Implementierungscommit. Codex hat zusätzlich den Gegenstandsbezug im
Prompt ausdrücklich benannt und zwei kontrollierte Adapterfälle ergänzt: Zustimmung zu
Notizen legitimiert keinen Rat zur Beziehung; Zustimmung zum Sammeln eigener Ideen auf
einem Blatt legitimiert keine Berateridee. Das ist eine technische Prüfung mit vorgegebenen
Modelleinschätzungen, kein Nachweis zuverlässiger semantischer Modellerkennung.

Unabhängige lokale Prüfungen, alle Exit 0:

- TrainerCore: 100 Tests; TrainerStorage: 3 Tests.
- App: zunächst 72, nach Codex' Ergänzung 73 Tests; beide Live-Tests deaktiviert/übersprungen.
- `swift build` erfolgreich, nach der Prompt-/Testergänzung erneut erfolgreich.
- `xcodebuild` für `generic/platform=iOS Simulator`, ohne Codesignierung: erfolgreich,
  nach der Ergänzung erneut erfolgreich. Kein Start der Oberfläche und kein Gerätetest.
- `git diff --check` erfolgreich; TrainerCore importiert weiterhin ausschließlich Foundation.
  ModelTrace, atomarer Turn-Commit, Rollenverhalten und Offenheitsregel bleiben erhalten.

Vollständige Befehle, direkt erfasste Prozess-Exitcodes und Logs liegen unter
`/private/tmp/rr-codex-permission-zuuawwxr/` (`results.json`, `results-final.json`) und
`/private/tmp/rr-codex-permission-ios-8mbnh845/` (`result.json`, `result-final.json`).
Gegenproben: `/private/tmp/rr-codex-counterprobe-tlrf79n1/`, fachlicher Fehlernachweis
`probe-3.log`/`result-3.json`, erfolgreiche Wiederholung `probe-4.log`/`result-4.json`.
Die beiden früheren Gegenprobenversuche scheiterten am Test-Compile und zählen nicht als
fachlicher Fehlernachweis. Die übergebenen fünf Keychain-Tests plus
`leererUmgebungswertZaehltNicht` wurden bei der Implementierungsprüfung ausgeschlossen;
`RR_RUN_GOAL_LIVE` und `RR_MODEL_TRACE_FILE` wurden aus der Prozessumgebung entfernt.

Auch die Basis `ab66292` wurde unabhängig geprüft: 81 Core-, 3 Storage-, 71 App-Tests,
Swift-Build und iOS-Kompilierung erfolgreich. Dort enthielt die übergebene Ausschlussliste
noch nicht den sechsten Keychain-Test: er fragte das Fehlen eines fiktiven Testdienstes ab.
Deshalb keine Behauptung eines vollständig Keychain-freien ersten Basislaufs. Basislogs:
`/private/tmp/rr-codex-baseline-hjoq8q5m/`.

Die Abnahme betrifft den begrenzten technischen Schritt im verfügbaren Kontext. Fachliche
Freigabe der Entwurfstexte, Live-Prüfung des neuen Vertrags, freie Rollenqualität und UI-/
iPhone-Prüfung bleiben offen. Alte Sitzungen sind lesbar/exportierbar, wegen der erhöhten
Prompt-/Regelversion aber nicht fortsetzbar. MI-04 bleibt geplant.

### Nachtrag zur bereits bezahlten Messung vom 29. September

Vorhandene Artefakte wurden nur gelesen, kein neuer OpenRouter-Aufruf ausgeführt. Der Lauf
auf `79dd498` mit `python3 Tools/run_goal_memory_live.py long` bestand 15/15 Runden und
14/14 Erwartungen, Exit 0. Prozessdauer inklusive Build: 199,431675 Sekunden. Die Messspur
enthält 34 gestartete und 34 abgeschlossene Aufrufe; gemeldete Kosten insgesamt
0,0234130391 USD. Wiederholungen sind darin enthalten. `usage.include=true` war in dieser
Stichprobe mit den Anbieterfiltern routbar; keine allgemeine Routengarantie und kein
Rechnungsabgleich. Das waren echte Analysen mit vorgegebenen Rollenreaktionen, keine
Prüfung freier Rollenqualität und kein Nachweis für den neuen Erlaubnisvertrag.

Artefakte unverändert zusammen unter
`/Users/jonasortmanns/Developer/Agents/codex/worktrees/messung/Evaluation/results/goal-live-20260929T215102Z-5c1ecf2c/`.
`model-calls.jsonl` und `model-calls.jsonl.run.json` gehören zusammen.

## 30. September 2026 · MI-03-Teilschritt: Erlaubnis vor einem Ratschlag

Branch `claude/mi03-erlaubnis`, Basis `ab66292`. Kein Modellaufruf, kein Push, keine
Änderung an E07 oder den MI-04-Entscheidungen. MI-04 ist weiterhin nur geplant.

### Zwei Festlegungen von Jonas

1. „Generell gilt eine Erlaubnis in so einem Kontext nur für die aktuelle Situation." Der
   gleiche Gegenstand trägt eine Zustimmung also nicht in eine spätere Gesprächssituation;
   es gibt keine pauschale und keine dauerhafte Erlaubnis.
2. „Wenn ich jemanden frage, ob ich ihm einen Ratschlag geben darf und er sagt ja, dann gebe
   ich ihm 1! Ratschlag." Danach ist die Zustimmung verbraucht — auch beim selben Thema, auch
   in derselben Situation und auch dann, wenn beide Ratschläge im selben Beitrag stehen.

Beides steht jetzt als verbindliche Regel im Analysevertrag und im Prompt. Unverändert offen
bleibt die strengere Produktfrage aus Abschnitt 13: ob nach einer direkten Bitte wie „Welchen
Vorschlag haben Sie?" zusätzlich rückversichert werden muss. Diese Bitte erzeugt deshalb
weiterhin keinen Vorwurf.

### Was jetzt geschieht

`TurnAnalysis.permissions` ist eine Einschätzung je Ratschlagssegment des gesendeten Beitrags
mit neun möglichen Lagen: erteilt, bereits verbraucht, frühere Situation, abgelehnt,
widerrufen, im selben Beitrag gefragt, vom Klienten erbeten, nicht eingeholt, unklar. Das
Modell trifft die semantische Einschätzung und muss sie mit wörtlichen Belegen ausweisen;
`OutputValidator.validatePermissions` prüft ausschließlich Nachprüfbares: Herkunft, Sprecher,
Reihenfolge, Zitate, Zuordnung zum Segment, Widerspruch zum Segmentcode und die
Wiederverwendung derselben Zustimmung. Es gibt bewusst keine Stichwortliste, die „ja" oder
„Darf ich" als Erlaubnisdetektor benutzt, und keine Turnzahl als fachliche Regel.

Daraus entstehen Rückmeldungen mit eigenen Textbausteinen (alle `reviewStatus: .draft`):
belegte Erlaubnis und Vorschlag auf Bitte als Rückmeldung, dazu Warnungen für nicht
abgewartete Antwort, Rat trotz Ablehnung, Rat nach Widerruf, verbrauchte Zustimmung und
Zustimmung aus einer früheren Situation. Unsicherheit — gemeldet oder ergänzt — führt immer
in dieselbe zurückhaltende Formulierung, also weder Lob noch Vorwurf.

### Grenzen, die absichtlich so gezogen sind

- **Ein Ja, ein Ratschlag, strukturell geprüft.** Eine Zustimmung wird über die Nachricht
  geführt, nicht über die Zeichenfolge des Zitats: „Ja, gerne." und „gerne" sind dieselbe
  Zusage und tragen zusammen genau einen Ratschlag. Ein zweiter Ratschlag muss als
  „bereits verbraucht" ausgewiesen werden und den aufbrauchenden früheren Ratschlag zitieren;
  im selben Beitrag muss dieser in einem vorangehenden Ratschlagssegment liegen, das genau
  diese Zustimmung genutzt hat. Eine vorangehende Frage verbraucht nichts.
- **Situationsbezug bleibt semantisch.** Ob dieselbe Zustimmung noch zur aktuellen Situation
  gehört, entscheidet das Modell mit Belegen. Strukturell geprüft wird nur eine Vorsichtsregel:
  Sicher ist eine Zustimmung nur, wenn sie die letzte Nachricht des gesehenen Kontexts ist.
  Steht danach noch etwas, bleibt die Einschätzung unsicher — der eine erlaubte Ratschlag
  könnte dort schon gefallen, die Situation weitergezogen oder die Zustimmung zurückgenommen
  worden sein. Diese Regel nimmt nur Sicherheit aus einem Freispruch; sie erzeugt nie einen
  sicheren Vorwurf.
- **Kontextlücke bleibt Lücke.** „Nicht eingeholt" wird nur dann ein sicherer Befund, wenn der
  Analyse das ganze bisherige Gespräch vorlag; `ContextBuilder.covers` prüft das über die
  dauerhafte Herkunft jeder Nachricht, nicht über ihre Anzahl. Sonst bleibt es bei „möglich".
  Dasselbe gilt für einen Ratschlag ganz ohne Erlaubniseinschätzung, etwa aus einer älteren
  Analyse. Belegte Vorwürfe wie Ablehnung oder Widerruf bleiben dagegen sicher: Sie stützen
  sich auf ein vorhandenes Zitat und nicht auf ein Schweigen.
- **Kein dauerhaftes Erlaubnisgedächtnis.** Dieser Schritt arbeitet ausschließlich auf dem
  tatsächlich gesehenen Kontext. Ein über das Kontextfenster hinaus belegter Erlaubnisverlauf
  nach dem Vorbild des Zielgedächtnisses — mit sitzungsstabiler Herkunft im `SimulationState`
  — ist ein eigener zweiter Schritt und ausdrücklich noch nicht gebaut. Bis dahin ist eine
  weiter zurückliegende Zustimmung unsicher statt sicher fortgeschrieben.
- Rollenverhalten, Offenheitsmodell, `StateReducer` und die Tippauswahl sind unverändert.
  Die Figurenantwort entsteht weiterhin nach der Rückmeldung und kann sie nicht färben.

### Versionen und Bestandsdaten

Prompt 0.6, Regeln 0.5, Textbausteine 0.3. Ältere Sitzungen bleiben lesbar und exportierbar;
`permissions: nil` heißt „nicht erhoben" und erzeugt keine Scheinbefunde. Wegen der neuen
Regel- und Promptstände sind vorhandene Sitzungen nicht fortsetzbar — das ist der
dokumentierte Weg statt einer stillen Übersetzung. Im Adapter gilt umgekehrt: Eine fehlende
oder auf `null` gesetzte Liste wird nicht still als Altvertrag akzeptiert, sondern abgewiesen.

### Unabhängige Gegenprobe von Codex

Codex hat drei Gegenproben gegen den ersten Entwurf ausgeführt; alle drei deckten echte
Lücken auf und wurden übernommen: zwei Ausschnitte derselben Zustimmung trugen zwei
Ratschläge, eine vorangehende offene Frage galt als aufbrauchender Ratschlag, und eine leere
Liste neben einem Ratschlag wurde als gültig akzeptiert. Zusätzlich korrigiert: Die belegte
Erlaubnis führt jetzt auch die Erlaubnisfrage als Beleg mit, weil die Formulierung sie
behauptet, und eine bereits aufgebrauchte Zustimmung kann in derselben Analyse nicht später
wieder als erteilt gelten.

### Prüfungen

Alle vier Läufe Exit 0, vollständige Logs im Arbeitsbaum unter
`.build/rr-mi03-permission-logs/` (ignoriert). Der vorgesehene Ablageort `/private/tmp/` ließ
sich nicht beschreiben, weil die Sitzung nur im Arbeitsbaum schreiben darf; der
Schutzmechanismus wurde nicht umgangen.

- `swift build`: erfolgreich.
- TrainerCore: **100 Tests bestanden** (81 vorher, 19 neu in `PermissionTests.swift`).
- TrainerStorage: **3 Tests bestanden.**
- App/TrainerPresentation: **72 Tests bestanden**, Live-Tests übersprungen. Ausgenommen sind
  sechs Schlüsselbundtests — die fünf bekannten aus `SettingsTests.swift` und zusätzlich
  `leererUmgebungswertZaehltNicht` aus `OpenRouterTests.swift`, das ebenfalls den
  Schlüsselbund abfragt. Kein schlüsselbundfreier Gesamtlauf behauptet.

Nicht geprüft: kein Modellaufruf, keine Live-Rolle, kein Simulator-/Gerätelauf, keine
fachliche Validierung der Formulierungen und keine Aussage darüber, wie zuverlässig ein
echtes Modell diese Erlaubnislagen trifft.

## 29. September 2026 · MI-04-Sitzungsrahmen dokumentiert

Jonas hat festgelegt: typischer Gesprächseinstieg mit Begrüßung und offener Frage;
20 Gesprächsrunden stehen für 60 fiktionale Minuten; zwischen zwei Sitzungen desselben
Falls liegt eine fiktionale Woche. Vor Folgeterminen wird eine kurze belegte Dokumentation
zur Vorbereitung gelesen. Keine Vorwegnahme noch nicht erzählter Wochenereignisse und
kein automatischer Fortschritt durch den Zeitabstand.

In `MI-UEBERGABE.md` (Version 1.1, MI-04) stehen die Festlegungen und die Abnahme für den
ersten Umsetzungsschritt MI-04a: Abschluss → Vorbereitungsnotiz → nächste Sitzung.
Die TODO-Liste unterscheidet beschlossene Anforderungen von offener Implementierung.
Vorzeitiger manueller Abschluss, Erzeugungsverfahren der Notiz und spätere Zwischenereignisse
bleiben ausdrücklich als offene Detailentscheidungen markiert.

Reine Dokumentationsänderung: keine neue App-Funktion, keine Code-/Gerätetests und kein
kostenpflichtiger Modelllauf. Dokumentverweise und `git diff --check` geprüft.

## 29. September 2026 · Inhaltsfreie Messspur für alle Modellaufrufe (offline geprüft)

Eigener Branch `codex/messung-modellaufrufe`, Basis `d715b10` von
`origin/claude/adapter-frist-und-anbieter`. Keine Änderungen an AppModel, Features oder
ENTSCHEIDUNGEN; keine bezahlten Aufrufe, kein Push. TrainerCore importiert weiterhin nur
Foundation und enthält keine Netzimplementierung.

### Messvertrag

`ModelCallMetrics` und das gespeicherte Snapshot-Schema bleiben unverändert. Sie enthalten
weiterhin nur angenommene Ergebnisse. Eine separate optionale `ModelTraceSink` erhält pro
Transportaufruf `callStarted` und `callFinished` mit derselben eindeutigen ID. Der Abschluss
enthält auch den Startzeitpunkt; Start ohne Ende weist nach Prozessabbruch auf einen offenen
Aufruf hin. Kein stilles Verwerfen bezahlter Erstversuche oder einer erfolgreichen Zielstufe
bei späterem Analysefehler. `accepted` heißt vom Adapter validiert; eine spätere Ablehnung
beim CharacterTracker erscheint als Coordinator-Wiederholung/Rundenfehler.

Erfasst werden Stufe, Modell/Prompt-/Regelversion, Budget, Budgetversuch, Coordinator-Versuch
(jeweils ab 1), Wiederholungsgrund, UTC-Unixzeit und monotone Dauern, HTTP-Status,
`finish_reason`, Generierungs-ID, tatsächliche Route, Eingabe-/Ausgabetoken und gemeldete
`usage.cost` in USD. Fehlendes bleibt unbekannt. Direkte Adapteraufrufe ohne Coordinator
haben keine künstlich erfundene Coordinator-Versuchsnummer. Runden-ID und Versuche sind
Task-lokal; gleichzeitige Runden vermischen sich nicht.

Die zusätzliche Inhaltsauswertung speichert ausschließlich Zahlen: Unicode-Skalarzahl,
Leerraumzahl, längste Folge und nachlaufender Leerraum. `suspectedWhitespaceLoop` bedeutet
mindestens 128 aufeinanderfolgende Leerraumzeichen bei `length/error`; das ist eine
Messheuristik, keine Inhaltsreparatur und kein Beweis einer Modellpathologie. Die früher
verworfenen Gegenmaßnahmen bleiben verworfen; Budgets, Frist und Wiederholungsregeln sind
unverändert. Keine Prompts, Antworten, Anfrageköpfe, Schlüssel oder Fehlermeldungstexte in
JSONL. Vorhandene separate Live-Fixture-Berichte/Rohdiagnosen sind davon unabhängig.

Die Dateisenke wird erst durch einen absoluten `RR_MODEL_TRACE_FILE`-Pfad aktiviert. Pro
Prozess teilen Adapter denselben Schreiber. Datei muss neu sein, Ordner vorhanden; Rechte
0600, synchrone Zeilen und Flush, kein Überschreiben alter Läufe. Schreibfehler vor dem
Transport verhindern weitere unbeobachtete Aufrufe. Nach bereits erfolgtem Gesprächs-Commit
wird ein fehlgeschlagener Rundenabschluss ausdrücklich gemeldet, aber der gespeicherte Turn
nicht als fehlgeschlagen zurückgegeben. Die offene Spanne bleibt im Bericht sichtbar.

### Auswertung und nächster bezahlter Lauf

Der bestehende Starter wurde nur bearbeitet, **nicht ausgeführt**. Bei künftiger ausdrücklicher
Freigabe aktiviert `python3 Tools/run_goal_memory_live.py long` beziehungsweise `probes`
die Messung automatisch: `model-calls.jsonl` plus `model-calls.jsonl.run.json` im neuen,
ignorierten Ergebnisordner. Der 15-Runden-Wrapper reicht die Senke an den Coordinator durch.
Der Prozessrahmen umfasst auch Swift-Build, Teststart und Testende; das ist ausdrücklich
keine reine Modelllatenz. Die vorhandenen fiktiven Inhaltsberichte bleiben separat.

Offline danach:

```sh
python3 Tools/model_trace.py summarize Evaluation/results/<Lauf>/model-calls.jsonl
python3 Tools/model_trace.py summarize Evaluation/results/<Lauf>/model-calls.jsonl --json
```

Für eine direkt gestartete Mac-Prüf-App (kein zusätzlicher Eingriff in AppModel nötig):

```sh
mkdir -p Evaluation/results/mein-messlauf
python3 Tools/model_trace.py run --trace Evaluation/results/mein-messlauf/model-calls.jsonl -- /absoluter/Pfad/RogersRodeo
```

`run` führt das angegebene Programm tatsächlich aus; eine freigegebene App kann dabei
Modellkosten verursachen. Hier wurde ausschließlich ein fest benannter Offline-Stubtest
über diesen Wrapper ausgeführt. Authentifizierung bleibt auf dem vorhandenen Weg; niemals
Schlüssel in Kommandoargumente, Berichte oder neue Dateien schreiben.

Die Übersicht zählt alle abgeschlossenen Aufrufe, gruppiert nach Stufe, Ausgang und Anbieter,
zeigt Wiederholungsgründe sowie Token-/Kostensummen mit Abdeckungszahlen. Dauervergleich:
ganzer Prozess, Summe aller Transporte, Vereinigung der Aufrufspannen, übrige Rundenzeit
und Rest außerhalb dieser Spannen. Überlappung wird nicht doppelt als Wandzeit gezählt.
Der Rest ist gemessen, aber nicht ursächlich weiter aufgeschlüsselt (Build, Start, Pausen,
Abschluss). Fehlender Prozessrahmen, offene Spannen und beschädigte letzte Zeilen werden
explizit gemeldet. Eine lückenlose Abrechnung trotz Prozessabsturz/fehlender Providerdaten
wird nicht behauptet. Keine Dateizeitstempel-Rekonstruktion nötig.

### usage und Generierungs-Endpunkt

Jede Chat-Anfrage enthält jetzt `"usage":{"include":true}` neben den unveränderten Filtern
`require_parameters=true`, `data_collection=deny` und `ignore`. Offline nachgewiesen sind
Serialisierung und Auswertung gestubbter Antworten. Die tatsächliche Routenverträglichkeit
ist mangels erlaubter Live-Aufrufe **nicht geprüft**; der E06-Handtest weiter unten prüfte
noch nicht diesen Zusatz. Keine automatische Wiederholung mit abgeschwächten Filtern.

`/api/v1/generation?id=…` wurde weder aufgerufen noch automatisch angebunden. Laut Auftrag
gebührenfrei, aber ein zusätzlicher Netzaufruf pro ID (bei noch nicht bereitstehenden Daten
gegebenenfalls weitere). Später für Kostenabgleich/native Token sinnvoll, falls direkte
Usage-Angaben fehlen. Er verlängert sonst die Messung unnötig und hilft ohne zurückerhaltene
ID bei Transportabbruch nicht verlässlich. Die IDs stehen nun für diesen getrennten Abgleich
zur Verfügung. Keine Kosten aus Listenpreisen schätzen und als Rechnung ausgeben.

### Prüfung

81 Core-Tests, 3 Storage-Tests und 64 reguläre App-Tests bestanden, darunter 14 neue
Messspurtests. Zwei kostenpflichtige Live-Tests übersprungen (Runner meldet insgesamt 66);
die fünf benannten Schlüsselbundtests gezielt ausgenommen. Acht neue Python-Tests bestanden.
`swift build` für die gemeinsame macOS-App und `git diff --check` erfolgreich. Swift-Aufrufe
mit ausgelagerten Caches/Buildpfaden unter `/private/tmp` und `--disable-sandbox` für die
SwiftPM-Unterprozesse; die Agentensandbox blieb aktiv. Storage meldet weiterhin Fehler beim
systemweiten Store-Änderungsdienst, die drei Dateiroundtrips bestanden trotzdem.

Abgedeckt: Abschneidung mit Budgeteskalation, zweite Stufe scheitert nach bezahlter erster,
HTTP-/Transport-/Schemafehler, Refusal, fehlende Nutzungsdaten, Cancellation auch nach
Antwortempfang, Rundenfrist, beide Coordinator-Wiederholungen, parallele Runden, Dateischutz,
Schreibfehler und keine doppelte Speicherung nach Diagnosefehler. Python prüft zusätzlich
Zeitvereinigung, Dezimalkosten, unvollständige/duplizierte Datensätze und Prozessfehler.

Ein vollständiger Offline-Stub-Beispiellauf durch Dateisenke, Prozessrahmen und Auswerter:
vier Aufrufe, davon ein abgeschnittener Ziel-Erstversuch und drei angenommene Ausgaben.
400/80 Token und 0,005 USD sind ausschließlich vorgegebene Fixturewerte, keine tatsächlichen
Kosten oder Modellmessungen. Keine Simulator-/Geräte- oder freie Rollenprüfung.
Beispieldaten und Testlogs bleiben außerhalb von Git unter
`Evaluation/results/model-trace-offline-20260929/` beziehungsweise `/private/tmp/rr-measure-*`.

## 29. September 2026 · Kurzprobe zur Anbieterbeschränkung nach E06

Erste Benutzung der macOS-Prüf-App mit eingeschaltetem `provider.data_collection: "deny"`
zusätzlich zu `require_parameters` und den drei ausgeschlossenen Anbietern. Das war die offene
Frage aus E06: ob unter dreifacher Filterung überhaupt noch Routen übrig bleiben.

**Geprüft:** Es kommen Antworten. Die Kombination schließt nicht alle Routen aus. Damit ist das
Hauptrisiko von E06 ausgeräumt.

**Nicht geprüft und ausdrücklich nicht behauptet:** Das war eine Handprobe über wenige Runden in
der macOS-Prüf-App durch Jonas, kein Messlauf. Es liegen keine Zahlen zu Rundendauer,
Wiederholungen, tatsächlich verwendeten Anbieterrouten, Tokenverbrauch oder Kosten vor. Ob die
neue Frist von 120 Sekunden je Runde angemessen ist, hat diese Probe nicht berührt. Ob sich die
Antwortqualität gegenüber dem ungefilterten Zustand verändert hat, ist nicht gemessen — dafür
fehlt ein Vergleich unter gleichen Bedingungen. Ein vollständiger Durchlauf steht aus.

**Qualitativer Eindruck, kein Befund:** Jonas beschreibt die Antworten der Figur als „ganz gut",
changierend zwischen Zurückhaltung und Veränderungswunsch. Das entspricht dem erwünschten
Nebeneinander von Beibehaltungs- und Veränderungsrede, ist aber ein Eindruck aus wenigen Runden
und ersetzt keine fachliche Bewertung. Der fachlich geprüfte Referenzsatz fehlt weiterhin.

## 29. September 2026 · Live-Zielgedächtnis korrigiert und erneut abgenommen

Die Fehler aus der ersten Live-Prüfung sind für die festgelegten Fälle behoben. Finale Läufe:
**15/15 Runden mit allen 14 Prüfaussagen bestanden**, anschließend **7/7 unabhängige Gegenproben
bestanden**. Dieselben Erwartungen wie zuvor; keine Abschwächung der Zielkriterien.

### Umsetzung

- Zwei getrennte Modellstufen im Adapter: Ziel-/Charakterbeobachtungen ausschließlich aus dem
  bisherigen Verlauf, danach Einordnung der aktuellen Beratung. Die Gedächtnisstufe bekommt
  die aktuelle Eingabe nicht. Beide verwenden dieselben nummerierten Belege und werden erst
  nach strikter Prüfung als gemeinsame `TurnAnalysis` an den Coordinator gegeben.
- Eigene Teil-Schemas, kopierbare exakte Zielkennungen und präzisere Ereignis-/Belegregeln.
  Fehlender Rapport wird ausgelassen; `confirmed` braucht einen früheren Vorschlag mit
  anschließender Zustimmung. Keine Charakterbeobachtung darf unter dem neuen Zielvertrag
  ein unbekanntes Parallelziel eröffnen. Alte optionale Verträge bleiben lesbar/verarbeitbar.
- Korrigierter Validator: Ein Zielausschnitt innerhalb eines längeren Ereigniszitats ist nicht
  „später“ als dieses Zitat; die ganze Nachricht ist verfügbar. Nachrichtenfolge bleibt geprüft.
- Einzelne vollständige JSON-Codehüllen am Adapterrand erlaubt. Keine Prosa-/Fragmentextraktion,
  keine Reparatur von Zitaten oder JSON-Inhalten. Das ist eine bewusste Änderung gegenüber der
  ersten Messung, keine Behauptung, dass die Anbieter jetzt immer rohes JSON liefern.
- `provider.require_parameters=true` nach offizieller OpenRouter-Dokumentation:
  https://openrouter.ai/docs/guides/features/structured-outputs . Eigene Validatoren bleiben nötig.
- Prompt **0.5**, Regeln **0.4**, Snapshot-Schema weiter **1**. Neues Gespräch für neue Regeln.
  Rollenprompt, Offenheitslogik und atomarer Commit unverändert. Ohne Wiederholung nun zwei
  Analyseaufrufe plus eine Rollenantwort pro Runde; frühes Feedback nach beiden Analysestufen.

### Nachweise und Grenzen

77 Core-Tests, 3 Storage-Tests und 40 reguläre App-Tests bestanden. Zwei zusätzliche Live-Tests
im Offline-Lauf übersprungen; fünf bekannte Schlüsselbundtests gezielt ausgenommen. Gemeinsame
SwiftUI-Quellen als macOS-Prüf-App gebaut. `git diff --check` bestanden. Speicherumgebung meldet
weiter Fehler des systemweiten Store-Änderungsdienstes bei erfolgreichen Dateiroundtrips.

Finaler Live-Verlauf: Einführung, Alias, Zustimmung, Erinnerung nach mehr als sechs Runden,
Reduktion → Abstinenz, Widerruf und Unsicherheit korrekt. Danach alle sieben isolierten
Gegenproben korrekt. Feste fiktive Klientenantworten; die durchgehende Historie entsteht aus
echten Modellanalysen, die Einzelproben haben belegte Fixture-Vorzustände. Kein freier Rollenlauf,
keine neue Simulator-/Geräteprüfung, keine fachlich validierte oder repräsentative Qualitätsquote.

Der finale 15-Runden-Lauf dauerte **327 Sekunden**. Median der erfolgreichen kombinierten
Analysestufen **5,7 Sekunden**, Maximum **14,2 Sekunden**; deren Summe nur **100,7 Sekunden**.
Wiederholungen/zusätzliche Wartezeiten sind damit erheblich. Metriken summieren die beiden
angenommenen Teilaufrufe, nicht alle Fehlversuche. Die Herkunft der Lücke ist inzwischen
aufgeklärt, siehe den folgenden Abschnitt. Anbieter-/Gesamtkostenmessung bleibt offen.
Ein Versuch mit aktiviertem Überlegen und 4000/8000 Token wurde nach einer langsamen ungültigen
ersten Gegenprobe beendet. Finale Einstellungen: Überlegen aus, 1500/4000 Token je Teilaufruf.

Zwischenstand mit nur verbessertem gemeinsamen Prompt bestand zwar 7/7 Einzelproben, ließ aber
im langen Lauf den Alias aus. Deshalb erst der abschließende zweistufige Lauf als Abnahme.
Rohbefunde außerhalb von Git: `Evaluation/results/goal-memory-fix-2026-09-29/`.
Nächste Arbeit: weitere unabhängige Formulierungen, geringere Latenz/verlässliche Routen und
manueller freier Rollen-/Simulatorlauf. Automatische Rollenentwicklung bleibt ausgeschaltet.

### Nachtrag 29.09.2026 · Die Latenzlücke von 226 Sekunden ist aufgeklärt

**Geprüft.** Die Differenz zwischen den 327 Sekunden Gesamtdauer und den 100,7 Sekunden
gemessener Analysestufen beträgt **226,3 Sekunden**. Sie wurde aus den Änderungszeitpunkten der
**34 Rohdateien** `goal-fix-long-02.json.analysis-N.json` unter
`Evaluation/results/goal-memory-fix-2026-09-29/` gegen die 15 gemessenen Rundenwerte
rekonstruiert. Die Rechnung geht bis auf unter eine Sekunde auf; es bleibt nichts Unerklärtes.

Zwei Ursachen, beide belegt:

1. **Abgeschnittene Erstversuche: rund 177 Sekunden, etwa 78 Prozent der Lücke.** Das Modell
   produziert einen Leerzeichenlauf und füllt damit das Ausgabebudget bis zur Abschneidung. Der
   Adapter wiederholt daraufhin mit erhöhtem Budget und meldet nur die Dauer des geglückten
   zweiten Versuchs. Der größte Einzelfall: in einer einzigen Runde rund **84 Sekunden**, die in
   keiner Metrik auftauchen.
2. **Bezahlte, aber verworfene Erststufen: rund 46 Sekunden.** Die Rohdateien enthalten
   **19 Zielanalyse-** gegenüber **15 Beratungsstufen**. Die Wiederholung im
   `ConversationCoordinator` hat also vier Runden vollständig neu gestartet, und `analyze()`
   summiert nur die beiden erfolgreichen Stufen. Die vier verworfenen Zielanalysen sind bezahlt
   und dauern, erscheinen aber nirgends.

**Ausgeschlossen.** Rollenantworten erklären die Lücke nicht: Der Testprovider liefert feste
Texte mit `durationSeconds: 0`; das steht so in den Rohdaten.

**Gegenprobe.** Der Vergleichslauf `goal-fix-long-01.json` zeigt **161,0 s** Gesamtdauer gegen
**120,8 s** gemessen, Lücke **40,2 s**, dort ausschließlich durch abgeschnittene Erstversuche.
Dasselbe Muster, kleinere Ausprägung.

**Einschränkung, nachgetragen am 29.09.2026.** Die Überschrift dieses Nachtrags ist zu
selbstbewusst, und die Aufteilung 177 zu 46 Sekunden ist **rekonstruiert, nicht gemessen**. Eine
spätere Gegenprüfung am Code und an den Rohdaten hat drei Punkte relativiert:

- Die „größte Einzellücke von rund 84 Sekunden" lässt sich nicht nachrechnen, weil je Runde
  keine Zeitstempel vorliegen. Belegt ist nur die größte Lücke zwischen zwei Dateiänderungen.
- Die **5,7 Sekunden** sind der Median **je Runde**, nicht je Analysestufe. Die Formulierung
  weiter oben in diesem Abschnitt ist an dieser Stelle ungenau.
- Der Vergleichslauf `goal-fix-long-01` zeigt ebenfalls rund **25 Prozent** unerfasste Zeit.
  Die Lücke geht damit **nicht vollständig** auf Leerzeichenläufe zurück; es bleibt ein
  ungeklärter Anteil.

Die Aussage „es bleibt nichts Unerklärtes" gilt für die Summenrechnung, nicht für die
Zuordnung der einzelnen Ursachen. Beides trennt erst die Messspur sauber, die seither gebaut
wurde; sie ersetzt die Rekonstruktion aus Dateizeitstempeln.

**Welche Daten dafür heute fehlen.** Die Rekonstruktion war nur über Dateizeitstempel möglich,
weil der Adapter das Nötige nicht erfasst:

- Metriken abgeschnittener Versuche werden verworfen, statt mitgezählt zu werden.
- Das dekodierte Feld `provider` der Antwort wird nie ausgewertet. Die Route je Aufruf ist damit
  unbekannt, obwohl E02 sie als ausschlaggebend für die Ausfallquote benennt.
- Der Anfragekörper sendet kein `"usage": {"include": true}`. Die von OpenRouter abgerechneten
  Kosten je Aufruf kommen deshalb gar nicht erst zurück.
- Die `id` der Antwort wird nicht gelesen. Ohne sie ist der kostenlose Generierungs-Endpunkt für
  Kosten und Route nicht abfragbar.

**Kostenrahmen — ausdrücklich eine Schätzung, keine Abrechnung.** Über die 30 angenommenen
Endstufen des Laufs sind **57 539 Eingabe-** und **3 509 Ausgabetoken** gemessen. Mit den
Listenpreisen aus E01 (0,42 bzw. 3,00 USD je Million) sind das rund **0,0347 USD**. Für die oben
rekonstruierten unsichtbaren Aufrufe kommen geschätzt rund **0,024 USD** hinzu, zusammen etwa
**0,06 USD** für 15 Runden ohne Rollenantworten — grob **0,4 Cent je Runde**, mit Rollenantworten
grob **0,08 bis 0,09 USD je Sitzung**. Die tatsächlich abgerechneten Kosten sind **unbekannt**,
weil die Nutzungsdaten nicht angefordert werden. Der Kostenrahmen ist damit der Größenordnung
nach geklärt und unkritisch; eine belastbare Zahl ist er nicht.

## 29. September 2026 · Live-Prüfung Zielgedächtnis: nicht bestanden

Der erste echte Modelltest mit Prompt 0.4 und `qwen/qwen3.8-27b` bestätigt die technische
Erinnerungsauswahl, aber **keine zuverlässige Zielentwicklung im Modellbetrieb**.

- Zwei geplante 15-Runden-Läufe über den produktiven Coordinator: Abbruch bei Runde 4 bzw. 5
  nach 3 bzw. 4 abgeschlossenen Runden; auch die jeweilige Analysewiederholung war ungültig.
  Fiktive Rollenreaktionen sind fest vorgegeben, die Analysen kommen vom echten Modell.
- Sieben unabhängige Gegenproben mit belegten Fixture-Vorzuständen: nur **1/7 vollständig
  erfüllt** (Vorschlag allein ist noch keine Vereinbarung). Drei technisch angenommene
  Antworten, vier `invalidAnalysis`. Keine fachlich validierte oder repräsentative Trefferquote.
- Alle sieben Kontexte enthalten den gezielt zurückgeholten alten Originalbeleg außerhalb des
  normalen Sechs-Turn-Fensters. Das Modell erkennt trotzdem den Alias nicht zuverlässig.
- Fehler: Markdown-Codezäune trotz JSON-Vorgabe; `confirmed` mit unzulässigem `currentGoal`;
  aktuelle Frage statt früherem konkreten Vereinbarungsvorschlag; unbelegter Rapport mit
  leerem Zitat, `messageIndex=null`, `occurrence=0`.
- Relevante Zustandslücke: spätere Unsicherheit erzeugt über `characterObservations` einen
  zweiten Zielverlauf mit neuem Zielzitat. Der alte Widerruf bleibt bestehen, aber die gemeinsame
  Zielidentität wird umgangen. Das ist ausdrücklich kein bestandener Wiederaufnahme-Test.
- Zielwechsel und Widerruf sind in einzelnen Rohantworten inhaltlich erkannt, werden wegen
  ungültiger Ausgabe jedoch nicht übernommen. Kein Entfernen von Codezäunen als Erfolg gewertet.

Neu: `GoalMemoryLiveTests.swift` (Opt-in über `RR_RUN_GOAL_LIVE=1`),
`Tools/run_goal_memory_live.py long|probes`, optionaler Diagnose-Rückruf im Adapter ausschließlich
für Modellinhalte. Keine Änderung von Prompt, Schema, Zustandsregeln oder Rollenwirkung.
Der Starter nutzt Umgebungsvariable oder den vorhandenen `security`-Ladeweg; der direkte
Schlüsselbundzugriff des Swift-Testprogramms schlug fehl. Keine Schlüsselausgabe/-ablage.

Ergebnisse außerhalb von Git: `Evaluation/results/goal-memory-2026-09-29/`.
38 bisherige App-Tests bestanden erneut; zwei neue Live-Tests im Offline-Lauf übersprungen;
fünf bekannte Schlüsselbundtests gezielt ausgenommen. SwiftUI-Quellen als Mac-Prüf-App gebaut,
`git diff --check` bestanden. Core-/Storage-Pakete unverändert, kein neuer eigenständiger Lauf.
Kein echter Rollenlauf, Simulator-/Gerätenachweis oder vollständiger Kosten-/Anbieternachweis.
Nächster Schritt ist Fehlerbehebung mit unveränderten Live-Erwartungen und erneuter Messung,
nicht Aktivierung automatischer Rollenentwicklung.

## 29. September 2026 · MI-03: belegtes Zielgedächtnis

### Implementierter Baustein

Die Analyse erhält gezielt alte Originalnachrichten über das bisherige Sechs-Turn-Fenster
hinaus. `GoalUpdate` unterscheidet Einführung, Umformulierung, ausdrückliche Vereinbarung,
Zielwechsel und Widerruf. `GoalEvent` verankert deren Zitate dauerhaft über Turn/Sprecher/
Vorkommen; `GoalMemory` führt Aliasse, Status und letzten Befund. Die semantische Zuordnung
trifft das Modell; keine Stichwortheuristik setzt „weniger trinken“ mit Abstinenz gleich.

- Umformulierungen teilen einen Verlauf. Ein echter Wechsel lässt zwei Ziele mit getrennten
  Bereitschafts-/Zuversichtsbelegen bestehen. Bereits getrennte Ziele werden nicht nachträglich
  zusammengeführt; Aliaskollisionen werden abgewiesen.
- Vereinbarung braucht ein schon genanntes Klientenziel, einen konkreten Berater-Vorschlag und
  die zeitlich folgende Klientenzustimmung. Die aktuelle Eingabe genügt nicht. Nur eine neue
  ausdrückliche Vereinbarung kann einen zurückgenommenen Verlauf wieder aufnehmen.
- Unsichere Änderungen bleiben als Ereignisse sichtbar, ändern jedoch den Status nicht.
  Neuere unsichere Befunde verhindern ein Zurückdrehen durch ältere Belege. Wiederholte Belege
  erzeugen keinen Fortschritt; auch eine unsichere Einführung wird nicht durch erneute Deutung
  desselben Belegs sicher. Unsichere neue Ziele werden vorerst nur in der Ereignishistorie geführt.
- `ContextBuilder.analysisMemory`: Eröffnung plus sechs letzte Turns, maximal drei Zielgruppen,
  sechs zusätzliche Original-Turns und 10.000 zusätzliche Zeichen. Eine Gruppe wird vollständig
  geholt oder ausgelassen; chronologisch sortiert. Enthalten sind Ziel, Aliasse, letzte
  Bereitschaft/Zuversicht, letzter Ereignisbeleg und die letzte sichere Statusgrundlage samt
  Vereinbarungsvorschlag. Der Prompt erhält die tatsächlich geholten Kennungen und die Zahl
  ausgelassener Ziele; er benennt Kontextlücken ausdrücklich. Zeichenbudget ist kein Tokenmaß.
- Strikter Decoder, Rollen-/Zitat-/Reihenfolgeprüfung und begrenzte Ereignislisten. Die
  Speicherprüfung rekonstruiert Aliasse und Status aus der Historie, prüft Verfügbarkeit zum
  Beobachtungszeitpunkt und weist fremde Turns, Dubletten und manipulierte Zustände ab.
  Commit erhält die bisherige Ereignishistorie unverändert; neue Ereignisse gehören zur aktuellen
  Beobachtungsrunde. Charakterbelege bleiben ausschließlich Klientenaussagen.
- OpenRouter-Schema und Prompt erweitert; vorhandene Entwicklerdiagnostik zeigt Zielstatus,
  Aliasse, letzte Belege und Ereignisse einschließlich Unsicherheit. Keine neue normale Skala.
- Prompt **0.4**, Regeln **0.3**, Feedbackbausteine **0.2**, Snapshot-Schema weiter **1**.
  Neue Felder sind optional; alte Gespräche bleiben lesbar. Neues Gespräch für neue Regeln starten.
  Der Rollenprompt erhält weiterhin das normale Sechs-Turn-Fenster und keine Zielhypothesen.

### Tatsächlich geprüft

- **75 Core-Tests bestanden** (12 zusätzliche Zielgedächtnistests): Erinnerung jenseits von sechs
  Turns, vollständiger Coordinator-Lauf über zehn Runden mit getrennten Kontexten, Alias versus
  Ersatz-Ziel, Vereinbarung/Widerruf/Wiederaufnahme, spätere Unsicherheit, wiederholte Aussagen
  mit verschiedenen Turn-IDs, falsche Belege/Rollen/Chronologie/Felder, manipulierte Historie,
  JSON-Roundtrip sowie Zielgruppen-, Zeichen- und zusätzliche-Turn-Budgets.
- Abbruch und Wiederholung nach unbekanntem Commit-Ausgang eigens mit Zielereignissen geprüft:
  keine vorzeitige Speicherung, kein zweiter Modelllauf, keine doppelten Ereignisse.
- **3 Storage-Tests bestanden**, erweitert um Zielstatus, Ereignisse und Analyse nach erneutem
  Öffnen des SwiftData-Dateispeichers sowie Idempotenz. Die Umgebung meldet weiterhin Fehler
  des systemweiten Store-Änderungsdienstes; die Datei-Roundtrips bestehen.
- **38 App-Tests bestanden**; gemeinsamer SwiftUI-Code als macOS-App kompiliert. Schema, konkrete
  Gedächtnisreferenzen, Auslassungshinweis und fehlende Rollenwirkung geprüft. Die fünf bekannten
  Schlüsselbundtests gezielt ausgenommen, kein vollständiges grünes Root-Ergebnis behauptet.
- `git diff --check` bestanden; temporäre Build-/Cachepfade `/private/tmp/rr-goal-*`.
  Zwei Swift-Exklusivitätsfehler in neuen Test-Fixtures vor den erfolgreichen Läufen korrigiert.

### Offene Nachweise und Grenzen

Kein echter Modelllauf für Schema 0.4, keine gemessene semantische Qualität, Kosten oder Latenz.
Die Tests setzen semantische Befunde als Fixtures; sie belegen nicht, dass das Modell Zielwechsel,
Zustimmung oder Unsicherheit fachlich richtig erkennt. Nächster Schritt ist ein längerer echter
Modelllauf. Keine neue iOS-/Simulator-/Geräte- oder visuelle/VoiceOver-Prüfung in diesem Paket.

Das begrenzte Gedächtnis garantiert keine vollständige Erinnerung: große Aliasgruppen können
ausgelassen werden. Die letzte Figurenantwort wird weiterhin erst bei der folgenden Analyse
beobachtet. Automatische Rollenentwicklung, SOC, mehrere Termine und MI-04 bleiben offen.
Fremde Änderungen am Evaluationsskript, lange Fälle und Jonas' Testläufe bleiben unverändert.

## 29. September 2026 · MI-03: getrennte Charakterbeobachtungen

### Was jetzt implementiert ist

Veränderungsbereitschaft, Zuversicht und Rapport werden durch denselben Analyseaufruf als
`characterObservations` erfasst. Grundlage sind ausschließlich bereits vorliegende Aussagen
von Lukas, nicht die vermutete Wirkung der aktuellen Beratung und nicht die erst anschließend
erzeugte Antwort. Die drei Dimensionen dürfen unterschiedliche Ausprägungen haben.

- `CharacterDimension`/`CharacterAssessment`: getrennte qualitative Kategorien. Bereitschaft
  kennt keine Absicht, Ambivalenz, geäußerte Bereitschaft und unklar; Zuversicht Zweifel,
  gemischte Zuversicht, geäußerte Zuversicht und unklar; Rapport Verständigung, Spannung,
  Reparatur und unklar. Diese Labels sind fachlich noch ungeprüfte Implementierungsentwürfe.
- Bereitschaft und Zuversicht benötigen zusätzlich einen wörtlichen Zielbeleg von Lukas.
  Rapport bezieht sich auf die Beratung, nicht auf Sarah oder eine bloße Ablehnung von
  Veränderung. Letztere Unterscheidung steht im Prompt und bedarf echter Modellprüfung.
- `SimulationState.development` speichert die letzten Beobachtungen, nach Zielbeleg getrennt,
  und Rapport unabhängig davon. Fehlend bedeutet nicht erhoben, nicht niedriger Wert.
  Ein neuerer unsicherer Befund verdrängt einen älteren sicheren; derselbe oder ein älterer
  Beleg erzeugt keine erneute Entwicklung. Offenheitsberechnung unverändert.
- `DialogueMessage.origin` und `CharacterEvidence` verankern Zitate dauerhaft über Turn-ID,
  Sprecher und Vorkommen. Die Eröffnungszeile hat keine Turn-ID. Das Modell verwendet weiter
  Kontextindizes; erst der geprüfte Coordinator übersetzt diese in dauerhafte Herkunft.
  Erfundenes, falscher Sprecher, falsche Dimension, fehlender Zielbeleg oder gefälschte
  Herkunft wird abgewiesen. Speicherprüfung verhindert Belege aus der noch unbekannten Zukunft.
- Die Charakterbeobachtungen gehören zur atomaren Turn-Transaktion. Abbruch speichert sie
  nicht, Wiederholung nach Speicherfehler erzeugt weder neuen Modelllauf noch Doppeleintrag.
  Ohne Einordnung bleiben frühere Beobachtungen als historische Angaben erhalten.
- In der vorhandenen Entwicklerdiagnostik: „Zuletzt belegte Aussagen zur Figur“, mit
  Zielzitaten, Unsicherheit und Herkunftsrunde. Zugang weiterhin über langes Drücken auf
  Rundenzähler oder „Protokoll“. Keine neuen Skalen im normalen Gespräch.
- Prompt **0.3**, Regeln **0.2**, Feedbackbausteine unverändert **0.2**; Snapshot-Schema bleibt
  **1** wegen optionaler neuer Felder. Alte Daten bleiben lesbar/exportierbar. Zum Verwenden
  der Erweiterung ein neues Gespräch starten; alte Prompt-/Regelstände nicht still fortsetzen.

### Tatsächlich geprüft

- **63 Core-Tests bestanden**: 14 neue Charaktertests ergänzen die zuvor 49. Unter anderem
  unabhängige Dimensionen, falsche Belege/Herkunft, spätere Zweifel, wiederholte Belege,
  Zielwechsel, gekürzter Kontext, Altformat, Abbruch, vollständiger Commit, idempotenter Retry,
  Überspringen der Analyse und zeitliche Herkunftsprüfung.
- **3 Speichertests bestanden**, einschließlich neuer Charakterbeobachtungen mit exakten
  Belegen nach erneutem Öffnen der SwiftData-Datei und Idempotenz bei erneutem Commit.
  Die Umgebung meldet weiter Warnungen des systemweiten Store-Änderungsdienstes.
- **37 App-Tests bestanden**, einschließlich erweitertem Schema/Prompt und Nachweis, dass
  die Hypothesen noch nicht als Rollenbefehle weitergegeben werden. Die fünf bekannten
  Schlüsselbundtests wurden gezielt ausgenommen (Zugriffsfehler im vorherigen Paket), nicht
  als bestanden gezählt. Die gemeinsame SwiftUI-App wurde dabei für macOS kompiliert.
- `git diff --check` bestanden. Build-/Cachepfade `/private/tmp/rr-character-*`;
  SwiftPM `--disable-sandbox` innerhalb der Agenten-Ausführungsbeschränkungen. Ein fehlendes
  `try` in einer neuen Testhilfsfunktion wurde vor den erfolgreichen Läufen korrigiert.

### Grenzen und nächster Baustein

Noch kein echter Modelllauf für das erweiterte Schema, keine gemessene semantische Güte,
Latenz oder Mehrkosten. Keine erneute iOS-/Simulatorprüfung in diesem Schritt; die zuvor
festgestellten Zugriffsblockaden bestehen als offener Nachweis fort. Diagnosefläche noch
nicht laufend visuell oder mit VoiceOver geprüft.

Die Rolle verwendet diese Zustände noch nicht. Ein Rückschluss von einer Modellhypothese auf
Lukas' nächste Antwort würde sonst ungeprüft eine sich selbst bestätigende Entwicklung erzeugen.
MI-04, SOC, Terminabstände und Maintenance sind nicht umgesetzt. Die neu erzeugte Antwort
kann erst beim nächsten Analyseaufruf beobachtet werden; die letzte Antwort eines abgeschlossenen
Gesprächs erhält daher noch keine nachgelagerte Charakteranalyse.

Das Analysefenster bleibt Eröffnung plus sechs letzte Turns. Dauerhafte Belege bleiben auch
außerhalb dieses Fensters lesbar, werden aber noch nicht gezielt in neue Prompts zurückgeholt.
Ein fehlender Zielbeleg führt zum Auslassen der Beobachtung. Unterschiedliche Zielformulierungen
werden nicht automatisch gleichgesetzt: derselbe Inhalt kann vorläufig mehrere Zielbelege
haben. Nächster Baustein ist deshalb belegte Zielidentität/Erinnerung, danach der kontrollierte
Einfluss auf Rollenverhalten. Skalenwerte werden noch nicht separat numerisch gespeichert;
als Beleg verwendete Formulierungen bleiben wörtlich erhalten, statt eine Zahl zu erfinden.

## 29. September 2026 · MI-03-Teilschritt: doppelseitige Reflexion

### Verhalten und Verträge

Gemäß Jonas' Präzisierung E04 erhält die Reihenfolge **Sustain Talk zuerst, Change Talk danach**
ausdrücklich Lob. Das Modell ordnet die beiden Seiten semantisch ein; beide benötigen je ein
wörtliches Zitat im eigenen Beitrag und einen überprüften Klientenbeleg. Die FeedbackEngine
prüft die tatsächlichen Textpositionen einschließlich des jeweiligen Vorkommens.

- Neues optionales `TurnAnalysis.doubleSidedReflection`, mit `ReflectionSide` und vorhandenen
  `EvidenceReference`-Werten. Kein zusätzlicher Modellaufruf, keine Stichworterkennung.
- OpenRouter-Schema und Systemnachtrag erweitert; Verlauf für genaue Referenzen nummeriert.
  Das ältere, lokal geänderte Python-Evaluationsskript wurde nicht angefasst und prüft dieses
  neue Schema noch nicht.
- Richtige Reihenfolge: eigener Textbaustein mit vier Belegen; erhält Platz unter den höchstens
  zwei positiven Rückmeldungen und ersetzt das allgemeine Reflexionslob dieser Runde.
  Warnungen bleiben zuerst. Umgekehrte Reihenfolge ist nicht automatisch ein Fehler.
- Unsichere Beobachtung oder unsicheres zugehöriges Segment: kein sicheres Reihenfolgelob.
  Ungültige/erfundene/überlappende Belege werden abgewiesen. Fragen/Ratschläge können nicht als
  Reflexionssegmente für die neue Beobachtung dienen.
- Frühmeldung, gespeicherter Turn und Rückblick verwenden die bestehende Feedbackstrecke.
  Offenheitsregeln unverändert; keine zusätzlichen Punkte oder sichtbaren Skalen.
- Promptstand **0.2**, Feedbackbausteine **0.2**, Regeln **0.1**, Snapshots weiterhin **1**.
  Alte Analysen ohne das Feld bleiben lesbar/exportierbar, neue Beobachtungen werden nicht
  nachträglich erfunden. Aktive Sitzungen mit Promptstand 0.1 werden nicht still unter neuen
  Regeln fortgesetzt; Hinweis schon beim Öffnen, neues Gespräch erforderlich.
- E04 bezeichnet Jonas' Produktentscheidung, keine wissenschaftliche Quelle. Der Baustein
  bleibt `.draft`; exakte Zitate belegen noch keine korrekte semantische Zuordnung.

### Tatsächlich geprüft

- TrainerCore: **49 Tests bestanden**, darunter neun neue Tests für Reihenfolge/Gegenrichtung,
  Unsicherheit, falsche Belege, wiederholte Zitate, Schema-/Altformat, Anzeigelimit,
  Frühmeldung vor angehaltener Antwort, Snapshot-Roundtrip und alte Promptstände.
- TrainerStorage: **2 Tests bestanden**, einschließlich Dateispeicher-/Feedback-Roundtrip.
  Die Umgebung meldete weiterhin Warnungen des Store-Änderungsdienstes.
- Root-Paket: im vollständigen Lauf **35 von 40 Tests bestanden**. Fünf bestehende
  Schlüsselbundtests scheiterten beim Speichern/Lesen/Löschen ihrer künstlichen Testeinträge.
  Kein echter Schlüssel wurde benötigt. Wiederholung mit genau diesen fünf Tests ausgenommen:
  **35 Tests bestanden**. App und Testmodule wurden dabei als Mac-Prüf-App kompiliert.
- `git diff --check`: bestanden.
- Buildausgaben und Swift-/Clang-Caches liegen unter `/private/tmp/rr-double-*`; SwiftPM mit
  `--disable-sandbox` innerhalb der unveränderten Agenten-Ausführungsbeschränkungen ausgeführt.
  Erster Core-Build scheiterte am Standard-Cachepfad; temporärer Cache behob das. Ein
  Swift-Exklusivitätsfehler in einem neuen Test wurde vor dem erfolgreichen Lauf korrigiert.

### Fehlende Nachweise

Der versuchte iOS-Simulator-Build scheiterte vor dem App-Build an Paketauflösung/gesperrten
Cachepfaden; CoreSimulator meldete zusätzlich eine ungültige Dienstverbindung. Kein erfolgreicher
iOS-Build, visueller Lauf, VoiceOver-/Gerätenachweis oder echter Modelllauf für diese Erweiterung.
Die Güte der semantischen Erkennung, Anbieterakzeptanz des neuen Schemas und zusätzliche
Ausgabelänge/Latenz/Kosten sind noch zu messen. Technische Fixtures sind keine Goldreferenzen.

### Einordnung in MI-01 bis MI-04 und Jonas' Nachfrage

MI-01 bleibt implementiert. MI-02 ist durch E01–E03 auf Cloud-Inferenz umgestellt, nicht durch
lokale Modellpläne neu zu beginnen; der vorhandene Nutzertest zeigt bereits Modellantworten,
ersetzt aber keine systematische Qualitätsprüfung. Dieser Ausbau ist ein Teil von MI-03.

Veränderungsbereitschaft, Zuversicht/Selbstwirksamkeit und Beziehung/Rapport sind in
`MI-UEBERGABE.md` Abschnitt 5.1–5.3 inhaltlich getrennt vorgesehen; Zuversichtsskalen außerdem
in Abschnitt 4.4 und Fall 13. Im tatsächlichen `SimulationState` existieren bisher nur Offenheit,
Fragenfolge, offengelegte Fakten und Wiederholungsschutz. Es gibt keine drei eigenständigen
Zustandsparameter, keine belegte Fortschreibung und keinen getrennten Einfluss auf die Rolle.
Nächster Schritt: zielbezogene Bereitschaft und Zuversicht sowie Beziehungsbeobachtungen
belegt speichern (MI-03), danach in Charakter-/Terminverlauf einbinden (MI-04). Keine Ableitung
aus Offenheit, kein automatischer Fortschritt über Punkteschwellen.

## 29. September 2026 · MI-01: Rückmeldung an die übende Person

### Was jetzt tatsächlich passiert

Der Ablauf vom gesendeten Beitrag zur angezeigten und gespeicherten Rückmeldung steht und ist
durch Tests belegt. Schreibt die übende Person etwas Drängendes — sicheres `konfrontation`
oder sicheres `ratschlag_ohne_erlaubnis` —, erscheint eine Warnung mit dem auslösenden Zitat,
sobald die Analyse validiert ist und bevor die Antwort der Figur fertig ist. Bei belegter
`komplexe_reflexion`, `wuerdigung`, `autonomie_betonen` oder `zusammenarbeit_suchen` erscheint
an derselben Stelle eine kurze Rückmeldung zum Beitrag. Beides in Worten, **ohne jede Zahl**.

- **Kein Offenheitswert, keine Punkte, kein Balken, keine Note in der normalen Oberfläche.**
  Jonas' Produktentscheidung vom 29.09.2026, fachlich gestützt durch MI-Nachtrag 5.3 und 13:
  Offenheit misst die Bereitschaft der Figur, Persönliches zu erzählen, nicht die Qualität der
  Beratung. Der Wiederholungsschutz im Reducer gibt derselben guten Reflexion beim zweiten Mal
  keine Gutschrift mehr — als Punktzahl gelesen wäre das eine falsche Aussage. Die
  Rückmeldung hängt deshalb nicht am Zustand: derselbe Beitrag ergibt dieselbe Rückmeldung.
- **Deterministisch, kein zweiter Modelllauf, keine Stichwortliste.** `FeedbackEngine` arbeitet
  ausschließlich auf der bereits validierten `TurnAnalysis` und dem Kontext, der dieser Analyse
  tatsächlich vorlag. Die Texte kommen aus versionierten Vorlagen (`FeedbackTemplates`,
  Version 0.1) und werden nur mit wörtlichen Gesprächszitaten gefüllt.
- **Die Figurenantwort kann die Rückmeldung nicht färben.** Sie wird erzeugt, nachdem die
  Befunde feststehen. Eine zustimmende Figur beweist keine gute Beratung.
- **Unsicher bleibt unsicher.** Ein unsicher eingeordnetes Segment ergibt „Möglicher Druck …“
  beziehungsweise „Möglicher Rat ohne Erlaubnis …“ statt eines sicheren Vorwurfs. Positive
  Rückmeldung gibt es nur für sichere und belegte Segmente; Reflexion und Würdigung brauchen
  zusätzlich ein echtes Klientenzitat.
- **Keine scheinbare Entwarnung.** Fehlt die Analyse, steht dort ausdrücklich „Für diesen
  Beitrag liegt keine Einordnung vor. Das ist keine Entwarnung.“
- **Der Schalter schaltet nur die Vorschläge.** Er heißt jetzt „Vorschläge ein-/ausblenden“;
  Warnung und Rückmeldung zum Beitrag bleiben in jedem Fall sichtbar. Die drei Ausgaben aus
  Abschnitt 7.1 sind auf dem Bildschirm unterscheidbar beschriftet.
- **Verborgene Entwicklerdiagnostik.** Langes Drücken auf den Rundenzähler im Gespräch
  beziehungsweise auf „Protokoll“ im Rückblick zeigt Offenheitsverlauf, gespeicherte
  `stateChangeReasons`, Gutschriften und Regelkennungen je Runde. Das ist der einzige Ort, an
  dem eine Zahl vorkommt.

### Frühe Anzeige ohne verfrühten Commit

`ConversationCoordinator.send` bekommt einen optionalen Rückruf und meldet die Befunde,
sobald die Analyse validiert ist — vor dem Antwortaufruf und ohne gespeicherten Turn. Die
Meldung trägt Sitzung, PendingTurn, erwartete Revision und die Generation des Versuchs.
`AppModel` nimmt sie nur an, wenn sie zur laufenden Operation gehört, und zeigt sie nur,
solange Sitzung, Revision und Eingabetext unverändert sind. Abbruch, bearbeitete Eingabe,
Sitzungswechsel, Hintergrundwechsel, Anbieterwechsel und Löschen verwerfen sie. Nach einem
Speicherfehler wird derselbe vorbereitete Turn erneut gespeichert und dieselbe Rückmeldung
erneut gemeldet — ohne neue Generierung und ohne doppelte Einträge.

### Verträge und Speicherformat

- Neu in `TrainerCore`: `FeedbackKind`, `FeedbackCertainty`, `EvidenceReference`,
  `FeedbackFinding`, `PreliminaryFeedback`, `FeedbackSink`, `FeedbackTemplate`,
  `FeedbackTemplates`, `FeedbackEngine`, `OutputValidator.validateEvidence`.
- `CompletedTurn.feedback` ist neu, hat einen Standardwert und wird mit einem eigenen
  `init(from:)` über `decodeIfPresent(…) ?? []` gelesen. **`SessionSnapshot.schemaVersion`
  bleibt 1**, und `rulesVersion` bleibt „0.1“: alte Sitzungen bleiben lesbar, exportierbar und
  fortsetzbar. Fehlendes Feedback bedeutet „nicht erhoben“, nicht „keine Befunde“.
- Die Textbausteine haben eine eigene Version, damit eine Formulierungsänderung nicht die
  `rulesVersion` anfassen und damit alte Sitzungen unfortsetzbar machen muss.
- Das Feedback gehört zur Idempotenzprüfung: `RepositoryRules.commit` vergleicht bei gleicher
  Turn-ID `existing == turn`, ein Wiederholversuch mit abweichender Rückmeldung wird
  abgewiesen statt still überschrieben.

### Geprüft am 29.09.2026

- `swift test --package-path Packages/TrainerCore`: **40 Tests, bestanden** (vorher 17).
  Neu unter anderem: Fälle 4a/4b, 5, 6, 10 und die Gegenproben aus `Evaluation/mi-faelle.json`
  als Fixtures, Warnung vor der fertigen Figurenantwort bei künstlich angehaltener Antwort,
  Abbruch, Kontextlücke bleibt unsicher, Commit-Wiederholung ohne zweiten Modellaufruf und
  ohne doppeltes Feedback, übersprungene Analyse ohne Entwarnung, erfundene und paraphrasierte
  Belege werden abgewiesen, alte Turns ohne `feedback` bleiben decodierbar, kein Baustein
  enthält eine Ziffer.
- `swift test --package-path Packages/TrainerStorage`: **2 Tests, bestanden** (vorher 1).
  Neu: gespeichertes Feedback übersteht Neustart und gehört zur Idempotenz.
- `swift test` (Wurzelpaket): **37 Tests, bestanden** (vorher 34). Neu: die reine
  Entscheidungslogik der frühen Anzeige (`FeedbackGate`).
- `swift build` und `xcodebuild … -destination 'id=8053E614-…' build`: **erfolgreich.**

### Weiterhin nicht nachgewiesen

- **Kein Lauf der neuen Oberfläche.** Weder im Simulator noch auf einem Gerät noch in der
  Mac-Prüf-App wurde die Feedbackfläche angesehen. Kleine Displays, große Schrift und
  VoiceOver sind ungeprüft.
- **Keine Messung mit echtem Modell im laufenden Gespräch.** Die Fixtures setzen die Analyse
  von Hand; der `DemoModelProvider` liefert bewusst leere Segmente und kann kein Feedback
  auslösen. Ohne hinterlegten Schlüssel sieht man deshalb nur den Hinweis, dass keine
  Einordnung vorliegt.
- **Keine gemessene Latenz.** Dass die Warnung vor der Figurenantwort erscheint, ist an einer
  künstlich angehaltenen Antwort belegt, nicht an einer realen Wartezeit.
- **Die Formulierungen der Bausteine sind fachlich ungeprüft** und tragen `reviewStatus:
  .draft`. Auch die zwölf Codes bleiben ein angepasstes Lernschema; die Rückmeldung ist
  ausdrücklich keine validierte MITI-Bewertung und keine Kompetenznote.
- **Prozessbeobachtungen fehlen weiterhin**: Wanderfalle, Bubble Sheet, Erlaubnislage über
  mehrere Turns, verlorener Fokus. Das sind die Fälle 7, 8, 9, 11 bis 14 und gehören zu MI-03.

## 29. September 2026

### Erstmals bestanden: iOS-Build und Simulatorlauf

- **Erster iOS-Build der Projektgeschichte.** `xcodebuild` gegen iPhone 17 mit iOS-26.5- und
  iOS-27.0-Simulatoren vorhanden; Build gegen iOS 27.0 erfolgreich. Werkzeugstand: Xcode 27.0
  (27A266a), iOS-27.0-SDK, Swift 6, Deployment-Target 27.0.
- **Dabei einen Fehler aufgedeckt, der nie kompiliert worden war.**
  `SwiftDataSessionRepository.swift` rief `FileManager.setAttributes` mit `atPath:` statt
  `ofItemAtPath:` auf. Die Zeile steht in `#if os(iOS)`; CI und lokale Prüfungen bauen nur die
  Pakete und die Mac-App und haben sie deshalb nie gesehen. Behoben.
- **Lauf im Simulator durch den Nutzer bestätigt.** Oberfläche und Navigation funktionieren.
  Offener Punkt: eine oder zwei Schaltflächen auf der Startseite reagieren nicht; Ursache noch
  nicht untersucht.
- **Weiterhin nicht nachgewiesen:** Lauf auf einem echten iPhone, Dateischutz auf einem
  gesperrten Gerät, Backup-Ausschluss, große Schrift, VoiceOver.

### Erstmals gemessen: Modellqualität der Einordnung

Drei Messreihen über OpenRouter mit `qwen/qwen3.8-27b`, zusammen 84 Aufrufe. Die ersten beiden
Reihen kosteten 0,25 USD; die dritte ist gleich groß, ihre Abrechnung wurde nicht eigens geprüft.
Rohdaten und Berichte in `Evaluation/results/`, außerhalb von Git.

- **Zitat-Treue fehlerfrei: 47 von 47 prüfbaren Läufen** über alle drei Reihen, sowohl im reinen Codepunkt-Vergleich als
  auch NFC-normalisiert. Kein erfundenes, verkürztes oder umformuliertes Zitat, keine
  Reihenfolgeverletzung, kein `supportingClientQuote` ohne echte Entsprechung in einer
  Klientennachricht. Geprüft mit einer Python-Nachbildung von `OutputValidator.locations` und
  `validateAnalysis`. Das war das größte technische Risiko der geplanten Feedback-Funktion und hat
  sich an diesen Fällen nicht bestätigt.
- **Der Normalisierungsvorbehalt ist belegt gegenstandslos**, nicht bloß vermutet: beide
  Vergleichsmodi stimmen in allen 24 Läufen überein. Gilt für diese Eingaben, ist keine Garantie
  für Text aus Kopieren und Einfügen oder von einer iOS-Tastatur.
- **Ausfallquote durch Abschneidung, und wie sie sinkt.** Mit `max_tokens: 768` waren nur 7 von 28
  Antworten lesbar, mit 4000 waren es 17 von 28. Ursache ist das interne Überlegen des Modells,
  nicht die Länge der Analyse. Die Ausfälle häufen sich auf einzelnen Anbietern: Nach Ausschluss
  von `wafer`, `mancer` und `parasail` über `provider.ignore` stieg die von der App akzeptierte
  Quote in der dritten Reihe auf **23 von 28, also 82 Prozent**. Die Anbieterwahl ist damit der
  wirksamste Hebel, nicht das Modell. Einzelheiten in E03.
- **Keine stabile Ausgabe bei `temperature: 0`:** 9 von 14 Fällen in der zweiten Reihe und 4 von 12
  in der dritten waren über zwei Läufe wortgleich. Auf Determinismus darf nichts aufgebaut werden.
- **Auffällig und fachlich zu bewerten:** Die Unsicherheitsquote bleibt niedrig — 1 von 23
  Segmenten in der zweiten Reihe, 3 von 31 in der dritten. Der MI-Nachtrag beschreibt mehrere der
  Fälle ausdrücklich als vorläufig unsicher und baut seine Schutzlogik darauf, dass unsichere
  Segmente keinen Zustandsbonus erzeugen.

**Ausdrücklich nicht gemessen:** die fachliche Richtigkeit der Einordnung. Die 14 Fälle sind laut
MI-Nachtrag Arbeitsentwürfe und keine Goldreferenz; es wurde bewusst keine Trefferquote gegen sie
gebildet. Der fachlich geprüfte Referenzsatz fehlt weiterhin und ist von Jonas zu liefern.

**Kein Swift-Adapter vorhanden.** Die App verwendet unverändert `DemoModelProvider` mit festen
Antworten. Gemessen wurde außerhalb der App mit `Tools/openrouter_eval.py`.

## 19. September 2026

### Bestanden

- TrainerCore: **17 Tests**, darunter 18 deterministische Regelreferenzen und ein parametrisierter Speicherfehlertest mit zwei Fällen.
- Abgedeckte Fehler: ungültige Einordnung/Antwort, unsichere Belege, gesperrte Fakten, doppelter Sendebefehl, späte Antwort nach Abbruch, Löschen während einer Antwort, Wiederholung nach Speicherfehler vor/nach Commit, Wiederholung der 20. Runde, idempotenter Abschluss.
- TrainerStorage: echter SwiftData-Dateispeicher angelegt und erneut geöffnet; Entwurf und Snapshot bleiben gleich; identischer Commit wird nach erneutem Öffnen nicht doppelt übernommen; Löschen verhindert spätere Wiederherstellung durch Commit.
- Inhaltscompiler: drei Tests mit ungültigen Typen, unbekannten/doppelten Schlüsseln, doppelten Fakten-IDs, ungültigen Schwellen, Entwurfssperre und Trennung des öffentlichen Profils. Deterministisches JSON und Hash erzeugt.
- Gemeinsame SwiftUI-Quellen als Mac-Debug-App kompiliert und lokal signiert.
- Mac-Oberfläche bedient: Sitzung starten, Beitrag senden, feste Antwort erhalten, ungesendeten Entwurf sichern, Sitzung über die Übersicht erneut öffnen, Entwurf unverändert fortsetzen, zweite Runde senden und abschließen. Rückblick zeigt zwei Runden, keine fachliche Einordnung und keine erfundene Kennzahl bei fehlendem Nenner.

### Konkrete Grenzen

- Xcode 26.6 / iOS-SDK 26.5 vorhanden; der geplante iOS-27-Integrationsversuch fehlt.
- Xcode-Paketauflösung scheiterte in der Ausführungsumgebung an einer verschachtelten Sandbox (`sandbox_apply: Operation not permitted`). Der Mac-Quellbuild wurde deshalb mit SwiftPM und dessen expliziter Option `--disable-sandbox` innerhalb der bestehenden Ausführungsbeschränkungen geprüft.
- Simulatorzugriff über CoreSimulator war in der Ausführungsumgebung nicht verfügbar. Kein Simulator- oder iPhone-Start behauptet.
- SwiftData meldete unter der Sandbox Warnungen zum systemweiten Store-Änderungsdienst. Der Datei-Roundtrip selbst bestand. Mehrprozess-Synchronisation wird nicht verwendet und wurde nicht geprüft.
- Backup-Ausschluss und iOS-Dateischutz benötigen reale Geräteprüfung. Kein positiver Datenschutz-Gerätenachweis aus dem Mac-Test abgeleitet.
- Kein echtes Sprachmodell angeschlossen oder als geeignet freigegeben. Keine Modellgewichte heruntergeladen. Keine KI-Qualitäts-, Speicher- oder Latenzmessung.
- Sprache, PDF, fachliche Inhaltsfreigabe, vollständiger Offline-Geräteversuch und iPhone-14/15-Freigabe stehen aus.

Der Stand ist eine technische Demo und Grundlage für die weitere Umsetzung, keine fertige Trainings-App.
