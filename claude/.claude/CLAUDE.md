# Global Memory

Loaded by Claude Code and any Agent SDK invocation that uses the
`claude_code` preset (including `forge run` via `@anthropic-ai/claude-agent-sdk`).
Project-level `CLAUDE.md` / `AGENTS.md` files extend or override these
rules.

## Destructive command guard

Never invoke commands that overwrite or destroy local/remote state
without explicit user instruction in the active turn.

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

## JSON Parsing

**Don't use Python one-liners to parse JSON.** Use `jq` instead — it's
more reliable and doesn't introduce a Python dependency.

Good: `jq -r '.entries | map(select(.gitBranch == "main")) | sort_by(.modified) | reverse | .[:5][] | ...'`
Bad: `cat file.json | python3 -c "import json, sys; ..."`

Also avoid `jq` date math (`fromdateiso8601`) — it fails on ISO 8601
timestamps with milliseconds. Stick to string comparison for dates
(lexicographic sort works for ISO 8601).

## PHYREXIA session lexicon (this machine)

Personal multi-agent naming for this host -- **not a team convention**. A
**Summoner** (the directing session, Pi or Claude Code) scopes work and
delegates to **Familiars** (same-runtime workers) and **Golems** (Anvil runs). Use this vocabulary when coordinating
multi-session work. Source of truth (topology + full role defs):
`~/.dotfiles/PHYREXIA.md` -- read it before summoning.
