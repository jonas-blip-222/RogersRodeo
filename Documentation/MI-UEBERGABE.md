# Rogers Rodeo — MI-Konzept und Übergabe zum Weiterentwickeln

Stand: 29. September 2026 · Dokumentversion 1.0

Dieses Dokument bündelt die MI-Recherche, Jonas’ Notizen, seine Korrekturen und die entwickelten Beispiele. Zusammen mit dem ursprünglichen **Beratungstrainer-Bauplan v0.1 vom 18. September 2026** und dem tatsächlichen Repository bildet es den Arbeitsauftrag für einen Coding-Agenten. Der bisherige Chat ist dafür nicht erforderlich.

**Status:** Produktentscheidungen und fachlicher Arbeitsentwurf für die nächste Entwicklungsphase. Keine validierte MI-/MITI-Bewertung, keine Geräte- oder Modellfreigabe. Die Erstellung dieser Übergabe verändert keinen Anwendungscode.

## 1. Startauftrag zum Kopieren

> Entwickle Rogers Rodeo im bestehenden Repository `/Users/jonasortmanns/Developer/RogersRodeo` auf Grundlage dieses MI-Nachtrags und des Bauplans v0.1 weiter. Lies zuerst `/Users/jonasortmanns/Developer/AGENTS.md`, die projektbezogene AGENTS.md, Documentation/ARCHITEKTUR.md, Documentation/STATUS.md, Documentation/UEBERGABE.md und Documentation/TODO.md sowie diesen Nachtrag. Prüfe den tatsächlichen Git- und Werkzeugstand; bewahre vorhandene Änderungen. Baue die App nicht neu auf. Die abgenommene Schwarz-Weiß-Oberfläche bleibt erhalten, Porträts erscheinen ausschließlich auf der Startseite.
>
> Die neueren Produktentscheidungen in diesem Nachtrag ersetzen die in Abschnitt 3 benannten älteren Annahmen. Beginne mit **MI-01: Feedback und unmittelbare Warnungen als prüfbaren vertikalen Ablauf vorbereiten** (Abschnitt 12). Verwende zunächst kontrollierte Testausgaben für technische Tests; zeige diese nicht als echte KI-Analyse. Danach folgt die tatsächliche lokale Modellanbindung mit denselben Schnittstellen und Prüffällen. Arbeite ein abgegrenztes Paket vollständig ab und dokumentiere Ergebnis, ausgeführte Tests, verbleibende Nachweise und das nächste Paket.
>
> Zentrale Anforderungen: Lukas behält die Entscheidung über seine Ziele und Veränderungen. Drängen und ungefragte Ratschläge sollen unmittelbar und mit Gesprächsbelegen rückgemeldet werden. Erlaubnis muss vor dem eigenen Vorschlag vorliegen. Das **Bubble Sheet sammelt mehrere Wege zu einem bereits vereinbarten Ziel von Lukas**. MI-Prozesse, Veränderungsstadien und Offenheit sind getrennte Konzepte. Vollständige Entwicklung bis Maintenance erfordert einen Verlauf über mehrere fiktionale Termine; sie darf nicht durch wenige passende Sätze oder hohe Offenheit erzeugt werden.
>
> Keine Cloud-Inferenz, keine erfundenen Testergebnisse oder Quellen, keine heimliche Änderung der Zielgeräte und keine automatischen Kompetenznoten. Inhalte und Zuordnungen aus dieser Übergabe sind zunächst Entwürfe. Nenne offene Produktfragen, bearbeite davon unabhängige Arbeit weiter und erfinde keine angebliche Freigabe. Quellen- und Versionsangaben für neu verwendete Bibliotheken/Modelle bei der Integration anhand offizieller Dokumentation prüfen.

## 2. Tatsächlicher Ausgangsstand

### 2.1 Repository und Referenzen

