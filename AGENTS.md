# Beratungstrainer

Native SwiftUI-App. Produkt- und Architekturentscheidungen stehen im Bauplan und in Documentation.
TrainerCore bleibt unabhängig von UI, SwiftData, MLX und Audio.
Offenheit ist intern; daraus niemals Veränderungsbereitschaft oder eine Kompetenznote ableiten.
Modellaufrufe laufen über OpenRouter (Documentation/ENTSCHEIDUNGEN.md, E01 bis E03); die
frühere Regel „Keine Cloud-Inferenz" gilt nicht mehr. Unverändert gilt: keine echten
Klienten- oder Mandatsdaten in Prompts, Logs oder Testdaten. Demo-Antworten eindeutig als
Testbetrieb kennzeichnen.
Modelldateien und Gesprächsprotokolle nicht in Git aufnehmen.
Nach Änderungen die betroffenen Core-Tests und den passenden App-Build ausführen; fehlende Geräteprüfungen ausdrücklich dokumentieren.
