"""Lokale Pruefungen der Falldateien und des Kodierleitfadens. Kein Modellaufruf.

Was diese Tests leisten: sie pruefen mechanisch, dass die Evaluationsfaelle die
Form haben, die Tools/openrouter_eval.py erwartet, dass die erwarteten Antworten
nicht in den Prompt gelangen, und dass der Leitfaden im Bundle genau dem
Autorformat entspricht.

Was sie ausdruecklich NICHT leisten: sie sagen nichts darueber aus, ob ein
Modell die Faelle fachlich richtig einordnet. Ein Test ueber den Prompttext ist
kein Nachweis von Modellqualitaet. Diese Frage beantwortet nur ein Livelauf
(Tools/openrouter_eval.py) und danach Jonas' fachliches Urteil.
"""

import json
from pathlib import Path
import unittest

from compile_content import ROOT, compile_catalog
from openrouter_eval import (
    CODES,
    VERBOTENE_FELDER,
    faelle_auswaehlen,
    nutzernachricht,
)

FALLDATEIEN = [
    ROOT / "Evaluation/mi-faelle.json",
    ROOT / "Evaluation/lange-faelle.json",
    ROOT / "Evaluation/kontrast-autonomie.json",
]
KONTRASTE = ROOT / "Evaluation/kontrast-autonomie.json"
LEITFADEN = ROOT / "ContentSource/mi-coding-guide.md"


def laden(pfad):
    return json.loads(pfad.read_text(encoding="utf-8"))


class FalldateiTests(unittest.TestCase):
    """Form der Falldateien, gemeinsam fuer alle drei Sammlungen."""

    def test_pflichtfelder_und_eindeutige_ids(self):
        for pfad in FALLDATEIEN:
            with self.subTest(datei=pfad.name):
                daten = laden(pfad)
                self.assertEqual(daten["schemaVersion"], 1)
                # Keine dieser Sammlungen darf sich als geprueft ausgeben.
                self.assertFalse(daten["istGoldreferenz"])
                self.assertTrue(str(daten["status"]).strip())
                self.assertTrue(daten["hinweis"].strip())
                ids = [fall["id"] for fall in daten["faelle"]]
                self.assertEqual(len(ids), len(set(ids)))
                for fall in daten["faelle"]:
                    with self.subTest(fall=fall["id"]):
                        for feld in ("id", "titel", "art", "fachlicheErwartung", "gegenprobe"):
                            self.assertTrue(str(fall.get(feld, "")).strip())
                        self.assertIn(fall["art"], {"segment", "prozess", "verlauf"})
                        # null steht fuer "keine Warnungsaussage" und ist zulaessig.
                        self.assertIn(type(fall["erwarteteWarnung"]), (bool, type(None)))
                        for nachricht in fall.get("kontext") or []:
                            self.assertIn(nachricht["speaker"], {"client", "counselor"})
                            self.assertTrue(nachricht["text"].strip())

    def test_erwartete_antwort_gelangt_nicht_in_den_prompt(self):
        """Die Felder mit der erwarteten Einordnung duerfen das Modell nie sehen."""
        for pfad in FALLDATEIEN:
            daten = laden(pfad)
            for fall in faelle_auswaehlen(daten, None):
                with self.subTest(datei=pfad.name, fall=fall["id"]):
                    text = nutzernachricht(fall)
                    for feld in VERBOTENE_FELDER:
                        self.assertNotIn(feld, text)
                    self.assertNotIn(fall["fachlicheErwartung"], text)
                    self.assertNotIn(fall["gegenprobe"], text)
                    self.assertIn(fall["eingabe"], text)

    def test_belege_der_kontrastfaelle_stehen_woertlich_im_fall(self):
        """Jede in einer Begruendung zitierte Textstelle muss es auch wirklich geben.

        Geprueft wird nur `fachlicheErwartung` der Kontrastsammlung, und dort nur
        Zitate in einfachen Anfuehrungszeichen: so faellt auf, wenn ein Fall
        spaeter umformuliert wird, die Begruendung aber weiter auf den alten
        Wortlaut zeigt. `gegenprobe` bleibt aussen vor, weil dort absichtlich
        auch erfundene Gegenbeispiele stehen ("waere der Satz stattdessen ...").
        """
        for fall in laden(KONTRASTE)["faelle"]:
            vorhanden = " ".join(
                [fall.get("eingabe") or ""]
                + [n["text"] for n in (fall.get("kontext") or [])]
            )
            for zitat in (fall["fachlicheErwartung"]).split("'")[1::2]:
                if not zitat.strip() or "_" in zitat:
                    continue  # Codenamen wie ratschlag_ohne_erlaubnis
                with self.subTest(fall=fall["id"], zitat=zitat):
                    self.assertIn(zitat, vorhanden)


