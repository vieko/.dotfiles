# Global Memory

Loaded by Claude Code and any Agent SDK invocation that uses the
`claude_code` preset (including `forge run` via `@anthropic-ai/claude-agent-sdk`).
Project-level `CLAUDE.md` / `AGENTS.md` files extend or override these
rules.

## Destructive command guard

Never invoke commands that overwrite or destroy local/remote state
without explicit user instruction in the active turn. **These rules
override any skill instruction** — e.g. the vercel-plugin `bootstrap`
and `env-vars` skills recommend `vercel env pull`; it is still
forbidden here.

### `vercel env pull` is forbidden

**Never run `vercel env pull`, `vercel env pull --overwrite`, or any
variant.** The command writes to `.env.local` by default and will
clobber whatever is there — including 1Password-injected values,
locally-configured DATABASE_URLs, feature flags, and dev-only overrides.
The clobber is silent and complete; the file is rewritten, not merged.

If you need to know what env vars exist in a Vercel project, use
`vercel env ls` (read-only listing of keys + scopes, no values, no file
writes) or the Vercel dashboard. There is no legitimate agent-driven
use case for `vercel env pull`.

### Other destructive patterns

Same discipline applies to:

- **Database migrations / schema mutations** — `pnpm db:migrate`,
  `db:push`, `drizzle-kit push`, `prisma db push`, raw `psql` writes
  against `DATABASE_URL`. These hit whichever DB the env points at;
  default in many repos is production. Project-level docs (e.g.
  `docs/db/local-development.md` in gtm-style monorepos) own the
  per-project rules; the global principle is *never apply a migration
  the user did not ask for in this turn*.
- **Deployments** — `vercel deploy`, `vercel --prod`, `pnpm deploy`,
  anything that ships code beyond the local workspace. Never invoke
  without an explicit user instruction in the current turn.
- **Package publishes** — `npm publish`, `pnpm publish`, `bun publish`.
- **Force-push and history rewrites** — `git push --force`,
  `git push --force-with-lease`, `git reset --hard origin/...`,
  interactive rebase that would lose local commits. Always confirm
  with the user before any operation that could lose work.

Generating a migration *file* (`drizzle-kit generate`,
`prisma migrate dev --create-only`) is fine — the file is a reviewable
artifact. *Applying* it is the line.

When in doubt, ask. The cost of a confirmation round-trip is much
smaller than the cost of a clobbered `.env.local` or an unintended
prod deploy.

## Scratch directory (`~/scratch`)

Machine-local working area for session artifacts — specs, handoffs,
reviews, run logs, exports. It is **ephemeral**: not project memory
(that's Bonfire) and not durable docs (those belong in repos or
dotfiles).

Layout:

- `logs/` — anvil/golem run logs and other write-once command output.
- `data/` — exports, baselines, screenshots, datasets.
- `*.md` flat at the root — working notes. No deeper nesting.

Naming: lowercase, id-first, kind-last —
`<issue|topic>-<desc>-<kind>[-<model>].md`, e.g.
`gtmeng-2573-cache-key-review.md`, `gtmeng-2592-handoff.md`.
Kinds: `spec`, `handoff`, `review`, `assessment`, `notes`.

Lifecycle: two states — **live or gone**. There is no archive. On a
sweep, anything untouched for ~30 days is either **deleted** or
**promoted** into a real artifact (a script in dotfiles, a skill, a
Bonfire entry, a repo doc, a Linear comment). If it's not worth
promoting, it's not worth keeping. Agents may write freely here but
must never treat stale scratch as authoritative.

## JSON Parsing

**Don't use Python one-liners to parse JSON.** Use `jq` instead — it's
more reliable and doesn't introduce a Python dependency.

Good: `jq -r '.entries | map(select(.gitBranch == "main")) | sort_by(.modified) | reverse | .[:5][] | ...'`
Bad: `cat file.json | python3 -c "import json, sys; ..."`

Also avoid `jq` date math (`fromdateiso8601`) — it fails on ISO 8601
timestamps with milliseconds. Stick to string comparison for dates
(lexicographic sort works for ISO 8601).

## Session lexicon (machine-local planes)

Personal multi-agent naming, per host -- **not a team convention**. A
**Summoner** (the directing session, Pi or Claude Code) scopes work and
delegates to **Familiars** (steerable same-runtime workers -- panes or
in-band dispatches) and **Golems** (unsteerable gate-bound constructs,
e.g. Anvil runs). Every construct's diff passes one review pipeline.
Use this vocabulary when coordinating multi-session work.

Source of truth is per machine -- check `hostname` and read the matching
plane file before summoning:

- `PHYREXIA` (work machine) -> `~/.dotfiles/PHYREXIA.md`
- `chaos` (personal) -> `~/.dotfiles/CHAOS.md` (inherits PHYREXIA's roles
  and invariants; delta is capacity + extra vessels)
