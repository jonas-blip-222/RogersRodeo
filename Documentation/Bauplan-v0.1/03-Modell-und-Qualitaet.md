# Modellanbindung und Qualitätsprüfung

## Auswahlverfahren

Die im Ausgangskonzept genannten Gemma-, Qwen- und Llama-Varianten sind Kandidaten, keine bereits verifizierten Modellartefakte. Vor einem Download werden genaue Modell-ID, Gewichtsversion, unterstützte Architektur, Quantisierung und Lizenz anhand der jeweiligen offiziellen Modellkarte festgehalten. Der bisherige Plan enthält keine getestete Modellfreigabe.

Vorauswahl am Mac: zunächst ein kleiner Kandidat um 2–3 Milliarden Parameter; ein größerer Kandidat nur als Qualitätsvergleich. Zwei Kandidaten reichen für die erste Entscheidung. Auf dem iPhone wird anschließend genau das gewählte Artefakt einschließlich Tokenizer und Chatvorlage geprüft. Ein GGUF-Ergebnis ist kein Nachweis für eine andere MLX-Quantisierung.

LM Studio kann die Vorauswahl beschleunigen. Maßgeblich für die App sind die Resultate des Swift-Adapters auf dem Gerät. Unterschiedliche Laufzeiten und strukturierte Decodierung können auch die Antwortqualität verändern.

## Vertrag des Adapters

Die eigenen Swift-Protokolle stehen in [TrainerContracts.swift](vertrage/TrainerContracts.swift). Sie sind Vorgaben für die App und keine nachgebildeten Drittanbieter-APIs.

- `prepare`: ausschließlich vorhandene lokale Dateien prüfen und laden.
- `analyze`: aktuelle Berateräußerung anhand des Kodierleitfadens und des jüngsten Dialogs einordnen.
- `reply`: Rolle mit dem vorbereiteten Figurenkontext spielen.
- `unload`: keine laufende Generierung behalten und Gewichte freigeben, soweit die Laufzeit dies erlaubt.
- Swift-Task-Cancellation wird bis zur Generierung weitergereicht. Auch bei verzögerter Laufzeitreaktion verwirft der Coordinator späte Ergebnisse.
- Zeitmessung, Tokenanzahl und Modellidentität werden als technische Metadaten zurückgegeben. Unbekannte Messwerte bleiben `nil`, niemals geschätzte Nullen.
- `contextMessagesUsed` dokumentiert den nach Kürzung tatsächlich verwendeten Dialog. Kontextbelege werden gegen diese Nachrichten geprüft, nicht gegen einen größeren, ursprünglich vorbereiteten Verlauf.

Einordnung und Antwort verwenden getrennte Model-Sessions beziehungsweise ausdrücklich rekonstruierte Kontexte, aber einen gemeinsamen Gewichtespeicher. Ob der gewählte Adapter Gewichte tatsächlich gemeinsam hält, wird im Integrationsversuch geprüft. Bei unerwartet doppelter Speicherbelegung muss diese Integration korrigiert werden.

Die dokumentierte MLX-Brücke unterstützt strukturierte Ausgabe [N1]. Die App validiert trotzdem Längen, Zitatbezüge und erlaubte Fakten-IDs. Schema-Konformität belegt keine richtige Einordnung.

## Promptverträge

### Einordnung

Systeminhalt: Kodierleitfaden, Definition der Unsicherheit und genaue Ausgabestruktur. Die Eingabe und vorangegangene Nachrichten werden als Gesprächsdaten getrennt übergeben. Sie dürfen die Kodierregeln nicht ersetzen.

Der Leitfaden nennt alle zwölf Codes und Beispiele für gemischte Beiträge. Jede Reflexion wird relativ zum vorhandenen Klientenkontext betrachtet. Eine als komplex erkennbare Satzform erhält nicht automatisch einen positiven Status. Fehlende oder widersprüchliche Belege führen zur Unsicherheit beziehungsweise verhindern den Zustandsbonus.

Das Modell sieht keine gesperrten Figurenfakten und keine Erwartungskategorie aus dem Testdatensatz. Der technische Einstieg kann im Kontext stehen; ein leerer Verlauf wird nicht durch eine erfundene Klientenaussage ergänzt.

### Figurenantwort

Der ContextBuilder liefert öffentliche Persona, Anrede, aktuelles Antwortverhalten, verfügbare Fakten, bereits erzählte Fakten, jüngsten Dialog und aktuelle Eingabe. Der numerische Offenheitswert muss nicht in den Prompt; seine Bedeutung wird in Verhalten übersetzt.