- Git-Remote: [jonas-blip-222/RogersRodeo](https://github.com/jonas-blip-222/RogersRodeo).
- Am 29.09.2026 lokal gelesen: Commit `b574170e77ec41b82fd308c5e0ba9ccca0f8c717`; Arbeitsbaum ohne angezeigte Änderungen. Kein erneuter Remote-/CI-Abgleich in dieser Sitzung.
- **Aktuelles Repository, durch Jonas' Ordnerhinweis gefunden und geprüft:** `/Users/jonasortmanns/Developer/RogersRodeo`.
- **Aktueller Ablageort des Bauplans:** `/Users/jonasortmanns/Developer/Agents/codex/2026-09-17_hey-ich-m-chte-dass-du/Beratungstrainer-Bauplan-v0.1.zip`.
- Der ursprüngliche Bauplan ist im Übergabepaket unverändert enthalten; SHA-256: `906bd7ac294fd49d1ff4a883b23e96d20b26ba1c3b9e6bf7bc5d5cfdc763041e`.
- Frühere Chatpfade unter `Documents/Codex` sind nicht der aktuelle Ort des Anwendungscodes. Aussortierte Kopien unter `_to_delete` gemäß den Developer-Regeln nicht verwenden. Diese Übergabe verschiebt oder stellt keine alten Projektdateien wieder her.

Die gemeinsamen Regeln aus `/Users/jonasortmanns/Developer/AGENTS.md` gelten zusätzlich zu den Projektregeln: Projektcode im Projektordner, agenteneigene Notizen unter `Developer/Agents/<agent>/`, eigener Agentenbranch, Git-Status vor Änderungen und Rückfrage bei fremdem ungesichertem Arbeitsstand. Push und Merge nach `main` erfordern Jonas' Freigabe. Keine endgültigen Löschungen oder Zugangsdaten in Dateien. Der Coding-Agent liest die jeweils aktuellen Regeldateien selbst; diese Zusammenfassung ersetzt sie nicht. Die übergebenen Downloads dieser Aufgabe liegen im Ausgabenordner des Chats.

Dateinamen in den folgenden technischen Abschnitten sind relativ zum Repository. Lokale Pfade dienen der Orientierung und sind keine Voraussetzung auf einem anderen Rechner.

### 2.2 Bereits vorhanden

- Native SwiftUI-App; gemeinsame Mac-Prüf-App und iPhone-Projekt.
- Figur auswählen, Textgespräch, Entwurf speichern, Gespräch fortsetzen/abschließen, Verlauf, Rückblick und Markdown-Export.
- `TrainerCore`: Verträge, Coordinator, Validatoren, Kontextaufbau, deterministische Offenheitsregel und TipSelector.
- `TrainerStorage`: SwiftData-Persistenz, atomare und idempotente Übernahme von Turns.
- Versionierter Inhaltskatalog aus `ContentSource`, deterministischer Compiler und Inhaltshash.
- Ausschließlich `DemoModelProvider` mit festen Antworten; keine echte lokale Modellinferenz.
- Tippbestand leer; keine umfassende Analyse des Beratungsbeitrags für das Feedback.
- Aktuell maximal 20 vollständige Turns und 1.500 Zeichen je Eingabe; KontextBuilder liefert Einstieg und die letzten sechs vollständigen Turns, der Modelladapter soll zusätzlich nach tatsächlichem Tokenbudget kürzen.

Die früher dokumentierten Core-, Speicher-, Compiler- und Präsentationstests sind historische Nachweise. Für diese Dokumentübergabe wurden keine Builds oder App-Tests erneut ausgeführt. Laut Übergabe vom 19.09. war Xcode 27 aktiv; der Werkzeugstand muss vor Implementierung erneut geprüft werden. iPhone-, Simulator-, große-Schrift- und VoiceOver-Prüfungen der neuen Oberfläche bleiben offen.

### 2.3 Gestaltung ist abgenommen

Jonas hat die korrigierte Schwarz-Weiß-Oberfläche mit sichtbarem Porträt ausdrücklich angenommen: „sieht super aus! lassen wir so“.

- Gestaltung, Typografie und bestehende Navigation bewahren.
- Porträts ausschließlich auf der Startseite, niemals im Gespräch.
- Rotation beim App-Start und bei Rückkehr aus dem Hintergrund; nicht bei gewöhnlicher Navigation.
- Lokal bekannte Vorschau: `RogersRodeo-Monochrom-v2.app`; keine aktuelle Laufprüfung daraus ableiten.
- Neue Feedbackflächen in die bestehende Gestaltung einpassen. Eine Warnung benötigt weder eine neue Farbwelt noch ein Redesign.
- KI-Hinweise nicht als Originalzitate der dargestellten Beratungspersönlichkeiten ausgeben.

## 3. Neuere Entscheidungen und Vorrang gegenüber dem Bauplan

Jonas’ spätere ausdrückliche Korrekturen sind für die Produktkonzeption maßgeblich. Der tatsächliche Code beschreibt den Ist-Zustand, nicht automatisch das gewünschte Endverhalten.

| Thema | Ältere Annahme | Aktueller Auftrag |
|---|---|---|
| Design | Noch offen/Abnahme ausstehend | Schwarz-Weiß-Oberfläche ist angenommen. |
| Laufzeithinweise | Alle Hinweise optional; Tipp aus primärem Figuren-Tag | Drängen/Fixing Reflex und Rat ohne Erlaubnis erhalten unmittelbares Feedback zum Beratungsbeitrag. Vorschläge zur nächsten Antwort bleiben davon getrennt. |
| Warnzeitpunkt | UI zeigt erst vollständig gespeicherten Turn | Frühestmögliche Warnung nach validierter Analyse des gesendeten Beitrags; nicht bis zur fertigen Figurenantwort oder zum Rückblick warten. Umsetzung muss die Speicherinvarianten erhalten. |
| Bubble Sheet | Frühere Chat-Erklärung: Auswahl verschiedener Beratungsthemen | **Mehrere für Lukas passende Wege zum bereits gemeinsam vereinbarten Ziel sammeln und grafisch festhalten.** Nicht als Themenmenü implementieren. |
| Wanderfalle | Beispiel nur über längeres Reden über die Arbeit | Lukas wechselt wiederholt das Thema, etwa Arbeit → Nachbarin → weitere Geschichte; die Beratung verliert den vereinbarten Fokus. Sanfte gemeinsame Rückführung. |
| Figurenentwicklung | Einzelne Sitzung mit interner Offenheit | Zielbild: Entwicklung durch SOC mit möglichen Rückbewegungen über mehrere Termine. MI-Prozesse begleiten diesen Verlauf. |
| Abschluss | 20 Turns/manueller Sitzungsabschluss | Ein Sitzungslimit bleibt eine technische Grenze. Maintenance kann das Ende der längeren Geschichte markieren; Gesprächsabschluss bedeutet nicht Maintenance. |
| SDK/Runtime | Ursprünglich bestimmte 27er-Brücke eingeplant | Direkte MLX-Anbindung gegen die Brücke prüfen; Deployment-Target aus tatsächlich gewählter Integration ableiten. Kein Modell/Pin ist durch diesen Nachtrag freigegeben. |

**Bubble-Sheet-Quellenstatus:** Jonas bezieht sich auf seine Lektüre von Miller und Rollnick; genaue Ausgabe und Seitenstelle liegen noch nicht vor. Seine Beschreibung ist als Produktanforderung übernommen. Keine Seitenzahl oder wörtliche Buchdefinition erfinden. Fachquellen, die ein Bubble Sheet für Agenda Mapping verwenden, dürfen diese Nutzerentscheidung nicht wieder umdeuten.

## 4. Haltung und fachliche Leitplanken

### 4.1 Fixing Reflex und Autonomie

Den Impuls, Lukas vorschnell zu überzeugen, zu reparieren oder ihm die Lösung abzunehmen, behandeln wir als zentrales Lernziel. MI soll in dieser App partnerschaftlich führen und begleiten. Lukas entwickelt eigene Gründe und entscheidet, ob und wie er handelt. Die Fachquelle zum Righting Reflex beschreibt diesen Wechsel zur gemeinsamen Lösungsfindung. [S3](https://www.cdc.gov/overdose-prevention/hcp/training-modules/motivational/page1092485.html)

Für das Produkt gilt:

- Klare Fälle von Druck unmittelbar rückmelden: vorweggenommene Entscheidungen, moralische Vorwürfe, Überreden trotz Ablehnung, ungefragte Handlungsvorgaben.
- Konkrete problematische Textstelle nennen; Verhalten besprechen, keine Persönlichkeit bewerten.
- Eine offene Frage, strukturierende Rückführung oder gemeinsam besprochene Planung ist nicht allein wegen ihrer Richtungsgebung Druck.
- Kontext und Unsicherheit berücksichtigen. Ein Wort wie „müssen“ allein ist kein ausreichender Auslöser.
- Entscheidungshoheit von Lukas nicht mit Schuld an Rückschritten verwechseln. Die Beratung bleibt für ihr eigenes Vorgehen verantwortlich.
- Höhere Offenheit und gutes Zuhören dürfen mit anhaltender Ambivalenz zusammenfallen.

### 4.2 Ratschläge und Erlaubnis

Jonas fordert als Trainingsstandard: **Erlaubnis erfragen → passende Zustimmung abwarten → eigenen Vorschlag anbieten → Passung erkunden.**

Beispiel: „Möchten Sie eine Idee dazu hören?“ — „Ja.“ — Vorschlag — „Was davon passt für Sie?“

- Erlaubnisfrage und Ratschlag im selben Atemzug ohne Antwort sind keine bestätigte Erlaubnis.
- Erlaubnis gilt für den erkennbaren Gegenstand; kein dauerhafter Freibrief für alle weiteren Themen.
- Eine Ablehnung oder ein Widerruf ist zu respektieren.
- Zustimmung muss im tatsächlich verfügbaren Gesprächskontext belegbar sein. Abgeschnittener Kontext bedeutet „unklar“, nicht „nie erteilt“.
- Auch nach Erlaubnis kann ein Vorschlag zu früh, ungeeignet oder zu drängend sein.
- Sachinformation und Handlungsempfehlung unterscheiden. Eine Empfehlung wird nicht durch höflichen Ton oder eine Frageform automatisch zur neutralen Information.
- Sonderfall einer direkten Bitte wie „Welchen Vorschlag haben Sie?“ siehe offene Detailfrage in Abschnitt 13: nicht fälschlich als unaufgefordert bezeichnen.

### 4.3 Grundfertigkeiten

- OARS: offene Fragen, Würdigungen, Reflexionen und Zusammenfassungen; nicht ausschließlich beim Engaging verwendbar.
- Würdigungen konkret an belegte Anstrengungen, Handlungen oder Stärken knüpfen. „Ich“ beim Loben wegzulassen ist Jonas’ hilfreiche Formulierungsübung, kein isoliertes automatisches Fehlerkriterium.
- Reflexionen können Vermutungen enthalten. Eine elegante Satzform allein beweist weder Empathie noch eine zutreffende komplexe Reflexion.
- Zusammenfassungen berücksichtigen Anliegen, Ressourcen und Bedenken. Kein bloßes Aufzählen von Defiziten; Gelegenheit zur Korrektur lassen.
- Geschlossene Fragen sind nicht pauschal schlecht: insbesondere eine Erlaubnisfrage kann fachlich passend sein. Die alte Fragenfolge-Regel ist eine Simulationsheuristik und keine MI-Qualitätsmessung.
- Für Diskrepanzen Lukas’ eigene Ziele und Werte verwenden; ihm keine Widersprüche vorwerfen und keine Ziele unterschieben.

Diese fachliche Ausrichtung knüpft an die Darstellung von MINT an; die konkrete App-Regelung ist unser Entwurf. [S2](https://motivationalinterviewing.org/node/11216)

### 4.4 Ambivalenz, Change Talk und Sustain Talk

Change Talk wird relativ zu einer benannten Veränderungsrichtung betrachtet. Unterschiedliche Zielrichtungen nicht zusammenwerfen. Vorbereitende Sprache kann Wünsche, Fähigkeiten, Gründe und Bedürfnisse enthalten; mobilisierende Sprache umfasst Festlegung, Bereitschaft zum Handeln und berichtete Schritte. Die DARN-CAT-Unterscheidung ist eine fachliche Orientierung, noch kein implementierter zusätzlicher Klassifikator. [S6](https://www.ncbi.nlm.nih.gov/books/NBK571064/)

- Sustain Talk respektvoll aufgreifen, ohne ihn routinemäßig immer weiter auszubauen oder zu beschämen.
- Eine zutreffende Reflexion von Sustain Talk ist nicht automatisch ein Fehler.
- Vollständige, gleichgewichtige Pro-und-Contra-Bilanzen nicht als universellen Weg zur Veränderung einsetzen. Bei ambivalenten Personen können sie die Veränderungsbindung schwächen; bei bewusst neutraler Entscheidungsbegleitung haben sie einen anderen Zweck. [S4](https://www.cambridge.org/core/journals/behavioural-and-cognitive-psychotherapy/article/motivational-interviewing-and-decisional-balance-contrasting-responses-to-client-ambivalence/74496E66A2D5625296F9B2EEE805B359)
- „Widerstand“ nicht als Eigenschaft von Lukas modellieren. Gründe für Beibehaltung und Spannungen in der Arbeitsbeziehung unterscheiden. Die vorhandene technische Kategorie `abwehr` darf nicht alle ablehnenden Äußerungen zu Beziehungsproblemen erklären. [S7](https://psychwire.com/free-resources/q-and-a/1xoz9rd/using-motivational-interviewing-in-addiction-treatment)

### 4.5 Weitere Notizen von Jonas

| Notiz | Übernahme in den Entwurf |
|---|---|
| Selbstwirksamkeit, Ressourcen, Bewältigungsstrategien | Frühere hilfreiche Erfahrungen und konkrete Unterstützungen erkunden; auf ein bestimmtes Ziel/einen Schritt beziehen. |
| Zuversichtsskala 1–10 | Selbstbericht von Lukas mit Zielbezug und Datum/Turn speichern, falls genutzt; kein vom Modell erfundener objektiver Wert. Nach vorhandenen Ressourcen und einer möglichen kleinen Verbesserung fragen. |
| Veränderungstempo | Tempo gemeinsam prüfen; nicht aus der Geschwindigkeit des Fortschritts eine Beratungsnote ableiten. |
| „Ehrlichkeit sich selbst gegenüber“ | Als Arbeit mit widersprüchlichen Anliegen und deren Benennung aufnehmen; keinen Ehrlichkeitswert und keinen Lügendetektor bauen. |
| Briefe, Anrufe, kleine Aufmerksamkeiten | Als Notizen zu Beziehungserhalt außerhalb des Gesprächs festhalten. Keine Fragetechniken und kein Auftrag zu realen Kontaktfunktionen. |
| Personalisiertes AUDIT-Feedback | Späterer eigener Übungsfall mit vollständig festgelegten Antworten der fiktiven Figur. Kein AUDIT-Wert aus losen Gesprächsfragmenten oder aus dem Profil errechnen. [S9](https://www.who.int/publications/i/item/WHO-MSD-MSB-01.6a) |

## 5. Die vier MI-Prozesse und Lukas’ Entwicklung

### 5.1 Unterschiedliche Ebenen

| MI-Prozess | Aufgabe im Gespräch | Möglicher Bezug zur Figur |
|---|---|---|
| Engaging | Beziehung und Verständnis aufbauen | Lukas kann sich verstanden fühlen, ohne Veränderung zu wollen. |
| Focusing | Gemeinsame Richtung und Ziel klären | Eigene Priorität von Lukas wird sichtbar; das Ziel kann sich ändern. |
| Evoking | Eigene Gründe, Wünsche und Zuversicht hervorlocken | Ambivalenz bleibt möglich; Veränderungsargumente gehören Lukas. |
| Planning | Einen selbst getragenen nächsten Schritt konkretisieren | Lukas entscheidet über einen Versuch; Planung kann zurückgestellt werden. |

Die Prozesse sind keine vier nacheinander freizuschaltenden Level. Erneutes Engaging oder Focusing bleibt auch später möglich. [S2](https://motivationalinterviewing.org/node/11216)

SOC beschreibt dagegen die Haltung und das Verhalten zu **einer konkreten Veränderung**: Precontemplation, Contemplation, Preparation, Action, Maintenance. Jonas möchte mögliche Vor- und Rückbewegungen abbilden. Die Zuordnung bleibt eine begründete Arbeitshypothese; ohne hinreichenden Ziel-/Verlaufskontext muss „unklar“ möglich sein.

### 5.2 Produktziel: mehrere Termine mit einer Figur

Vorschlag zur Umsetzung des von Jonas gewünschten Verlaufs:

1. Eine übergeordnete Lukas-Geschichte verbindet einzelne abgeschlossene Gespräche.
2. Ein Termin kann mit besserem Verständnis oder einem geklärten Ziel sinnvoll enden.
3. Zwischen Terminen liegen explizit erzählte Zeiträume und konsistente Alltagserfahrungen.
4. Ein Plan wird nicht als ausgeführtes Verhalten gespeichert.
5. Action erfordert ein tatsächlich im fiktionalen Verlauf berichtetes/definiertes Tun; Maintenance eine länger aufrechterhaltene Veränderung. Die Stabilisierung benötigt mehr als eine Zusage. [S8](https://www.ncbi.nlm.nih.gov/books/NBK571075/)
6. Rückschritte eröffnen erneute Erkundung und Planung. Sie löschen weder alle Erfahrungen noch die bisherige Beziehung und sind keine automatische Strafe für eine einzelne Formulierung.
7. Maintenance kann das Ende dieser Geschichte markieren. Das technische Ende einer 20-Turn-Sitzung darf dafür nicht verwendet werden.

Die genaue Kampagnenstruktur, die fiktionalen Zeitabstände und die Abschlusskriterien sind noch festzulegen. Bis diese Erweiterung implementiert ist, darf der aktuelle Einzelgesprächs-Prototyp weder Action noch Maintenance allein durch Gesprächspunkte behaupten.

### 5.3 Getrennt halten

- **Offenheit:** Bereitschaft, Persönliches mitzuteilen; vorhandener interner Simulationswert.
- **Entscheidungshoheit/erlebte Autonomie:** Wird Lukas’ Wahl respektiert? Kein automatisch gemessener Persönlichkeitswert.
- **Beziehung:** Beobachtbare Verständigung oder Dissonanz, mit Belegen und Unsicherheit.
- **Wichtigkeit und Zuversicht:** Zielbezogene Aussagen; optional explizite Selbsteinschätzungen.
- **Ziel, Wege und Plan:** Wer hat was vorgeschlagen, was hat Lukas übernommen, was bleibt offen?
- **Veränderungsstadium:** Zielbezogene Hypothese auf Grundlage von Absichten und Verhalten.
- **Alltagserfahrungen:** Im bisherigen Verlauf bekannte, zeitlich eingeordnete Ereignisse; keine frei erfundenen Beweise des Modells.

Die vorhandenen Offenheitsboni bleiben bis zu einer bewusst versionierten Änderung technische Heuristiken. Daraus darf keine Formel für SOC, Zuversicht oder Beratungskompetenz entstehen.

## 6. Bubble Sheet: verbindliche Bedeutung für diese App

**Ein vereinbartes Ziel steht fest. Gemeinsam werden unterschiedliche für Lukas akzeptable Wege dorthin gesammelt und als Blasen/Kreise festgehalten.**

Beispiel einer späteren Übung: Lukas hat als Ziel einen wieder nutzbaren Sonntag benannt. Er selbst sammelt mögliche Veränderungen seines Wochenendes. Das Blatt enthält seine Ideen und nach Erlaubnis ergänzte Vorschläge. Die Auswahl bleibt bei ihm.

Anforderungen:

- Ziel in Lukas’ Worten mit Gesprächsbeleg sichtbar bzw. im Kontext nachvollziehbar halten.
- Wege zunächst erfragen; eine leere Blase für weitere Ideen vorsehen.
- Eigene Ideen der beratenden Person nur nach Erlaubnis ergänzen.
- Vorschlag, akzeptable Möglichkeit, gewählter Versuch und ausgeführte Handlung sind unterschiedliche Zustände.
- Ein akzeptabler Weg bedeutet noch keine Verpflichtung, ihn auszuprobieren.
- Ändert sich das Ziel, das Blatt gemeinsam überprüfen.
- Nicht „Alkohol, Arbeit, Beziehung“ als drei unterschiedliche Beratungsthemen automatisch eintragen.
- Keine gesperrten Zusatzfakten als angeblich naheliegende Ideen vorwegnehmen.

**Entwurf für den App-Hinweis:**

> „Das Ziel ist klar, der Weg noch offen. Bieten Sie Lukas an, verschiedene für ihn passende Wege dorthin als Kreise auf einem Blatt zu sammeln. Fragen Sie zuerst nach seinen Ideen. Ergänzen Sie eigene Vorschläge erst nach Erlaubnis und lassen Sie Lukas auswählen, was er weiterverfolgen möchte.“

Zunächst ist ein Hinweistext mit Gesprächsbezug gewünscht. Ein interaktiver Zeicheneditor ist dadurch noch nicht beauftragt. Die fachliche Funktion kann beim Übergang von Zielklärung zur Planung liegen; die konkrete Benennung der UI darf Jonas’ Bedeutung nicht verändern.

## 7. Feedback: Zeitpunkt, Belege und Form

### 7.1 Drei unterschiedliche Ausgaben

| Ausgabe | Bezug | Beispiel |
|---|---|---|
| Unmittelbare Warnung | Gerade gesendeter Beratungsbeitrag, klarer Druck/Rat ohne Erlaubnis | „Mit ‚Dann legen wir jetzt fest‘ nehmen Sie Lukas die Entscheidung ab.“ |
| Rückmeldung zum Beitrag | Was die Beratung in diesem Kontext getan hat | „Ihre Reflexion greift seinen Wunsch auf, die Sonntage wieder zu nutzen.“ |
| Hinweis zur nächsten Reaktion | Mögliche hilfreiche nächste Handlung | „Fragen Sie, was ihn an dieser Veränderung besonders reizt.“ |

Ein Hinweis ist keine einzig richtige Musterantwort. Eine abweichende, passende Reaktion ist kein Fehler.

### 7.2 Sofortige Warnung

„Sofort“ bedeutet: **nach dem Senden und sobald eine kontextbezogene, technisch validierte Analyse vorliegt**, möglichst bevor die Figurenantwort fertig generiert ist. Kein unzuverlässiger Wortfilter beim Tippen. Die reale Latenz wird später gemessen, nicht hier versprochen.

- Warnung mit dem auslösenden Zitat und einer kurzen Erläuterung verbinden.
- Bei unklarer Bedeutung „Möglicher Druck …“ statt eines sicheren Vorwurfs; bei fehlender Analyse keine scheinbare Entwarnung.
- Der Schalter für optionale Lernhinweise darf diese von Jonas ausdrücklich gewünschten Kernwarnungen nicht unbeabsichtigt abschalten. Wegklicken einer angezeigten Warnung ist eine mögliche UI-Detailentscheidung; gespeicherte Rückmeldung bleibt nachvollziehbar.
- Wiederholungsschutz für normale Tipps unterdrückt keine neue Warnung bei erneutem Druck in einem anderen Turn.
- Warnungen sind Lehrfeedback, kein automatischer Gesprächsabbruch und keine Pflicht, die Eingabe zu ändern.
- Warnungen an die lernende Person nicht als Worte von Lukas darstellen.

### 7.3 Quellen und Unsicherheit

Für jede gespeicherte Rückmeldung mindestens Thema/Regel, Belegstellen, Unsicherheitsstatus, verwendeten Inhalts-/Regelstand und Quellenverweis nachvollziehbar führen. Zitate müssen exakt aus tatsächlich berücksichtigten Nachrichten stammen. Fehlende Textstellen nicht ergänzen oder paraphrasiert als Zitat ausgeben.

Die Einordnung des Beratungsbeitrags darf nicht nachträglich durch die zu erzeugende Lukas-Reaktion begründet werden. Eine zustimmende Figur beweist keine gute Beratung; eine ablehnende Figur beweist keine schlechte.

### 7.4 Weitere Hinweisentwürfe

| Auslöser | Inhalt und Grenze |
|---|---|
| Wiederholte Themenwechsel bei verlorenem vereinbartem Fokus | Kurz aufgreifen, an das Anliegen erinnern, Rückkehr anbieten. Kein Alarm nach einem einzelnen neuen Thema. |
| Eigenes Ziel vorhanden, Weg unklar | Bubble Sheet aus Abschnitt 6 anbieten. |
| Explizite Zweifel an der Umsetzung | Ressourcen/Erfahrungen erkunden; gegebenenfalls Zuversicht für einen konkreten Schritt erfragen. |
| Bereitschaft zur Planung erkennbar | Veränderungsgründe zusammenfassen, mit offener Schlüsselfrage weitergehen. Keine Abstinenz oder andere Lösung unterschieben. |
| Schweigen/kurze Äußerung | Raum lassen; eventuell eine korrigierbare Reflexion anbieten. Keine garantierte Öffnung und keine Diagnose von Ablehnung. |
| Beziehungsdissonanz nach Druck | Eigenen Beitrag anerkennen und Verständigung wiederherstellen. Kein Schuldvorwurf an Lukas. |

## 8. Konkrete Gesprächsfälle für Implementierung und spätere Prüfung

### Gemeinsame Regeln für alle Fälle

Alle Dialoge sind fiktive redaktionelle Entwürfe. Angegebene Reaktionen sind plausible Varianten, keine exakten Soll-Ausgaben. Die Ausgangsnachrichten gehören zum tatsächlich vorgelegten Kontext. Fälle sind voneinander unabhängige Ausschnitte, sofern kein Verlauf ausdrücklich genannt ist. Neue Alltagssätze, etwa zur Nachbarin, sind vorgeschlagene Szenarioergänzungen und noch keine eingepflegten biografischen Fakten.

Die bestehenden zwölf Codes sind weiterhin ein angepasstes Lernschema. Prozessbeobachtungen wie verlorener Fokus, Planungsdruck oder eine Zusammenfassung passen nicht automatisch in einen zusätzlichen bereits vorhandenen Code. Nicht gewaltsam als `sonstiges` wegklassifizieren; ggf. als getrennte, versionierte Kontextbeobachtung modellieren. Mehrdeutige Referenzen vor einer fachlichen Freigabe diskutieren.

### Fall 1 — Einstieg unter äußerem Druck (bisheriger Fall erhalten)

**Kontext, Lukas:** „Sarah hat gesagt, ich soll hierher. Ich finde das völlig übertrieben.“

**Beratung:** „Sie entscheiden selbst, ob Sie etwas verändern möchten. Was stört Sie daran, heute hier zu sein?“

**Möglicher Lukas:** „Dass alle schon wissen wollen, was mit mir falsch ist. Ich geh arbeiten, ich krieg meinen Alltag hin.“

**Einordnung:** `autonomie_betonen` für „Sie entscheiden selbst, ob Sie etwas verändern möchten.“; `offene_frage` für den zweiten Satz. Bei diesem vollständigen Kontext geringe Zuordnungsunsicherheit. Keine Annahme einer bereits gelungenen Allianz.

**Feedback:** „Sie lassen Lukas die Entscheidung und geben seiner Sicht auf den Termin Raum.“

**Nächster Hinweis:** Seine Sicht aufgreifen, z. B. „Sie möchten, dass auch gesehen wird, was bei Ihnen funktioniert.“

**Gegenprobe:** Kein automatischer Wechsel zu Contemplation wegen einer einzelnen Autonomieformulierung.

### Fall 2 — Ambivalenz reflektieren (bisheriger Fall erhalten)

**Kontext, Lukas:** „Mit den Jungs kann ich abschalten. Aber die Filmrisse machen mir schon Angst. Und Sarah will ich nicht verlieren.“

**Beratung:** „Sie wünschen sich einen Weg, mit Ihren Freunden abzuschalten, ohne dafür Ihre Sicherheit und die Beziehung zu Sarah aufs Spiel zu setzen.“

**Möglicher Lukas:** „Ja, schon. Aber ich weiß nicht, ob ich deswegen gleich alles ändern muss.“

**Einordnung:** Kandidat `komplexe_reflexion`; exakter Kontextbeleg ist Lukas’ gesamte Ausgangsäußerung. Die Begriffe „einen Weg wünschen“ und „Sicherheit“ sind Deutungen. Vorläufig unsicher; nicht als unstrittige Goldreferenz verwenden.

**Feedback:** „Sie verbinden mehrere Anliegen. Prüfen Sie, ob Sie Lukas schon mehr Veränderungsabsicht zuschreiben, als er benannt hat.“

**Nächster Hinweis:** Ambivalenz weiter aufnehmen und einen von ihm benannten Veränderungsgrund erkunden.

**Gegenprobe:** „Sie wollen also aufhören zu trinken“ ist durch den Kontext nicht belegt. Doppelseitige Form allein erzeugt keinen Bonus.

### Fall 3 — Würdigung und Ressourcen (bisheriger Fall erhalten)

**Kontext, Lukas:** „Im Urlaub mit Sarah habe ich zwei Wochen fast nichts getrunken. Das war eigentlich schön. Aber mit den Jungs ist das was anderes.“

**Beratung:** „Sie haben im Urlaub etwas geschafft, das Ihnen im Alltag schwierig erscheint. Was hat Ihnen dort geholfen?“

**Möglicher Lukas:** „Wir waren viel unterwegs, da hab ich kaum dran gedacht. Hier ist am Freitag halt immer dieselbe Runde.“

**Einordnung:** Erster Satz Kandidat `wuerdigung` mit exaktem Beleg aus der Ausgangsnachricht, vorläufig unsicher wegen der erschlossenen Schwierigkeit; zweiter Satz `offene_frage`.

**Feedback:** „Sie greifen eine konkrete hilfreiche Erfahrung auf. Die Aussage über die Schwierigkeit ist eine Deutung, die Lukas korrigieren können soll.“

**Nächster Hinweis:** Hilfreiche Bedingungen genauer erkunden. Eine spätere Zuversichtsskala erst auf einen bestimmten Schritt beziehen.

**Gegenprobe:** „Dann können Sie ja jederzeit aufhören“ ist eine unbelegte Verallgemeinerung. Eine neutrale Wiederholung der Urlaubserfahrung wird nicht allein dadurch zur Würdigung.

### Fall 4 — Erlaubnis vor einem Rat (bisheriger Fall fachlich präzisiert)

**Kontext A:** Lukas hat bereits selbst einen ersten Versuch ausgewählt und sagt: „Ich weiß nicht, wie ich beim nächsten Mal sagen soll, was daran geholfen hat.“ Beratung: „Möchten Sie eine Idee hören, wie Sie das festhalten könnten?“ Lukas: „Ja, gerne.“

**Beratung:** „Sie könnten kurz notieren, was Ihnen bei Ihrem Versuch geholfen hat und was schwierig war.“

**Möglicher Lukas:** „Ja, ein paar Stichworte krieg ich hin.“

**Einordnung A:** `ratschlag_mit_erlaubnis`; Erlaubnisfrage und „Ja, gerne.“ als Kontextbelege. Der Vorschlag ist keine vollständige Pro-und-Contra-Bilanz einer noch offenen Veränderungsentscheidung.

**Variante B:** Derselbe Rat in einem vollständig bekannten Austausch ohne Frage, Zustimmung oder direkte Bitte → `ratschlag_ohne_erlaubnis` und unmittelbarer Hinweis. Bei fehlender Vorgeschichte bleibt die Erlaubnislage unsicher.

**Feedback:** A: „Die Zustimmung passt zu diesem Vorschlag.“ B: „Im vorliegenden Austausch liegt keine Erlaubnis für diesen Rat vor.“

**Nächster Hinweis:** „Wie passt das für Sie?“ Eine Ablehnung respektieren.

### Fall 5 — Konfrontation und Reparatur (bisheriger Fall erhalten)

**Kontext, Lukas:** „Sarah ist mir wichtig. Aber ich will mir auch nicht jedes Wochenende vorschreiben lassen.“

**Beratung:** „Wenn Ihnen Sarah wirklich wichtig wäre, würden Sie endlich mit dem Trinken aufhören.“

**Möglicher Lukas:** „Sie kennen uns doch gar nicht. Genau wegen so einem Gerede hatte ich keinen Bock, herzukommen.“

**Einordnung:** `konfrontation`, klarer Textbeleg „Wenn Ihnen Sarah wirklich wichtig wäre“ im Widerspruch zu seinem ausgesprochenen Anliegen. Unmittelbare Warnung, nicht nur ein späterer Beziehungstipp.

**Feedback:** „Sie machen Lukas’ Zuneigung von Ihrer Veränderungsforderung abhängig.“

**Nächster Hinweis:** „Ich habe Ihnen gerade unterstellt, dass Ihnen Sarah nicht wichtig genug ist. Das war unfair. Ich möchte besser verstehen, was Sie meinen.“

**Gegenprobe:** Auch Schweigen oder oberflächliche Zustimmung sind plausible Reaktionen. Die Warnung hängt nicht davon ab, dass die Figur protestiert.

### Fall 6 — Zu früh ins Planning springen (Jonas’ Ergänzung)

**Kontext, Lukas:** „Die Filmrisse machen mir schon Gedanken. Aber ich weiß nicht, ob ich deswegen meine Wochenenden komplett ändern will.“

**Beratung:** „Dann legen wir jetzt fest, dass Sie ab Freitag nicht mehr mit Ihren Freunden trinken gehen.“

**Möglicher Lukas:** „Moment, davon war überhaupt nicht die Rede. Sie wollen mir auch nur Vorschriften machen.“

**Einordnung:** Entscheidung wird mit „Dann legen wir jetzt fest“ vorweggenommen; „ich weiß nicht“ belegt die noch offene Haltung. Je Segment Rat ohne Erlaubnis und/oder drängendes Überstimmen prüfen; keine künstlich eindeutige Gesamtcode-Vorgabe bei fachlicher Überlappung. Prozessbeobachtung: verfrühte Festlegung, Fixing Reflex.

**Feedback:** „Sie setzen eine Entscheidung voraus, die Lukas noch nicht getroffen hat.“

**Nächster Hinweis:** „Ich bin gerade zu schnell geworden. Was beschäftigt Sie an den Filmrissen?“

**Gegenprobe:** Wenn Lukas bereits konkret planen möchte, ist gemeinsames Planen nicht allein deshalb Druck.

### Fall 7 — Wanderfalle: Arbeit → Nachbarin → weitere Geschichte (korrigiert)

**Vereinbarter Fokus:** Lukas möchte verstehen, warum seine Freitage häufig anders verlaufen, als er sich vorgenommen hat.

**Verlauf:** Er berichtet über Ärger auf der Arbeit, wechselt zur Nachbarin und danach zu einer weiteren Alltagsgeschichte. Die Beratung folgt über mehrere Beiträge ausschließlich mit Paraphrasen; kein Zusammenhang zum Anliegen wird hergestellt.

**Beispiel, Lukas:** „Auf der Arbeit ist gerade ständig Ärger. Und dann meine Nachbarin – gestern hat sie sich schon wieder wegen der Fahrräder im Flur beschwert …“

**Passende Rückführung:** „Da kommt gerade einiges an Ärger zusammen. Vorhin wollten Sie genauer anschauen, wie Ihre Freitage verlaufen. Wäre es für Sie in Ordnung, dahin zurückzukommen?“ Nach Zustimmung: „Wie beginnt so ein typischer Freitagabend bei Ihnen?“

**Möglicher Lukas:** „Ja, stimmt. Meistens schreib ich den Jungs schon auf dem Heimweg.“ Alternativ darf er erklären, weshalb die Nachbarin gerade wichtiger ist.

**Einordnung:** Verlorener gemeinsamer Fokus ist eine mehrturnige Prozessbeobachtung. Einzelne Paraphrasen können korrekt kodiert sein. Bei unklarem Zusammenhang oder fehlender Zielvereinbarung unsicher bleiben.

**Feedback zum bisherigen Verlauf:** „Sie greifen Lukas’ Erleben auf; das gemeinsam vereinbarte Anliegen ist über mehrere Themenwechsel aus dem Blick geraten.“

**Nächster Hinweis:** Kurz aufgreifen, an den gemeinsam vereinbarten Fokus erinnern und die Rückkehr anbieten. Neue Prioritäten gemeinsam prüfen.

**Gegenproben:** Ein einzelner Themenwechsel ist kein Fehler. Arbeits-/Nachbarschaftsstress kann für das Trinken relevant sein. Ohne gemeinsam vereinbartes Anliegen keine angebliche Rückkehr zu einem erfundenen Ziel fordern. Nicht nach starrer Anzahl von Themen oder Minuten auslösen.

### Fall 8 — Entscheidungsbilanz trotz vorhandenem Change Talk (Jonas’ Ergänzung)

**Kontext, Lukas:** „Ich würde schon gern weniger trinken. Ich möchte die Sonntage wieder mitkriegen. Aber die Abende mit den Jungs sind mir wichtig.“

**Beratung:** „Wir sammeln jetzt ausführlich alle Vorteile und Nachteile des Weitertrinkens und des Wenigertrinkens.“

**Möglicher Lukas:** „Na ja, mit Bier bin ich lockerer. Und eigentlich sind die Abende schon ziemlich gut.“

**Einordnung:** „Ich möchte die Sonntage wieder mitkriegen“ belegt eine eigene Veränderungsmotivation; die vollständige Bilanz ist in diesem gerichteten Kontext fachlich zu hinterfragen. Ihre tatsächliche Wirkung ist nicht aus dem Satz sicher ableitbar. Fehlende Erlaubnis separat prüfen, nicht mit der Prozessfrage verwechseln.

**Feedback:** „Sie könnten Lukas’ bereits benannten Veränderungsgrund weiter erkunden, bevor Sie beide Seiten erneut ausführlich sammeln.“

**Nächster Hinweis:** „Was würden Sie an einem Sonntag gern wieder machen können?“

**Gegenprobe:** Bewusst ergebnisoffene Entscheidungsbegleitung ist ein anderer Kontext. Jede Erwähnung von Vorteilen oder Bedenken pauschal abzuwerten wäre falsch.

### Fall 9 — Sustain Talk verstärken und beschämen (Jonas’ Ergänzung)

**Kontext, Lukas:** „Mit ein paar Bier bin ich einfach lockerer.“

**Beratung:** „Sie brauchen also Alkohol, um locker zu sein. Aber wenn Ihnen Sarah wirklich wichtig wäre, würden Sie endlich etwas ändern.“

**Möglicher Lukas:** „Sie tun gerade so, als wäre mir Sarah egal.“

**Einordnung:** „Sie brauchen also Alkohol“ erweitert die Aussage zur Notwendigkeit; diese Deutung ist nicht belegt. Der zweite Satz ist klarer moralischer Druck und löst die Warnung aus.

**Feedback:** „Sie verstärken Lukas’ Aussage und stellen anschließend seine Gefühle für Sarah infrage.“

**Nächster Hinweis:** Den Vorwurf zurücknehmen, anschließend seine Erfahrung erkunden.

**Gegenprobe:** „Mit Alkohol fällt Ihnen das Lockerwerden leichter“ kann eine passende Reflexion sein. Das Spiegeln von Sustain Talk allein darf keine Warnung auslösen.

### Fall 10 — Erlaubnis nur scheinbar einholen (zusätzlicher Grenzfall)

**Kontext:** Keine erkennbare vorherige Erlaubnis.

**Beratung:** „Darf ich Ihnen einen Tipp geben? Sie sollten Ihre Freunde am Wochenende einfach nicht mehr treffen.“

**Möglicher Lukas:** „Sie haben meine Antwort doch gar nicht abgewartet.“

**Einordnung:** Erlaubnisfrage liegt vor, Zustimmung fehlt. Ratschlag im zweiten Satz erhält deshalb keine Erlaubnis allein durch den ersten. Unmittelbare Warnung mit genauem Bezug.

**Feedback:** „Sie fragen um Erlaubnis, geben den Rat aber vor Lukas’ Antwort.“

**Nächster Hinweis:** Zunächst eine tatsächliche Antwort abwarten und ein Nein akzeptieren.

**Gegenprobe:** Frage in einem vorherigen Turn und passende Zustimmung im verfügbaren Kontext müssen erkannt werden. Fehlender Kontext ist keine sichere Ablehnung.

### Fall 11 — Bubble Sheet als Wege zum Ziel (Jonas’ letzte Korrektur)

**Kontext, Lukas:** „Ich möchte den Sonntag wieder nutzen können. Wie ich da hinkomme, weiß ich noch nicht.“ Dieses Ziel wurde gemeinsam festgehalten.

**Beratung:** „Möchten Sie verschiedene Wege zu diesem Ziel auf einem Blatt sammeln? Welche Möglichkeiten fallen Ihnen selbst ein?“

**Möglicher Lukas:** „Vielleicht könnte ich freitags früher Schluss machen. Oder die Jungs mal tagsüber treffen.“ Diese Möglichkeiten sind fiktive Fallergänzungen, kein schon beschlossener Plan.

**Fortsetzung:** Lukas’ Ideen als Wege festhalten; vor weiteren Beraterideen fragen: „Möchten Sie noch einen Vorschlag ergänzen?“ Zustimmung abwarten. Dann: „Welchen dieser Wege würden Sie gern genauer anschauen?“

**Einordnung:** Gemeinsames Erkunden von Wegen zu einem vorhandenen Ziel; Zusammenarbeit/offene Frage nach Segment. Die Annahme der Arbeitsmethode ist keine pauschale Erlaubnis für eigene Ratschläge.

**Feedback:** „Sie nutzen Lukas’ Ziel und beginnen mit seinen eigenen Ideen.“

**Nächster Hinweis:** Passung und Auswahl durch Lukas erkunden; Möglichkeit und Verpflichtung unterscheiden.

**Gegenproben:** Ein Blatt mit verschiedenen Beratungsthemen erfüllt diesen Fall nicht. Zustimmung zum Bubble Sheet legitimiert nicht automatisch ungefragte eigene Ideen. Nicht freigegebene Vater-/Hausflur-/Alternativthemen nicht in das Blatt einschmuggeln.

### Fall 12 — Schweigen und korrigierbare Vermutung (Jonas’ Ergänzung)

**Kontext:** Lukas ist trotz Raum und kurzer Gesprächseinladung schweigsam. Falls es bereits Aussagen über äußeren Druck gibt, diese konkret als Kontext führen.

**Beratung:** „Sie wollen gerade lieber nicht hier sein.“

**Plausible Varianten:** A: „Ja, ich bin eigentlich nur wegen Sarah hier.“ B: „Doch, schon. Ich weiß bloß nicht, wo ich anfangen soll.“ C: Er schweigt weiter.

**Einordnung:** Vermutung über sein Erleben, keine festgestellte Tatsache. Ohne unterstützende Äußerung unsicher; keine positive komplexe Reflexion nur wegen der Formulierung gutschreiben. Korrektur muss angenommen werden.

**Feedback:** „Sie bieten eine Vermutung an. Lassen Sie Lukas Raum, sie zu bestätigen, zu korrigieren oder zunächst nichts zu sagen.“

**Nächster Hinweis:** Bei B etwa „Der Anfang ist gerade schwierig.“ Anschließend Raum lassen bzw. fragen, was den Einstieg erleichtern würde.

**Gegenproben:** Schweigen beweist weder Ablehnung noch mangelnde Motivation. Eine lange technische Antwortlatenz des Modells ist kein Schweigen von Lukas. Textdarstellung von Pausen als Szenarioelement eigens festlegen; nicht als Modellfehler tarnen. [S11](https://pmc.ncbi.nlm.nih.gov/articles/PMC3330017/)

### Fall 13 — Zusammenfassen, Planning und Zuversicht (positive Ergänzung)

**Kontext, Lukas:** „Die Sonntage fehlen mir. Ich möchte am Wochenende weniger trinken, weiß aber noch nicht, wie.“

**Beratung:** „Sie möchten Ihre Sonntage zurückgewinnen. Welche Idee haben Sie selbst für einen ersten Versuch?“

**Möglicher Lukas:** „Vielleicht könnte ich einmal früher nach Hause. Ganz sicher bin ich mir aber nicht.“

**Fortsetzung:** Erst klären, welchen Versuch Lukas tatsächlich meint und wählen möchte. Dann: „Wie zuversichtlich sind Sie auf einer Skala von 1 bis 10, dass Sie diesen Schritt ausprobieren können?“ Bei einer Vier: „Was gibt Ihnen schon diese vier Punkte Zuversicht?“ und später „Was würde Ihnen einen Punkt mehr ermöglichen?“ Bei Eins keine Frage nach einer niedrigeren, nicht angebotenen Zahl stellen.

**Einordnung:** Reflexion plus offene Einladung; danach Selbsteinschätzung der Zuversicht. Kein zuverlässiger SOC-Wechsel allein aus „vielleicht“ oder einer hohen Zahl. [S10](https://bhss-wa.psychiatry.uw.edu/wp-content/uploads/2025/07/MC7A-Motivational-Interviewing.pdf)

**Feedback:** „Sie knüpfen an Lukas’ Anliegen an und lassen ihn den Versuch entwickeln.“

**Nächster Hinweis:** Konkreten Schritt, Unterstützung, mögliche Hürden und Zeitpunkt gemeinsam klären, soweit Lukas das möchte.

**Gegenprobe:** „Dann machen Sie das ab jetzt jedes Wochenende“ wäre eine nicht vereinbarte Erweiterung.

### Fall 14 — Planung ist noch keine Action oder Maintenance (Verlaufsprüfung)

**Termin A:** Lukas formuliert einen selbst gewählten Versuch für das nächste Wochenende. Erwartung: Plan/Absicht, noch keine ausgeführte Handlung.

**Termin B nach explizitem fiktionalem Zeitabstand:** Er berichtet, was er tatsächlich versucht hat und was passiert ist. Erwartung: Erfahrungen prüfen und aufgreifen; nicht allein aus einem gelungenen Wochenende Maintenance ableiten.

**Späterer Verlauf:** Über längere fiktionale Zeit zeigt sich eine stabilisierte Veränderung mit Umgang mit schwierigen Situationen. Erst nach den noch festzulegenden Verlaufskriterien ist der Abschluss der Geschichte möglich.

**Rückschrittvariante, Lukas:** „Letztes Wochenende ist es doch wieder anders gelaufen.“

**Passende Reaktion:** „Was hat dieses Wochenende schwieriger gemacht?“ Erarbeitete Ressourcen bleiben Teil der Geschichte.

**Einordnung/Unsicherheit:** Konkrete Aussagen und Ereignisse speichern; SOC als begründete Hypothese. Dauer und Stabilität dürfen nicht vom Modell dazuerfunden werden.

**Gegenprobe:** Einmalige Zustimmung, hohe Offenheit, viele OARS-Beiträge oder Erreichen des Turnlimits beenden die Geschichte nicht als Erfolg.

## 9. Technischer Anschluss an die bestehende App

### 9.1 Betroffene vorhandene Bereiche

| Bereich | Relevanz |
|---|---|
| `Packages/TrainerCore/Sources/TrainerCore/Contracts.swift` | Derzeit nur segmentierte Analyse, primärer Figuren-Tag, Offenheitszustand und SessionSnapshot. Neue Daten bewusst versionieren. |
| `ConversationCoordinator.swift` im selben Ordner | Analyse → Reduktion → Antwort → Tipp → atomarer Commit; bislang keine vorzeitige Feedbackausgabe. |
| `StateReducer.swift` im selben Ordner | Enthält auch ContextBuilder und TipSelector. Tippauswahl nur nach `primaryTag`; reicht für Beraterfeedback nicht. |
| `Validation.swift` im selben Ordner | Exakte Zitat-/Faktenprüfung; für zusätzliche Belegtypen und Kontextreferenzen erweitern. |
| `Packages/TrainerStorage` | Persistenz/Migration neuer Daten und Verhalten beim Wiederöffnen. |
| `Beratungstrainer/App/AppModel.swift` | Aktuell DemoModelProvider und ein abschließendes `send`-Ergebnis. Für frühe Warnungen einen begrenzten Zwischenzustand benötigen. |
| `Beratungstrainer/Features/ConversationView.swift` | Bisher optionale Tippfläche; Warnung, Feedback und Vorschlag semantisch unterscheiden. |
| `ReviewBuilder.swift` / `ReviewView.swift` | Gespeicherte Rückmeldungen mit Belegen und Unsicherheit zeigen. |
| `ContentSource`, `Tools/compile_content.py`, `ContentCatalog` | Quellenfähigen Hinweis-/Feedbackbestand und zusätzliche Felder durchgehend validieren. |

### 9.2 Empfohlene Verarbeitung — Entwurf, keine externe API

Ein lokales Modell erkennt Bedeutung und liefert strukturierte Beobachtungen. Deterministische Logik prüft Belege, entscheidet über Hinweise und verwendet versionierte Textbausteine. Freie Umformulierungen sind für den ersten Ablauf nicht erforderlich.

Die technische Analyse benötigt zwei unterschiedliche Ebenen:

1. Vorhandene Codes für konkrete Segmente.
2. Kontextbeobachtungen wie Erlaubnislage, vorweggenommene Entscheidung, Bezug zum vereinbarten Ziel, mehrturniger Fokusverlust und belegte Äußerungen zur Veränderung.

Die zweite Ebene nicht aus einem einzelnen `primaryTag` der frisch generierten Figurenantwort ableiten. Für die Bewertung der Eingabe nur bereits vorhandenen Kontext und aktuelle Eingabe verwenden. Die Rollen-KI darf weder Referenzantworten der Tests noch Bewertungserwartungen sehen.

Vorgeschlagene Datenbedürfnisse, nicht verbindliche Typnamen:

- `EvidenceReference`: stabile Nachrichtenreferenz, Sprecher, exakter Ausschnitt und eindeutiges Vorkommen.
- `PermissionEvidence`: angefragter Gegenstand, Zustimmung/Ablehnung/Widerruf, Belege, ggf. unbekannt.
- `FeedbackFinding`: Regelkennung, Art, Unsicherheit, Belege, Quellen-/Inhaltsversion.
- `GoalRecord`: Ziel in Lukas’ Worten, Belege, akzeptiert/offen/verändert, zugehörige Wege.
- `PathOption`: Ursprung Klient/Beratung, bei Berateridee Erlaubnisbeleg, von Lukas akzeptiert/abgelehnt/offen, ausgewählt oder noch nicht.
- `NarrativeProgress`: fiktionale Zeit, bekannte Erfahrungen, Pläne und zielbezogene SOC-Hypothese; getrennt von Offenheit.

Heute enthalten `DialogueMessage` keine stabilen Nachrichten-IDs und `TurnAnalysis` nur Segmente. Eine Implementierung muss die nötigen Referenzen bewusst ergänzen oder eindeutig aus Sitzung/Turn/Sprecher ableiten. Kein Scheincode mit Feldern, die die realen Verträge nicht besitzen.

### 9.3 Frühe Warnung ohne verfrühten Commit

Empfohlener Ablauf:

```text
PendingTurn speichern
→ Eingabe mit tatsächlichem Dialogkontext analysieren
→ Schema und Belege validieren
→ vorläufiges Feedback für genau diesen Versuch an die UI melden
→ Figurenantwort erzeugen und validieren
→ Turn einschließlich Feedback und neuem Zustand atomar speichern
→ endgültigen Turn anzeigen
```

Der Zwischenhinweis ist an Sitzung, PendingTurn, erwartete Revision und Generation des Ausführungsversuchs gebunden. Er ist noch kein gespeicherter vollständiger Turn. Abbruch, bearbeitete Eingabe, Wechsel der Sitzung, Hintergrundwechsel und Löschen müssen ihn verwerfen. Ein technischer Fehler darf die Warnung nicht fälschlich einem neuen Beitrag zuordnen.

Bei fehlgeschlagenem Commit denselben vorbereiteten Turn erneut speichern; keine neue Generierung und keine doppelten Feedbackeinträge. Ein bereits erfolgreich gespeicherter Turn bleibt auch bei unmittelbar folgendem Abbruch erhalten. Das vorhandene Verhalten bei späten Ergebnissen, idempotentem Abschluss und Speicherfehlern bewahren.

Ein Event-/Stream-/Callback-Kanal ist eine interne Umsetzungsentscheidung. Keine parallele zweite Modellinstanz nur für den Warnhinweis laden. Technische Testausgaben und echte Inferenz sichtbar unterscheiden.

### 9.4 Kontext und Gedächtnis

Eine frühere Erlaubnis, ein gemeinsam vereinbartes Ziel oder ein mehrturniger Themenwechsel kann außerhalb des bisherigen Sechs-Turn-Fensters liegen. Das muss explizit behandelt werden:

- Relevante belegte Einträge mit überprüfbaren Ursprungsreferenzen gezielt in den Kontext aufnehmen oder bei fehlendem Beleg unsicher bleiben.
- Budget mit dem tatsächlichen Tokenizer prüfen; Referenzen gegen den tatsächlich gesehenen Kontext validieren.
- Keine erfundenen Modellzusammenfassungen als Beweise verwenden.
- Bei längerem Verlauf eigene Tests für Erinnerung, Zielwechsel, Widerruf und widersprechende Aussagen durchführen.
- Kürzung darf nicht aus „Zustimmung nicht mehr im Fenster“ ein sicheres „Rat ohne Erlaubnis“ machen.

### 9.5 Persistenz, Migration und Inhaltsfreigabe

- Snapshot-, Regel-, Prompt- und Inhaltsversionen bei relevanten Änderungen erhöhen; neue Fälle nicht in alte gespeicherte Sitzungen zurückrechnen.
- Alte Sitzungen bleiben lesbar und exportierbar. Fehlende neue Felder bedeuten unbekannt/nicht erhoben, keine erfundenen Ziel- oder SOC-Werte.
- Fortsetzen nur bei kompatiblen Versionen; sonst nachvollziehbarer Abschluss/Neustart statt stiller Übersetzung.
- Gesprächsbelege, endgültiges Feedback und tatsächlich verwendete Inhaltsversion gemeinsam persistieren.
- Debug-Inhalte dürfen Entwurfsstatus tragen. Eine Quelle und Jonas’ Zustimmung zum Produktkonzept ersetzen keine dokumentierte fachliche Prüfung sämtlicher Kodierungen.
- Release-Inhalte mit explizitem Reviewstatus, Quellen und Versionshistorie bereitstellen. Bestehende Entwurfssperren nicht entfernen, um Anzeigen schneller zu ermöglichen.

## 10. Rollenprofil und Grenzen erhalten

Lukas ist 28, Elektriker, lebt mit Sarah und kommt zunächst unter ihrem Druck. Er schätzt Abschalten und Zugehörigkeit; zugleich belasten ihn Filmrisse, verlorene Sonntage und Konflikte. Die Urlaubserfahrung und sein Verhalten beim Fahren sind Ressourcen aus dem öffentlichen Profil. Seine Aussage, unter der Woche wenig zu trinken und deshalb alles steuern zu können, bleibt seine Sicht und keine objektive Feststellung.

- Kurze umgangssprachliche Antworten, gewöhnlich ein bis drei, höchstens vier Sätze; Anrede „Sie“.
- Ausschließlich als Lukas antworten. Keine Coaching-Kommentare, Codes oder technischen Erklärungen aus der Figur.
- Kein Rollenwechsel durch Anweisungen im Gespräch, keine schweren neuen Lebensereignisse, keine Konsum-/Mischanleitungen.
- Die bestehenden Zusatzfakten bleiben gesperrt bzw. kontextabhängig verfügbar: Hausflur ab Offenheit 4, Vater ab 6, mögliche Alternativen ab 8. Bereits Erzähltes bleibt bekannt. Interne Schwellen und gesperrte Inhalte sind kein sichtbares Lernfeedback.
- Alternative Freizeitideen aus dem gesperrten Pool sind Möglichkeiten, kein automatisch beschlossenes Ziel.
- Neues Material für Nachbarin, Zwischenereignisse und Kampagnenverlauf kontrolliert in den Inhaltsbestand aufnehmen; nicht durch die Runtime wahllos biografische Fakten erfinden lassen.

## 11. Abnahme- und Gegenproben

### 11.1 Inhalt und Feedback

- [ ] Fälle 1–5 bleiben thematisch erhalten; Fall 4 wurde um die Passung der Intervention präzisiert.
- [ ] Fälle 6–9 bilden Jonas’ vier Negativbeispiele ab; Fall 7 enthält tatsächliche Themenwechsel.
- [ ] Bubble Sheet enthält Wege zu einem vereinbarten Ziel, kein bloßes Themenmenü.
- [ ] Eine Frage nach Erlaubnis ohne Antwort gewährt keine Erlaubnis.
- [ ] Fehlende/gekürzte Vorgeschichte führt zu Unsicherheit statt erfundener Erlaubnis oder sicherem Vorwurf.
- [ ] Rückführung mit Zustimmung, legitime Strukturierung und sachliche Fragen werden nicht pauschal als Druck gewertet.
- [ ] Zutreffende Sustain-Talk-Reflexion und normale Ambivalenz erzeugen keinen pauschalen Fehler.
- [ ] Schweigen/kurze Antwort ist keine sichere Aussage über Motivation; technische Wartezeit wird nicht als Figurensignal verarbeitet.
- [ ] Jeder angezeigte Befund hat tatsächlich vorhandene Belege; keine Begründung aus der erst danach erzeugten Reaktion.
- [ ] Einordnung und Feedback unterscheiden sichere Befunde, mehrdeutige Fälle und fehlende Daten.
- [ ] Die Beispiele werden nicht wortwörtlich als einzig erlaubte Lukas-Reaktion oder einzig gute Beratungsantwort getestet.

### 11.2 Technik und Benutzeroberfläche

- [ ] Vorläufige Warnung erscheint nach Analyse und vor Abschluss einer künstlich verzögerten Figurenantwort.
- [ ] Abschalten optionaler Tipps unterdrückt die Kernwarnung nicht.
- [ ] Abbruch, neuer Text, Sitzungswechsel, Hintergrundwechsel und Löschen verhindern späte/falsch zugeordnete Warnungen.
- [ ] Speicherfehler vor/nach tatsächlichem Commit und Wiederholung erzeugen keinen doppelten Turn und kein doppeltes Feedback.
- [ ] Fehlgeschlagene Analyse zeigt keine scheinbare fachliche Entwarnung; Fortsetzen ohne Analyse bleibt nachvollziehbar.
- [ ] Migration erhält alte Sitzungen und erfindet keine neuen Zustandswerte.
- [ ] Fehlende Quellen, falsche Referenzen, unbekannte Felder und unzulässige Fakten-IDs werden abgewiesen.
- [ ] Keine Prompts, internen Codes, gesperrten Fakten oder Offenheitswerte in normalem Gespräch/Export.
- [ ] Warnungen und Hinweise bleiben auf kleinen Displays und mit großer Schrift bedienbar; VoiceOver sinnvoll prüfen.
- [ ] Keine Veränderung der abgenommenen Porträtregeln.

### 11.3 Figurenverlauf und reale Modellprüfung

- [ ] Hohe Offenheit bei weiterem Festhalten am Konsum bleibt möglich.
- [ ] Ziele, Wege, Entscheidungen und ausgeführte Handlungen bleiben getrennt.
- [ ] Ein gemeinsamer Plan oder das Turnlimit erzeugt keine Maintenance.
- [ ] Spätere Termine berücksichtigen echte bisherige Ereignisse, Zielwechsel und Rückschritte.
- [ ] Rolle, Analyse, Warnung und Gedächtnis getrennt prüfen; keine Testantwort im Modellkontext verstecken.
- [ ] Technische Tests mit Fixtures ersetzen keine Modellqualitätsprüfung. Die 14 Entwürfe ersetzen nicht den größeren fachlich geprüften Evaluationssatz des Bauplans.
- [ ] Fehlalarme bei Druck/Erlaubnis und übersehene klare Fälle gesondert erfassen; Enthaltungen und Kontextabdeckung mitberichten.
- [ ] Mac-/Simulatorbefunde und reale iPhone-Messungen getrennt ausweisen; keine geschätzten Latenzen als Ergebnisse darstellen.

## 12. Empfohlene nächste Arbeitspakete

Die folgende Reihenfolge konkretisiert den nächsten Schritt; sie ist kein Auftrag, sämtliche späteren Funktionen in einem Durchlauf zu bauen. Ein unabhängiger technischer Teil kann trotz fehlender Geräte- oder Fachfreigabe umgesetzt werden.

### MI-01 — Feedback und unmittelbare Warnungen vorbereiten

**Ziel:** Ein technisch vollständiger Ablauf vom gesendeten Beitrag zur vorläufigen Warnung und zum gespeicherten Feedback, zunächst mit kontrollierten Testausgaben.

**Arbeit:** Daten-/Belegverträge, Quellenmodell und nötige Migration ergänzen; deterministische FeedbackEngine für klare Fälle von Druck und Rat ohne Erlaubnis; Zwischenfeedback im Coordinator/AppModel; kleine UI-Erweiterung im bestehenden Stil. Prozessbeobachtungen nicht fälschlich aus dem primären Figuren-Tag ableiten. Ausgewählte Fälle 4–6 und 10 samt Gegenproben als Fixtures vorbereiten; übrige Fälle im Katalog bewahren.

**Abnahme:** Relevante Tests aus 11.2 einschließlich langsamer Antwort, Abbruch, Kontextlücke und Commit-Wiederholung bestehen. Demo bleibt ausdrücklich Demo. Kein vorgetäuschter semantischer Detektor durch Stichwortlisten. Aktualisierte Dokumentation nennt alle noch nicht erfüllten fachlichen und Geräteprüfungen.

### MI-02 — Echtes lokales Modell anschließen und messen

**Ziel:** Derselbe Ablauf mit echter Rollen- und Einordnungsleistung.

**Arbeit:** Aktuelle Xcode-/SDK- und Simulatorlage prüfen; Runtime anhand offizieller Quellen und Integrationsversuch auswählen, Modellrevision/Lizenz/Hashes festhalten, lokales Laden und Cancellation implementieren. Eine geladene Gewichtemenge für getrennte Kontexte. Früh einen iPhone-Build erproben; Leistung und Offline-Erststart am echten Gerät nachweisen.

**Abnahme:** Tatsächliche Inferenz mit überprüften Belegen; Fälle getrennt nach technischer Struktur, Rollenpassung und fachlicher Einordnung auswerten. Den bisherigen Bauplan zur Evaluation als Arbeitsziel verwenden, keine daraus abgeleitete wissenschaftliche Validierung behaupten. Fehlende Referenzfreigaben klar benennen.

### MI-03 — Kontextbezogene Hinweise und Lernrückblick ausbauen

**Ziel:** Wanderfalle, Bubble Sheet, Ressourcen, Schweigen, Ambivalenz und Planning sinnvoll unterstützen.

**Arbeit:** Kontrollierten Hinweisbestand, mehrturnige Belege und passende Erinnerung an Ziel/Erlaubnis ergänzen. Feedback zum eigenen Beitrag von Vorschlägen trennen. Quellen, Unsicherheit und Inhaltsstände im Rückblick nachvollziehbar anzeigen.

**Abnahme:** Relevante Fälle und Gegenproben aus Abschnitt 8; keine „eine richtige Antwort“-Logik, kein Themenmenü anstelle des gewünschten Bubble Sheets.

### MI-04 — Lukas über mehrere Termine entwickeln

**Ziel:** Verknüpfte Gespräche mit fiktionaler Zeit, selbst getragenen Plänen, Erfahrungen, Rückbewegungen und einem begründeten möglichen Abschluss bei Maintenance.

**Arbeit:** Datenmodell für Geschichte und Termine, kuratierte Zwischenereignisse, zuverlässige belegte Erinnerung und getrennte Zustände. Abschlusskriterien aus Abschnitt 13 konkretisieren, bevor sie fest kodiert werden. Bestehende Sitzungen migrieren oder kompatibel lesbar halten.

**Abnahme:** Fall 14 und Varianten; kein automatischer Fortschritt aus Offenheit, Formulierungszahl oder verstrichener Gerätezeit. Das größere Gedächtnis-/Kontextproblem vor Aufhebung bisheriger Grenzen prüfen.

Spracheingabe/-ausgabe, PDF-Export, ältere Geräte und weitere Figuren bleiben spätere Pakete entsprechend dem Bauplan. Ein interaktiver Bubble-Sheet-Editor ist ein möglicher gesonderter Ausbau.

## 13. Noch offene Entscheidungen — keine Blockade für alle Arbeit

| Frage | Vorläufiger Umgang / Zeitpunkt |
|---|---|
| Genaue Ausgabe/Seite bei Miller und Rollnick zum Bubble Sheet | Produktbedeutung ist entschieden. Buchstelle später ergänzen; keine falsche Attribution. |
| Direkte Bitte „Welchen Vorschlag haben Sie?“ als Erlaubnis | Jonas fordert ausdrücklich vorherige Erlaubnis. Ob zusätzliche Rückversicherung auch bei klarer direkter Bitte obligatorisch sein soll, ist nicht eigens entschieden. Solche Bitten im Modell erkennen; nicht als „unaufgefordert“ beschuldigen. Fachliche Erlaubnislage und strengere Übungsabläufe getrennt halten und vor endgültiger Warnregel klären. |
| Unterbrechung/Überarbeitung bei Warnung | Beschlossen ist unmittelbares Feedback. Kein verpflichtender Modal-Dialog, kein Sendeblock und kein automatisches Umschreiben beauftragt. |
| Fiktionale Dauer, Termine, konkrete Maintenance-Kriterien | Vor MI-04 festlegen. Ein stabiles längerfristiges Verhalten ist erforderlich; genaue Zeit-/Ereignisregeln noch nicht beschlossen. |
| Neue Ziel-, Beziehungs- oder SOC-Anzeigen | Keine neuen sichtbaren Punkteskalen beschlossen. Vorläufig sprachliche, belegte Rückmeldung; keine numerischen Erfolgsbalken. |
| Fachliche Referenzlabels und Grenzwerte | Produktabnahme und fachliche Validierung auseinanderhalten. Vor Release dokumentiert prüfen; bis dahin Entwurf. |
| Tatsächliche Runtime und Modell | Integrationsversuch erforderlich; keine aus dem alten Plan ungeprüft übernommenen API-Annahmen oder Pins. |
| Größerer Textumfang/Kontext | Kein pauschales Entfernen des 20-Turn-Limits ohne Erinnerungskonzept und Tests. |
| Schweigen in der Textsimulation | Inhaltlich gewünscht, konkrete Darstellung noch offen; nicht mit technischer Verzögerung simulieren. |

## 14. Quellen und ihr Status

Die Links sind fachliche Ausgangspunkte aus der Recherche dieses Tasks. Sie ersetzen keine vollständige Literaturprüfung. Fachliche Textbeispiele oben sind neu formuliert. Veraltete Formulierungen einer Quelle nicht als automatisch aktuellen Konsens ausgeben.

- **S1 — SAMHSA (2019), TIP 35:** [Gesamtes Handbuch](https://www.ncbi.nlm.nih.gov/books/NBK571071/), [Kapitel 3](https://www.ncbi.nlm.nih.gov/books/NBK571068/), [PDF beim Herausgeber](https://library.samhsa.gov/sites/default/files/tip-35-pep19-02-01-003.pdf). Ausführlicher Leitfaden für motivierende Interventionen in der Suchtberatung; breiter als ein reines MI-Lehrbuch. NCBI/SAMHSA waren zeitweise direkt zugriffsbeschränkt; Suchindex lieferte Textauszüge. Das ganze Handbuch wurde hier nicht vollständig gelesen.
- **S2 — MINT:** [Understanding Motivational Interviewing](https://motivationalinterviewing.org/node/11216). Partnerschaft, Autonomie, Fertigkeiten und vier Prozesse. Die Seite bezieht sich auf die dritte Lehrbuchauflage; ihr Hinweis „most current“ ist keine Bestätigung des Publikationsstands 2026.
- **S3 — CDC:** [Resist the Righting Reflex](https://www.cdc.gov/overdose-prevention/hcp/training-modules/motivational/page1092485.html). Begleiten und eigene Lösungen ermöglichen.
- **S4 — William R. Miller / Gary S. Rose:** [Motivational Interviewing and Decisional Balance: Contrasting Responses to Client Ambivalence](https://www.cambridge.org/core/journals/behavioural-and-cognitive-psychotherapy/article/motivational-interviewing-and-decisional-balance-contrasting-responses-to-client-ambivalence/74496E66A2D5625296F9B2EEE805B359). Online veröffentlicht 11.11.2013; Unterscheidung von Evoking und vollständiger Entscheidungsbilanz.
- **S5 — MINT:** [Training New Trainers Manual, Revision 2020](https://motivationalinterviewing.org/sites/default/files/tnt_manual_rev_2020.pdf). Enthält Agenda Mapping mit Bubble Sheet. Diese Verwendung ist nicht mit Jonas’ gewünschtem Blatt für Wege zum Ziel gleichzusetzen und ersetzt dessen Präzisierung nicht.
- **S6 — SAMHSA (2019):** [Kapitel 5: Increasing Commitment](https://www.ncbi.nlm.nih.gov/books/NBK571064/). Ambivalenz und Veränderungssprache. TIP 35 verwendet „Decisional Balance“ teilweise weiter als S4; nicht als pauschal identische Intervention behandeln.
- **S7 — William Miller / Theresa Moyers:** [Q&A zu MI in der Suchtbehandlung](https://psychwire.com/free-resources/q-and-a/1xoz9rd/using-motivational-interviewing-in-addiction-treatment). Sustain Talk und Discord statt eines pauschalen Widerstandsbegriffs.
- **S8 — SAMHSA (2019):** [Kapitel 6: Initiating Change](https://www.ncbi.nlm.nih.gov/sites/books/NBK571066/), [Kapitel 7: Stabilizing Change](https://www.ncbi.nlm.nih.gov/books/NBK571075/). Selbst getragene Planung, Umsetzung und Stabilisierung.
- **S9 — WHO (2001):** [AUDIT: Guidelines for Use in Primary Health Care, zweite Ausgabe](https://www.who.int/publications/i/item/WHO-MSD-MSB-01.6a). Grundlage für einen späteren eigenständigen Screening-Fall.
- **S10 — University of Washington:** [Meta-Competency 7-a: Motivational Interviewing](https://bhss-wa.psychiatry.uw.edu/wp-content/uploads/2025/07/MC7A-Motivational-Interviewing.pdf). Zuversichtsskala und gemeinsames Entwickeln eines Plans.
- **S11 — Fachartikel:** [Motivational Interviewing: moving from why to how with autonomy support](https://pmc.ncbi.nlm.nih.gov/articles/PMC3330017/). Unter anderem Reflexionen auf Auslassungen/Schweigen; theoretischer älterer Beitrag, keine Garantie einer bestimmten Reaktion.
- **S12 — Indian Health Service:** [Using Motivational Interviewing in Treatment of Pediatric Obesity](https://www.ihs.gov/diabetes/files/?fileName=6813_Handout_Session_3). Focusing, gemeinsame Ziele und Wanderfalle; Anwendung auf Lukas ist unser Szenarioentwurf.
- **S13 — Moyers, Manuel, Ernst:** [MITI Coding Manual 4.2.1, Revision Juni 2015](https://motivationalinterviewing.org/sites/default/files/miti4_2.pdf). Referenz zur strukturierten Beobachtung; unser angepasstes Schema, seine Punkte und App-Feedback sind keine validierte MITI-Anwendung.

Für technische Bibliotheken/Modelle die offiziellen Quellen aus dem Bauplan bei Implementierung erneut prüfen. Dieses Dokument trifft keine neue Versions- oder Gerätefreigabe.

## 15. Fertigmeldung des Coding-Agenten

Am Ende eines Pakets berichten:

1. Welches konkrete Verhalten jetzt vorhanden ist und ob es Testdaten oder echte Inferenz verwendet.
2. Welche Dateien/Verträge und Inhalts-/Regelversionen geändert wurden.
3. Welche Prüfungen wirklich liefen und mit welchem Ergebnis.
4. Welche fachlichen, Modell-, Simulator- oder Gerätenachweise fehlen.
5. Welches nächste Paket auf diesem Stand aufbauen kann.

**Erstellung dieser Übergabe:** Repository und Bauplan gelesen, lokale Referenzdateien gefunden und Anforderungen zusammengeführt. Kein Anwendungscode verändert, kein Modell heruntergeladen, keine neue App-/Geräteprüfung behauptet.
