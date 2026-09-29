# Entscheidungsprotokoll

Grundsatzentscheidungen, die von Bauplan v0.1 oder dem MI-Nachtrag abweichen. Jede Entscheidung
nennt, wer sie getroffen hat, was sie ersetzt und welche Folgen offen sind. Der MI-Nachtrag
verlangt ausdrücklich, dass ein Wechsel zu Cloud-Modellen nicht als beiläufige Änderung
eingeführt wird; deshalb steht er hier.

## E01 · Cloud-Inferenz über OpenRouter statt lokaler Modellausführung

**Datum:** 29.09.2026 · **Entschieden von:** Jonas · **Status:** beschlossen, Umsetzung offen

Die App führt ihre Modellaufrufe über die OpenRouter-API aus. Lokale Inferenz über MLX entfällt
als Weg für die Kernfunktion.

**Begründung.** Jonas hat als Priorität die beste erreichbare Feedbackqualität benannt und ist auf
absehbare Zeit der einzige Nutzer, später ergänzt um zwei bis drei Arbeitskolleg:innen. Ein
Modell der 27-Milliarden-Klasse ist auf dem vorhandenen MacBook Pro mit 16 GB RAM nicht lokal
lauffähig und auf einem iPhone erst recht nicht; ein lokal mögliches Modell um vier Milliarden
Parameter erschien für die geforderte Einordnung nicht ausreichend, insbesondere für die
wörtliche Zitat-Treue und die Unterscheidung von Rat mit und ohne Erlaubnis.

**Was das ersetzt.**

| Abgelöste Festlegung | Quelle |
|---|---|
| „Keine Cloud-Inferenz", vollständige Sitzung offline | Bauplan README, 05-Uebergabe |
| MLX-Anbindung beziehungsweise FoundationModels-Brücke als Trägerin der Kernfunktion | Bauplan 01-Architektur, 03-Modell-und-Qualitaet |
| Modellgewichte im App-Bundle, `Models.lock.json`, Offline-Erststart | Bauplan 01-Architektur, T00/T07 |
| iOS 27 als Deployment-Target, abgeleitet aus der Brücke | Bauplan 01-Architektur |

**Bewusst beibehalten.** Alles, was nicht die Modellherkunft betrifft, bleibt gültig: die Trennung
von `TrainerCore` und Adaptern, die atomare Turn-Transaktion, verborgene Offenheit, gesperrte
Fakten, keine automatische Kompetenznote, und die Anforderungen des MI-Nachtrags an Belege,
Unsicherheit und unmittelbare Warnungen. Der Adapter erfüllt weiterhin `TrainerModelProvider`;
der Bauplan hatte für einen zweiten Adapter dieselbe Stelle vorgesehen.

**Modell- und Routenwahl.** Am 29.09.2026 aus der öffentlichen OpenRouter-Modellliste gelesen:
`qwen/qwen3.8-27b` mit 1.000.000 Kontext, 0,42 USD je Mio Eingabe- und 3,00 USD je Mio
Ausgabetoken, unterstützt `structured_outputs` **und** `response_format`. Die Variante
`qwen/qwen3.8-27b:free` unterstützt `response_format` nicht und ist deshalb für die strikt
schemagebundene Einordnung nicht geeignet. Kostenschätzung: rund 0,5 Cent je Gesprächsrunde,
etwa 9 Cent je Sitzung mit 20 Runden. Die Eignung des Modells für die fachliche Einordnung ist
damit **nicht** belegt; sie wird vor der Swift-Integration an den Fällen aus Abschnitt 8 des
MI-Nachtrags gemessen.

**Zugangsdaten.** Ein einziger Schlüssel, der von Jonas. Er liegt im macOS-Schlüsselbund
(`security`-Dienst `rogersrodeo-openrouter`), niemals im Repository, in einer Quelldatei oder in
einem Log. Skripte lesen ihn aus dem Schlüsselbund oder aus einer Umgebungsvariablen. Sollte die
App je an einen größeren Kreis gehen, ist die Schlüsselverwaltung neu zu lösen; ein Schlüssel in
einer verteilten App ist nicht geheim.

**Offene Folgen, noch nicht erledigt.**

- README, `Documentation/ARCHITEKTUR.md` und die Oberfläche behaupten derzeit ausschließlich
  lokale Verarbeitung. Diese Aussagen müssen angepasst werden, bevor die Cloud-Anbindung
  benutzbar ist. Eine App, die Text an einen Dienst sendet, darf nicht weiter „vollständig lokal"
  versprechen.
