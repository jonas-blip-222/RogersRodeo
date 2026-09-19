# Nächste Schritte · gemeinsamer Arbeitsentwurf

Die folgenden Punkte sind eine Diskussionsgrundlage, keine bereits fachlich freigegebene Spezifikation.

## 1. MI-Inhalte und Feedback entscheiden

- [ ] Kompakten, versionierten MI-Inhaltsbestand festlegen: Prinzip, Erklärung, Beispiele/Gegenbeispiele, Quellenverweis und fachlicher Freigabestatus.
- [ ] Fachliche Einordnung am Gesprächskontext mit exakten Belegzitaten und expliziter Unsicherheit definieren.
- [ ] Rückmeldung zum eigenen Beitrag von Hinweisen für die nächste Reaktion unterscheiden.
- [ ] Eigene FeedbackEngine ergänzen. Der aktuelle TipSelector verwendet nur das primäre Signal der Figurenantwort und liefert noch kein umfassendes Feedback zur Berateräußerung.
- [ ] Als Startvariante: LLM erkennt sprachliche Bedeutung; geprüfte Regeln wählen Hinweise; Vorlagen verbinden sie mit echten Gesprächszitaten. Freie Umformulierungen optional per zusätzlichem LLM-Aufruf.
- [ ] Anzeige entscheiden: Vorschlag sind ein optionaler Hinweis während des Gesprächs und ein ausführlicherer Rückblick am Ende.
- [ ] Gemeinsam geprüfte Testdialoge und typische Grenzfälle erstellen. Automatische Einordnung nicht als validierte MITI-Bewertung ausgeben.

## 2. Oberfläche und Illustrationen – heute vorgesehen

- [x] Stilreferenz und Liste der Persönlichkeiten vom Nutzer erhalten.
- [x] Zusammenhängende Schwarz-Weiß-Cartoon-Porträts erstellen.
- [x] Neue Startansicht und Verlauf implementieren; Porträts ausschließlich auf der Startseite.
- [x] Erweiterbaren Porträt-Pool und gespeicherte Rotation bei erneutem Öffnen implementieren und testen.
- [ ] Neue Oberfläche in der laufenden App visuell prüfen und mit dem Nutzer abstimmen.
- [ ] Porträts als Orientierung einsetzen; generierte Hinweise nicht als echte Zitate dieser Personen ausgeben.
- [ ] Kleine Displays, große Schrift und VoiceOver prüfen.

## 3. Lokales LLM anschließen

- [ ] Direkte MLX-Anbindung gegen die bisher vorgesehene FoundationModels-Brücke abwägen. iOS 27 ist eine Anforderung der ausgewählten Brücke, keine allgemeine Voraussetzung lokaler Inferenz.
- [ ] Zwei Aufgaben mit einem geladenen Modell und getrennten Kontexten: Figur spielen und Gespräch einordnen.
- [ ] Modellkandidat, genaue Revision, Lizenz und Gewichtsformat festlegen; kleinen Integrationsversuch vor endgültigem Pin durchführen.
- [ ] Lokales Laden, strukturierte Ausgabe, Tokenbudget, Abbruch und Fehlerverhalten implementieren.
- [ ] Rollenqualität und Einordnung mit denselben geprüften Fällen messen; danach Geschwindigkeit und Speicher auf iPhone 17.

## 4. Xcode und Geräteprüfung

- [ ] Xcodes vorhandene MCP-Brücke verbinden und projektbezogene Freigabe in Xcode einrichten.
- [ ] Lokalen iPhone-Build und Simulatorstart prüfen; die aktuelle Shell erreicht CoreSimulator nicht.
- [ ] Deployment-Target nach der Laufzeitentscheidung anpassen, statt iOS 27 ungeprüft vorauszusetzen.
- [ ] Reales iPhone für Offline-Erststart, Modellleistung, Dateischutz und Wiederaufnahme testen.
- [ ] Danach Spracheingabe mit Transkriptkorrektur, Sprachausgabe, PDF-Export und ältere Geräte bearbeiten.
