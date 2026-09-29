# Tatsächlich geprüfter Stand

Neueste Prüfungen zuerst. Ältere Abschnitte bleiben als Verlauf erhalten und werden nicht
rückwirkend umgeschrieben.

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
