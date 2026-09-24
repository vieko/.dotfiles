---
name: linear-cli
description: Manage Linear issues from the command line using the linear cli. This skill allows automating linear management.
allowed-tools: Bash(linear:*), Bash(curl:*)
---

# Linear CLI (linearis)

The installed `linear` command is **linearis** (https://github.com/czabaj/linearis
lineage; `linear --version` prints a calver like `2026.6.0`), a JSON-output CLI
for Linear.app. It is NOT schpet's `linear-cli`, which this skill previously
documented — command syntax differs (`issues create` vs `issue create`, no
`--description-file`, no `api`/`schema` subcommands).

## Prerequisites & auth

```bash
linear --version        # linearis calver, e.g. 2026.6.0
linear auth status      # authenticated? which source?
```

Token resolution order: `--api-token <token>` flag, `LINEAR_API_TOKEN` env var,
`~/.linearis/token` file (via `linear auth login`).

**On this machine**: 1Password injects `LINEAR_API_KEY` (see
`~/.dotfiles/bash/env.op`), and `~/.dotfiles/bash/.bash_exports` bridges it to
`LINEAR_API_TOKEN`. Interactive shells just work. If a non-interactive context
lacks the bridge, pass `--api-token "$LINEAR_API_KEY"` explicitly. Never write
the token to `~/.linearis/token` (plaintext; 1Password is the source of truth).

**Credential types.** `LINEAR_API_KEY` holds either a personal API key
(`lin_api_*`, the current setup) or an OAuth access token, which the API wants
as `Bearer lin_oauth_*`. The bridge adds the `Bearer ` prefix when the value
isn't a `lin_api_*` key, and linearis sends the header verbatim, so both work
without touching the CLI. The workspace is phasing out personal-key minting;
the OAuth path is `~/.scripts/linear-oauth` (`authorize` once, `refresh` when
expired, `status` to check), which stores tokens in 1Password. If linearis
starts returning 401s, the OAuth token has probably expired: run
`linear-oauth refresh` and reload the shell. Never run it from an agent turn
(it calls `op`, which prompts).

**Linear MCP is also available in Pi** (`~/.agents/mcp.json`, via pi-mcp-adapter,
OAuth through `/mcp-auth linear`). It is the workspace-sanctioned agent route
and works with no API key; reach it with `mcp({ search: "linear" })`. Prefer
linearis when the shell key works (JSON output, cheaper, documented here) and
fall back to MCP when it 401s or on a machine without the key.

The `scripts/linear/*.sh` helpers in the gtm repo use `LINEAR_API_KEY` directly
against GraphQL with the same verbatim header — they follow whatever the bridge
exports and need no change either.

## Output & identifiers

- All output is JSON. `--compact` for single-line; `--fields <dot-paths>` to
  trim (e.g. `--fields identifier,title,state.name`). **On `list` commands the
  paths must start with `nodes.`** (`--fields nodes.identifier,nodes.title`);
  without the prefix the output is an empty `{}`, not an error.
- Commands accept UUIDs or human-readable identifiers: issue `ABC-123`, team
  key (`GTMENG`), project/label/user names.
- **Do not name git branches from the `branchName` field.** Linear generates it
  from the account's full-name slug plus the full issue title (SCIM prevents
  changing the username), e.g. `viekofranetovic/gtmeng-2433-persist-botid-...`.
  Repo convention is the short form: `vieko/<issue-id>` (e.g. `vieko/gtmeng-878`).

## Command surface

Domains: `issues`, `labels`, `projects`, `cycles`, `milestones`, `documents`,
`files`, `attachments`, `teams`, `users`, `initiatives`, `auth`.

Discovery is built in — prefer it over guessing:

```bash
linear usage                  # overview of all domains
linear issues usage           # detailed per-domain usage (any domain)
linear issues create --help   # flags for a specific command
```

Key issue commands: `list`, `search <query>`, `read <issue>`, `create <title>`,
`update <issue>`, `archive`, `delete`, `relations add/list/remove`,
`discuss <issue>` (start comment thread), `activity`, `discussions`, `reply`,
`resolve`. The top-level `comments` domain is a deprecated facade — use the
`issues` discussion commands.

## Common workflows

```bash
# Find where existing work lives (project, state) before filing
linear issues read GTMENG-2162 --fields identifier,title,project.name,state.name

# Create an issue with a markdown body (no --description-file in linearis —
# write the markdown to a file, then command-substitute; see below)
linear issues create "Title here" \
  --team GTMENG --project Coach --status Triage \
  --description "$(cat /tmp/desc.md)" \
  --relates-to GTMENG-2362 \
  --fields identifier,title

# List my in-progress issues on a team
linear issues list --team GTMENG --assignee vieko.franetovic@vercel.com --status "In Progress" \
  --fields nodes.identifier,nodes.title,nodes.state.name

# Full-text search
linear issues search "account association" --team GTMENG --limit 10

# Comment on an issue
linear issues discuss GTMENG-2362 --body "$(cat /tmp/comment.md)"

# Update state / assignee
linear issues update GTMENG-2362 --status "In Progress" --assignee vieko.franetovic@vercel.com
```

## Markdown content

linearis has **no file-based flags** (`--description-file` / `--body-file` do
not exist). For multi-line markdown, write to a temp file and pass
`--description "$(cat /tmp/desc.md)"` / `--body "$(cat /tmp/comment.md)"`.
This preserves newlines and avoids shell-escaping issues; the file content is
data, not re-evaluated by the shell. Avoid heredocs inline in the command —
they mangle easily in agent harnesses.

