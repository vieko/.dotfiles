#!/usr/bin/env python3
"""Gather deterministic evidence for a monthly performance check-in."""

from __future__ import annotations

import argparse
import calendar
import json
import subprocess
import sys
from datetime import date, datetime, timezone
from pathlib import Path

VIEWER_QUERY = "{ viewer { id name email } }"
ISSUES_QUERY = """
query($filter: IssueFilter!) {
  issues(first: 250, filter: $filter) {
    nodes {
      identifier
      title
      completedAt
      project { name }
      creator { id name }
      assignee { id name }
    }
  }
}
"""
DEFAULT_CONFIG = Path.home() / ".config" / "monthly-checkin" / "config.json"
REQUIRED_CONFIG_KEYS = {
    "person_name",
    "repo",
    "window_start_day",
    "window_end_day",
    "due_day",
    "output_dir",
    "project_paths",
}


def run(args: list[str], *, cwd: Path | None = None, stdin: str | None = None) -> str:
    result = subprocess.run(
        args,
        cwd=cwd,
        input=stdin,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"{' '.join(args)} failed: {detail}")
    return result.stdout


def load_config(path: Path) -> dict:
    if not path.exists():
        raise ValueError(
            f"missing private config: {path}. "
            "Read references/private-profile-setup.md to create it."
        )
    config = json.loads(path.read_text())
    missing = sorted(REQUIRED_CONFIG_KEYS - config.keys())
    if missing:
        raise ValueError(f"private config is missing: {', '.join(missing)}")
    if not isinstance(config["project_paths"], list):
        raise ValueError("project_paths must be a JSON array")
    return config


def next_month(year: int, month: int) -> tuple[int, int]:
    return (year + 1, 1) if month == 12 else (year, month + 1)


def previous_month(year: int, month: int) -> tuple[int, int]:
    return (year - 1, 12) if month == 1 else (year, month - 1)


def month_bounds(value: str, config: dict) -> tuple[date, date, date, str]:
    try:
        year, month = (int(part) for part in value.split("-", 1))
        date(year, month, 1)
        start_day = int(config["window_start_day"])
        end_day = int(config["window_end_day"])
        due_day = int(config["due_day"])
    except (TypeError, ValueError):
        raise ValueError("month must use YYYY-MM and cadence days must be valid integers") from None

    previous_year, previous_number = previous_month(year, month)
    due_year, due_month = next_month(year, month)
    try:
        start = date(previous_year, previous_number, start_day)
        end = date(year, month, end_day)
        due = date(due_year, due_month, due_day)
    except ValueError as error:
        raise ValueError(f"invalid cadence in private config: {error}") from None

    return start, end, due, calendar.month_name[month]


def github_prs(repo: str, start: date, end: date) -> list[dict]:
    query = f"repo:{repo} is:pr author:@me is:merged merged:{start.isoformat()}..{end.isoformat()}"
    raw = run(
        [
            "gh",
            "api",
            "--paginate",
            "--slurp",
            "-X",
            "GET",
            "search/issues",
            "-f",
            f"q={query}",
            "-f",
            "per_page=100",
        ]
    )
    pages = json.loads(raw)
    return [item for page in pages for item in page.get("items", [])]


def completed_issues(start: date, end_exclusive: date) -> list[dict]:
    viewer = json.loads(run(["linear", "api", VIEWER_QUERY]))["data"]["viewer"]
    filter_value = {
        "or": [
            {"creator": {"id": {"eq": viewer["id"]}}},
            {"assignee": {"id": {"eq": viewer["id"]}}},
        ],
        "completedAt": {
            "gte": f"{start.isoformat()}T00:00:00.000Z",
            "lt": f"{end_exclusive.isoformat()}T00:00:00.000Z",
        },
    }
    raw = run(
        ["linear", "api", "--variables-json", json.dumps({"filter": filter_value})],
        stdin=ISSUES_QUERY,
    )
    return json.loads(raw)["data"]["issues"]["nodes"]


def git_log(repo: Path, start: date, end_exclusive: date, author: str | None = None) -> list[str]:
    args = [
        "git",
        "log",
        f"--since={start.isoformat()}",
        f"--until={end_exclusive.isoformat()}",
        "--date=short",
        "--format=%ad\t%an\t%ae\t%s",
    ]
    if author:
        args.append(f"--author={author}")
    return [line for line in run(args, cwd=repo).splitlines() if line.strip()]


