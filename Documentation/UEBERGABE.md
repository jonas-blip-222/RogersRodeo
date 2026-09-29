# Übergabe an Claude · 29. September 2026

Weiterarbeit auf Branch `codex/doppelseitige-reflexion`. Letzter Implementierungscommit:
`9b80790` (MI-03: Zielanalyse trennen und belegte Zielidentität absichern).
Jonas hat Abschluss und Push dieses Branches beauftragt; kein Merge nach `main`.
Die folgenden Angaben ersetzen die Arbeitsplanung vom 19. September weiter unten.

## Erledigt und geprüft

Das belegte Zielgedächtnis einschließlich Alias, Zustimmung, Zielwechsel, Widerruf und späterer
Unsicherheit ist implementiert. Alte Originalbelege werden gezielt außerhalb des normalen
Sechs-Turn-Fensters zurückgeholt. Die dokumentierten Fehlerfälle der ersten Live-Prüfung sind
mit unveränderten Erwartungen erneut geprüft und bestanden.

Der OpenRouter-Adapter trennt jetzt Ziel-/Charakteranalyse des bisherigen Verlaufs von der
Einordnung der aktuellen Beratung. Erst validierte Teilergebnisse ergeben eine `TurnAnalysis`.
Keine unbelegten Parallelziele aus Charakterbeobachtungen. Prompt 0.5, Regeln 0.4,
Snapshot-Schema 1. Für neue Regeln ein neues Gespräch beginnen. Regulär zwei Analyseaufrufe
plus eine Rollenantwort je Runde; Wiederholungen können weitere Aufrufe auslösen.
Atomarer Commit bleibt erhalten. Automatische Rollenentwicklung bleibt ausgeschaltet.

- 77 Core-, 3 Storage- und 40 reguläre App-Tests bestanden; gemeinsame SwiftUI-Quellen als
  macOS-Prüf-App gebaut. Zwei Live-Tests im Offline-Lauf übersprungen.
- Fünf bekannte Schlüsselbundtests gezielt ausgenommen, nicht als bestanden gezählt.
- Finale Live-Prüfung: 15 Runden, alle 14 Prüfaussagen bestanden; danach sieben von sieben
  unabhängigen Gegenproben bestanden. Fiktive feste Klientenantworten, echte Modellanalysen.
- Kein freier Rollenlauf und keine neue iOS-/Simulator-/Geräte- oder VoiceOver-Abnahme.

## Empfohlene nächste Arbeit

1. Weitere unabhängige Formulierungsvarianten prüfen und einen freien Rollenlauf manuell testen.
2. Latenz, Wiederholungen, konkrete Anbieterrouten und vollständige Kosten erfassen. Der finale
   15-Runden-Lauf dauerte 327 Sekunden. Der Median von 5,7 Sekunden umfasst nur erfolgreiche
   kombinierte Analysestufen, nicht sämtliche Wartezeiten und Fehlversuche.
3. Simulator-/Geräteprüfung nachholen; anschließend weitere Aufgaben aus `TODO.md` priorisieren.
   Die kleinen erfolgreichen Testreihen sind keine repräsentative fachliche Qualitätsmessung.

Details und historische Fehlversuche: [STATUS.md](STATUS.md). Architektur:
[ARCHITEKTUR.md](ARCHITEKTUR.md). Beschlossene Cloud-Ausnahme gegenüber älteren Offline-Vorgaben:
[ENTSCHEIDUNGEN.md](ENTSCHEIDUNGEN.md), E01–E03. Zugangsdaten niemals ausgeben oder speichern.

Live-Tests sind kostenpflichtig und ausdrücklich opt-in:
`python3 Tools/run_goal_memory_live.py long` beziehungsweise
`python3 Tools/run_goal_memory_live.py probes`.
Die finalen lokalen Rohbefunde liegen ignoriert unter
`Evaluation/results/goal-memory-fix-2026-09-29/` und werden nicht gepusht.

## Vorhandene fremde Änderungen

Beim Abschluss lagen folgende Änderungen bereits außerhalb der eigenen Commits vor; sie
wurden nicht verändert oder gestaged und sind nicht Teil dieses Pushs:

- `Tools/openrouter_eval.py` (modifiziert)
- `Evaluation/lange-faelle.json` (unversioniert)
- `Tests/Testläufe Jonas/` (unversioniert)

Nicht zurücksetzen, überschreiben oder beiläufig committen. Der Arbeitsbaum bleibt deshalb
absichtlich nicht vollständig sauber.

---

# Historischer Zwischenstand · 19. September 2026

