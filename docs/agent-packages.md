# Agent-related packages: reference

Detail for the `pi/`, `agents/`, `claude/`, and `opencode/` packages. The
operative rules live in `AGENTS.md`; read this file when you change one of
these packages, bootstrap a machine, or need to know why something is laid
out the way it is. Moved out of `AGENTS.md` on 2026-10-11 so the per-session
prompt only carries the rules.

## `pi/`

Pi coding agent config. `~/.pi/agent/` is a real directory with
per-file stow symlinks into `pi/.pi/agent/`, so tracked files *are* the repo
working tree while untracked machine state (`sessions/`, `auth.json`,
`models-store.json`, …) coexists alongside them. Tracks: `AGENTS.md`, `settings.base.json`, `hosts/*.json`, `setup-pi.sh`,
`models.json`, `keybindings.json`, `prompts/`, `themes/`. **Does NOT track**
`auth.json`, `git/`, `sessions/`, `models-store.json`, `skills/`, or the generated
`settings.json` (auto-generated / machine-local).

`models.json` registers custom models (or models newer than Pi's built-in registry)
for the configured providers. It merges into the built-in providers — most useful
for adding bleeding-edge gateway models that Pi's bundled registry doesn't know
about yet. It is shared across all hosts: `modelOverrides` are inert unless a
model is actually used, so host-restricted models (e.g. Kimi K3, Grok 4.7) can
carry routing/cost overrides everywhere without affecting hosts that lack access.

**Per-host `settings.json` (generated, not tracked).** Pi has only two settings
layers (global + per-project) with no env interpolation or includes, so
per-machine differences can't live inside the tracked file. `enabledModels` (the
`/model` picker + Ctrl+P cycle set) must differ per host because each machine's
Vercel AI Gateway key has different model access — Chaos (unrestricted) enables
Kimi K3 + Grok 4.7; Phyrexia (Vercel Team key) does not. `setup-pi.sh` switches
on `hostname` (mirroring `hypr/scripts/host.sh`), merges `settings.base.json`
with `hosts/enabledModels.<host>.json` via `jq`, and writes
`~/.pi/agent/settings.json` directly (the live file is a real file, not a
stow symlink -- Pi's atomic writes replace symlinks). It preserves the
Pi-managed `lastChangelogVersion` key and warns if live package pins drifted
from the base (base wins; sync base first if live is newer after `pi update`). An
unknown host falls back to `hosts/enabledModels.default.json` (the restricted
set). Add a host by dropping in a new `hosts/enabledModels.<host>.json` fragment.
An optional `hosts/packages.<host>.json` appends per-host package extras to the
shared pins: local dev checkouts loaded as pi packages (e.g. `"../../dev/sigil"`,
relative to `~/.pi/agent`, so it only resolves where the clone exists). Without
it, a dev path added to the live file is dropped on the next `setup-pi.sh` run.

**pi-prose** (`~/dev/pi-prose`, published as `pi-prose` on npm, installed via
the `packages` array) follows the same dev pattern as the bonfire adapter: the
installed package runs the pinned release, not the local working copy. Footgun:
the package and a local copy cannot load simultaneously -- both register the
`--style` flag, and flag collisions fail the extension load. To test in-flight
changes, use `pi -ne -e ~/dev/pi-prose/extensions/pi-prose.ts` (isolated, no
hot reload), or for longer dev bursts remove the package entry from
`settings.base.json` + rerun `setup-pi.sh`, then symlink
`~/.pi/agent/extensions/pi-prose-dev.ts` -> `~/dev/pi-prose/extensions/pi-prose.ts`
(gitignored) for `/reload` support. Restore the package entry when done.

**pi-redact** (`~/dev/pi-redact`, npm `@vieko/pi-redact`, pinned via
`packages`) keeps secrets out of session transcripts: placeholders in, real
values back only for local tools. It logs each first sighting as a
`pi-redact` custom entry (counts and channel, no value).
`scripts/scrub-sessions.ts` in that repo rewrites vendor-shaped keys out of
old sessions. Same dev footgun as pi-prose: the pinned package and a local
path both register `/redact`, so load only one.

**Footer status convention.** Every extension that calls
`ctx.ui.setStatus` uses one shape so the footer line reads as one list.
Pi sorts items by status key and joins them with one space, so each item
is one token with no spaces inside:

- `name:value`, with a six-letter lowercase name (`styles`, `redact`,
  `remind`, `canvas`, `follow`) so the line reads evenly; pick words that
  read without knowing the extension. Bonfire keeps its `△ <value>`
  identity.
- `dim` at rest. `warning` only when the user must act, with `!` after the
  value (`remind:1!`, `canvas:gtm!`, `follow:#3146!`, bonfire `△ init!`);
  put the detail in a one-time notify, not the footer. Use semantic theme
  colors only; literal names throw on themes that lack them.
- Clear the status (`undefined`) when there is nothing to say.
- Keep cost and other telemetry out of the footer. Record it in a custom
  entry (`pi.appendEntry`) and report it in `session-audit` (counsel,
  `sigil-map-run`).

| Item | Source | Value |
|---|---|---|
| `△` | bonfire | breadcrumb age; `init!`, `fences!`, `7d!` stale in-flight, `compact?` nudge |
| `styles:` | pi-prose | active output style |
| `redact:` | pi-redact | distinct values kept out of the transcript |
| `remind:` | `extensions/reminders.ts` | pending reminders; `N!` when one fired and is open |
| `canvas:` | sigil map observer | map name; `!` when a run failed |
| `follow:` | `extensions/waits.ts` | detached gtm `pr-wait`/`deploy-wait --notify` runs (`#N`, `deploy#N`, `deploy@main`, or a count); `!` when one exited without a delivered message (`/waits` shows its log) |

Example: `△ today styles:ste redact:1 remind:2 canvas:gtm waiter:#3146`.
`tmux-status.ts` writes tmux, not the footer.

Run `pi/.pi/agent/setup-pi.sh` once after stowing on a fresh machine, and again
whenever `settings.base.json` or a host fragment changes. Because the generated
`settings.json` is gitignored, the old `lastChangelogVersion` churn is gone —
Pi writes into a file git no longer tracks.

## `agents/`

cross-agent shared skills. Stows to `~/.agents/`. Single source
of truth for skills that any agent (Pi, Claude, Codex) should see.

Some skills are symlinks to dev repos:
- `~/.agents/skills/bonfire` → `~/dev/bonfire/skills/bonfire`
- `~/.agents/skills/anvil` → `~/dev/anvil/packages/cli/skills/anvil`

These point into machine-local `~/dev` clones, so their absolute target differs
per OS (`/Users/...` on macOS, `/home/...` on Linux) — a single committed symlink
can't be right for both. They are **gitignored and regenerated per machine**: on a
fresh machine, clone the dev repos (`~/dev/bonfire`, `~/dev/anvil`), then run
`agents/.agents/setup-skill-symlinks.sh` after stowing `agents/`. Other skills are
self-contained directories.

(Lineage notes for retired names — forge, old bonfire commands — live in
`docs/agent-maintenance.md`.)

## Bonfire adapter installation

The Pi adapter is tracked as a `pi install` package entry in
`pi/.pi/agent/settings.json` (`packages: ["git:github.com/vieko/bonfire@vX.Y.Z"]`).
On a fresh machine, run `pi update` after stowing to materialize it. Pi
clones to `~/.pi/agent/git/github.com/vieko/bonfire/` and the root
`package.json` manifest points at `./pi/extension.ts`.

The Claude Code adapter is wired via a `Stop` hook entry in
`claude/.claude/settings.json` pointing to
`$HOME/dev/bonfire/claude/update-bonfire.mjs`. This requires
`~/dev/bonfire/` cloned (see the deploy checklist); the `$HOME`-relative path
is portable across macOS and Linux, so no per-OS editing is needed.

## Skill layout convention

- **Tracked skills** live as real directories under `agents/.agents/skills/<name>/`
  in this repo. They ship via stow with the rest of the dotfiles. Use this for
  stable, machine-agnostic skills that don't change often.
- **Symlinked skills** live at `~/dev/<name>/skills/<name>/` and are symlinked
  in from `agents/.agents/skills/<name>`. Use this for skills under active
  development that benefit from their own git history, releases, and PRs. These
  symlinks are gitignored and regenerated per machine via
  `agents/.agents/setup-skill-symlinks.sh` (absolute `~/dev` targets differ by OS).

Both resolve to the same path at runtime (`~/.agents/skills/<name>`). The
choice is purely about where the source of truth lives. Migrate a skill
between modes by replacing the dotfiles entry with the opposite kind
(symlink → directory or vice versa) and re-stowing `agents/`.

## Spinner verb dictionary (shared across agents)

The occult/metallurgical agent-spinner verbs are centralized in one
canonical file: `agents/.agents/verbs.json` (structured by section).
Two consumers read it:

- **Pi** — `pi/.pi/agent/extensions/spinner-verbs.ts` reads
  `~/.agents/verbs.json` at runtime. Always current; nothing to regenerate.
- **Claude Code** — `claude/.claude/settings.json` `spinnerVerbs.verbs`
  (flat array, lives in dotfiles, synced).

Claude's synced copy is regenerated from the canonical JSON by
`agents/.agents/scripts/sync-verbs.mjs`. Both the canonical file and the synced
copy now live in this repo, but there is intentionally **no** commit hook
enforcing sync — it's a manual discipline:

```bash
# 1. edit the canonical dictionary
$EDITOR agents/.agents/verbs.json

# 2. regenerate the synced copy
node agents/.agents/scripts/sync-verbs.mjs

# 3. (optional) confirm no drift remains
node agents/.agents/scripts/sync-verbs.mjs --check   # exit 1 on drift

# 4. commit dotfiles: verbs.json + claude/settings.json together
```

## `claude/`

Claude Code config. Stows to `~/.claude/`. Tracks `settings.json`,
`statusline.sh`, and `output-styles/` (matter-of-fact and ste, ported from
[pi-prose](https://github.com/vieko/pi-prose)) — matches the same "config not
state" philosophy as `pi/`. Keep the style bodies in sync with pi-prose's
built-ins by hand when they change; pi-prose is the source of truth.

## `opencode/`

OpenCode V2 config. Stows to `~/.config/opencode/`. Tracks
`opencode.jsonc` (server config: model, agents, permissions, policies) and
`cli.json` (TUI theme/keybinds; V2 collapsed the old layered `tui.json` into
this one global file). Models route through Vercel AI Gateway via the catalog
provider `vercel`, which activates from `AI_GATEWAY_API_KEY` in the background
server's environment -- no key is stored in OpenCode. Because every client
attaches to one shared server, that server must have been started from a login
shell where the key is hydrated; if `opencode auth list` does not show
`Vercel AI Gateway ... environment`, run `opencode service restart` from such a
shell. An `experimental.policies` block denies every provider except `vercel` so
stray stored accounts (e.g. the legacy Anthropic key in the SQLite db) stay out
of `/models`. `AGENTS.md` is a relative symlink to `pi/.pi/agent/AGENTS.md`
(one global instruction set for both agents; relative, so it is committed and
works on both OSes). Not tracked: `service.json`, `package.json`/`node_modules`
(plugin deps), and `skills/` (machine-local; `~/.agents/skills` is
auto-discovered anyway). Skills, `AGENTS.md`, and `.opencode/` project dirs
follow the same conventions as Pi; OpenCode reads `~/.agents/skills` and
`~/.claude/skills` natively.

Status (2026-09-26): OpenCode is a **bounded trial**, not a Summoner runtime.
Use it for fresh-start, single-sitting work (cross-family second reads,
one-shot reviews, `opencode run` in scripts, harness A/Bs against Pi); Pi
remains the Summoner and constructs stay Pi/Anvil. Known gaps, investigated
and deliberately not built yet: no Bonfire adapter (nothing native writes
portable project memory; run `/skill:bonfire end` before closing a session in
an opted-in repo), no pi-post bridge (the server has per-session inboxes with
steer/queue delivery, but no addresses, registry, offline queue, or path to
Pi/anvil senders, so `summon-golem.sh` refuses to dispatch from an OpenCode
pane without `-R`), and no pi-prose (agent `system` replaces the base prompt
rather than appending, so the native half-measure is not worth configuring).
All three are buildable on the V2 plugin API (`@opencode/plugin`: `context` /
`compaction` hooks, `session.prompt` steer, `command.transform`). Build
trigger: OpenCode earns a standing weekly role. Build order if so: pi-post
bridge, then Bonfire adapter; skip pi-prose. If the trial shows nothing Pi
lacks, keep this package as maintained config and stop.

