import json
from pathlib import Path
import sys
import tempfile
import unittest

from model_trace import execute_run, read_events, summarize, render


def event(kind, identity, offset, **fields):
    return dict(schemaVersion=1, runID='fixture-run', kind=kind, id=identity,
                offsetSeconds=offset, **fields)


def pair(identity, start, end, **fields):
    return [event('callStarted', identity, start), event('callFinished', identity, end,
            durationSeconds=end - start, transportSeconds=end - start, **fields)]


class ModelTraceTests(unittest.TestCase):
    def test_failed_attempts_costs_and_time_accounting(self):
        events = [event('runStarted', 'run', 0), event('roundStarted', 'round', 1)]
        events += pair('first', 2, 6, stage='goalMemory', outcome='truncated', budgetAttempt=1,
                       provider='A', costUSD=0.25, inputTokens=10, outputTokens=50,
                       suspectedWhitespaceLoop=True, longestWhitespaceRun=1000)
        events += pair('second', 7, 9, stage='goalMemory', outcome='accepted', budgetAttempt=2,
                       provider='B', costUSD=0, inputTokens=10, outputTokens=5, retryReason='truncated')
        events += pair('third', 10, 11, stage='counselorAnalysis', outcome='transportError')
        events += [event('roundFinished', 'round', 12, result='modelUnavailable')]
        report = summarize(events, {'durationSeconds': 15})
        self.assertEqual(report['totals']['calls'], 3)
        self.assertEqual(report['totals']['costUSD'], {'reported': '0.25', 'knownCalls': 2, 'missingCalls': 1})
        self.assertEqual(report['time']['callSpanUnionSeconds'], 7)
        self.assertEqual(report['time']['roundOverheadSeconds'], 4)
        self.assertEqual(report['time']['outsideMeasuredScopesSeconds'], 4)
        self.assertEqual(report['budgetRetries'], {'truncated': 1})
        self.assertEqual(report['groups']['provider']['A']['suspectedWhitespaceLoops'], 1)
        self.assertEqual(report['roundResults'], {'modelUnavailable': 1})
        self.assertIn('ohne Angabe', render(report))

    def test_parallel_calls_use_union_not_sum(self):
        events = [event('runStarted', 'run', 0)] + pair('a', 1, 5) + pair('b', 2, 6)
        report = summarize(events, {'durationSeconds': 10})
        self.assertEqual(report['totals']['transportSeconds'], 8)
        self.assertEqual(report['time']['callSpanUnionSeconds'], 5)
        self.assertEqual(report['time']['outsideMeasuredScopesSeconds'], 5)

    def test_unfinished_and_absent_process_window_stay_unknown(self):
        report = summarize([event('runStarted', 'run', 0), event('callStarted', 'call', 1)])
        self.assertEqual(report['unfinished'], {'call': 1})
        self.assertIsNone(report['time']['wholeProcessSeconds'])
        self.assertIsNone(report['time']['outsideMeasuredScopesSeconds'])
        self.assertEqual(report['totals']['calls'], 0)
        self.assertEqual(len(report['warnings']), 2)

    def test_duplicate_finish_and_mixed_runs_rejected(self):
        events = [event('runStarted', 'run', 0)] + pair('a', 1, 2)
        with self.assertRaises(ValueError):
            summarize(events + [events[-1]])
        with self.assertRaises(ValueError):
            summarize(events + [dict(event('runStarted', 'other', 3), runID='second-run')])

    def test_decimal_costs_are_not_repriced(self):
        events = [event('runStarted', 'run', 0)]
        for index in range(10):
            events += pair(str(index), index, index + 0.5, costUSD=0.00001)
        self.assertEqual(summarize(events)['totals']['costUSD']['reported'], '0.00010')

    def test_partial_tail_recovered_but_bad_middle_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'trace.jsonl'
            path.write_text(json.dumps(event('runStarted', 'run', 0)) + '\n{"PRIVATE_TEXT":')
            rows, warnings = read_events(path)
            self.assertEqual(len(rows), 1)
            self.assertEqual(len(warnings), 1)
            self.assertNotIn('PRIVATE_TEXT', str(warnings))
            path.write_text('PRIVATE_TEXT\n{}\n')
            with self.assertRaises(ValueError) as error:
                read_events(path)
            self.assertNotIn('PRIVATE_TEXT', str(error.exception))

    def test_process_wrapper_records_failure_without_command_or_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'trace.jsonl'
            code = execute_run([sys.executable, '-c', 'raise SystemExit(3) # PRIVATE_COMMAND'], path,
                               environment={'PRIVATE_KEY': 'secret'})
            self.assertEqual(code, 3)
            raw = Path(str(path) + '.run.json').read_text()
            record = json.loads(raw)
            self.assertEqual(record['exitCode'], 3)
            self.assertGreater(record['durationSeconds'], 0)
            self.assertNotIn('PRIVATE', raw)
            with self.assertRaises(ValueError):
                execute_run([sys.executable, '-c', 'pass'], path)

    def test_wrong_short_run_window_is_rejected(self):
        with self.assertRaises(ValueError):
            summarize([event('runStarted', 'run', 0)] + pair('a', 1, 5), {'durationSeconds': 2})


if __name__ == '__main__':
    unittest.main()
