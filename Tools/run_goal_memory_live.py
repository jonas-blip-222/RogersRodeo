#!/usr/bin/env python3
"""Expliziter, kostenpflichtiger Live-Test des produktiven Swift-Analyseadapters.

Nur fiktive Stimuli. Antworten der Figur und Vorzustände sind kontrollierte Fixtures.
Schlüssel ausschließlich im Arbeitsspeicher; keine Ausgabe und keine Dateiablage.
"""
import argparse
import datetime
import getpass
import os
from pathlib import Path
import subprocess
import sys
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['long', 'probes'], help='15-Runden-Verlauf oder sieben unabhängige Übergänge')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    key = os.environ.get('OPENROUTER_API_KEY', '').strip()
    if not key:
        try:
            result = subprocess.run(['security', 'find-generic-password', '-a', getpass.getuser(),
                                     '-s', 'rogersrodeo-openrouter', '-w'],
                                    capture_output=True, text=True, timeout=30, check=False)
        except (OSError, subprocess.TimeoutExpired):
            print('Kein Schlüsselbundzugriff; kein Modelltest gestartet.', file=sys.stderr)
            return 2
        if result.returncode == 0:
            key = result.stdout.strip()
    if not key:
        print('Keine Authentifizierung verfügbar; kein Modelltest gestartet.', file=sys.stderr)
        return 2
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    directory = root / 'Evaluation' / 'results' / f'goal-live-{stamp}-{uuid.uuid4().hex[:8]}'
    directory.mkdir(parents=True)
    report = directory / f'{args.mode}.json'
    environment = os.environ.copy()
    environment.update(OPENROUTER_API_KEY=key, RR_RUN_GOAL_LIVE='1', RR_GOAL_LIVE_REPORT=str(report),
                       CLANG_MODULE_CACHE_PATH='/private/tmp/rr-goal-app-modules')
    test = 'zielgedaechtnisLiveMitFuenfzehnRunden' if args.mode == 'long' else 'zielgedaechtnisLiveEinzelneUebergaenge'
    command = ['swift', 'test', '--disable-sandbox', '--scratch-path', '/private/tmp/rr-goal-app',
               '--cache-path', '/private/tmp/rr-goal-cache', '--config-path', '/private/tmp/rr-goal-config',
               '--security-path', '/private/tmp/rr-goal-security', '--filter', test]
    print(f'Live-Test {args.mode}; fiktive Daten werden an OpenRouter gesendet. Ergebnis: {report}', flush=True)
    with (directory / 'build-and-test.log').open('w') as log:
        result = subprocess.run(command, cwd=root, env=environment, stdout=log, stderr=subprocess.STDOUT, check=False)
    print(f'Test beendet, Exitstatus {result.returncode}. Log und rohe Analyseantworten liegen im Ergebnisordner.')
    return result.returncode


if __name__ == '__main__':
    sys.exit(main())