## Raw GraphQL fallback

linearis has **no `api`/`schema` subcommands**. For queries the CLI doesn't
cover, hit the API directly:

```bash
curl -s -X POST https://api.linear.app/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: $LINEAR_API_TOKEN" \
  -d '{"query": "{ viewer { id name } }"}'
```

For queries with variables, build the JSON body with `jq -n` to avoid escaping
pitfalls:

```bash
jq -n --arg term "onboarding" '{query: "query($term: String!) { searchIssues(term: $term, first: 10) { nodes { identifier title } } }", variables: {term: $term}}' \
  | curl -s -X POST https://api.linear.app/graphql \
      -H "Content-Type: application/json" \
      -H "Authorization: $LINEAR_API_TOKEN" \
      -d @-
```

## Known quirks (local additions — keep when regenerating)

- **Any single argument of ~1000+ bytes gets the process SIGKILLed on PHYREXIA**
  (`Killed: 9`, exit 137, within 50 ms, before any network call; `--help` dies
  too). Not linearis-specific: `node <script.js> <arg >= ~1023 bytes>` is
  killed at exec while `node -e`, python, and curl are untouched, which points
  at an EDR exec rule (SentinelOne is installed). Symptom in practice: a long
  `--description "$(cat file.md)"` / `--body "$(cat file.md)"` produces no
  output and nothing is created or updated. Workaround: keep CLI text under
  ~900 bytes, or send long markdown via the raw GraphQL fallback with
  `jq --rawfile` (curl carries the body, not argv):

  ```bash
  jq -n --arg id GTMENG-1234 --rawfile desc /tmp/desc.md \
    '{query: "mutation($id: String!, $desc: String!) { issueUpdate(id: $id, input: { description: $desc }) { success } }", variables: {id: $id, desc: $desc}}' \
    | curl -s -X POST https://api.linear.app/graphql -H "Content-Type: application/json" -H "Authorization: $LINEAR_API_TOKEN" -d @-
  ```

  `issueCreate(input: { teamId, title, description, assigneeId, parentId, stateId })`
  and `commentCreate(input: { issueId, body })` take the same shape; `id` on
  `issueUpdate` accepts the identifier. Verify with `linear issues read <id>
  --fields description`.

- **`--assignee` resolves by exact `displayName`, then email, then UUID.**
  `vieko`, `me`, and the full name `"Vieko Franetovic"` all return `User
  "..." not found` (linearis 2026.6.0) because none is the displayName.
  Email is the reliable human-readable form; the UUID also works:

  ```bash
  linear issues update GTMENG-1234 --assignee vieko.franetovic@vercel.com
  # or: --assignee ed9c0bc0-0e38-44a6-a020-59d2fd7ac474  (Vieko's UUID)
  ```

  There is no `linear users me`; the `users` domain takes no positional arg.
  `--project` accepts the project UUID reliably; names may work but the UUID
  is the safe path.
- **`linear projects list` fails with `Query too complex`** in this workspace
  even with `--fields name` (too many projects; no `--team` filter). Find a
  project via GraphQL instead:

  ```bash
  jq -n '{query: "{ projects(filter: { name: { containsIgnoreCase: \"index\" } }, first: 10) { nodes { id name state teams { nodes { key } } } } }"}' \
    | curl -s -X POST https://api.linear.app/graphql -H "Content-Type: application/json" -H "Authorization: $LINEAR_API_TOKEN" -d @- | jq -c '.data.projects.nodes[]'
  # GTMENG "Index" project: 7f53b968-16db-4a15-aa8f-27fae00dc5d5
  ```

- **Only one `linear` binary should be on PATH.** schpet's `linear-cli` was
  installed via Homebrew alongside linearis until 2026-07 (shadowed, but
  `which -a linear` showed both). It is not in any Brewfile, so it will not
  come back; if `which -a linear` ever lists `/opt/homebrew/bin/linear` again,
  `brew uninstall --formula linear`.
- **Auth misses look like "No API token found"** even when `LINEAR_API_KEY` is
  set — linearis only reads `LINEAR_API_TOKEN`. The dotfiles bridge fixes
  interactive shells; pass `--api-token "$LINEAR_API_KEY"` elsewhere.
- **`--fields` with a path into a nullable object** (e.g. `project.name` on an
  issue with no project) can produce output `jq` chokes on if you assume shape —
  handle nulls in your jq filter.
- **Verify writes with a fresh read** (`linear issues read <id>`) when a
  mutation matters — cheap insurance, and read-replica lag of a few seconds has
  been observed on the API.

## Writing Style: Comments vs Descriptions (local additions)

The *description* is the canonical spec — put durable scope/design there.
*Comments* are the decision trail (decisions, deltas, answers), not a place for
analysis that really belongs in the description. Lead with the decision (BLUF:
first line = takeaway / next action). Right-size to stakes: an ack is one line;
a real fork (architecture, scope split) is verdict + 2–3 bullets + links — never
an essay. Keep only the 1–2 non-obvious facts a future reader (human or agent)
can't quickly re-derive, and cite files/IDs (`webhook/route.ts:565`,
`GTMENG-1768`) over re-explaining. Long comments get skimmed past or truncated
and cost agents context to re-ingest.
