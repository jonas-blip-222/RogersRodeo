# Tatsächlich geprüfter Stand

Neueste Prüfungen zuerst. Ältere Abschnitte bleiben als Verlauf erhalten und werden nicht
rückwirkend umgeschrieben.

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