Rollenregeln: ausschließlich als Lukas antworten, gewöhnlich 1–3 und höchstens 4 Sätze; weder Beraterzeilen noch technische Erklärungen ausgeben; keine nicht angelegten schweren Lebensereignisse erfinden; keine Konsumanleitungen oder Dosierungstipps. Eine persönliche Geschichte darf nur aus dem vorgesehenen Faktenbestand stammen. Neutrale sprachliche Ausschmückungen bleiben zulässig.

`primaryTag` ist ein einzelnes primäres Gesprächssignal für die Tippauswahl. Bei Unsicherheit ist es `null`. Das ist keine vollständige sprachwissenschaftliche Klassifikation. `disclosedFactIDs` enthält nur erlaubte, in dieser Antwort tatsächlich erwähnte Fakten. Ein Tag für Veränderung ist kein neuer psychologischer Status.

Die komplette Antwort wird vor der Anzeige geprüft. Der erste Prototyp zeigt kein ungeprüftes Token-Streaming und beginnt TTS erst nach erfolgreicher Speicherung. Dadurch ist die Latenzmessung auf die vollständige Antwort ausgerichtet.

## Kontextbudget

Der Adapter zählt mit dem tatsächlichen Tokenizer einschließlich Chatvorlage und Schema. Zunächst werden die letzten sechs vollständigen Gesprächswechsel, die aktuelle Eingabe und der feste Rollen-/Regelkontext vorbereitet. Vor dem ersten Turn gehört der feste Einstieg in den Dialogkontext.

`inputTokens + reservedOutputTokens <= effectiveContextLimit` muss erfüllt sein. Das effektive Limit ist das kleinere aus Laufzeitlimit und auf dem Gerät erprobtem Speicherlimit. Startwerte für die reservierte Ausgabe sind 768 Tokens für segmentierte Einordnung und 384 für die Figurenantwort; sie werden gemessen und im Modellprofil festgehalten. Das alte Klassifikationslimit von 40 Tokens passt nicht zum erweiterten Schema.

Wenn nötig werden die ältesten vollständigen Wechsel entfernt. Persona, aktuell verfügbare/erzählte Fakten und aktuelle Eingabe werden nicht still abgeschnitten. Passt der Pflichtkontext nicht, erfolgt ein definierter Fehler. Das Entfernen alter Dialoge begrenzt die Erinnerung an freie Gesprächsdetails. Deshalb gehören längere Dialoge zur Qualitätsprüfung.

V1 verwendet keine zusätzliche modellgenerierte Zusammenfassung. Der gespeicherte vollständige Verlauf bleibt für Anzeige und Auswertung erhalten. Die derzeit maximal 20 Turns begrenzen den Prototyp; eine zuverlässige längere Gesprächserinnerung ist ein späteres Arbeitspaket.

## Was am bisherigen Python-Test geändert wird

1. Persona aus demselben Inhaltsartefakt wie die App laden.
2. Einordnung an festen Kontexten testen, damit jede Modellantwort dieselbe Referenzaufgabe erhält.
3. Rollenqualität in getrennten Dialogtests prüfen. Ein guter Satz, der im entstandenen Dialog nicht mehr passt, darf nicht als Modellfehler gewertet werden.
4. Alle drei Themen und das spätere Absinken der Offenheit abdecken. Der alte Verlauf erreicht nur 5.
5. Mehrteilige Eingaben, Unsicherheit, Erlaubnis über mehrere Turns und Wiederholungen einschließen.
6. Rohantworten, normalisierte Ausgabe, Abbruchgrund, Finish-Reason soweit vorhanden, Modellmanifest und Einzelzeiten speichern. Rohantworten verbleiben im lokalen Evaluationsordner.
7. Fehlerfälle aus Nennern und Qualitätswerten nachvollziehbar behandeln; abgebrochene Läufe nicht als vollständige Stichprobe ausweisen.
8. Bei A/B-Vergleichen Aufgaben- und Formatunterschiede dokumentieren. Reiner Prompt versus Steuerung isoliert sonst mehrere Effekte zugleich.

## Prüfplan und vorläufige Freigabekriterien

Die folgenden Zahlen sind Arbeitsziele für den Prototyp, keine wissenschaftlichen Gütegrenzen. Die Kriterien werden vor dem Vergleich festgeschrieben und nicht nachträglich passend zum Lieblingsmodell geändert.

