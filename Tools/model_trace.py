#!/usr/bin/env python3
"""Inhaltsfreie Modell-Messspur auswerten oder einen ausdrücklich gewählten Lauf umschließen.

Kein Netzwerkcode, keine Preisannahmen. Fehlende Kosten bleiben unbekannt.
"""
import argparse
from collections import Counter, defaultdict
from decimal import Decimal
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time


def execute_run(command, trace, *, cwd=None, environment=None, stdout=None, stderr=None):
    """Schreibt den Prozessrahmen, auch bei Fehlschlag. Speichert weder Kommando noch Umgebung."""
    trace = Path(trace).resolve()
    manifest = Path(str(trace) + '.run.json')
    if trace.exists() or manifest.exists():
        raise ValueError('Für jeden Lauf einen neuen Dateipfad wählen.')
    if not trace.parent.is_dir():
        raise ValueError('Der Ausgabeordner muss bereits existieren.')
    env = dict(os.environ if environment is None else environment)
    env['RR_MODEL_TRACE_FILE'] = str(trace)
    record = {'schemaVersion': 1, 'startedAt': time.time(), 'finishedAt': None,
              'durationSeconds': None, 'exitCode': None,
              'scope': 'wholeProcessIncludingBuildAndSetup'}
    # Exklusiv anlegen, damit auch versehentlicher Parallelstart nicht überschreibt.
    with manifest.open('x', encoding='utf-8') as handle:
        json.dump(record, handle, indent=2)
    start = time.perf_counter()
    try:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=stdout, stderr=stderr, check=False)
        record['exitCode'] = result.returncode
        return result.returncode
    except KeyboardInterrupt:
        record['exitCode'] = 130
        return 130
    except OSError:
        record['exitCode'] = 127
        raise ValueError('Der gewählte Prozess konnte nicht gestartet werden.') from None
    finally:
        record['durationSeconds'] = time.perf_counter() - start
        record['finishedAt'] = time.time()
        temporary = Path(str(manifest) + '.tmp')
        temporary.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
        temporary.replace(manifest)


def read_events(path):
    data = Path(path).read_bytes()
    lines = data.splitlines()
    events, warnings = [], []
    for index, line in enumerate(lines):
        if not line.strip():
            continue
        try:
            event = json.loads(line, parse_float=Decimal)
        except (ValueError, UnicodeDecodeError):
            if index == len(lines) - 1 and not data.endswith(b'\n'):
                warnings.append('Letzte JSONL-Zeile unvollständig; Lauf möglicherweise abgebrochen.')
                break
            raise ValueError(f'Ungültiger Datensatz in Zeile {index + 1}; Inhalt wird nicht ausgegeben.') from None
        if not isinstance(event, dict) or event.get('schemaVersion') != 1:
            raise ValueError(f'Unbekanntes Format in Zeile {index + 1}.')
        events.append(event)
    return events, warnings


def number(value):
    if isinstance(value, (int, float, Decimal)) and not isinstance(value, bool):
        result = float(value)
        if math.isfinite(result) and result >= 0:
            return result
    return None


def merged(intervals):
    result = []
    for start, end in sorted(intervals):
        if end < start:
            raise ValueError('Negative Zeitspanne in Messspur.')
        if result and start <= result[-1][1]:
            result[-1] = (result[-1][0], max(end, result[-1][1]))
        else:
            result.append((start, end))
    return result


def covered(intervals):
    return sum(end - start for start, end in merged(intervals))


def totals(calls):
    def total(field):
        values = [row[field] for row in calls if number(row.get(field)) is not None]
        return {'reported': str(sum((Decimal(str(v)) for v in values), Decimal(0))),
                'knownCalls': len(values), 'missingCalls': len(calls) - len(values)}
    return {'calls': len(calls),
            'durationSeconds': sum(number(row.get('durationSeconds')) or 0 for row in calls),
            'transportSeconds': sum(number(row.get('transportSeconds')) or 0 for row in calls),
            'inputTokens': total('inputTokens'), 'outputTokens': total('outputTokens'), 'costUSD': total('costUSD'),
            'suspectedWhitespaceLoops': sum(row.get('suspectedWhitespaceLoop') is True for row in calls),
            'whitespaceMeasuredCalls': sum(row.get('longestWhitespaceRun') is not None for row in calls)}


