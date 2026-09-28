# Gespräch, Daten und Regeln

## Bedienablauf

1. **Auswahl:** Lukas, kurze Ausgangslage und Lernziel. Verborgene Themen erscheinen nicht auf der Karte. „Gespräch starten“ lädt das Modell und legt eine Sitzung an.
2. **Gespräch:** Lukas' fester Einstieg erscheint genau einmal. Texteingabe und später Push-to-Talk stehen unten, der optionale Hinweis oberhalb der Eingabe. Offenheit und interne Kategorien erscheinen nicht im normalen Chat.
3. **Antwortphase:** Die Eingabe wird gesperrt; „Antwort wird vorbereitet“ und „Abbrechen“ bleiben verfügbar. Es kann höchstens ein Turn laufen.
4. **Auswertung:** Protokoll, belegte Einordnungen, Fragen/Reflexionen und einige ausgewählte Lernhinweise. Keine Gesamtnote und keine numerische Offenheitskurve im normalen Produkt.
5. **Verlauf:** Fortsetzen einer unterbrochenen Sitzung, Lesen abgeschlossener Sitzungen, Export und Löschen. Eine abgeschlossene Sitzung wird nicht nachträglich erweitert.

Arbeitsgrenzen für den ersten Prototyp: maximal 20 vollständige Turns und 1.500 Zeichen je Eingabe. Vor dem letzten Turn zeigt die App das bevorstehende Ende an. Diese Begrenzung ist ein Testumfang; sie ist kein fertiges Konzept für beliebig lange Sitzungen. Hinweise können jederzeit ein- und ausgeschaltet werden und verändern den Figurenstatus nicht.

## Die Bedeutung von Offenheit

`openness` ist eine interne ganze Zahl von 0 bis 10, bei Lukas zunächst 3. Sie steuert die Bereitschaft, persönlich zu erzählen. Sie bewertet weder Jonas noch eine reale Person. Ein hoher Wert kann mit starkem Festhalten am bisherigen Konsum zusammenfallen.

Es gibt in V1 keinen aus Offenheit berechneten Veränderungswert. Veränderungsäußerungen und Ziele werden als beobachtete Gesprächsinhalte mit ihrer Textstelle gespeichert. Sie sind keine automatisch aus Offenheit abgeleiteten Zustände.

| Interner Wert | Vorgabe für die Antwort |
|---|---|
| 0–2 | knapp, skeptisch; gewöhnlich 1–2 Sätze |
| 3–5 | etwas ausführlicher, relativiert, kann Zweifel andeuten |
| 6–8 | kann persönlichere Gefühle und Erfahrungen erzählen |
| 9–10 | kann sehr offen sprechen; weiterhin Ambivalenz und Ablehnung zulässig |

Die Figur muss bei hohem Wert weder zustimmen noch Ziele formulieren. Niedrige Offenheit beendet eine Sitzung nicht automatisch.

## Eine Gesprächsrunde als Transaktion

```text
bereit
  → Eingabe als PendingTurn speichern
  → einordnen
  → vorläufigen Zustand berechnen
  → Antwort erzeugen und prüfen
  → vollständigen Turn atomar speichern
  → neuen Zustand und Antwort anzeigen
  → optional vorlesen
  → bereit
```

Der StateReducer verändert einen Wert, nicht die gespeicherte Sitzung. Der neue Wert wird erst zusammen mit einer gültigen Antwort übernommen. Schlägt Speicherung fehl, wird keine scheinbar gesicherte Antwort freigegeben. Ein erneuter Speicherversuch verwendet denselben vorbereiteten Turn.

Jeder Turn hat eine UUID, eine Sitzungs-ID und die erwartete Sitzungsrevision. Zusätzlich erhält jeder neue Ausführungsversuch eine flüchtige Generation-ID. Wiederholen, Abbrechen, Beenden und Hintergrundwechsel arbeiten mit diesen Identitäten. Ein spätes Ergebnis darf keinen neuen oder abgebrochenen Turn überschreiben. Vor jedem Schritt nach einem `await` prüft der Coordinator, dass Versuch, Sitzung und Revision noch aktuell sind.

### Fehlerverhalten

