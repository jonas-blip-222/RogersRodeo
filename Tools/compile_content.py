#!/usr/bin/env python3
"""Deterministischer Autorformat-Compiler. Kein Modellaufruf, kein Netzwerk."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]


class UniqueLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"Doppelter YAML-Schlüssel: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping)


def keys(obj, expected):
    if not isinstance(obj, dict) or set(obj) != set(expected):
        raise ValueError(f"Erwartete Felder: {sorted(expected)}")


def string(value):
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Nichtleere Zeichenkette erwartet")
    return value


def integer(value, lo, hi):
    if type(value) is not int or not lo <= value <= hi:
        raise ValueError(f"Ganze Zahl {lo} bis {hi} erwartet")
    return value


def identifier(value):
    if not re.fullmatch(r"[a-z][a-z0-9_.-]*", string(value)):
        raise ValueError("Ungültige ID")
    return value


def compile_scenario(path, allow_drafts=False):
    source = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    parts = source.split("---\n", 2)
    if len(parts) != 3 or parts[0] != "":
        raise ValueError("YAML-Kopf zwischen --- erwartet")
    data = yaml.load(parts[1], Loader=UniqueLoader)
    keys(data, {"schema_version", "id", "version", "status", "name", "age", "address", "approaches", "openness_start", "opening_line", "facts"})
    integer(data["schema_version"], 1, 1)
    identifier(data["id"])
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", string(data["version"])):
        raise ValueError("Ungültige Inhaltsversion")
    if data["status"] not in {"draft", "reviewed"} or (data["status"] == "draft" and not allow_drafts):
        raise ValueError("Entwurfsinhalt nur mit --allow-drafts zulässig")
    if data["address"] not in {"Sie", "Du"} or data["approaches"] != ["mi"]:
        raise ValueError("Unbekannte Anrede oder Ansatz")
    if not isinstance(data["facts"], list):
        raise ValueError("facts muss eine Liste sein")
    facts = []
    seen = set()
    for fact in data["facts"]:
        keys(fact, {"id", "minimum_openness", "text"})
        fid = identifier(fact["id"])
        if fid in seen:
            raise ValueError(f"Doppelte Fakten-ID: {fid}")
        seen.add(fid)
        facts.append({"id": fid, "minimumOpenness": integer(fact["minimum_openness"], 0, 10), "text": string(fact["text"])})
    return {"schemaVersion": 1, "id": data["id"], "version": data["version"], "status": data["status"],
            "name": string(data["name"]), "age": integer(data["age"], 1, 120), "address": data["address"],
            "approaches": data["approaches"], "opennessStart": integer(data["openness_start"], 0, 10),
            "openingLine": string(data["opening_line"]), "publicProfile": string(parts[2].strip()),
            "facts": sorted(facts, key=lambda item: item["id"])}


def compile_catalog(source, allow_drafts=False):
    scenarios = [compile_scenario(p, allow_drafts) for p in sorted(source.glob("*.md")) if p.name != "mi-coding-guide.md"]
    if not scenarios or len({s["id"] for s in scenarios}) != len(scenarios):
        raise ValueError("Keine Figuren oder doppelte Figuren-ID")
    guide = string((source / "mi-coding-guide.md").read_text(encoding="utf-8").strip())
    # Kein erfundener, als fachlich geprüft markierter Tippbestand.
    catalog = {"schemaVersion": 1, "scenarios": scenarios, "codingGuide": guide, "tips": []}
    return (json.dumps(catalog, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "ContentSource")
    parser.add_argument("--output", type=Path, default=ROOT / "Beratungstrainer/Resources/Content/catalog.json")
    parser.add_argument("--allow-drafts", action="store_true")
    parser.add_argument("--check", action="store_true", help="Nur prüfen, ob eingecheckte Artefakte aktuell sind")
    args = parser.parse_args()
    try:
        output = compile_catalog(args.source, args.allow_drafts)
        digest = (hashlib.sha256(output).hexdigest() + "\n").encode("ascii")
        checksum = args.output.with_suffix(".sha256")
        if args.check:
            if args.output.read_bytes() != output or checksum.read_bytes() != digest:
                raise ValueError("Katalog veraltet; Compiler ohne --check ausführen")
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_bytes(output)
            checksum.write_bytes(digest)
        print(f"Inhalte geprüft: {len(json.loads(output)['scenarios'])} Figur(en)")
    except (ValueError, OSError, yaml.YAMLError) as error:
        print(f"Inhaltsfehler: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