- Datenschutz: Beratungsäußerungen verlassen das Gerät. Zur Anbieterwahl siehe E02, die diesen
  Punkt am 29.09.2026 neu geregelt hat. Unverändert gilt: `~/Developer/AGENTS.md` verbietet
  Klienten- und Mandatsdaten in Prompts und Logs, und eine Beratungsübung verleitet dazu, echtes
  Fallmaterial einzutippen. Ein Hinweis in der App ist vorzusehen.
- Offline-Betrieb entfällt. Verhalten ohne Netz, bei Zeitüberschreitung und bei Fehlern der
  Gegenseite muss definiert werden; die Speicherinvarianten des Coordinators gelten unverändert.
- Das Deployment-Target ist neu zu bestimmen. Ohne MLX und ohne FoundationModels-Brücke gibt es
  keinen technischen Grund mehr für iOS 27, womit iPhone 14 und 15 leichter erreichbar werden.
- Der fachlich geprüfte Referenzsatz aus dem Bauplan (60 Einzelbeispiele, fünf je Code) fehlt
  weiterhin. Er wird durch diese Entscheidung nicht ersetzt.

## E02 · Keine Beschränkung auf Anbieter ohne Datenspeicherung

**Datum:** 29.09.2026 · **Entschieden von:** Jonas · **Status:** beschlossen

Anfragen werden ohne `provider.data_collection: "deny"` gestellt. OpenRouter darf frei routen,
auch an Anbieter, die übermittelte Daten speichern oder für eigenes Training verwenden dürfen.

**Begründung.** Die geübten Gespräche sind fiktiv: Die Figur Lukas ist erfunden, und die
Äußerungen der übenden Person sind ihr eigenes Übungsmaterial, keine Klientendaten. Funktionalität
und Antwortqualität haben nach Jonas' Abwägung Vorrang vor der strengeren Einstellung.

**Auslösender Befund — am 29.09.2026 als falsch widerlegt.** Ursprünglich wurde angenommen, die
Beschränkung lasse nur einen einzigen Anbieter zu (Reka) und sei deshalb die Ursache dafür, dass
der Auswertungslauf nach 13 von 28 Aufrufen stehen blieb. Die Messung widerlegt beides:

- Die Beschränkung hat **nie** auf einen Anbieter verengt. Auch mit `deny` wurden acht
  verschiedene Anbieter bedient.
- Der Stillstand hatte eine ganz andere Ursache: `urlopen(timeout=…)` wirkt in Python je
  Socket-Operation und nicht als Gesamtfrist. Der Prozess hing ohne CPU-Last in `read()` bei
  offener Verbindung. Behoben durch eine harte Gesamtfrist von 150 Sekunden in einem Wachfaden.
- Das Aufheben der Beschränkung hat die Lage **nicht** verbessert: bei `max_tokens: 768` waren
  7 von 16 Antworten mit Beschränkung lesbar und 0 von 12 ohne. Entscheidend war das
  Tokenbudget, weil das Modell als Reasoning-Modell 344 bis 3742 Token für interne Überlegungen
  verbraucht und danach kein Budget für das JSON übrig hat.

**Die Entscheidung selbst bleibt damit gültig, ihre Begründung schrumpft aber.** Tragend ist allein
Jonas' Abwägung: fiktives Übungsmaterial, Vorrang für Funktionalität und Antwortqualität. Der
technische Anlass ist entfallen — die Beschränkung hätte den Stillstand nicht verursacht und ihre
Aufhebung hat ihn nicht behoben. Jonas kann die Entscheidung auf dieser korrigierten Grundlage
jederzeit zurücknehmen, ohne dafür einen technischen Preis zu zahlen.

**Was das ersetzt.** Den Punkt „Nur Anbieterrouten ohne Datenspeicherung verwenden" aus den
offenen Folgen von E01.

**Grenzen dieser Entscheidung.** Sie gilt für fiktives Übungsmaterial. Sie ist **keine** Freigabe
für echte Klienten- oder Mandatsdaten; das Verbot aus `~/Developer/AGENTS.md` bleibt unberührt.
Sobald Kolleg:innen mitüben, sind es deren Äußerungen, und eine Beratungsübung verleitet dazu,
echtes Fallmaterial einzutippen. Die Abwägung ist dann erneut zu treffen, und ein Hinweis in der
App bleibt vorgesehen.