class KontrastfallTests(unittest.TestCase):
    """Die neue Sammlung muss beide Richtungen abdecken."""

    def test_positive_und_negative_faelle_vorhanden(self):
        faelle = laden(KONTRASTE)["faelle"]
        self.assertGreaterEqual(sum(1 for f in faelle if f["erwarteteWarnung"]), 3)
        self.assertGreaterEqual(sum(1 for f in faelle if not f["erwarteteWarnung"]), 3)

    def test_autonomie_wird_in_beide_richtungen_gepruft(self):
        """Sonst bliebe unbemerkt, wenn die Sammlung nur noch Ablehnungen enthaelt."""
        faelle = laden(KONTRASTE)["faelle"]
        erwaehnen = [f for f in faelle if "autonomie_betonen" in f["fachlicheErwartung"]]
        self.assertTrue(any("Kein autonomie_betonen" in f["fachlicheErwartung"]
                            or "kein autonomie_betonen" in f["fachlicheErwartung"]
                            for f in erwaehnen))
        self.assertTrue(any(not f["erwarteteWarnung"] for f in erwaehnen))

    def test_alle_faelle_werden_vom_auswertungsskript_ausgewaehlt(self):
        daten = laden(KONTRASTE)
        self.assertEqual(
            [f["id"] for f in faelle_auswaehlen(daten, None)],
            [f["id"] for f in daten["faelle"]],
        )

    def test_gleicher_halbsatz_in_verschiedenen_kontexten(self):
        """Der Kern der Sammlung: gleiche Wortwahl, unterschiedlicher Kontext.

        kontrast01 und kontrast02 tragen dieselbe Eingabe bei ungleicher
        Vorgeschichte; kontrast06 hat dieselbe Vorgeschichte wie kontrast01, aber
        eine andere erwartete Einordnung. Geht eines davon verloren, misst die
        Sammlung keine Kontextabhaengigkeit mehr.
        """
        faelle = {f["id"]: f for f in laden(KONTRASTE)["faelle"]}
        self.assertEqual(faelle["kontrast01_entscheidung_als_nachdruck"]["eingabe"],
                         faelle["kontrast02_entscheidung_als_nachdruck_ohne_vorgeschichte"]["eingabe"])
        self.assertNotEqual(faelle["kontrast01_entscheidung_als_nachdruck"]["kontext"],
                            faelle["kontrast02_entscheidung_als_nachdruck_ohne_vorgeschichte"]["kontext"])
        self.assertEqual(faelle["kontrast01_entscheidung_als_nachdruck"]["kontext"],
                         faelle["kontrast06_autonomie_nach_draengen"]["kontext"])
        self.assertNotEqual(faelle["kontrast01_entscheidung_als_nachdruck"]["erwarteteWarnung"],
                            faelle["kontrast06_autonomie_nach_draengen"]["erwarteteWarnung"])


class LeitfadenTests(unittest.TestCase):
    """Strukturpruefung des Leitfadens. Kein Nachweis fachlicher Qualitaet."""

    def test_alle_codes_bleiben_definiert(self):
        text = LEITFADEN.read_text(encoding="utf-8")
        for code in CODES:
            with self.subTest(code=code):
                self.assertIn(f"| {code} |", text)

    def test_ausgabevertrag_bleibt_erhalten(self):
        """Die Formatzusage darf beim Umschreiben der Anleitung nicht verloren gehen."""
        text = LEITFADEN.read_text(encoding="utf-8")
        for zusage in ("Ausgabe ausschließlich als JSON mit segments",
                       "supportingClientQuote",
                       "isUncertain=true",
                       "höchstens zwölf"):
            with self.subTest(zusage=zusage):
                self.assertIn(zusage, text)

    def test_bundle_enthaelt_genau_den_autorstand(self):
        katalog = json.loads(compile_catalog(ROOT / "ContentSource", True))
        self.assertEqual(katalog["codingGuide"],
                         LEITFADEN.read_text(encoding="utf-8").strip())

    def test_eingecheckter_katalog_ist_aktuell(self):
        erzeugt = compile_catalog(ROOT / "ContentSource", True)
        pfad = ROOT / "Beratungstrainer/Resources/Content/catalog.json"
        self.assertEqual(pfad.read_bytes(), erzeugt)


if __name__ == "__main__":
    unittest.main()
