# Übergabe an das ausführende Coding-Modell

## Startauftrag zum Kopieren

> Implementiere den Beratungstrainer anhand dieses Bauplans. Beginne mit einer Bestandsaufnahme des tatsächlichen Projektordners und bearbeite als Nächstes genau ein noch offenes Arbeitspaket aus `04-Umsetzungsplan.md`. Die App ist eine native, vollständig lokal arbeitende iPhone-Übungsapp mit SwiftUI. Der erste Meilenstein ist ein Textgespräch mit Lukas. Lies zuerst die README, dann nur die für das Paket notwendigen Abschnitte und Verträge. Halte die festgelegten Schnittstellen ein. Beschreibe am Ende das entstandene Verhalten, tatsächlich ausgeführte Prüfungen und das nächste Paket. Kennzeichne fehlende Geräte-, Inhalts- oder Modellnachweise ausdrücklich. Erfinde keine Bibliotheks-APIs, Testergebnisse oder fachlichen Referenzdaten.

## Vor jeder Änderung

1. Git-Status und vorhandene Implementierung lesen. Nutzeränderungen bewahren.
2. Das aktuelle Paket und dessen Voraussetzungen bestimmen.
3. Nur dessen benötigte Spezifikationen laden; nicht bei jedem Auftrag alle Quellen und Dialoge erneut einlesen.
4. Bei Drittanbieter-APIs die tatsächlich gepinnte Version prüfen. Der Bauplan beschreibt eigene Verträge, nicht sämtliche externen Aufrufsignaturen.
5. Änderungen so klein halten, dass ein prüfbarer Zustand entsteht. Neue Grundsatzentscheidungen in einem kurzen Entscheidungsprotokoll festhalten.

## Unveränderliche Produktgrenzen dieses Stands

- Offenheit bleibt während des Gesprächs verborgen und erzeugt keine Veränderungsbereitschaft.
- Das eigene lokale Modell trägt die gesamte Kernfunktion. Kein unbemerkter Cloud-Zugriff.
- Tipps kommen aus einem kuratierten Katalog. Fehlende Tipps werden nicht frei erfunden.
- Aktuelle Modellantworten, Einordnungen und neue Zustände werden gemeinsam übernommen.
- `TrainerCore` bleibt frei von UI-, Datenbank-, Modell- und Audioframeworks.
- Gewichte und Protokolle gehören nicht ins Git-Repository.
- Die Schwellen und Kategorien sind als fachliche Entwürfe markiert. Deren technische Umsetzung ist keine fachliche Validierung.

## Wann eigenständig entscheiden?

Dateinamen innerhalb der vorgesehenen Module, kleine Swift-Hilfstypen, verständliche Fehlermeldungen und interne Implementierungsdetails können selbständig entschieden werden, soweit Schnittstellen und Verhalten erhalten bleiben.

Ein Wechsel zu Cloud-Modellen, ein anderer Geräteumfang, veränderte Lernmechaniken oder eine neue Bewertungsskala sind Produktentscheidungen und dürfen nicht als beiläufige Fehlerbehebung eingeführt werden. Bei einem technischen Hindernis erst eine konkrete Alternative samt Befund ausarbeiten.

## Arbeiten mit begrenztem Modellbudget

Der kleinste sinnvolle Auftrag ist ein Arbeitspaket oder ein ausdrücklich abgegrenzter Teil davon. Beispiel: „T03: Segmentvalidierung; StateReducer bleibt unverändert.“ Nach einem erfolgreichen Paket tatsächlichen Stand in `Documentation/STATUS.md` eintragen. Ein späterer Lauf liest Status, Verträge und relevante Tests und muss die Produktarchitektur nicht erneut entwerfen.

Für eine anstehende Aufgabe sollten Eingabe, gewünschtes Ergebnis, berührte Module, Abnahmekriterien und Grenzen in der Nachricht stehen. Umfangreiche wiederholte Erklärungen des ganzen Projekts entfallen.

## Fertig bedeutet

Ein Paket ist erst abgeschlossen, wenn sein Ergebnis konkret vorhanden ist und seine notwendigen Prüfungen ausgeführt wurden. „Baut im Simulator“ und „läuft offline auf dem iPhone“ sind unterschiedliche Nachweise. Ausstehende Hardwaretests verhindern eine Gerätefreigabe, aber nicht die Weiterarbeit an unabhängigen Paketen.

Die Swift-Datei dieses Pakets enthält nur Datentypen und Protokolle. Ihr erfolgreicher Compilerlauf bestätigt Typkonsistenz; er bestätigt weder Gesprächslogik noch Inferenz, Persistenz oder UI.