**Folge für die Umsetzung.** Der Swift-Adapter braucht unabhängig davon eine echte Gesamtfrist,
begrenzte Wiederholungen und eine verständliche Fehlermeldung statt einer hängenden Oberfläche.
Der tatsächlich verwendete Anbieter wird je Aufruf protokolliert: gemessen am 29.09.2026 lieferten
Wafer (0 von 6), Mancer 2 (0 von 3) und Parasail (0 von 2) keine verwertbare Antwort, während
Phala, Ionstream, Darkbloom, Cloudflare, DeepInfra, Chutes, Venice, AkashML und Reka sauber
lieferten. Die Anbieterwahl ist damit kein Randthema, sondern bestimmt die Ausfallquote. Siehe E03.

## E03 · Tokenbudget und Anbieterwahl aus der Messung ableiten

**Datum:** 29.09.2026 · **Grundlage:** eigene Messung, 56 Aufrufe · **Status:** Befund, technische
Folge noch nicht implementiert

Die Startwerte des Bauplans für die reservierte Ausgabe — 768 Token für die segmentierte
Einordnung, 384 für die Figurenantwort — sind für dieses Modell zu niedrig. Der Bauplan hatte sie
ausdrücklich als zu messende Startwerte gekennzeichnet; das ist hiermit geschehen.

**Messergebnis.** Mit `max_tokens: 768` waren 7 von 28 Aufrufen als JSON lesbar, mit 4000 waren es
17 von 28. Ursache ist nicht die Länge der Analyse, sondern das interne Überlegen des Modells: 344
bis 3742 Token gehen dafür weg, bevor das JSON beginnt. Bei zu kleinem Budget endet der Aufruf mit
`finish_reason=length` und **leerem** Inhalt — also HTTP 200 ohne jede Analyse.

**Was daraus für den Adapter folgt.**

- Das Ausgabebudget deutlich höher ansetzen als im Bauplan, oder das Überlegen des Modells
  begrenzen. Reasoning-Token werden als Ausgabe abgerechnet und kosten beim gewählten Modell
  3,00 USD je Million; die Kostenschätzung aus E01 ist damit zu niedrig.
- Abschneidung ist ein eigener, wiederholbarer Fehlerfall und darf nicht als ungültige Analyse
  behandelt werden. Der vorhandene Weg über `TrainerFailure.invalidAnalysis` mit einem
  Wiederholungsversuch passt dafür nur, wenn die Wiederholung das Budget erhöht.
- Anbieter, die nichts Verwertbares liefern, gezielt ausschließen.

**Nicht belegt.** Bei `temperature: 0` war die Ausgabe **nicht** stabil: nur 9 von 14 Fällen waren
über zwei Läufe wortgleich. Auf Determinismus darf kein Zwischenspeicher und keine
Wiederholungslogik aufgebaut werden.

**Tatsächliche Kosten der Messung:** 0,25 USD für 56 Aufrufe.

## E04 · Reihenfolge einer doppelseitigen Reflexion ausdrücklich loben

**Datum:** 29.09.2026 · **Entschieden von:** Jonas · **Status:** beschlossen

Eine belegte doppelseitige Reflexion erhält ausdrücklich positives Feedback für die Reihenfolge:
**zuerst Sustain Talk (Gründe für Beibehaltung), danach Change Talk (Gründe für Veränderung)**.
Die Reihenfolge selbst ist der Anlass für dieses Lob. Sie darf nicht lediglich als Stilmerkmal
ohne Rückmeldung behandelt werden. Beide Seiten müssen zu tatsächlichen Aussagen von Lukas
über dieselbe Veränderung passen; eine erfundene Veränderungsbereitschaft genügt nicht.

Die umgekehrte Reihenfolge bekommt dieses spezielle Lob nicht, wird aber nicht automatisch als
Fehler bezeichnet. Unsichere Deutung erzeugt kein sicheres Reihenfolgelob. Die Aussage über die
Reihenfolge kommt aus geprüften Textpositionen, die semantische Zuordnung aus dem Modell.

Umgesetzt als MI-03-Teilschritt: optionales `doubleSidedReflection` mit vier Belegreferenzen,
Promptstand 0.2, Feedbackbausteine 0.2. Kein neuer Offenheitsbonus und keine sichtbare Punktzahl.
E04 ist eine Produktentscheidung und keine Literaturquelle oder wissenschaftliche Validierung;
der Textbaustein bleibt fachlicher Entwurf.
