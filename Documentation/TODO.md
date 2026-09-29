# Nächste Schritte · gemeinsamer Arbeitsentwurf

Die folgenden Punkte sind eine Diskussionsgrundlage, keine bereits fachlich freigegebene Spezifikation.

## Aktueller Teilschritt · 29.09.2026

- [x] MI-03: doppelseitige Reflexion mit belegten Sustain-/Change-Seiten und ausdrücklichem
      Lob für Sustain zuerst, Change danach. Produktentscheidung E04; Prompt und Bausteine 0.2.
- [ ] Neues Analyseschema mit echtem Modell und aktuelle Feedbackanzeige im Simulator prüfen.
- [x] MI-03: Veränderungsbereitschaft, Zuversicht und Rapport getrennt als belegte
      Beobachtungen speichern. Bereitschaft/Zuversicht sind an einen konkreten Zielbeleg
      gebunden, Rapport ist eigenständig. Dauerhafte Nachrichtenherkunft, Unsicherheit,
      atomare Speicherung und Entwicklerdiagnostik vorhanden. Prompt 0.3, Regeln 0.2.
- [x] MI-03: belegte Zielidentität mit Umformulierungen, getrennten Zielwechseln, Vereinbarungen,
      Widerrufen und Unsicherheit; begrenzte Originalbelege jenseits von sechs Turns gezielt
      in die Analyse holen. Prompt 0.4, Regeln 0.3; keine automatische Rollenwirkung.
- [x] Erste Live-Prüfung mit Schema 0.4 ausgeführt: zwei Verlaufsläufe früh abgebrochen,
      sieben isolierte Gegenproben; nur eine vollständig erfüllt. Siehe neuesten STATUS.
- [x] Dokumentierte Befunde behoben: getrennte Ziel-/Beratungsanalyse, exakte Kennungen,
      Parallelziel-Sperre und enge JSON-Hüllenbehandlung. Finale Abnahme: 15/15 Runden,
      alle 14 Verlaufserwartungen und danach 7/7 unabhängige Gegenproben bestanden.
- [ ] Weitere unabhängige Formulierungen und reale freie Rollen-/Simulatorprüfung belegen.
- [ ] Lange Wartezeiten/Wiederholungen untersuchen: finaler Verlauf 327 Sekunden trotz nur
      100,7 Sekunden erfasster erfolgreicher Analysestufen. Vollständige Anbieter-/Kostenmessung
      ergänzen. Zwei Analysestufen sind ein bewusster Mehraufwand, keine Latenzverbesserung.
- [ ] Die drei Dimensionen nachvollziehbar in Rollenverhalten und Termine einbinden (MI-04).
      Keine Umrechnung aus Offenheit und keine automatischen SOC-Schwellen. Aktuell wird
      Lukas' jeweils neue Antwort erst beim nächsten Analyseaufruf berücksichtigt; kein
      weiterer Modellaufruf und keine nachträgliche Umdeutung des Feedbacks.
- [ ] Explizite Zuversichtsskalen als strukturierte Selbstberichte mit Ziel/Skala/Zeitpunkt
      erfassen. Bis dahin bleiben die tatsächlich verwendeten Skalenformulierungen nur
      als wörtliche Belege erhalten; keine vom Modell geschätzte Zahl.
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
- [x] Entschieden: E02 bleibt nicht bestehen. E06 schaltet die Anbieterbeschränkung wieder ein.
      Die Umsetzung im Code steht aus, siehe unten.

### Technisch

- [ ] OpenRouter-Adapter als zweite Konformität von `TrainerModelProvider` bauen, außerhalb von
      `TrainerCore` unter `Beratungstrainer/Services/Models/`. Muss `null` für
      `supportingClientQuote` annehmen, weil `strict: true` das Auslassen eines Feldes nicht
      erlaubt.
- [ ] Ausgabebudget nach E03 festlegen und Abschneidung als eigenen, wiederholbaren Fehlerfall
      behandeln — nicht als ungültige Analyse. Eine Wiederholung ohne höheres Budget läuft ins
      selbe Ergebnis.
- [x] Echte Gesamtfrist **je HTTP-Aufruf**: `timeoutIntervalForResource = 150` Sekunden im
      Adapter. Wiederholungen sind begrenzt, die Fehlermeldung ist verständlich.
- [x] **Frist je Gesprächsrunde.** Umgesetzt als `RoundDeadline` im `ConversationCoordinator`:
      120 Sekunden ab Beginn der Runde, über beide Analysestufen, die Rollenantwort und alle
      Wiederholungen hinweg. Danach `TrainerFailure.roundDeadlineExceeded` mit eigener
      Meldung. Die Frist umschließt nur die Modellaufrufe, nicht `repository.commit` — ein
      Fristablauf kann also nur vor dem Übergabepunkt eintreten, die atomare
      Turn-Transaktion bleibt unberührt. Der Wert ist begründet gewählt, nicht gemessen:
      Median einer erfolgreichen Analysestufe 5,7 s, größte beobachtete Einzellücke 84,6 s.
      Ob 120 s im echten Betrieb zu knapp oder zu großzügig sind, zeigt der bezahlte Lauf.
      Anbieter ohne verwertbare Antworten bleiben weiter ausgeschlossen.