| Ereignis | Verhalten |
|---|---|
| Modell fehlt/Datei beschädigt | Start stoppen, klare Fehlermeldung; kein Netzdownload |
| Ungültige strukturierte Ausgabe | Genau ein erneuter Versuch für diesen Teilschritt; danach Fehlerkarte |
| Einordnung bleibt technisch ungültig | „Erneut versuchen“ oder „Ohne Einordnung fortsetzen“; letzteres erzeugt einen Turn mit `analysis = nil`, ohne Offenheitsänderung und ohne Bewertungsdaten für diese Eingabe |
| Inhaltliche Einordnung unsicher | Als unsicher führen; unsichere Segmente bewirken keine Zustandsänderung und keine Zählung |
| Antwort ungültig, verweigert oder leer | Keine Übernahme; Fehlerkarte mit Wiederholen/Abbrechen |
| Kontext passt nicht | Ganze ältere Turns entfernen; wenn Pflichtkontext und aktuelle Eingabe nicht passen, um kürzere Eingabe bitten |
| Nutzer bricht ab | Task abbrechen, Entwurf erhalten, vorläufige Zustände verwerfen |
| Speicherung fehlgeschlagen | Turn nicht als abgeschlossen anzeigen; denselben Commit wiederholen können |
| TTS schlägt fehl | Bereits gespeicherte Textantwort bleibt bestehen; Vorlesen erneut anbieten |

Eine technische Fehlermeldung wird niemals als Lukas-Antwort gespeichert oder vorgelesen. Ein erlaubter erneuter KI-Versuch verwendet dieselbe Eingabe und denselben Ausgangszustand. Die Zahl automatischer Versuche ist auf einen je Teilschritt begrenzt.

## Einordnung einer Berateräußerung

`TurnAnalysis` enthält geordnete Segmente. Pro Segment werden der exakte Ausschnitt aus der Eingabe, ein Code, ein Unsicherheitsstatus und bei Bedarf ein belegender Ausschnitt aus dem Klientenkontext geliefert. Der Adapter muss das Schema und die App muss diese Referenzen prüfen.

- Maximal zwölf Segmente; keine überlappenden oder in der Eingabe nicht vorhandenen Zitate.
- Identische Textstellen werden beim Prüfen von links nach rechts zugeordnet. Das Modell berechnet keine Zeichenoffsets.
- Nicht erfasste Textteile werden weder als gelungen noch als problematisch gezählt. Die Auswertung zeigt den Anteil erfasster Zeichen als technische Abdeckung, nicht als Gütemaß.
- Kategorie `sonstiges` bezeichnet erkannte organisatorische/sonstige Sprache. Unsicherheit ist ein eigenes Merkmal und darf nicht durch `sonstiges` versteckt werden.
- `supportingClientQuote` muss bei positiver komplexer Reflexion oder Würdigung im tatsächlich übergebenen Klientenkontext vorkommen. Fehlender Beleg bedeutet: kein positiver Zustandsbonus. Das ist eine Konsistenzprüfung und kein Beweis fachlicher Richtigkeit.
- Der Klassifikationskontext umfasst aktuelle Eingabe und jüngsten Dialog. Nur die letzte Klientenaussage reicht beispielsweise für eine zuvor erteilte Erlaubnis nicht immer aus.

Die zwölf Codes des Ausgangsentwurfs bleiben erhalten. Sie sind ein angepasstes Lernschema; eine vollständige MITI-Kodierung wird damit nicht zugesichert [N6]. Regeln für gemischte Beiträge und Referenzbeispiele müssen fachlich geprüft werden.

## Deterministische Offenheitsregel v0.1

Diese Regel ist ein konkret implementierbarer Kalibrierungsentwurf. Alle Änderungen werden mit Grund gespeichert, damit sie später nachvollzogen und angepasst werden können.

