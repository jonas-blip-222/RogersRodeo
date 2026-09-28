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
- Datenschutz: Beratungsäußerungen verlassen das Gerät. Nur Anbieterrouten ohne Datenspeicherung
  verwenden. Sobald Kolleg:innen mitüben, sind es deren Äußerungen; `~/Developer/AGENTS.md`
  verbietet Klienten- und Mandatsdaten in Prompts und Logs, und eine Beratungsübung verleitet
  dazu, echtes Fallmaterial einzutippen. Ein Hinweis in der App ist vorzusehen.
- Offline-Betrieb entfällt. Verhalten ohne Netz, bei Zeitüberschreitung und bei Fehlern der
  Gegenseite muss definiert werden; die Speicherinvarianten des Coordinators gelten unverändert.
- Das Deployment-Target ist neu zu bestimmen. Ohne MLX und ohne FoundationModels-Brücke gibt es
  keinen technischen Grund mehr für iOS 27, womit iPhone 14 und 15 leichter erreichbar werden.
- Der fachlich geprüfte Referenzsatz aus dem Bauplan (60 Einzelbeispiele, fünf je Code) fehlt
  weiterhin. Er wird durch diese Entscheidung nicht ersetzt.