def collaborator_log(
    repo: Path,
    start: date,
    end_exclusive: date,
    own_email: str,
    configured_paths: list[str],
) -> list[str]:
    existing_paths = [path for path in configured_paths if (repo / path).exists()]
    if not existing_paths:
        return []
    args = [
        "git",
        "log",
        f"--since={start.isoformat()}",
        f"--until={end_exclusive.isoformat()}",
        "--date=short",
        "--format=%ad\t%an\t%ae\t%s",
        "--",
        *existing_paths,
    ]
    lines = [line for line in run(args, cwd=repo).splitlines() if line.strip()]
    return [line for line in lines if own_email not in line]


def format_lines(lines: list[str]) -> str:
    return "\n".join(f"- {line}" for line in lines) if lines else "- None found"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("month", help="check-in month in YYYY-MM format")
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--repo", type=Path, help="override the private config repo")
    parser.add_argument("--output", type=Path, help="override the evidence output path")
    args = parser.parse_args()

    config_path = args.config.expanduser()
    try:
        config = load_config(config_path)
        start, end, due, month_name = month_bounds(args.month, config)
    except (ValueError, json.JSONDecodeError) as error:
        parser.error(str(error))

    end_exclusive = date.fromordinal(end.toordinal() + 1)
    repo = (args.repo or Path(config["repo"])).expanduser().resolve()
    if not (repo / ".git").exists():
        parser.error(f"not a git repository: {repo}")

    repo_name = run(
        ["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"],
        cwd=repo,
    ).strip()
    own_name = run(["git", "config", "user.name"], cwd=repo).strip()
    own_email = run(["git", "config", "user.email"], cwd=repo).strip()

    prs = github_prs(repo_name, start, end)
    issues = completed_issues(start, end_exclusive)
    own_commits = git_log(repo, start, end_exclusive, own_email or own_name)
    collaborator_commits = collaborator_log(
        repo,
        start,
        end_exclusive,
        own_email,
        config["project_paths"],
    )

    today = datetime.now(timezone.utc).date()
    period_status = f"open; evidence gathered through {today.isoformat()}" if today <= end else "closed"

    pr_lines = [
        f"{item['closed_at'][:10]} #{item['number']} {item['title']} ({item['html_url']})"
        for item in sorted(prs, key=lambda item: item["closed_at"])
    ]
    issue_lines = [
        "\t".join(
            [
                item["completedAt"][:10],
                item["identifier"],
                item["title"],
                (item.get("project") or {}).get("name") or "no project",
                (item.get("assignee") or {}).get("name") or "unassigned",
            ]
        )
        for item in sorted(issues, key=lambda item: item["completedAt"])
    ]

    project_memory = repo / ".bonfire" / "index.md"
    memory_note = (
        f"Read `{project_memory}` and extract only in-window rollout state, measurements, reversals, incidents, and collaboration context."
        if project_memory.exists()
        else "No project-memory index found; ask for rollout and production context."
    )

    person_name = config["person_name"]
    body = f"""# Evidence: {month_name} {end.year} monthly check-in

- Check-in month: `{args.month}`
- Evidence window: `{start.isoformat()}` through `{end.isoformat()}` inclusive
- Due: `{due.isoformat()}`
- Period status: {period_status}
- Repository: `{repo_name}`
- Git identity: `{own_name} <{own_email}>`
- Authored merged PR count: **{len(prs)}**
- Completed created-or-assigned issue count: **{len(issues)}**

## Authored merged PRs

{format_lines(pr_lines)}

## Completed issues

Columns: completed date, identifier, title, project, assignee.

{format_lines(issue_lines)}

## {person_name} commits

Columns: commit date, author, email, subject. Commit count is not a performance metric; use this for implementation detail and clustering.

{format_lines(own_commits)}

## Collaboration candidates

Other-authored commits touching configured project paths in the same window. These are candidates, not proof of collaboration. Inspect shared files, issue relationships, PR bodies, and reviews before naming anyone.

{format_lines(collaborator_commits)}

## Project-memory follow-up

{memory_note}

## Manual checks before drafting

- Inspect key PR bodies and commit bodies for the business reason and production proof.
- Inspect reviews on the few PRs central to the narrative; approval alone does not establish co-ownership.
- Group the evidence into two to four outcomes rather than recapping PRs.
- Report proposed collaborators and growth framings before applying them.
"""

    output_dir = Path(config["output_dir"]).expanduser()
    output = args.output or output_dir / "evidence" / f"{args.month}.md"
    output = output.expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(body)
    print(output)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, json.JSONDecodeError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        raise SystemExit(1)