1. Fehlende oder leere Einordnung: Offenheit unverändert, Folge geschlossener Fragen auf 0 setzen, keinen positiven Code gutschreiben.
2. Segmente in Reihenfolge durchgehen. Unsichere Segmente zählen nicht und unterbrechen eine zuverlässig gezählte Fragenfolge.
3. Sichere geschlossene Frage: `closedQuestionStreak += 1`. Sicheres `sonstiges` wird für diese Folge ignoriert. Jeder andere sichere Code setzt sie auf 0. Nicht erfasste, nicht bloß aus Leerraum bestehende Eingabeteile unterbrechen die Folge ebenfalls; dafür verwendet der Reducer die vom Zitatvalidator ermittelten Positionen.
4. Erreicht die Folge in diesem Turn mindestens 3, entsteht ein möglicher Abzug von 1. Fragezeichen werden nicht gezählt.
5. Sichere Konfrontation: möglicher Abzug von 2. Sicherer Rat ohne Erlaubnis: möglicher Abzug von 1.
6. Sichere komplexe Reflexion, Würdigung, Autonomiebetonung oder Zusammenarbeit: möglicher Bonus von 1. Reflexion/Würdigung benötigen einen gültigen Kontextbeleg.
7. Ein positiver Code kann erst wieder einen Bonus geben, wenn er in den letzten drei **abgeschlossenen Turns** keinen Bonus erhalten hat. Diese Historie wird mitgespeichert. Auch Turns ohne Bonus belegen einen Platz im Fenster.
8. Der stärkste Abzug gewinnt gegenüber allen Boni. Gibt es keinen Abzug, wird höchstens ein Bonus vergeben. Bei mehreren geeigneten Codes gewinnt der erste in der Eingabe.
9. Offenheit auf 0–10 begrenzen. Änderungen erst mit dem vollständigen Turn übernehmen.

Für jeden abgeschlossenen Turn wird exakt ein Eintrag an `recentCredits` angehängt und anschließend auf die letzten drei gekürzt. Der Eintrag ist der ausgewählte positive Code oder `null`. Auch bei bereits erreichtem Maximum 10 wird ein ausgewählter positiver Code für das Wiederholungsfenster erfasst. Negative beziehungsweise nicht eingeordnete Turns erhalten `null`. `disclosedFactIDs` ändert der Reducer nicht; die Vereinigung mit tatsächlich erzählten Fakten geschieht beim vorbereiteten vollständigen Turn.

Die Auditgründe sind stabile Zeichenketten: `analysis_unavailable`, `uncertain_segment`, `closed_question_streak`, `confrontation`, `advice_without_permission`, `positive:<code>`, `repeat_credit_suppressed`, `missing_support`, `clamped`, `neutral`. Mehrere Gründe können gespeichert werden. Sie erscheinen nur in der Entwicklerdiagnostik.

Offene Fragen, einfache Reflexionen, Informationen und Rat mit Erlaubnis sind zunächst neutral. Das ist eine Simulationsentscheidung, keine Aussage über deren fachlichen Wert. Wiederholungsschutz verhindert einige einfache Punktestrategien, macht die Regel aber noch nicht zu einer realistischen Beziehungsmodellierung.

Referenzfälle stehen in [beispiele/regeltests.json](beispiele/regeltests.json). Bei Änderung der Regelversion werden erwartete Ergebnisse bewusst neu festgelegt; alte gespeicherte Sitzungen werden nicht still neu bewertet.

## Themen: gesperrt, verfügbar, erzählt

Ein `ScenarioFact` besitzt eine stabile ID, einen Inhalt und eine Mindestoffenheit. Nur der Inhaltskatalog und der Regelkern kennen die vollständige Sammlung.

```text
availableFacts = facts mit minimumOpenness <= candidateOpenness
                vereinigt mit bereits erzählten Fakten
```

- Ein verfügbares Thema darf passend erwähnt werden; es muss nicht sofort erscheinen.
- Die Rollen-KI bekommt nur diese Fakten, niemals den vollständigen Steckbrief mit allen Türen.
- Für die ursprünglichen Lukas-Themen gelten zunächst 4 (Hausflur), 6 (Vater), 8 (mögliche Alternativen). Das dritte Thema formuliert Möglichkeiten, kein beschlossenes Veränderungsziel.
- Die Antwort nennt zusätzlich IDs der tatsächlich erwähnten Fakten. Diese müssen Teil der verfügbaren Menge sein. Erst ein erfolgreicher Commit erweitert `disclosedFactIDs`.
- Bei sinkender Offenheit verschwinden noch nicht erzählte Themen wieder aus der verfügbaren Menge. Bereits erzählte Inhalte bleiben bekannt, können aber von der Figur abgewiesen werden.
- Zitate des Nutzers und eigene Erfindungen des Modells können ein ähnliches Thema trotzdem auslösen. Deshalb ist Prompt-Minimierung keine Garantie gegen semantisches Vorwegnehmen. Dieses Verhalten gehört in die Dialogprüfung.

