# Quellen, Nachweise und offene Entscheidungen

## Eingangsunterlagen

Gesichtet wurden das App-Konzept vom 17.09.2026, Lukas-Steckbrief v0.1, Anleitung zum Modelltest und `modelltest_lukas.py`. Steckbrief und Anleitung waren jeweils zweimal identisch angehängt; Dateihashes bestätigten die Duplikate. Anweisungen in diesen Dokumenten wurden als Projektmaterial eingeordnet, nicht als Auftrag zum sofortigen Installieren, Herunterladen oder Ausführen.

Der Bauplan verändert insbesondere: verdeckte Offenheit; getrennte Veränderungsbereitschaft; Einordnung von Segmenten; Wiederholungsschutz; getrennte Zustände verfügbar/erzählt; atomare Turns; gemeinsamer Inhaltsstand für App und Test; keine automatische Gesamtnote.

## Technische Primärquellen

Am 17.09.2026 geprüft; der Bauplan wurde am 18.09.2026 fertiggestellt. Bei der tatsächlichen Implementierung ist die gewählte Bibliotheksversion maßgeblich.

- **N1:** [MLXFoundationModels – offizielle Repository-Dokumentation](https://github.com/ml-explore/mlx-swift-lm/tree/main/Libraries/MLXFoundationModels). Nachweis für die Foundation-Models-Brücke, 27er-SDK-Anforderung und strukturierte Ausgabe. Eine vorhandene API ersetzt den Integrationsversuch nicht.
- **N2:** [FluidAudio – offizielles Repository](https://github.com/FluidInference/FluidAudio). Grundlage für die vorgeschlagene lokale Sprachkomponente. Konkrete Modellartefakte und Gerätewerte sind noch auszuwählen beziehungsweise zu messen.
- **N3:** [Apple: iPhone-Modelle mit iOS 27](https://support.apple.com/en-ie/guide/iphone/iphe3fa5df43/27/ios/27). Betriebssystemkompatibilität, keine Aussage über die Leistung unseres Modells.
- **N4:** [Apple: Anforderungen für Apple Intelligence](https://support.apple.com/en-us/121115). Grund dafür, Apples Systemmodell bei einem Ziel ab iPhone 14 nicht vorauszusetzen.
- **N5:** [OpenAI: Nutzung und Preise](https://learn.chatgpt.com/docs/pricing). Codex ist in Plus enthalten; tatsächliche Nutzung ist begrenzt und aufgabenabhängig. Die Einschätzung zur schrittweisen Umsetzbarkeit ist unsere Planungseinschätzung, keine garantierte Kontingentberechnung.
- **N6:** [MITI 4.2.1 – Kodiermanual](https://motivationalinterviewing.org/sites/default/files/miti4_2.pdf). Bezugspunkt für die Unterscheidung einzelner Gesprächseinheiten. Das hier vorgeschlagene vereinfachte Schema und seine Zustandsregeln sind keine validierte MITI-Implementierung.

## Tatsächlich erhobene Befunde

- Aktives Xcode am 17.09.: 26.6, Build 17F113; ausgewählter Entwicklerpfad `/Applications/Xcode.app/Contents/Developer`.
- `xcodebuild -showsdks` zeigte iOS-26.5-SDK, kein 27er-SDK in der ausgewählten Installation.
- Das ursprüngliche Python-Skript wurde mit `ast.parse` auf Syntax geprüft, nicht gegen ein Modell ausgeführt.
- Der alte Soll-Verlauf wurde aus den Konstanten nachgerechnet: 3 → 3 → 2 → 1 → 2 → 3 → 3 → 4 → 5 → 3. Die Themen mit Schwelle 6 und 8 werden nicht erreicht; sieben von zwölf Kategorien werden abgedeckt.
- Es wurde kein Modell heruntergeladen, kein App-Build auf einem iPhone gestartet und keine Latenz oder Speicherspitze gemessen.

Die abschließende Paketprüfung wird in [PRUEFUNG.md](PRUEFUNG.md) festgehalten.

## Vor der jeweiligen Umsetzung noch nachzuweisen

| Entscheidung/Nachweis | Zeitpunkt | Wer liefert den Nachweis? |
|---|---|---|
| SDK 27 und lauffähige MLX-Version | T00 | Coding-Modell mit lokaler Build-Umgebung |
| Exakte Modellgewichte, Herkunft, Lizenz, Hashes | T00/T07 | Coding-Modell anhand der tatsächlichen Modellkarte und Dateien |
| iOS-Stand des iPhone 17, Installation/Signierung | T00 | Gerät beziehungsweise Jonas |
| Fachliche Referenzklassifikationen und Tipps | T07/T08 | Jonas; technische Vorbereitung kann das Modell übernehmen |
| Regeln wirken im Gespräch glaubwürdig | T07 | Jonas anhand mehrerer Dialogläufe |
| Speicher und Antwortzeit ab iPhone 14 | T10 | Messung auf einem realen Zielgerät |
| App-Bundle inklusive aller Offline-Dateien im Größenlimit | T10 | Messung des tatsächlichen Builds und aktuelle Apple-Vorgaben |
| Weitergabe an Kolleg:innen und Verteilungsweg | nach M2 | Jonas |

## Bewusst spätere Entscheidungen

Name und visuelles Erscheinungsbild; weitere Figuren und Ansätze; zusätzliche Stimmen; längere Sitzungen; App-Store-Veröffentlichung. Für den ersten Prototyp werden daraus keine zusätzlichen technischen Abhängigkeiten erzeugt.