def summarize(events, manifest=None):
    warnings = []
    runs = {row.get('runID') for row in events if row.get('runID')}
    if len(runs) != 1:
        raise ValueError('Genau eine runID je Messdatei erforderlich.')
    starts, finishes = {}, {}
    for row in events:
        kind = row.get('kind')
        if kind in ('callStarted', 'roundStarted', 'callFinished', 'roundFinished'):
            key = ('call' if kind.startswith('call') else 'round', row.get('id'))
            target = starts if kind.endswith('Started') else finishes
            if key in target:
                raise ValueError('Doppeltes Start-/Endereignis; Summen wären unzuverlässig.')
            target[key] = row
    intervals = defaultdict(list)
    for key, finish in finishes.items():
        begin = starts.get(key)
        if begin is None:
            warnings.append(f'{key[0]}-Abschluss ohne Start; Zeitabdeckung unvollständig.')
            continue
        a, b = number(begin.get('offsetSeconds')), number(finish.get('offsetSeconds'))
        if a is None or b is None:
            warnings.append('Monotone Zeitmarke fehlt; Zeitabdeckung unvollständig.')
        else:
            intervals[key[0]].append((a, b))
    incomplete = Counter(key[0] for key in starts if key not in finishes)
    if incomplete:
        warnings.append('Offene Aufrufe/Runden: deren Dauer und Kosten sind unbekannt, nicht null.')
    calls = [row for (kind, _), row in finishes.items() if kind == 'call']
    offsets = [number(row.get('offsetSeconds')) for row in events]
    offsets = [value for value in offsets if value is not None]
    observed = max(offsets, default=0) - min(offsets, default=0)
    wall = number((manifest or {}).get('durationSeconds'))
    if wall is None:
        warnings.append('Kein vollständiger Prozessrahmen: Start-/Endlücke des Gesamtlaufs nicht messbar.')
    elif wall < observed - 0.01:
        raise ValueError('Prozessrahmen kürzer als Messspur; falsche Dateien?')
    call_coverage = covered(intervals['call'])
    scope_coverage = covered(intervals['call'] + intervals['round'])
    groups = {}
    for field in ('stage', 'outcome', 'provider'):
        buckets = defaultdict(list)
        for row in calls:
            buckets[row.get(field) or 'unknown'].append(row)
        groups[field] = {key: totals(rows) for key, rows in sorted(buckets.items())}
    retry = Counter(row.get('retryReason', 'unknown') for row in calls if (row.get('budgetAttempt') or 1) > 1)
    coordinator_retry = Counter(row.get('retryReason', 'unknown') for row in events if row.get('kind') == 'coordinatorRetry')
    return {'schemaVersion': 1, 'runID': next(iter(runs)), 'totals': totals(calls), 'groups': groups,
            'time': {'wholeProcessSeconds': wall, 'observedTraceSeconds': observed,
                     'callSpanUnionSeconds': call_coverage,
                     'roundOverheadSeconds': scope_coverage - call_coverage,
                     'outsideMeasuredScopesSeconds': None if wall is None else max(0, wall - scope_coverage)},
            'budgetRetries': dict(retry), 'coordinatorRetries': dict(coordinator_retry),
            'roundResults': dict(Counter(row.get('result', 'unknown') for (kind, _), row in finishes.items() if kind == 'round')),
            'unfinished': dict(incomplete), 'warnings': warnings}


