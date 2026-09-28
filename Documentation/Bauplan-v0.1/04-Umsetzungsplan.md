# Umsetzungsplan

Jedes Arbeitspaket endet mit einem lauffähigen oder eindeutig prüfbaren Ergebnis. Das ausführende Modell bearbeitet standardmäßig genau ein Paket, dokumentiert tatsächliche Prüfungen und hinterlässt eine kurze Übergabe. Die Reihenfolge ist verbindlich, soweit Abhängigkeiten genannt sind.

## T00 – Werkzeugstand und Integrationsversuch

**Voraussetzung:** Zugriff auf Xcode mit iOS-27-SDK und auf Jonas' Testgerät für den Geräteteil.

**Arbeit:** Aktive Xcode-/SDK-Version prüfen; bei Bedarf Xcode aktualisieren beziehungsweise korrekt auswählen. In einem wegwerfbaren Probeprojekt MLX lokal laden, einmal strukturiert einordnen und einmal eine Rollen-Antwort erzeugen. Einen kleinen Kandidaten mit festgehaltener Modellrevision verwenden. Framework-API direkt aus der gewählten Version übernehmen. Lokalen Loader und Cancellation prüfen.

**Abnahme:** Build für Gerät und tatsächlicher Offline-Lauf auf iPhone 17; keine automatische Netzwerkbeschaffung beim App-Start; ein Modell im Speicher; verwendete Pins und Artefakte dokumentiert.

**Grenze:** Kein App-Design, kein vollständiger Vergleich aller fünf ursprünglichen Kandidaten. Falls Xcode oder Gerät fehlt, diesen fehlenden Nachweis klar festhalten. Unabhängiger Core-Code aus T01–T05 kann mit Testantworten vorbereitet werden; iOS-27-Builds und Simulatorprüfungen benötigen trotzdem das passende SDK.

## T01 – Repository und App-Gerüst

**Arbeit:** Projektbaum aus Architektur anlegen, eine App mit Auswahl- und Gesprächsplatzhalter, lokales Paket `TrainerCore`, Git-Ignore, Testschema und kurze Build-Anleitung. Verträge aus diesem Paket übernehmen. Abhängigkeiten im App-Target halten.

**Abnahme:** Core baut ohne MLX; App startet im Simulator; genau ein Scheme `Beratungstrainer`; Core-Tests laufen über `swift test` und UI-Tests über Xcode. Deployment-Target 27, Swift-6-Sprachmodus. Gewichte, `.build`, DerivedData und lokale Protokolle sind nicht in Git.

**Prüfbefehl nach Einrichtung:** `swift test --package-path Packages/TrainerCore`; für Xcode zunächst `xcodebuild -list` und `-showdestinations`, anschließend `xcodebuild test -project Beratungstrainer.xcodeproj -scheme Beratungstrainer -destination 'id=<ermittelte Simulator-ID>'`. Die ID wird tatsächlich ermittelt und nicht erfunden.

## T02 – Inhalte und Compiler

**Abhängigkeit:** T01.

**Arbeit:** Autorformat und JSON-Abbildung implementieren, Lukas migrieren, öffentliche Persona von gesperrten Fakten trennen. Compiler liest Markdown/YAML und erzeugt den Katalog. In der App nur `ContentCatalog` mit Decodable-JSON. Der Python-Test liest denselben Katalog.

**Abnahme:** Fehlende Pflichtfelder, doppelte IDs, ungültige Schwellen und unbekannte Felder brechen den Build ab. Gleiche Quelle ergibt bytegleiches JSON. Entwickler-Build kann Entwürfe laden. Gesperrte Fakten stehen weder auf der Auswahlkarte noch im öffentlichen Rollenprofil.

## T03 – Validierung und Regelkern

**Abhängigkeit:** T02.

**Arbeit:** Segmentzitate und Fakten-IDs prüfen, StateReducer und Faktenauswahl implementieren. Unterstützende Klientenzitate prüfen. Referenzfälle aus `regeltests.json` übernehmen.

