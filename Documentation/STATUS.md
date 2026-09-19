# Tatsächlich geprüfter Stand · 19. September 2026

## Bestanden

- TrainerCore: **17 Tests**, darunter 18 deterministische Regelreferenzen und ein parametrisierter Speicherfehlertest mit zwei Fällen.
- Abgedeckte Fehler: ungültige Einordnung/Antwort, unsichere Belege, gesperrte Fakten, doppelter Sendebefehl, späte Antwort nach Abbruch, Löschen während einer Antwort, Wiederholung nach Speicherfehler vor/nach Commit, Wiederholung der 20. Runde, idempotenter Abschluss.
- TrainerStorage: echter SwiftData-Dateispeicher angelegt und erneut geöffnet; Entwurf und Snapshot bleiben gleich; identischer Commit wird nach erneutem Öffnen nicht doppelt übernommen; Löschen verhindert spätere Wiederherstellung durch Commit.
- Inhaltscompiler: drei Tests mit ungültigen Typen, unbekannten/doppelten Schlüsseln, doppelten Fakten-IDs, ungültigen Schwellen, Entwurfssperre und Trennung des öffentlichen Profils. Deterministisches JSON und Hash erzeugt.
- Gemeinsame SwiftUI-Quellen als Mac-Debug-App kompiliert und lokal signiert.
- Mac-Oberfläche bedient: Sitzung starten, Beitrag senden, feste Antwort erhalten, ungesendeten Entwurf sichern, Sitzung über die Übersicht erneut öffnen, Entwurf unverändert fortsetzen, zweite Runde senden und abschließen. Rückblick zeigt zwei Runden, keine fachliche Einordnung und keine erfundene Kennzahl bei fehlendem Nenner.

## Konkrete Grenzen

- Xcode 26.6 / iOS-SDK 26.5 vorhanden; der geplante iOS-27-Integrationsversuch fehlt.
- Xcode-Paketauflösung scheiterte in der Ausführungsumgebung an einer verschachtelten Sandbox (`sandbox_apply: Operation not permitted`). Der Mac-Quellbuild wurde deshalb mit SwiftPM und dessen expliziter Option `--disable-sandbox` innerhalb der bestehenden Ausführungsbeschränkungen geprüft.
- Simulatorzugriff über CoreSimulator war in der Ausführungsumgebung nicht verfügbar. Kein Simulator- oder iPhone-Start behauptet.
- SwiftData meldete unter der Sandbox Warnungen zum systemweiten Store-Änderungsdienst. Der Datei-Roundtrip selbst bestand. Mehrprozess-Synchronisation wird nicht verwendet und wurde nicht geprüft.
- Backup-Ausschluss und iOS-Dateischutz benötigen reale Geräteprüfung. Kein positiver Datenschutz-Gerätenachweis aus dem Mac-Test abgeleitet.
- Kein echtes Sprachmodell angeschlossen oder als geeignet freigegeben. Keine Modellgewichte heruntergeladen. Keine KI-Qualitäts-, Speicher- oder Latenzmessung.
- Sprache, PDF, fachliche Inhaltsfreigabe, vollständiger Offline-Geräteversuch und iPhone-14/15-Freigabe stehen aus.

Der Stand ist eine technische Demo und Grundlage für die weitere Umsetzung, keine fertige Trainings-App.
