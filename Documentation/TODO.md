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

## 3. Lokales LLM anschließen — überholt durch E01 vom 29.09.2026

**Dieser Abschnitt ist nicht mehr der Plan.** Die Modellaufrufe laufen über OpenRouter; lokale
Inferenz entfällt als Weg für die Kernfunktion. Der Abschnitt bleibt als Verlauf stehen. Was
stattdessen zu tun ist, steht in Abschnitt 5. Siehe `ENTSCHEIDUNGEN.md`, E01 bis E03.

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

## 5. Offen nach dem Stand vom 29. September 2026

### Fachlich, nur von Jonas zu entscheiden

- [ ] Die 14 Fälle in `Evaluation/results/` durchsehen und die Modelleinordnungen korrigieren.
      Daraus entsteht der fachlich geprüfte Referenzsatz, den der Bauplan für jede echte Messung
      verlangt und der bisher fehlt. Ohne ihn lässt sich fachliche Qualität nicht beurteilen.
- [ ] Bewerten, dass das Modell fast nie `isUncertain` setzt (1 von 23 Segmenten), obwohl Fälle 2,
      3 und 12 als vorläufig unsicher beschrieben sind. Die Schutzlogik des MI-Nachtrags hängt
      daran: unsichere Segmente dürfen keinen Bonus erzeugen, und bei unklarer Erlaubnislage soll
      „unklar" herauskommen statt eines sicheren Vorwurfs. Ein Modell, das nie zweifelt, unterläuft
      das.
- [ ] Entscheiden, ob E02 auf der korrigierten Grundlage bestehen bleibt. Der technische Anlass für
      die Aufhebung der Anbieterbeschränkung ist entfallen.

### Technisch

- [ ] OpenRouter-Adapter als zweite Konformität von `TrainerModelProvider` bauen, außerhalb von
      `TrainerCore` unter `Beratungstrainer/Services/Models/`. Muss `null` für
      `supportingClientQuote` annehmen, weil `strict: true` das Auslassen eines Feldes nicht
      erlaubt.
- [ ] Ausgabebudget nach E03 festlegen und Abschneidung als eigenen, wiederholbaren Fehlerfall
      behandeln — nicht als ungültige Analyse. Eine Wiederholung ohne höheres Budget läuft ins
      selbe Ergebnis.
- [ ] Echte Gesamtfrist, begrenzte Wiederholungen und verständliche Fehlermeldung statt hängender
      Oberfläche. Anbieter ohne verwertbare Antworten ausschließen.
- [ ] Schlüsselverwaltung in der App über den Schlüsselbund; eine `.env` ist auf dem iPhone nicht
      lesbar.
- [ ] Offline-Aussagen in README, `ARCHITEKTUR.md` und Oberfläche anpassen. Eine App, die Text an
      einen Dienst sendet, darf nicht weiter vollständig lokale Verarbeitung versprechen.
- [ ] Deployment-Target neu bestimmen. Ohne MLX und ohne FoundationModels-Brücke gibt es keinen
      technischen Grund mehr für iOS 27, womit iPhone 14 und 15 leichter erreichbar werden.
- [ ] iOS-Simulator-Build in die CI aufnehmen. Der am 29.09. gefundene Fehler stand in
      `#if os(iOS)` und war für Paket- und Mac-Prüfungen unsichtbar; weitere solche Stellen sind
      möglich.
- [ ] Ursache der nicht reagierenden Schaltflächen auf der Startseite klären.
- [ ] Nicht auf Determinismus bauen: bei `temperature: 0` waren nur 9 von 14 Fällen über zwei
      Läufe wortgleich.
