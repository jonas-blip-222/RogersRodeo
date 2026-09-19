#!/usr/bin/env python3
"""Verpackt einen vorhandenen SwiftPM-Debug-Build zur lokalen Mac-Prüfung."""
import argparse
from pathlib import Path
import plistlib
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--bin-path", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
executable = args.bin_path / "RogersRodeo"
resource = args.bin_path / "RogersRodeo_TrainerDesktop.bundle"
if not executable.is_file() or not resource.is_dir():
    parser.error("Zuerst den SwiftPM-Debug-Build erzeugen")
if args.output.exists():
    parser.error("Ausgabe existiert bereits; für einen neuen Stand einen neuen Pfad verwenden")
contents = args.output / "Contents"
(contents / "MacOS").mkdir(parents=True)
shutil.copy2(executable, contents / "MacOS/RogersRodeo")
(contents / "Resources").mkdir()
shutil.copytree(resource, contents / "Resources" / resource.name)
with (contents / "Info.plist").open("wb") as file:
    plistlib.dump({"CFBundleExecutable": "RogersRodeo", "CFBundleIdentifier": "de.rogersrodeo.desktop-preview",
                  "CFBundleName": "Rogers Rodeo Demo", "CFBundleDisplayName": "Rogers Rodeo Demo",
                  "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1",
                  "LSMinimumSystemVersion": "15.0", "NSHighResolutionCapable": True}, file)
subprocess.run(["codesign", "--force", "--sign", "-", str(args.output)], check=True)
print(args.output)
