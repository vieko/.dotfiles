#!/usr/bin/env python3
"""Vercel Security Review lookup contracts. Run: python3 scripts/.scripts/lib/pr-wait/vercel-security.test.py"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
LIB = HERE / "vercel-security.sh"
STATUS = HERE / "pr-status.sh"

FAKE_VC = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ['FAKE_ROOT'])
with (root / 'vc-calls').open('a') as f: f.write(json.dumps(sys.argv[1:]) + '\n')
if os.environ.get('FAKE_VC_RC'): sys.exit(int(os.environ['FAKE_VC_RC']))
print((root / 'vc-out.json').read_text())
'''

def finding(n, severity, sha):
    return {"findingId": f"ID{n}", "number": n, "severity": severity,
            "title": f"finding {n}", "status": "open",
            "foundIn": {"repository": "vercel/gtm", "commitSha": sha}}


class VercelSecurityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="vercel-security-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "bin").mkdir()
        vc = self.root / "bin" / "vc"
        vc.write_text(FAKE_VC)
        vc.chmod(0o755)
        self.env = dict(os.environ, FAKE_ROOT=str(self.root),
                        PATH=str(self.root / "bin") + os.pathsep + os.environ["PATH"])
        self.env.pop("PR_WAIT_VERCEL_SCOPE", None)

    def lookup(self, repo="vercel/gtm", branch="feature", head="head1", **env):
        proc = subprocess.run(
            ["bash", "-c", f'. "{LIB}"; vercelSecurityJson "$@"', "_", repo, branch, head],
            env=dict(self.env, **env), text=True, capture_output=True, timeout=15)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return json.loads(proc.stdout)

    def vc_calls(self):
        path = self.root / "vc-calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_non_vercel_repo_is_not_looked_up(self):
        self.assertEqual(self.lookup(repo="owner/repo")["available"], False)
        self.assertEqual(self.vc_calls(), [])

    def test_other_vercel_repos_read_the_vercel_team(self):
        (self.root / "vc-out.json").write_text(json.dumps({"vulnerabilities": []}))
        self.lookup(repo="vercel/other")
        self.assertEqual([c[c.index("--scope") + 1] for c in self.vc_calls()], ["vercel"])

    def test_reads_open_findings_most_severe_first_and_marks_the_head(self):
        (self.root / "vc-out.json").write_text(json.dumps({"vulnerabilities": [
            finding(1, "low", "head1"), finding(2, "high", "old"), finding(3, "critical", "head1")]}))
        out = self.lookup()
        self.assertTrue(out["available"])
        self.assertEqual([f["number"] for f in out["findings"]], [3, 2, 1])
        self.assertEqual([f["onHead"] for f in out["findings"]], [True, False, True])
        calls = self.vc_calls()
        call = calls[0]
        self.assertEqual(call[:3], ["security", "vulnerabilities", "list"])
        self.assertEqual([c[c.index("--scope") + 1] for c in calls], ["vercel-internal-apps", "vercel"])
        self.assertEqual(len(out["findings"]), 3)  # same finding in both teams is listed once
        self.assertEqual(call[call.index("--git-branch") + 1], "feature")
        self.assertEqual(call[call.index("--status") + 1], "open")
        self.assertNotIn("dismiss", json.dumps(self.vc_calls()))

    def test_scope_override(self):
        (self.root / "vc-out.json").write_text(json.dumps({"vulnerabilities": []}))
        self.lookup(repo="vercel/other", PR_WAIT_VERCEL_SCOPE="team-x")
        self.assertIn("team-x", self.vc_calls()[0])

    def test_cli_failure_degrades(self):
        out = self.lookup(FAKE_VC_RC="1")
        self.assertFalse(out["available"])
        self.assertIn("vc lookup failed", out["reason"])

    def test_missing_cli_degrades(self):
        (self.root / "bin" / "vc").unlink()
        out = self.lookup(PATH="/usr/bin:/bin:" + str(Path(subprocess.check_output(["bash", "-c", "command -v jq"], text=True).strip()).parent))
        self.assertEqual(out, {"available": False, "reason": "vc not installed"})

    def test_status_renders_at_most_five_findings(self):
        findings = [{"id": f"ID{n}", "number": n, "severity": "medium", "title": f"t{n}",
                     "foundIn": "head1" if n % 2 else "old", "onHead": bool(n % 2)} for n in range(7)]
        snapshot = {"number": 42, "title": "T", "url": "u", "state": "OPEN", "isDraft": False,
                    "additions": 1, "deletions": 0, "headRef": "f", "baseRef": "main", "head": "head1",
                    "mergeStateStatus": "UNSTABLE", "reviewDecision": None,
                    "checks": {"summary": "fail", "pass": 1, "fail": 1, "pending": 0, "skip": 0,
                               "failing": [{"name": "Vercel Security Review", "required": False, "url": "x"}],
                               "pendingNames": []},
                    "threads": {"unresolved": 0, "items": []},
                    "vercelSecurity": {"available": True, "scope": "s", "findings": findings}}
        proc = subprocess.run([str(STATUS), "--from-json"], input=json.dumps(snapshot),
                              env=self.env, text=True, capture_output=True, timeout=15)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        lines = [l for l in proc.stdout.splitlines() if l.startswith("    ")]
        self.assertEqual(len(lines), 6)
        self.assertIn("+2 more", lines[-1])
        self.assertIn("found in head1, head", proc.stdout)
        self.assertIn("older than the head: open until a rescan closes it", proc.stdout)
        self.assertEqual(self.vc_calls(), [])

    def test_status_reports_an_unavailable_lookup(self):
        snapshot = {"number": 42, "title": "T", "url": "u", "state": "OPEN", "isDraft": False,
                    "additions": 1, "deletions": 0, "headRef": "f", "baseRef": "main", "head": "h",
                    "mergeStateStatus": "UNSTABLE", "reviewDecision": None,
                    "checks": {"summary": "fail", "pass": 0, "fail": 1, "pending": 0, "skip": 0,
                               "failing": [], "pendingNames": []},
                    "threads": {"unresolved": 0, "items": []},
                    "vercelSecurity": {"available": False, "reason": "vc not installed"}}
        proc = subprocess.run([str(STATUS), "--from-json"], input=json.dumps(snapshot),
                              env=self.env, text=True, capture_output=True, timeout=15)
        self.assertIn("security findings unavailable: vc not installed", proc.stdout)

    def merge_dry_run(self, findings):
        gh = self.root / "bin" / "gh"
        gh.write_text("#!/usr/bin/env python3\nimport json\nprint(json.dumps({'state':'OPEN','mergeStateStatus':'CLEAN',"
                      "'headRefName':'feature','headRefOid':'head1','baseRefName':'main','isCrossRepository':False,"
                      "'url':'https://github.com/vercel/gtm/pull/42','mergeCommit':None}))\n")
        gh.chmod(0o755)
        (self.root / "vc-out.json").write_text(json.dumps({"vulnerabilities": findings}))
        repo = self.root / "repo"
        repo.mkdir()
        subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
        return subprocess.run([str(HERE.parents[1] / "pr-merge.sh"), "42", "--dry-run", "--keep-branch", "--no-linear"],
                              cwd=repo, env=self.env, text=True, capture_output=True, timeout=30)

    def test_merge_refuses_a_high_finding_from_an_older_commit(self):
        proc = self.merge_dry_run([finding(1, "high", "oldsha1234")])
        self.assertIn("[ERROR] #42 has open critical/high", proc.stdout)
        self.assertIn("found in oldsha1, older than the head", proc.stdout)

    def test_merge_only_warns_on_medium_low_and_unknown(self):
        proc = self.merge_dry_run([finding(1, "medium", "head1"), finding(2, "weird", "head1")])
        self.assertNotIn("[ERROR]", proc.stdout)
        self.assertIn("[WARN] open security finding: medium ID1", proc.stdout)
        self.assertIn("unknown severity weird", proc.stdout)
        self.assertIn("[DRY] would squash-merge", proc.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