**Abnahme:** Referenzfälle vollständig grün; Offenheit bleibt 0–10; geschlossene Fragen werden anhand der Segmente gezählt; Bonusfenster zählt die letzten drei abgeschlossenen Turns einschließlich leerer Gutschriften. Bereits erzählte Themen bleiben verfügbar. Das bloße Berechnen verändert keine gespeicherte Sitzung.

**Zusatzfälle:** Identische Zitate in einem Text, Emojis/Umlaute, überlappende beziehungsweise erfundene Zitate, unbekannter Code, ungültige Fakten-ID, leere/zu lange Ausgabe. JSON-Validierung darf nicht allein aus `Codable` bestehen: unbekannte Schlüssel müssen vor Decoding erkannt werden.

## T04 – Gesprächssteuerung mit festen Antworten

**Abhängigkeit:** T03.

**Arbeit:** Coordinator und Testprovider implementieren; erfolgreiche und fehlerhafte Teilschritte durchspielen. Eingabe-UUID und getrennte Versuchsgeneration verwenden, damit ein früher Versuch bei erneuter Anfrage nicht gewinnt.

**Abnahme:** Eine vollständige Runde; Klassifikationsfehler mit ausdrücklichem Fortsetzen ohne Einordnung; Antwortfehler; Abbruch; verspätetes Ergebnis; doppelte Sendetaste. In keinem dieser Fälle doppelter Turn oder verfrühte Offenheitsänderung. Actor-Reentrancy wird durch IDs/Revisionen abgesichert, nicht bloß durch die Wahl eines Actors.

## T05 – Speicherung und Wiederaufnahme

**Abhängigkeit:** T04.

**Arbeit:** SwiftData-Repository, Snapshot-Codierung, PendingTurn, atomaren Commit und Abschließen implementieren. Eingefrorenen Inhaltsstand und BuildIdentity mit der Sitzung speichern. UI-Wiederaufnahme immer aus dem Repository.

**Abnahme:** Neustart nach Eingabe, nach Einordnung, während Antwort und unmittelbar nach Commit. Entwurf bleibt Entwurf; kein doppelter Einstieg. Commit nach unbekanntem Ausgang kann sicher wiederholt werden. Revisionskonflikt überschreibt nichts. Löschen entfernt Sitzung und Entwurf; Abbruch während Löschens kann sie nicht wiederherstellen.

**Prüfung:** Mindestens eine Integration mit dem echten SwiftData-Speicher, zusätzlich schneller In-Memory-Test für Fehlerfälle. Dateischutz, Backup-Ausschluss und deaktivierte CloudKit-Synchronisation prüfen.

## T06 – Vollständiger Textablauf

**Abhängigkeit:** T05.

**Arbeit:** Auswahl, Chat, Hinweisfläche, Verlauf und einfache Abschlussansicht verbinden. Dynamische Schriftgrößen, VoiceOver-Beschriftungen und Tastaturbedienung berücksichtigen. Technische Diagnostik nur im Entwicklerbereich.

**Abnahme:** Neuer Durchlauf mit Testprovider bis Abschluss, App schließen und fortsetzen, exportierbares Protokoll. Offenheit bleibt in allen normalen Ansichten verborgen. Eingabe bleibt nach einem Fehler erhalten. Keine Nutzeransicht zeigt JSON, interne Codes oder Modellprompts.

## T07 – Reales Modell und Evaluation

**Abhängigkeit:** T00 und T06.

**Arbeit:** Gepinnten Adapter integrieren; Kontextbudget, lokale Artefaktprüfung und technische Messwerte implementieren. Modelltest nach Qualitätsplan überarbeiten. Fachlich geprüften Evaluationssatz bereitstellen; bis dahin sind technische Testdaten ausdrücklich provisorisch.

**Abnahme:** Kriterien aus Qualitätsplan mit Ergebnisdatei belegen. Fehlende fachliche Referenzen als offene Prüfung dokumentieren. Drei reale Textsitzungen mit 20 Turns auf iPhone 17. Kalt-/Warmzeiten und Speichermaximum messen.

**Meilenstein M1:** Textprototyp mit echtem Modell. Wenn die Modellqualität scheitert, keine Zeit in zusätzliche Oberflächenpolitur investieren, bevor die Ursache geklärt ist.