def render(report):
    t, timing = report['totals'], report['time']
    lines = ['# Modellaufrufe – Messübersicht', '', f"Abgeschlossene Aufrufe: {t['calls']}"]
    def seconds(value):
        return 'unbekannt' if value is None else f'{value:.3f} s'
    lines += [f"Gesamter Prozess (einschließlich Build/Start/Ende): {seconds(timing['wholeProcessSeconds'])}",
              f"Summe aller Transportdauern, auch Fehlversuche: {seconds(t['transportSeconds'])}",
              f"Summe Aufrufdauern einschließlich Auswertung: {seconds(t['durationSeconds'])}",
              f"Zeit durch Aufrufspannen abgedeckt (Vereinigung bei Parallelität): {seconds(timing['callSpanUnionSeconds'])}",
              f"Rundenzeit außerhalb der Aufrufe: {seconds(timing['roundOverheadSeconds'])}",
              f"Außerhalb gemessener Runden/Aufrufe: {seconds(timing['outsideMeasuredScopesSeconds'])}", '',
              'Letzterer Rest umfasst Build, Start, Vorbereitung, Pausen und Abschluss. Er ist gemessen,',
              'aber nicht ursächlich weiter aufgeschlüsselt. Offene Spannen machen die Zuordnung unvollständig.', '']
    for field, title in [('inputTokens', 'Eingabetoken'), ('outputTokens', 'Ausgabetoken'), ('costUSD', 'Gemeldete Kosten (USD)')]:
        value = t[field]
        lines.append(f"{title}: {value['reported']} bekannt; {value['knownCalls']} Aufrufe mit Angabe, {value['missingCalls']} ohne Angabe.")
    lines += ['', f"Budgetwiederholungen: {json.dumps(report['budgetRetries'], ensure_ascii=False)}",
              f"Coordinator-Wiederholungen: {json.dumps(report['coordinatorRetries'], ensure_ascii=False)}",
              f"Rundenausgänge: {json.dumps(report['roundResults'], ensure_ascii=False)}", '']
    for field, title in [('stage', 'Stufen'), ('outcome', 'Ausgänge'), ('provider', 'Anbieterrouten')]:
        lines += [f'## {title}', '', '| Wert | Aufrufe | Transport s | Kosten USD bekannt | Kosten fehlen | Leerraumverdacht / gemessen |',
                  '|---|---:|---:|---:|---:|---:|']
        for key, value in report['groups'][field].items():
            label = str(key).replace('|', '/').replace('\n', ' ')
            lines.append(f"| {label} | {value['calls']} | {value['transportSeconds']:.3f} | {value['costUSD']['reported']} | {value['costUSD']['missingCalls']} | {value['suspectedWhitespaceLoops']} / {value['whitespaceMeasuredCalls']} |")
        lines.append('')
    lines += ['Leerraumverdacht: mindestens 128 aufeinanderfolgende Unicode-Leerraumzeichen und',
              '`finish_reason=length/error`. Kein Text wird gespeichert. Null beobachtete Fälle',
              'belegen bei kleinen Stichproben keinen fehlerfreien Anbieter.', '']
    if report['unfinished']:
        lines += [f"Offene Spannen: {json.dumps(report['unfinished'])}", '']
    lines.extend('Hinweis: ' + warning for warning in report['warnings'])
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='mode', required=True)
    run = commands.add_parser('run', help='Gewählten Prozess messen; führt das Kommando tatsächlich aus')
    run.add_argument('--trace', type=Path, required=True)
    run.add_argument('command', nargs=argparse.REMAINDER)
    summary = commands.add_parser('summarize', help='Vorhandene Metadaten offline auswerten')
    summary.add_argument('trace', type=Path)
    summary.add_argument('--json', action='store_true')
    args = parser.parse_args()
    try:
        if args.mode == 'run':
            command = args.command[1:] if args.command[:1] == ['--'] else args.command
            if not command:
                raise ValueError('Kein Kommando angegeben.')
            return execute_run(command, args.trace)
        events, warnings = read_events(args.trace)
        path = Path(str(args.trace) + '.run.json')
        manifest = json.loads(path.read_text()) if path.exists() else None
        report = summarize(events, manifest)
        report['warnings'] += warnings
        print(json.dumps(report, ensure_ascii=False, indent=2) if args.json else render(report), end='\n' if args.json else '')
        return 0
    except (ValueError, OSError) as error:
        # Keine Inhalte beschädigter JSON-Zeilen und keine Prozessumgebung ausgeben.
        print(f'Messauswertung nicht möglich: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
