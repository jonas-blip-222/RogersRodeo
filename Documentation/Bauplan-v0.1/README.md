# Beratungstrainer – Bauplan v0.1

Stand: 18.09.2026. Planungsstand nach Sichtung der vier unterschiedlichen Projektunterlagen und dem Gespräch mit Jonas. Dieses Paket enthält Spezifikationen, Schnittstellen und Beispiele. Es enthält noch keine fertige iPhone-App und keine gemessenen Ergebnisse eines lokalen Sprachmodells.

> **Überholt in einem zentralen Punkt, Stand 29.09.2026.**
> Dieses Dokument bleibt als historischer Planungsstand unverändert erhalten und wird nicht
> rückwirkend umgeschrieben. Es beschreibt durchgehend ein **lokal auf dem Gerät ausgeführtes
> Modell** über MLX oder die FoundationModels-Brücke. Dieser Weg wird nicht mehr verfolgt: die
> Modellaufrufe laufen über die OpenRouter-API. Damit sind insbesondere überholt — die
> Offline-Zusage, die gebündelten Modellgewichte samt `Models.lock.json`, das daraus abgeleitete
> Deployment-Target iOS 27, die reservierten Ausgabebudgets von 768 und 384 Token, und die
> Arbeitspakete T00 und T07 in [04-Umsetzungsplan.md](04-Umsetzungsplan.md).
>
> Weiterhin gültig ist alles, was nicht an der Modellherkunft hängt: die Trennung von Kern und
> Adaptern, die atomare Turn-Transaktion, die verborgene Offenheit, die Faktenfreigabe, die
> Validierung von Zitaten und Fakten-IDs, und der Verzicht auf eine automatische Kompetenznote.
>
> Maßgeblich sind [../ENTSCHEIDUNGEN.md](../ENTSCHEIDUNGEN.md) (E01 bis E03) und
> [../MI-UEBERGABE.md](../MI-UEBERGABE.md).

## Die geplante App

Jonas übt ein Gespräch mit einer fiktiven Person aus der Drogenberatung. Die erste Figur ist Lukas, der erste Beratungsansatz Motivational Interviewing (MI). Das Gespräch läuft vollständig lokal auf dem iPhone. Freiwillig eingeblendete Hinweise unterstützen die nächste Gesprächsreaktion. Anschließend gibt es eine Auswertung mit konkreten Gesprächsstellen.

Der erste durchgehende Prototyp bietet Texteingabe. Für V1 kommen Push-to-Talk, Sprachausgabe, lokale Protokolle und Export hinzu.

## Festgelegt und vorgeschlagen

| Status | Entscheidung |
|---|---|
| Von Jonas bestätigt | Offenheit bleibt während des Gesprächs im Hintergrund. |
| Von Jonas genannt | Erstes Testgerät ist ein iPhone 17. Unterstützung ab iPhone 14/15 ist erwünscht, abhängig von technischen Anforderungen. |
| Fachlich erläutert und akzeptiert | Offenheit beschreibt die Bereitschaft der Figur, persönlich zu erzählen; sie ist von Veränderungsbereitschaft getrennt. |
| Aus dem Konzept übernommen | Native iPhone-App, offline, MI zuerst, Lukas zuerst, kuratierte Tipps, lokales Modell als Standard. |
| Architekturvorschlag | SwiftUI, iOS 27, Xcode 27, ein unabhängiges Swift-Paket für den Gesprächskern. |
| Architekturvorschlag | Eigenes Modell über MLX; Apples Modell als optionaler Entwicklungsvergleich. |
| Produktvorschlag | Auch in der normalen Auswertung erscheint kein numerischer Offenheitswert. Entwicklerdiagnostik darf ihn anzeigen. |
| Produktvorschlag | Hinweise zunächst ausgeschaltet, über „Hinweis“ abrufbar; Einstellung für automatische Hinweise möglich. |
| Noch zu messen | Modellwahl, Quantisierung, Antwortzeiten, Speicherbedarf und Freigabe älterer Geräte. |
| Fachlicher Entwurf | Figureninhalte, positive/negative Zustandsänderungen, Einordnungskategorien und Tipptexte. |

Vorschläge sind Arbeitsvorgaben für diesen Entwurf. Die Regelwerte sind keine validierten psychologischen Kennzahlen.

## Lesen und umsetzen

1. [Architektur und Entwicklungsumgebung](01-Architektur.md)
2. [Gesprächsablauf, Daten und Regeln](02-Gespraech-und-Regeln.md)
3. [Modellanbindung und Qualitätsprüfung](03-Modell-und-Qualitaet.md)
4. [Arbeitspakete mit Abnahmekriterien](04-Umsetzungsplan.md)
5. [Übergabe an das ausführende Modell](05-Uebergabe.md)

Ergänzend:

- [Swift-Schnittstellen](vertrage/TrainerContracts.swift): eigene, von MLX und SwiftUI unabhängige Verträge.
- [Beispiel einer Turn-Einordnung](beispiele/einordnung.json).
- [Beispiel einer Figurenantwort](beispiele/antwort.json).
- [Referenzfälle für Zustandsänderungen](beispiele/regeltests.json).
- [Quellen, Befunde und offene Nachweise](06-Nachweise.md).
- [Prüfung dieses Bauplanpakets](PRUEFUNG.md).

## Erster überprüfbarer Meilenstein

Eine neue Sitzung startet mit Lukas' festem Einstieg. Jonas schreibt eine Antwort. Die App ordnet sie ein, berechnet einen vorläufigen Zustand, erzeugt Lukas' Antwort und speichert den vollständigen Wechsel genau einmal. Jonas kann abbrechen, erneut versuchen, die Sitzung schließen und fortsetzen. Die Auswertung zeigt nur Einordnungen, die tatsächlich vorliegen.

Zuerst funktioniert dieser Ablauf mit festen Testantworten. Danach wird ein echtes lokales Modell angeschlossen und auf dem iPhone 17 geprüft. Das iPhone 14 ist ein angestrebtes Leistungsziel, noch keine zugesicherte Gerätefreigabe.

## Rahmen der ersten Version

- Eine Figur und ein Ansatz; weitere Figuren können später als Inhalte ergänzt werden.
- Eine lokal laufende Modellinstanz für Einordnung und Rollenantwort, mit getrennten Kontexten.
- Keine Konten, kein eigener Server, keine Cloud-Synchronisation.
- Vollständige Sitzung einschließlich beider KI-Aufgaben offline. Kein automatischer Wechsel auf ein Cloud-Modell.
- Markdown-Export zuerst, PDF-Export vor Abschluss von V1.
- Keine automatische Gesamtnote und keine Behauptung einer standardisierten MITI-Bewertung.
- Der eigene App-Code wird versioniert; Modellgewichte bleiben außerhalb des normalen Git-Verlaufs.

## Aufwand und Plus

Die Umsetzung lässt sich in kurze, prüfbare Aufgaben zerlegen. Das passt grundsätzlich zu einer schrittweisen Arbeit innerhalb eines Plus-Abos; die tatsächlich benötigten Sitzungen hängen vor allem von Modellproblemen und Gerätetests ab. Dieses Paket vermeidet eine Zusage über feste Nutzungsbudgets oder einen Fertigstellungstermin. Die spätere App verwendet lokale Modelle und benötigt für ihren vorgesehenen Betrieb keine OpenAI-API.
