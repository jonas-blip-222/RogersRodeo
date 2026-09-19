# Zwischenstand · 19. September 2026

Auf Wunsch des Nutzers wegen knapper werdender Nutzung gesichert. Keine weitere Arbeit im Hintergrund vorgesehen.

Nachtrag: Der Code-Stand `caaceff` hat sämtliche GitHub-Actions-Prüfungen bestanden. Die neue Mac-Demo wurde als `RogersRodeo-Monochrom.app` im lokalen outputs-Ordner verpackt und geöffnet. Die Startseite lädt das Carl-Rogers-Porträt und die neue Navigation. Die gemeinsame gestalterische Abnahme mit dem Nutzer steht noch aus; kein iPhone-Sichttest durchgeführt.

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
2. Die aktuelle lokale Demo heißt RogersRodeo-Monochrom.app; RogersRodeo.app enthält noch die alte Oberfläche. Weitere Motive, Verlauf, Gespräch und kleine Ansichten visuell prüfen.
3. Xcode-MCP-Verbindung und Simulator mit dem jetzt vorhandenen Xcode 27 prüfen. Die neue Lizenz/SDK-Version allein belegt noch keinen funktionierenden Simulatorzugriff.
4. MI-Feedback-Entscheidung gemeinsam fortsetzen: LLM für kontextbezogene Analyse, geprüfte Inhalte und deterministische Auswahl für Hinweise; freie Umformulierungen optional. Das ist bisher ein Vorschlag, keine implementierte Feedback-KI.
5. Danach echte lokale LLM-Anbindung. Direkte MLX-Anbindung und FoundationModels-Brücke noch gegeneinander abwägen; kein Modell als freigegeben behandeln.

Weitere offene Punkte stehen in TODO.md. STATUS.md beschreibt den zuvor geprüften Basisstand; die aktualisierte Toolchain und UI-Prüfung stehen hier.
