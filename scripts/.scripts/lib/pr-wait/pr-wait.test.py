#!/usr/bin/env python3
"""Hermetic host-waiter contracts. Run: python3 scripts/.scripts/lib/pr-wait/pr-wait.test.py"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "pr-wait.sh"

FAKE_GH = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ['FAKE_ROOT'])
scenario = json.loads((root / 'scenario.json').read_text())
args = sys.argv[1:]
with (root / 'calls').open('a') as f: f.write(json.dumps(args) + '\n')
if args[:2] == ['pr', 'view']:
    print(json.dumps({'number': 42, 'url': 'https://github.com/owner/repo/pull/42'}))
elif args[:2] == ['api', 'graphql']:
    count = root / 'count'
    n = int(count.read_text()) if count.exists() else 0
    count.write_text(str(n + 1))
    poll = scenario['polls'][min(n, len(scenario['polls']) - 1)]
    if poll.get('error'):
        print('API unavailable', file=sys.stderr); sys.exit(1)
    checks = poll.get('checks', [{'name':'test','status':'COMPLETED','conclusion':'SUCCESS','isRequired':False}])
    for c in checks: c.setdefault('__typename', 'CheckRun')
    pr = dict(number=42,title='Test PR',url='https://github.com/owner/repo/pull/42',
        state=poll.get('state','OPEN'),isDraft=False,mergedAt=None,additions=1,deletions=0,
        mergeStateStatus=poll.get('merge','CLEAN'),reviewDecision=poll.get('review'),
        headRefOid=poll.get('head','head1'),headRefName='feature',baseRefName=poll.get('baseRef','main'),
        baseRef={'target':{'oid':poll.get('base','base1')}},mergeCommit=None,autoMergeRequest=None,
        commits={'nodes':[{'commit':{'statusCheckRollup':{'contexts':{'nodes':checks}}}}]},
        reviews={'nodes':[]},reviewThreads={'nodes':[]})
    print(json.dumps({'data':{'repository':{'pullRequest':pr}}}))
elif args[0] == 'api' and any('/pulls/42/files' in a for a in args):
    print(json.dumps(scenario.get('prPages', [[{'filename':'shared.py'}]])))
elif args[0] == 'api' and any('/compare/' in a for a in args):
    failures = root / 'compare_failures'
    n = int(failures.read_text()) if failures.exists() else 0
    if n < scenario.get('compareErrors', 0):
        failures.write_text(str(n + 1))
        print('compare API unavailable', file=sys.stderr); sys.exit(1)
    print(json.dumps(scenario.get('comparePages', [{'files':[{'filename':'shared.py'}]}])))
elif args[0] == 'api' and any('/commits/' in a for a in args):
    print(json.dumps(scenario.get('commitPages', [{'files':[{'filename':'shared.py'}]}])))
else:
    print('unexpected gh invocation: ' + repr(args), file=sys.stderr); sys.exit(9)
'''
FAKE_POST = '''#!/usr/bin/env python3
import os, sys
from pathlib import Path
root = Path(os.environ['FAKE_ROOT'])
with (root / 'messages').open('a') as f: f.write(sys.stdin.read())
sys.exit(int(os.environ.get('FAKE_POST_RC', '0')))
'''


class WaiterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="host-pr-wait-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "bin").mkdir()
        (self.root / "tmp").mkdir()
        for name, body in (("gh", FAKE_GH), ("pi-post", FAKE_POST)):
            path = self.root / "bin" / name
            path.write_text(body)
            path.chmod(0o755)
        self.env = dict(os.environ, FAKE_ROOT=str(self.root), TMPDIR=str(self.root / "tmp"),
                        PATH=str(self.root / "bin") + os.pathsep + os.environ["PATH"],
                        PI_SESSION_ADDRESS="s-test", XDG_STATE_HOME=str(self.root / "state"))
        self.env.pop("CLAUDE_CODE_MESSAGING_SOCKET", None)
        self.env.pop("AGENT_WAIT_KIND", None)
        self.env.pop("AGENT_WAIT_TARGET", None)
        self.env.pop("AGENT_WAIT_LOG", None)

    def scenario(self, polls, **extra):
        (self.root / "scenario.json").write_text(json.dumps(dict(polls=polls, **extra)))

    def run_wait(self, *args, expected=0):
        proc = subprocess.run([str(SCRIPT), "42", "--interval", "1", "--timeout", "0", *args],
                              env=self.env, cwd=self.root, text=True, capture_output=True, timeout=15)
        self.assertEqual(proc.returncode, expected, proc.stdout + proc.stderr)
        return proc

    def test_default_checks_needs_no_review(self):
        self.scenario([{}])
        proc = self.run_wait()
        self.assertIn("#42: ok", proc.stdout)
        self.assertNotIn("bot", proc.stdout)

    def test_all_failures_gate_without_required_checks(self):
        self.scenario([{"checks":[dict(name="test", status="COMPLETED", conclusion="FAILURE", isRequired=False)]}])
        self.run_wait(expected=1)

    def test_optional_failure_does_not_gate(self):
        self.scenario([{"checks":[dict(name="gate", status="COMPLETED", conclusion="SUCCESS", isRequired=True),
                                  dict(name="advisory", status="COMPLETED", conclusion="FAILURE", isRequired=False)]}])
        self.assertIn("1 optional check(s) failing", self.run_wait().stdout)

    def test_pending_times_out(self):
        self.scenario([{"checks":[dict(name="test", status="IN_PROGRESS", isRequired=True)]}])
        self.run_wait(expected=2)

    def test_review_uses_github_decision(self):
        for review, expected in (("APPROVED", 0), ("CHANGES_REQUESTED", 1), (None, 2)):
            with self.subTest(review=review):
                self.scenario([{"review":review}])
                self.run_wait("--for", "review", expected=expected)

    def test_empty_checks_observe_grace(self):
        self.scenario([{"checks":[]}])
        self.run_wait(expected=2)
        self.run_wait("--grace", "0")

    def test_terminal_states(self):
        for state, condition, expected in (("MERGED", "review", 0), ("CLOSED", "checks", 0), ("CLOSED", "merged", 1)):
            with self.subTest(state=state, condition=condition):
                self.scenario([{"state":state}])
                self.run_wait("--for", condition, expected=expected)

    def test_bad_arguments_fail_before_detach(self):
        self.scenario([{}])
        for args in (("--interval", "0"), ("--timeout", "no"), ("--grace", "08"),
                     ("--for", ",checks"), ("--for", "checks,"), ("--for", "checks,,review"),
                     ("--for", "unknown"), ("--notify-to",)):
            with self.subTest(args=args):
                self.run_wait("--detach", *args, expected=3)
        self.assertFalse((self.root / "count").exists())

    def test_api_failure_reports_timeout(self):
        self.scenario([{"error":True}])
        self.assertIn("No PR snapshot", self.run_wait(expected=2).stdout)

    def test_then_exports_same_snapshot(self):
        self.scenario([{}])
        self.run_wait("--then", 'printf "%s" "$PR_JSON" > "$FAKE_ROOT/export.json"')
        data = json.loads((self.root / "export.json").read_text())
        self.assertEqual(data["number"], 42)
        self.assertEqual(data["host"], "github.com")

    def overlap_run(self, **extra):
        self.scenario([{'base':'old'}, {'base':'new','state':'MERGED'}], **extra)
        return self.run_wait('--for', 'merged', '--timeout', '10', '--notify', '--then',
                             'printf "%s" "$PR_JSON" > "$FAKE_ROOT/export.json"')

    def overlap_events(self):
        return json.loads((self.root / 'export.json').read_text())['baseOverlapEvents']

    def test_base_overlap_in_final_message(self):
        proc = self.overlap_run()
        self.assertEqual(self.overlap_events()[0]['paths'], ['shared.py'])
        message = (self.root / 'messages').read_text()
        self.assertIn('base overlap: main moved to new', message)
        self.assertEqual(message.count('pr-wait #42:'), 1)
        self.assertIn('[pr-wait] main moved to new', proc.stderr)

    def test_non_overlap_sends_no_event(self):
        self.overlap_run(comparePages=[{'files':[{'filename':'unrelated.py'}]}])
        self.assertEqual(self.overlap_events(), [])

    def test_renames_match_both_names(self):
        self.overlap_run(prPages=[[{'filename':'new.py','previous_filename':'old.py'}]],
                         comparePages=[{'files':[{'filename':'renamed.py','previous_filename':'old.py'}]}])
        self.assertEqual(self.overlap_events()[0]['paths'], ['old.py'])

    def test_paginated_files(self):
        self.overlap_run(prPages=[[{'filename':'unrelated.py'}], [{'filename':'last.py'}]],
                         comparePages=[{'files':[{'filename':'last.py'}]}, {'files':[]}])
        self.assertEqual(self.overlap_events()[0]['paths'], ['last.py'])
        calls = [json.loads(line) for line in (self.root / 'calls').read_text().splitlines()]
        self.assertTrue(all('--paginate' in call and '--slurp' in call
                            for call in calls if any('/files?' in arg or '/compare/' in arg for arg in call)))

    def test_large_base_compare_reads_commit_files(self):
        self.overlap_run(comparePages=[{'files':[{'filename':f'other-{n}'} for n in range(300)],
                                       'commits':[{'sha':'commit1'}]}])
        self.assertEqual(self.overlap_events()[0]['paths'], ['shared.py'])

    def test_base_api_error_retries_old_baseline(self):
        self.scenario([{'base':'old'}, {'base':'new'}, {'base':'new','state':'MERGED'}], compareErrors=1)
        proc = self.run_wait('--for', 'merged', '--timeout', '10', '--then',
                             'printf "%s" "$PR_JSON" > "$FAKE_ROOT/export.json"')
        self.assertIn('will retry without advancing', proc.stderr)
        self.assertEqual(self.overlap_events()[0]['oldBase'], 'old')
        calls = [json.loads(line) for line in (self.root / 'calls').read_text().splitlines()]
        compares = [call for call in calls if any('/compare/old...new' in arg for arg in call)]
        self.assertEqual(len(compares), 2)

    def test_base_ref_change_resets_baseline(self):
        self.scenario([{'base':'old'}, {'base':'new','baseRef':'release','state':'MERGED'}])
        self.run_wait('--for', 'merged', '--timeout', '10', '--then',
                      'printf "%s" "$PR_JSON" > "$FAKE_ROOT/export.json"')
        self.assertEqual(self.overlap_events(), [])

    def test_same_base_is_compared_once(self):
        self.scenario([{'base':'old'}, {'base':'new'}, {'base':'new','state':'MERGED'}])
        self.run_wait('--for', 'merged', '--timeout', '10', '--then',
                      'printf "%s" "$PR_JSON" > "$FAKE_ROOT/export.json"')
        self.assertEqual(len(self.overlap_events()), 1)

    def test_notify_delivers_final_status(self):
        self.scenario([{}])
        self.run_wait("--notify")
        self.assertIn("#42: ok", (self.root / "messages").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
