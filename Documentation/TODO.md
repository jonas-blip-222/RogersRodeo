# Nächste Schritte · gemeinsamer Arbeitsentwurf

Die folgenden Punkte sind eine Diskussionsgrundlage, keine bereits fachlich freigegebene Spezifikation.

## Aktueller Teilschritt · 29.09.2026

- [x] MI-03: doppelseitige Reflexion mit belegten Sustain-/Change-Seiten und ausdrücklichem
      Lob für Sustain zuerst, Change danach. Produktentscheidung E04; Prompt und Bausteine 0.2.
- [ ] Neues Analyseschema mit echtem Modell und aktuelle Feedbackanzeige im Simulator prüfen.
- [ ] Drei getrennte Zustände für die Figurenentwicklung konkretisieren: Veränderungsbereitschaft
      mit Zielbezug, Zuversicht/Selbstwirksamkeit mit Zielbezug und Rapport/Arbeitsbeziehung.
      Fachlich bereits in MI-Übergabe 5.1–5.3 vorgesehen, noch nicht als Parameter implementiert.
      Explizite Skalenantworten als Selbstbericht samt Beleg speichern; keine Umrechnung aus
      Offenheit, keine automatischen SOC-Schwellen. Jonas hat die drei Bereiche am 29.09.
      erneut ausdrücklich benannt. Zunächst belegte Beobachtungen (MI-03), danach Einfluss auf
      Rollenverhalten und Verlauf über Termine (MI-04) ausarbeiten.
- [ ] Skalierungsfragen und das begründete Erfragen eigener Lösungsideen erkennen.
- [ ] Wiederholungen in Lukas' Antworten untersuchen und vorhandene Beibehaltungsmotive
      situationsbezogen nutzen. Grundlage: Jonas' erster Testlauf und seine Anmerkungen.

Die folgenden älteren Checkboxen sind historisch teilweise überholt; tatsächlichen Code und
neueste STATUS-Einträge berücksichtigen. MI-01 nicht erneut aufbauen; MI-02 gilt mit Cloud
statt lokaler Inferenz gemäß E01–E03. MI-03 und MI-04 bleiben insgesamt offen.

## 1. MI-Inhalte und Feedback entscheiden

- [ ] Kompakten, versionierten MI-Inhaltsbestand festlegen: Prinzip, Erklärung, Beispiele/Gegenbeispiele, Quellenverweis und fachlicher Freigabestatus.
- [ ] Fachliche Einordnung am Gesprächskontext mit exakten Belegzitaten und expliziter Unsicherheit definieren.
- [x] Rückmeldung zum eigenen Beitrag von Hinweisen für die nächste Reaktion unterscheiden.
      Umgesetzt am 29.09.2026: Warnung, Rückmeldung zum Beitrag und Vorschlag sind getrennte
      Flächen; der Schalter gilt nur für die Vorschläge.
- [x] Eigene FeedbackEngine ergänzen. Umgesetzt am 29.09.2026 für klare Fälle von Druck und
      Rat ohne Erlaubnis sowie für belegte komplexe Reflexion, Würdigung, Autonomie und
      Zusammenarbeit. Der TipSelector bleibt daneben für den Vorschlag zur nächsten Reaktion.
- [x] Als Startvariante: LLM erkennt sprachliche Bedeutung; geprüfte Regeln wählen Hinweise; Vorlagen verbinden sie mit echten Gesprächszitaten. Umgesetzt; freie Umformulierungen bleiben bewusst aus.
- [x] Anzeige entscheiden: **Keine Zahl.** Kurze Rückmeldung in Worten während des Gesprächs,
      gespeichert und im Rückblick nachlesbar. Kein Offenheitswert, keine Punkte, kein Balken,
      keine Note außerhalb der verborgenen Entwicklerdiagnostik. Entschieden von Jonas am
      29.09.2026; Begründung in `STATUS.md` und im MI-Nachtrag, Abschnitte 5.3 und 13.
- [ ] Gemeinsam geprüfte Testdialoge und typische Grenzfälle erstellen. Automatische Einordnung nicht als validierte MITI-Bewertung ausgeben. Die Fixtures zu den Fällen 4a, 4b, 5, 6 und 10 liegen seit dem 29.09.2026 in `FeedbackTests.swift`, sind aber Arbeitsentwürfe und keine Goldreferenz.
- [ ] Formulierungen der Textbausteine fachlich prüfen und freigeben. Sie tragen bis dahin
      `reviewStatus: .draft`. Zu klären ist auch die Anrede: die Bausteine duzen die übende
      Person wie die übrige Oberfläche, die Beispiele im MI-Nachtrag siezen.
- [ ] Prozessbeobachtungen ergänzen (Wanderfalle, Erlaubnislage über mehrere Turns, Bubble
      Sheet, verlorener Fokus). Sie lassen sich nicht aus dem primären Figuren-Tag ableiten
      und gehören zu MI-03; die Fälle 7 bis 14 sind dafür noch nicht abgedeckt.

## 2. Oberfläche und Illustrationen – heute vorgesehen

- [x] Stilreferenz und Liste der Persönlichkeiten vom Nutzer erhalten.
- [x] Zusammenhängende Schwarz-Weiß-Cartoon-Porträts erstellen.
- [x] Neue Startansicht und Verlauf implementieren; Porträts ausschließlich auf der Startseite.
- [x] Erweiterbaren Porträt-Pool und gespeicherte Rotation bei erneutem Öffnen implementieren und testen.
- [ ] Neue Oberfläche in der laufenden App visuell prüfen und mit dem Nutzer abstimmen.
- [ ] Porträts als Orientierung einsetzen; generierte Hinweise nicht als echte Zitate dieser Personen ausgeben.
- [ ] Kleine Displays, große Schrift und VoiceOver prüfen. Seit dem 29.09.2026 betrifft das
      auch die neuen Feedbackflächen; sie wurden noch in keiner laufenden App angesehen.

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
- [ ] **Schlüsseleingabe auf dem iPhone.** Der `security`-Eintrag vom Mac existiert dort nicht, die
      App bleibt deshalb auf dem iPhone im Demo-Betrieb. Nötig ist eine Einstellungsansicht, die
      den Schlüssel per `SecItemAdd` unter `rogersrodeo-openrouter` mit
      `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` ablegt.
- [ ] **Zeitpunkt der Schlüsselsuche auf dem Mac.** `OpenRouterKey.lookup` läuft in
      `AppModel.init`; bei der nur lokal signierten Mac-App löst der Schlüsselbundzugriff einen
      Systemdialog aus, der damit beim App-Start erscheint und den Main Actor blockiert. Besser
      erst beim Start einer Sitzung. Behelf bis dahin: Mac-App mit `OPENROUTER_API_KEY` starten
      oder im Dialog einmal „Immer erlauben" wählen. Auf iOS tritt das nicht auf.
- [ ] **Kosten je Runde messen.** Es sind bis zu vier Modellaufrufe möglich: Der Adapter erhöht
      das Budget bei Abschneidung einmal, und der Coordinator wiederholt zusätzlich einmal. Ein
      realer Kostenrahmen je Sitzung fehlt.
- [ ] Simulatorlauf mit echtem Modell durchführen. Bisher wurde der Adapter nur außerhalb der App
      gegen die Schnittstelle geprüft, nicht im laufenden Gespräch.
- [ ] `RootView` „Nur auf diesem Gerät gespeichert" prüfen: Die Aussage stimmt für die
      Gesprächsdaten, kann aber neben dem neuen Hinweis zur Modellnutzung missverstanden werden.
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