Auf Wunsch des Nutzers wegen knapper werdender Nutzung gesichert. Keine weitere Arbeit im Hintergrund vorgesehen.

Nachtrag: Der Code-Stand `caaceff` hat sämtliche GitHub-Actions-Prüfungen bestanden. Die erste Mac-Vorschau zeigte trotz vorhandener Datei kein Porträt. Die korrigierte Vorschau heißt `RogersRodeo-Monochrom-v2.app` im lokalen outputs-Ordner: PNGs werden explizit mit ImageIO dekodiert statt über die benannte SwiftUI-Bildsuche geladen. Nach Neubau und Neustart wurde das Steve-de-Shazer-Porträt im Screenshot sichtbar bestätigt. Alle vier PNGs werden zusätzlich im Test dekodiert; beide Präsentationstests bestanden. Die gemeinsame gestalterische Abnahme mit dem Nutzer steht noch aus; kein iPhone-Sichttest durchgeführt.

## Neue Oberfläche

- Schwarz-weiße Gestaltung mit hellen Karten, klarer Typografie und getrennten Bereichen „Entdecken“ und „Meine Gespräche“.
- Vier erzeugte Cartoon-Motive: Carl Rogers, Steve de Shazer, Mara Selvini Palazzoli sowie William R. Miller und Stephen Rollnick gemeinsam.
- Porträts ausschließlich auf der Startseite, niemals im Gespräch.
- Rotation beim App-Start sowie bei Rückkehr aus dem Hintergrund. Navigation innerhalb der App wechselt das Motiv nicht. Die letzte Porträt-ID bleibt lokal gespeichert.
- Der Pool ist über `Beratungstrainer/Resources/Illustrations/portrait-pool.json` erweiterbar. Bilder und Erzeugungsprompts sind im Repository enthalten; siehe BILDGESTALTUNG.md.
- Der wechselnde Kopf ändert nicht den Beratungsansatz. Die eigentliche Übung bleibt die bisherige MI-Demo mit festen Antworten.

## Prüfung

- Nach dem vom Nutzer installierten Update ist Xcode 27.0 (27A266a) aktiv; die Lizenz wurde vom Nutzer bestätigt.
- Die aktuellen gemeinsamen SwiftUI-Quellen kompilieren mit dieser Toolchain.
- Zwei neue Präsentationstests bestanden: Ressourcen vorhanden, vollständiger Rotationszyklus, gespeicherte Auswahl über neue Rotatorinstanzen, entfernter Eintrag und Einzelelement-Pool.
- Der erste Test-Build unter dem iCloud-synchronisierten Projektpfad scheiterte beim Signieren an Finder-Metadaten. Derselbe Build und die Tests bestanden mit dem Build-Verzeichnis unter /private/tmp. Kein Anwendungscode musste dafür verändert werden.
- Die bisherigen Core-/Speichertests wurden für diese reine UI-Änderung nicht erneut lokal ausgeführt. GitHub Actions umfasst sie weiterhin und führt zusätzlich die neuen Präsentationstests aus.
- Noch offen: Sichtprüfung der neuen Oberfläche in der laufenden App, kleine iPhone-Bildschirme, große Schrift und echtes Hintergrund-/Vordergrundverhalten. Ein iPhone- oder Simulatorlauf der neuen Oberfläche wird nicht behauptet.

## Nächste Sitzung

1. Rückmeldung des Nutzers zur geöffneten Oberfläche aufnehmen. GitHub-Actions-Prüfungen für den UI-Code-Stand waren erfolgreich.
2. Die aktuelle lokale Demo heißt RogersRodeo-Monochrom-v2.app; RogersRodeo.app enthält noch die alte Oberfläche. Weitere Motive, Verlauf, Gespräch und kleine Ansichten visuell prüfen.
3. Xcode-MCP-Verbindung und Simulator mit dem jetzt vorhandenen Xcode 27 prüfen. Die neue Lizenz/SDK-Version allein belegt noch keinen funktionierenden Simulatorzugriff.
4. MI-Feedback-Entscheidung gemeinsam fortsetzen: LLM für kontextbezogene Analyse, geprüfte Inhalte und deterministische Auswahl für Hinweise; freie Umformulierungen optional. Das ist bisher ein Vorschlag, keine implementierte Feedback-KI.
5. Danach echte lokale LLM-Anbindung. Direkte MLX-Anbindung und FoundationModels-Brücke noch gegeneinander abwägen; kein Modell als freigegeben behandeln.

Weitere offene Punkte stehen in TODO.md. STATUS.md beschreibt den zuvor geprüften Basisstand; die aktualisierte Toolchain und UI-Prüfung stehen hier.
