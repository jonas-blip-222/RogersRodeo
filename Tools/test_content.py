import tempfile
from pathlib import Path
import unittest
from compile_content import ROOT, compile_catalog, compile_scenario


class ContentTests(unittest.TestCase):
    def source(self, text):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        path = Path(temporary.name) / "figure.md"
        path.write_text(text, encoding="utf-8")
        return path

    def test_deterministic_and_draft_gate(self):
        self.assertEqual(compile_catalog(ROOT / "ContentSource", True), compile_catalog(ROOT / "ContentSource", True))
        with self.assertRaises(ValueError):
            compile_catalog(ROOT / "ContentSource", False)

    def test_invalid_authoring(self):
        original = (ROOT / "ContentSource/lukas.md").read_text(encoding="utf-8")
        for invalid in [
            original.replace("age: 28", "age: true"),
            original.replace("age: 28", "age: 28\nextra: unknown"),
            original.replace("age: 28", "age: 28\nage: 29"),
            original.replace("minimum_openness: 6", "minimum_openness: 11"),
            original.replace("lukas.vater", "lukas.hausflur"),
            original.replace('version: "0.2"', "version: 0.2"),
        ]:
            with self.subTest(source=invalid[:80]), self.assertRaises(ValueError):
                compile_scenario(self.source(invalid), True)

    def test_hidden_facts_not_in_public_profile(self):
        scenario = compile_scenario(ROOT / "ContentSource/lukas.md", True)
        self.assertNotIn("Hausflur", scenario["publicProfile"])
        self.assertNotIn("Dein Vater", scenario["publicProfile"])
        self.assertEqual([fact["minimumOpenness"] for fact in scenario["facts"]], [8, 4, 6])


if __name__ == "__main__":
    unittest.main()
