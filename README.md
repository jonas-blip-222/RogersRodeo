# Rogers Rodeo

Native Übungs-App für Gesprächsführung in der Drogenberatung. Der erste Stand enthält eine **ausprobierbare Text-Demo mit festen Antworten**, noch keine KI. Die Figur Lukas und das MI-Lernschema sind fachliche Entwürfe.

## Vorhanden

- SwiftUI: Figur auswählen, Gespräch führen, Entwürfe sichern, Sitzungen fortsetzen und abschließen, Verlauf und Rückblick.
- Ausschließlich lokale SwiftData-Speicherung; kein Konto, Server oder CloudKit.
- Markdown-Protokoll speichern oder ausdrücklich teilen.
- Getesteter Regelkern: verborgene Offenheit, segmentbezogene Regeln, Faktenfreigabe, Wiederholungsschutz und Ausgabevalidierung.
- Abbruch, verspätete Modellantworten, Speicherfehler und idempotente Übernahme vollständiger Runden.
- Ein gemeinsamer, deterministisch erzeugter Inhaltskatalog mit SHA-256-Prüfung.

**Noch nicht vorhanden:** echte lokale Modellinferenz, Spracheingabe/-ausgabe, PDF-Export, fachlich geprüfte Tipps und Gerätefreigabe. Die Demo liefert keine fachliche Einordnung und bewertet keine Beratungskompetenz.

## Start am Mac

Benötigt macOS 15 oder neuer und eine Swift-6-Toolchain. Die Mac-Prüf-App verwendet dieselben SwiftUI-Quellen wie das iPhone-Projekt.

```sh
swift run RogersRodeo
```

Für eine anklickbare lokale Debug-App:

```sh
swift build
python3 Tools/package_desktop.py --bin-path "$(swift build --show-bin-path)" --output dist/RogersRodeo.app
```

Das Verpackungsskript überschreibt keine bestehende Ausgabe. Der Build ist lokal signiert, nicht für öffentliche Verteilung notarisiert. Sitzungsspeicher der Mac-Prüf-App: Application Support/RogersRodeo/Conversations im Benutzerkonto. Tests können im Debug-Build mit `ROGERS_RODEO_TEST_STORAGE` einen getrennten Stammordner verwenden.

## iPhone-Projekt

`Beratungstrainer.xcodeproj` öffnen, Scheme **Beratungstrainer**, Konfiguration **Debug**, eigenes Signing-Team und Gerät auswählen. Das geplante Deployment-Target bleibt **iOS 27**. Die unabhängigen Pakete benötigen iOS 17; daraus folgt keine Freigabe der vollständigen App für iOS 17.

Die geplante FoundationModels/MLX-Brücke erfordert einen noch ausstehenden Integrationsversuch mit dem passenden 27er-SDK. Eine vorhandene Version Xcode 26.6 ersetzt diesen Nachweis nicht. Zuerst auf iPhone 17 prüfen; iPhone 14/15 bleiben angestrebte, nicht zugesicherte Zielgeräte. Aktueller Prüfstand: [Documentation/STATUS.md](Documentation/STATUS.md).

## Prüfungen

```sh
swift test --package-path Packages/TrainerCore
swift test --package-path Packages/TrainerStorage
python3 -m venv .venv
.venv/bin/pip install -r Tools/requirements.txt
.venv/bin/python -m unittest discover -s Tools -p 'test_*.py'
.venv/bin/python Tools/compile_content.py --allow-drafts --check
```

Nach Inhaltsänderungen den letzten Befehl ohne `--check` ausführen. Entwürfe sind nur in Debug-Builds erlaubt. Es existiert bewusst noch kein Release-Inhaltsbestand; einfaches Ändern des Status ersetzt keine fachliche Prüfung.

GitHub Actions prüft Pakete, Inhalte und den Mac-App-Build. Modellgewichte, Sitzungsdaten und lokale Testergebnisse sind nicht Bestandteil des Repositories.

## Aufbau

| Bereich | Verantwortung |
|---|---|
| `Packages/TrainerCore` | Verträge, Regeln, Koordination, Validierung, Auswertung; kein UI-/MLX-/Speicherframework |
| `Packages/TrainerStorage` | SwiftData-Repository; atomare Persistenz über dieselben geprüften Regeln |
| `Beratungstrainer` | SwiftUI-Oberfläche und Zusammensetzen der Abhängigkeiten |
| `ContentSource` | Figurenprofil, getrennte verborgene Fakten, Kodierleitfaden |
| `Tools` | Inhaltscompiler, Tests und reproduzierbare Projekt-/Demo-Verpackung |
| `Documentation` | Architekturentscheidungen, Prüfstand, nächste Implementierungsschritte |

Offenheit steuert ausschließlich die Bereitschaft der Figur, persönlich zu erzählen. Sie bleibt in normalen Ansichten verborgen und ist weder Veränderungsbereitschaft noch eine Kompetenznote.
