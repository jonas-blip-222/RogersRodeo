# Prüfung des Bauplanpakets

Stand: 18.09.2026.

## Ausgeführt

| Prüfung | Ergebnis |
|---|---|
| Swift-Verträge mit Swift-6-Sprachmodus kompilieren | Erfolgreich |
| Beispiel-Einordnung mit dem tatsächlichen Swift-Typ decodieren | Erfolgreich |
| Beispiel-Antwort mit dem tatsächlichen Swift-Typ decodieren | Erfolgreich |
| Alle 18 Regelreferenzfälle in Swift decodieren | Erfolgreich |
| Vorher-/Nachher-Zustände codieren und wieder decodieren | Erfolgreich; Werte unverändert |
| Zustandsbereiche und Größe des Gutschriftfensters in den Beispielen | Alle im vorgesehenen Bereich |
| JSON-Syntax, lokale Markdown-Links und geschlossene Codeblöcke | Erfolgreich |

Für die Swift-Prüfung wurden die unveränderte Vertragsdatei und ein temporärer Decoder-Prüflauf gemeinsam kompiliert. Ziel war `arm64-apple-macosx15.0`, Sprachmodus Swift 6; Compiler-Caches und ausführbare Prüfdateien liegen außerhalb des Lieferpakets im Arbeitsordner. Das Prüfprogramm wurde erfolgreich ausgeführt.

## Durchsicht auf Konsistenz

Abgeglichen wurden Datenfelder, Codes, JSON-Beispiele und Regeln, die Behandlung fehlender Einordnungen, die Trennung von verfügbaren und erzählten Fakten, Wiederholungsfenster, Transaktionsgrenzen, Kontextkürzung und Referenzbelege sowie die Abhängigkeiten der Arbeitspakete. Während der Durchsicht wurden fehlende Details ergänzt, etwa die Versuchsgeneration nach Abbruch und das Verhalten bei bereits erreichtem Offenheitsmaximum.

## Aussagegrenzen

Die Vertragsdatei enthält keine Implementierung des StateReducers. Die 18 Fälle sind erwartete Ergebnisse für dessen spätere Tests; sie wurden nicht gegen einen fertigen App-Regelkern ausgeführt. Die Kodierbeispiele sind synthetisch und fachlich nicht validiert.

Es wurden keine iOS-App, Modellinferenz, SwiftData-Implementierung oder Audiointegration gebaut oder auf dem iPhone getestet. Es gibt noch keine nachgewiesene Gerätefreigabe, Modellwahl, Antwortzeit, Speicherspitze oder App-Bundle-Größe. Diese Nachweise haben konkrete Plätze im Umsetzungsplan.
