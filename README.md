# Rogers Rodeo

Native Übungs-App für Gesprächsführung in der Drogenberatung. Die Analyse und die Antworten der
Figur kommen von einem Sprachmodell über OpenRouter; ohne hinterlegten Zugangsschlüssel läuft die
App stattdessen mit **festen Demo-Antworten** und weist das aus. Die Figur Lukas und das
MI-Lernschema sind fachliche Entwürfe.

Aktueller Zwischenstand und nächste Schritte: [Übergabe](Documentation/UEBERGABE.md).

Fachliche und architektonische Grundlage: [Bauplan v0.1](Documentation/Bauplan-v0.1/README.md) und der
[MI-Nachtrag vom 29.09.2026](Documentation/MI-UEBERGABE.md). Bei Widerspruch gilt der MI-Nachtrag
in **fachlichen** Fragen; für Architektur- und Betriebsentscheidungen gilt
[ENTSCHEIDUNGEN.md](Documentation/ENTSCHEIDUNGEN.md). Die Abschnitte 3 und 12 des Nachtrags
benennen die abgelösten Annahmen und die nächsten Arbeitspakete.

> **Wichtige Änderung am 29.09.2026: keine lokale Modellausführung mehr.**
> Die Modellaufrufe laufen über die OpenRouter-API statt über ein Modell auf dem Gerät. Damit
> verlassen die eingegebenen Beratungsäußerungen das Gerät, und ein Offline-Betrieb ist nicht mehr
> vorgesehen. Bauplan v0.1 beschreibt an vielen Stellen noch den lokalen Weg über MLX; diese
> Abschnitte sind überholt. Begründung, Grenzen und die gemessenen Folgen stehen in
> [ENTSCHEIDUNGEN.md](Documentation/ENTSCHEIDUNGEN.md), E01 bis E03.

## Vorhanden

- SwiftUI: Figur auswählen, Gespräch führen, Entwürfe sichern, Sitzungen fortsetzen und abschließen, Verlauf und Rückblick.
- Gesprächsdaten werden ausschließlich lokal per SwiftData gespeichert; kein Konto, keine
  CloudKit-Synchronisation. Das gilt weiterhin. Die **eingetippten Beiträge und der bisherige
  Gesprächsverlauf verlassen dagegen das Gerät**: sie gehen als Teil der Modellaufrufe an
  OpenRouter und von dort an den jeweils gewählten Anbieter. Nichts, was hier eingegeben wird,
  bleibt auf dem iPhone. Echtes Fall-, Klienten- oder Mandatsmaterial gehört deshalb nicht in
  die App.
- Markdown-Protokoll speichern oder ausdrücklich teilen.
- Schwarz-weiße Startseite mit vier wechselnden Cartoon-Motiven; Porträts bleiben aus dem Gespräch ausgeblendet.
- Getesteter Regelkern: verborgene Offenheit, segmentbezogene Regeln, Faktenfreigabe,
  Wiederholungsschutz und Ausgabevalidierung. Getestet heißt hier: die deterministische Logik ist
  durch Unit-Tests abgedeckt. Es ist **keine** Aussage über die fachliche Richtigkeit der
  MI-Einordnung; ein fachlich geprüfter Referenzsatz fehlt weiterhin.
- Abbruch, verspätete Modellantworten, Speicherfehler und idempotente Übernahme vollständiger Runden.
- Ein gemeinsamer, deterministisch erzeugter Inhaltskatalog mit SHA-256-Prüfung.
- Angebundene Modellinferenz: `Beratungstrainer/Services/Models/OpenRouterModelProvider.swift`
  mit zweistufiger Analyse und Rollenantwort, Schlüsselablage im Schlüsselbund und einer
  Einstellungsansicht zur Schlüsseleingabe.

**Noch nicht vorhanden:** Lauf des angebundenen Modells im Simulator und auf einem echten Gerät,
eine Zeitgrenze je Gesprächsrunde, der einmalige Disclaimer nach E07, die Anbieterbeschränkung
nach E06, Spracheingabe und -ausgabe, PDF-Export, fachlich geprüfte Tipps und Gerätefreigabe.
Ohne hinterlegten Schlüssel greift der Demo-Betrieb; dessen feste Antworten liefern keine
fachliche Einordnung. Auch die Modellanalyse bewertet keine Beratungskompetenz.

Was am Modell bereits gemessen ist und was ausdrücklich nicht, steht in
[STATUS.md](Documentation/STATUS.md) unter dem 29. September 2026.

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

Der Build gegen den iPhone-17-Simulator mit iOS 27.0 ist am 29.09.2026 erstmals erfolgreich
gelaufen und wurde im Simulator bedient. Ein Lauf auf einem echten Gerät steht weiterhin aus.

Die früher geplante FoundationModels/MLX-Brücke entfällt ersatzlos (siehe Hinweis oben und E01).
Damit gibt es auch keinen technischen Grund mehr für iOS 27 als Deployment-Target; es steht noch
auf 27 und ist neu zu bestimmen. Aktueller Prüfstand: [Documentation/STATUS.md](Documentation/STATUS.md).

## Prüfungen

```sh
swift test --package-path Packages/TrainerCore
swift test --package-path Packages/TrainerStorage
swift test
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