## T08 – Kuratierte Hinweise und Auswertung

**Abhängigkeit:** T07 für reale Qualitätsprüfung; technische Umsetzung kann bereits mit T06 beginnen.

**Arbeit:** Tippkatalog mit Quellen, deterministische Auswahl, Kennzahlen und zitierte Gesprächsstellen. Einen Minimalbestand von elf fachlich geprüften Tipps anlegen, je primärem Etikett einen. `null`-Etikett zeigt keinen Tipp. Solange Inhalte fehlen, zeigt die App einen leeren Hinweiszustand statt erfundener Beratungstexte.

**Abnahme:** Kein Tipp für falschen Ansatz; stabile Auswahl; reine Testtexte gelangen nicht in Release-Inhalte. Unsichere/fehlende Einordnungen werden nachvollziehbar ausgewiesen. Division durch null ist ausgeschlossen. Hohe Offenheit erzeugt weder Kompetenznote noch automatisches Veränderungsziel.

## T09 – Push-to-Talk und Sprachausgabe

**Abhängigkeit:** T07.

**Arbeit:** Audioaufnahme, lokale ASR, Transkriptkorrektur, Senden und TTS anbinden. Audioanbieter bleiben außerhalb des Core. Die Aufnahme liefert am Ende denselben Eingabetext wie der Textmodus.

**Abnahme:** Offline-Erststart einschließlich ASR; Mikrofon verweigert; Unterbrechung; Bluetooth-Wechsel; 60-Sekunden-Grenze; Hintergrundwechsel. TTS erst nach Commit. Drei Sprachsitzungen mit Speicher- und Latenzmessung. Kein paralleles Abspielen und Aufnehmen im Push-to-Talk-Modus.

## T10 – Export und Gerätefreigabe

**Abhängigkeit:** T08, T09.

**Arbeit:** Markdown- und PDF-Export via Teilen-Menü, vollständiger Offline-Test, Paketgröße und Lizenzdateien prüfen. Tests auf einem echten iPhone 14 und gegebenenfalls iPhone 15. Bei fehlendem Gerät keine Freigabe durch Simulation ersetzen.

**Abnahme:** Deutsche Sonderzeichen, lange Dialoge und Seitenumbrüche im PDF visuell prüfen. Export enthält Rolle, Zeit, Text, Hinweis auf automatische Einordnung und Versionsmetadaten; interne Prompttexte/noch gesperrte Fakten fehlen. Keine dauerhafte Exportkopie außerhalb der kontrollierten Ablage; temporäre Dateien werden später bereinigt.

**Meilenstein M2:** V1 für Jonas. Zielgeräte werden einzeln mit Ergebnissen aufgeführt. TestFlight-Verteilung ist anschließend ein separater Schritt mit Jonas' konkretem Verteilungsauftrag.

## Optionale Pakete nach M1

- **Apple-Vergleich:** Separater Adapter mit denselben eigenen Verträgen; Verfügbarkeit prüfen; nie still aufrufen. Ein identischer Evaluationssatz ermöglicht den Vergleich. Die Kern-App muss ohne diesen Adapter vollständig funktionieren.
- **Längere Gespräche:** Erprobtes Gedächtnis-/Zusammenfassungsverfahren samt Verlust- und Faktenkonsistenztests, bevor das 20-Turn-Limit erhöht wird.
- **Weitere Figuren/Ansätze:** Inhalte und gegebenenfalls neue Regelimplementierung; jede Kombination bekommt Referenzfälle.

## Abschlussmeldung je Paket

```text
Paket: Txx
Ergebnis: sichtbares beziehungsweise messbares Verhalten
Geänderte Bereiche: kurze Liste
Prüfungen: tatsächlich ausgeführte Befehle/Tests und Ergebnis
Offen: fehlende Nachweise oder bekannte Fehler
Nächstes Paket: Tyy und notwendige Voraussetzung
```

Tests werden nicht durch die Aussage „sollte funktionieren“ ersetzt. Ein Simulator-Build bestätigt keinen Offline-Modellbetrieb auf einem realen iPhone.