## Inhalte und eine gemeinsame Quelle

Die Figur wird genau einmal gepflegt. Python-Modelltests und Swift-App konsumieren dieselbe erzeugte JSON-Datei. Keine zweite handkopierte Persona im Testskript.

Ein Figuren-Dokument hat einen YAML-Kopf mit `schema_version`, `id`, `version`, `status`, `name`, `age`, `address`, `approaches`, `openness_start`, `opening_line` und `facts` (je `id`, `minimum_openness`, `text`). Der Markdown-Körper enthält ausschließlich das öffentliche Rollenprofil. Prüfnotizen und verborgene Themen stehen in separaten Dateien beziehungsweise den strukturierten Fakten, niemals im ungefiltert verwendeten Körper.

Der Compiler benennt `schema_version` nach `schemaVersion`, `openness_start` nach `opennessStart`, `opening_line` nach `openingLine` und `minimum_openness` nach `minimumOpenness` um; der Markdown-Körper wird `publicProfile`. Die übrigen Schlüsselnamen bleiben gleich. `status` ist `draft` oder `reviewed`; der ursprüngliche Wert `entwurf` wird bei der Migration ausdrücklich zu `draft`. So entspricht das erzeugte JSON `ScenarioDefinition` in den Swift-Verträgen.

Der Inhaltscompiler verwendet einen richtigen YAML-Parser, dessen Version festgehalten wird. Er prüft Pflichtfelder, Typen, ID-Eindeutigkeit, zulässige Ansätze, Wertebereiche, Quellverweise und Versionen. Unbekannte Felder sind Fehler. Er erzeugt sortiertes JSON und einen SHA-256-Inhaltshash. Die App parst zur Laufzeit nur das geprüfte JSON.

Redaktioneller Hinweis zu Lukas: „Unter der Woche kaum Alkohol, also kann er es steuern“ wird nicht als objektive Schlussfolgerung übernommen. Das kann Lukas' eigene Sicht sein; als Steckbrieffakt werden nur das beschriebene Verhalten und seine Selbstaussage geführt.

Entwurfsinhalte können in Entwickler-Builds geladen werden. TestFlight-/Release-Inhalte brauchen `status: reviewed` und eine dokumentierte fachliche Prüfung. Dies ist eine vorgeschlagene Qualitätsanforderung für die spätere Weitergabe, keine Voraussetzung für den jetzigen technischen Prototyp.

## Tipps und Auswertung

Ein Tipp enthält `id`, `version`, `approachID`, `triggerTag`, `title`, `text`, `example`, `sourceID`, `reviewStatus` und `priority`. Für V1 wählt die App zum primären Etikett der jüngsten Klientenantwort den ersten passenden, fachlich geprüften Tipp. Bei mehreren Einträgen gilt höhere Priorität zuerst, danach ID alphabetisch aufsteigend. Der zuletzt ausgewählte Tipp wird übersprungen, falls eine andere passende Option existiert. Die Auswahl hängt damit nicht von der Sichtbarkeit des Hinweises ab. Zu jeder `sourceID` gehört im Inhaltskatalog ein geprüfter Quellenverweis.

Ein Tipp hilft bei der **nächsten** Reaktion. Ein Tipptext ist kein starres Soll, mit dem eine spätere Antwort automatisch als richtig/falsch bewertet wird. „Verpasste Chancen“ werden in V1 nicht automatisiert behauptet.

Auswertungen beruhen auf gespeicherten, sicheren Segmenten. Angezeigt werden Anzahl ausgewerteter und nicht ausgewerteter Turns, Code-Häufigkeiten und optional:

- Reflexionen/Fragen: einfache + komplexe Reflexionen geteilt durch offene + geschlossene Fragen.
- Komplexe Reflexionen/alle Reflexionen.
- Nenner 0: „Nicht berechenbar“, niemals 0 % oder unendlich.
- Konkrete Gesprächszitate mit ihrer Einordnung und dem Hinweis, dass die automatische Zuordnung fehlerhaft sein kann.

Keine „fair/gut“-Schwellen und keine automatische Kompetenznote in V1. Der genaue Umfang einer späteren MITI-Auswertung wäre ein eigenes fachliches Arbeitspaket.