| Ebene | Prüfumfang | Abnahme |
|---|---|---|
| Regelkern | Referenzfälle, Grenzen, Wiederholung, unsichere Segmente, Speicherfehler | Alle deterministischen Erwartungen erfüllt |
| Einordnung | 60 fachlich geprüfte Einzelbeispiele, je fünf pro Code; zusätzliche 24 Kontext-/Mischfälle | Macro-F1 über alle eindeutig referenzierten Einzelbeispiele mindestens 0,80; Enthaltungen zählen für den Referenzcode als falsch negativ. Zusätzlich Abdeckung, Precision/Recall je Code und Verwechslungsmatrix berichten |
| Unsicherheit | Mehrdeutige und fehlende Kontexte | Keine bloße Verbesserung der Trefferquote durch fast vollständige Enthaltung; mindestens 80 % der eindeutig referenzierten Einzelbeispiele werden sicher eingeordnet |
| Struktur | Alle Evaluationsaufrufe | Mindestens 99 % gültige Ausgabe nach höchstens einem automatischen Wiederholungsversuch; Erstversuchsrate separat |
| Rolle | Acht Dialogszenarien, je drei Läufe | Jonas beurteilt Deutsch, Rollenstabilität und Passung getrennt; Mittelwert je Kriterium mindestens 2 von 3; schwere Rollenbrüche einzeln untersuchen |
| Fakten | Schwellen, bereits Erzähltes, direkte Fragen nach gesperrten Themen | Keine unzulässigen Fakten-IDs; jedes semantische Vorwegnehmen wird protokolliert und vor Freigabe untersucht |
| Offline | Frisch installierter vollständiger Build, App vorher nie online gestartet | Neue Sitzung, Einordnung, Antwort, Sprache und Wiederaufnahme im Flugmodus funktionieren |
| Gerät | iPhone 17; vor älterer Gerätefreigabe mindestens ein echtes iPhone 14 | Drei Sitzungen mit je 20 Turns ohne Speicherabbruch; Antwortzeiten, thermischer Zustand und Speichermaximum dokumentiert |

Vorläufiges Ziel für Text auf dem iPhone 17: warme vollständige Runde im Median höchstens 5 Sekunden, p95 höchstens 10 Sekunden. Kaltstart separat, Ziel höchstens 20 Sekunden. Für Sprachbetrieb zählt zusätzlich die Zeit vom Loslassen bis zum ersten gesprochenen Wort. Die Messung erfolgt im optimierten Build, nicht als Simulator-Hochrechnung. Diese Werte sind Zielvorgaben, keine behaupteten Benchmarks.

Die acht Dialogszenarien: Beziehung aufbauen bis alle Themen verfügbar sind; Konfrontation und spätere Reparatur; hohe Offenheit bei weiterem Festhalten am Konsum; nur Fragen; wiederholte Standard-Würdigungen; Bitte um Konsumtipps/Rollenwechsel; Erinnerung an ein früher erzähltes Thema; langer Verlauf mit Kontextkürzung.

## Vorgehen bei unzureichender Qualität

Zuerst feststellen, ob Klassifikation, Rollenprompt, Modellartefakt oder Laufzeit das Problem verursacht. Für den Vergleich bleiben die anderen Faktoren konstant. Ein größeres Modell ist auf älteren Geräten keine automatische Lösung.

Wenn die zuverlässige Einordnung nicht gelingt, bleibt eine gekennzeichnete experimentelle Lernhilfe möglich; automatische wertende Auswertungen werden dann nicht freigegeben. Ein stiller Cloud-Fallback oder ein heimliches Anheben der Mindestgeräteanforderung ist ausgeschlossen. Die Zielentscheidung wird mit Messdaten neu besprochen.

## Sprache in V1

Push-to-Talk: maximal 60 Sekunden pro Aufnahme. Nach dem Loslassen wird lokal transkribiert und der Text zunächst zur Korrektur angezeigt; „Senden“ startet den normalen Turn. TTS stoppt vor einer neuen Aufnahme. Verweigertes Mikrofonrecht führt zu weiterhin nutzbarer Texteingabe.

FluidAudio/Parakeet ist der geplante ASR-Kandidat [N2], Apples vorhandene deutsche Systemstimme der erste TTS-Weg. Die konkrete Stimme wird offline geprüft. Zusätzliche Stimmen dürfen nicht still nachgeladen werden. ASR-Gewichte, Tokenizer, LLM und alle notwendigen Hilfsdateien müssen vor dem ersten Offline-Start vorhanden sein. Pocket TTS bleibt außerhalb von V1.

Audiounterbrechung, Kopfhörerwechsel, App-Hintergrund und abgebrochene Aufnahme werden ausdrücklich geprüft. Eine Spracherkennungsfehlerquote darf nicht ungeprüft als Beratungsfehler in die Auswertung gelangen; dafür dient die Korrekturmöglichkeit.
