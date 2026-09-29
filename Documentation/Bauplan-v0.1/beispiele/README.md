# Beispieldaten

Diese Daten erklären die Verträge. Sie sind synthetische technische Beispiele und kein fachlich validierter Evaluationssatz.

## Einordnung und Antwort

Vorheriger Kliententext: „Sarah nervt mit ihrem Druck. Aber verlieren will ich sie auch nicht.“

Aktuelle Berateräußerung: „Sie sind genervt von Sarahs Druck und trotzdem ist Ihnen die Beziehung wichtig. Was würden Sie sich von diesem Gespräch wünschen?“

[einordnung.json](einordnung.json) ist ein mögliches strukturelles Ergebnis. Angenommen, der vorherige Offenheitswert war 3 und es gab keinen kürzlichen Bonus für komplexe Reflexion: Der vorläufige Wert wird 4, und `lukas.hausflur` wird verfügbar. [antwort.json](antwort.json) demonstriert dessen Erwähnung. Erst ein gültiger, gespeicherter Turn fügt die ID zur Offenbarungshistorie hinzu.

## Regeltests

[regeltests.json](regeltests.json) enthält unabhängige Testfälle. `before` und `expectedAfterReduction` entsprechen `SimulationState`. Die Einordnungen sind für diese Tests als Eingaben vorgegeben; geprüft werden soll ausschließlich die deterministische Rechenregel, nicht die fachliche Richtigkeit der Kategorie.

`clientContext` enthält die für Kontextbelege verfügbaren Klientenaussagen. `currentInput` ist der eingeordnete Text. Die Faktenhistorie verändert sich in diesen Reducer-Tests nicht; Offenbarungen werden separat beim vollständigen Turn geprüft.

Zusätzliche Integrationstests müssen Antwortvalidierung, Faktenauswahl, spätere Offenlegung und Commit abdecken. Eine Prüfung, dass diese JSON-Dateien lesbar sind, ersetzt die spätere Ausführung des StateReducers nicht.