- [x] **Schlüsseleingabe auf dem iPhone.** `Beratungstrainer/Features/SettingsView.swift` gibt es;
      der Adapter legt den Schlüssel unter `rogersrodeo-openrouter` mit
      `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` ab, bewusst erst per `SecItemUpdate` und
      nur bei `errSecItemNotFound` per `SecItemAdd`. Ein Lauf auf einem echten Gerät steht aus.
- [ ] **Zeitpunkt der Schlüsselsuche auf dem Mac.** `OpenRouterKey.lookup` läuft in
      `AppModel.init`; bei der nur lokal signierten Mac-App löst der Schlüsselbundzugriff einen
      Systemdialog aus, der damit beim App-Start erscheint und den Main Actor blockiert. Besser
      erst beim Start einer Sitzung. Behelf bis dahin: Mac-App mit `OPENROUTER_API_KEY` starten
      oder im Dialog einmal „Immer erlauben" wählen. Auf iOS tritt das nicht auf.
- [ ] **Tatsächlich abgerechnete Kosten erfassen.** Der Größenordnung nach ist der Rahmen
      geschätzt (grob 0,4 Cent je Runde, siehe STATUS vom 29.09.2026), die Schätzung ist aber
      keine Abrechnung. Es fehlen: `"usage": {"include": true}` im Anfragekörper, das Auswerten
      der Antwort-`id` gegen den kostenlosen Generierungs-Endpunkt und die Metriken der
      abgeschnittenen Versuche, die der Adapter derzeit verwirft. Ebenso ungenutzt bleibt das
      bereits dekodierte Feld `provider` der Antwort, womit die Route je Aufruf unbekannt ist.
- [ ] **Bis zu zwölf HTTP-Aufrufe je Runde.** Die Schleife in `OpenRouterModelProvider.call`
      sendet jede Stufe zweimal (normales und erhöhtes Budget), `analyze` hat zwei Stufen, und
      der `ConversationCoordinator` wiederholt sowohl `analyze` als auch `reply` je einmal
      vollständig: bis zu acht Aufrufe für die Analyse plus vier für die Rollenantwort. Der
      Adapter dokumentiert das im Kommentar zu `call` selbst. Ob diese Obergrenze sinnvoll ist,
      ist offen; sie bestimmt zugleich die Kosten und die Wartezeit im schlimmsten Fall.
- [x] **`provider.data_collection: "deny"` im Anfragekörper setzen (E06).** Umgesetzt über
      `OpenRouterConfiguration.dataCollection`; `OpenRouterSchema.body` setzt das Feld neben
      `require_parameters` und `ignore`. Offen bleibt die Messung: die acht Anbieter aus E02
      wurden mit `deny` allein gemessen, nicht zusammen mit `require_parameters` und der
      Ausschlussliste. Verfügbarkeit im nächsten bezahlten Lauf beobachten.
- [ ] **Einmaligen Disclaimer bauen (E07).** Datenverarbeitung und die pädagogische
      Vereinfachung der Szenarien, zu bestätigen vor der ersten Benutzung. Text noch nicht
      geschrieben und nicht fachlich abgenommen.
- [ ] **Markdown-Hülle inkonsistent behandelt.** `analyze` schickt die Antwort durch
      `OpenRouterResponse.analysisPayload` und entfernt damit eine einzelne Markdown-Codehülle;
      `reply` gibt die Daten unverändert an `OutputValidator.decodeReply`. Dieselbe Route, die
      bei der Analyse toleriert wird, lässt die Figurenantwort scheitern. Entweder beide Wege
      gleich behandeln oder die Ungleichbehandlung begründen.
- [ ] **Der gesamte Vorschlagspfad ist tot.** `Beratungstrainer/App/ContentCatalog.swift` erzwingt
      beim Laden `catalog.tips.isEmpty`; ein Katalog mit Tipps wird als ungültiges Artefakt
      abgelehnt. `TipSelector.select` im `ConversationCoordinator` bekommt damit dauerhaft eine
      leere Liste und liefert immer `nil`. Die Sperre ist als Schutz gegen fachlich ungeprüfte
      Tipps gedacht; sie muss zusammen mit dem Tippschema und dessen Freigaben aufgehoben
      werden, sonst bleibt die Tippfläche der Oberfläche ohne Funktion.
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
