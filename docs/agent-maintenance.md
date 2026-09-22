# Agent Maintenance Notes

Rarely-needed procedures for the agent tooling on this machine. Referenced
from `~/.pi/agent/AGENTS.md`.

## Refreshing Pi's model catalog

Pi (0.80.8+) keeps a dynamic model catalog in `~/.pi/agent/models-store.json`
(machine-local, gitignored). `/model` refreshes it in the background, but if a
newly added gateway model isn't showing up, force an immediate refresh with:

```
pi update --models
```

No pi/extension update happens — catalog only.

Since 0.82.0, `/model` also reloads `models.json` when the picker opens, so
edits to custom model config (routing pins, cost overrides) take effect
without restarting Pi. Restart is only needed for `settings.json` changes
(e.g. `enabledModels` after re-running `setup-pi.sh`).

## Adding a Claude model to the gateway overrides (`models.json`)

Pi's `vercel-ai-gateway` catalog entries for Claude carry only
`allowEmptySignature` / `forceAdaptiveThinking`. The native `anthropic`
entries carry more, and because our overrides pin routing to
`only: ["anthropic"]` the transport is the real Messages API, so the native
flags hold. When a new Claude model lands, copy its native compat onto the
gateway override in `pi/.pi/agent/models.json`:

```bash
cd /Users/vieko/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist
node --input-type=module -e 'import * as m from "./models.generated.js"; console.log(JSON.stringify(m.MODELS.anthropic["claude-<id>"].compat))'
```

The override needs, as of pi 0.87:

- `promptCache: { short: 300, long: 3600 }` -- without it cache warming
  (`cacheWarming` in settings) is inert for the model ("cache lifetime
  unavailable" in `/session`).
- `compat.supportsStrictTools: true` -- strict tool sampling is the pi
  default since 0.86 but only goes out when the model advertises it
  (pi#9212 malformed-edit fix).
- `compat.supportsEagerToolInputStreaming: false` on **sonnet-5 only**,
  as an A/B started 2026-09-22. ~11% of sonnet edit calls arrive as
  `edits:[{}]` with output tokens proving the body was generated (transit
  truncation, not sampling; strict did not move it: 12.3% -> 10.7%). With
  this off, pi sends the `fine-grained-tool-streaming` beta instead of
  per-tool `eager_input_streaming`. Judge at the next session audit
  (sonnet-edits script); drop the override if the rate does not fall.
- `compat.supportsMidConvoSystemMessages` + `supportsMidConvoToolChanges`
  when the native entry has them -- turns prompt-section and tool-set changes
  (e.g. a pi-prose `/style` switch) into a small system patch instead of a
  full-prefix rewrite. Measured on fable-5.1: cacheWrite 14337 -> 50.
- `compat.supportsMidConvoEffort` when the native entry has it.
- `compat.vercelGatewayRouting: { only: ["anthropic"], order: ["anthropic"] }`
  -- enforced by `extensions/gateway-routing.ts` until pi#9211 lands.

Anvil keeps its own copy of this overlay in
`~/dev/anvil/packages/core/src/node/model-resolver.ts` (`withGatewayCompat`);
update both. Verify with a `-ne` probe that logs `ctx.model` on
`session_start` using `--provider vercel-ai-gateway --model <id>` (without
`--provider`, `anthropic/<id>` resolves the provider prefix, not the gateway).

## Updating pinned git packages in Pi (pi-post, bonfire)

Pi packages pinned via the `packages` array in `~/.pi/agent/settings.json`
(e.g. `git:github.com/vieko/pi-post@vX.Y.Z`) are cloned to
`~/.pi/agent/git/<host>/<path>`. Two gotchas when bumping the pin:

1. **Editing the pin in settings.json does NOT move the clone.** Pi's startup
   package resolution loads existing git clones as-checked-out and only
   reconciles a pinned ref via `pi update` / `pi install` — restarting Pi
   will silently keep running the old version. After changing (or to change)
   the pin, run:

   ```
   pi install git:github.com/vieko/pi-post@vX.Y.Z
   ```

   Idempotent: writes the settings pin, fetches + hard-resets the managed
   clone to the tag, and runs `npm install` in it. Verify with
   `git -C ~/.pi/agent/git/github.com/vieko/pi-post log --oneline -1`.

2. **Already-running sessions keep the old code.** Extensions load at session
   start; only sessions started after the reconcile get the new version.

Release procedure for pi-post itself (bump, tag, npm publish via OIDC) is in
the repo: `~/dev/pi-post/docs/releasing.md`. Same pin-bump rules apply to the
bonfire adapter (see `~/.pi/agent/AGENTS.md`).

## vercel-plugin skills path (`current` symlink)

`settings.base.json` points the vercel-plugin skills at a stable `current`
symlink, not a version directory:

```
~/.claude/plugins/cache/claude-plugins-official/vercel/current/skills
```

(The plugin's own dev skills under `current/.claude/skills` are intentionally
NOT loaded globally — their trigger words are too generic, e.g. `release`.
Re-add that path in a per-project `.pi/settings.json` when actively working
on vercel-plugin itself.)

`current` -> the installed version dir (e.g. `0.43.0`), so `settings.base.json`
never changes on a plugin bump. BUT the symlink lives inside the
plugin-managed cache: a plugin update creates a new version dir and removes
the old one, which leaves `current` dangling (or clobbers it). Symptom: the
skill set shrinks at startup with no error.

This now self-heals in two places (both act only when `current` is missing
or dangling):

- `bash/.bash_profile` — every login shell.
- `pi/.pi/agent/setup-pi.sh` — covers fresh-machine bootstrap.

Manual fix, if ever needed before a login shell runs:

```
cd ~/.claude/plugins/cache/claude-plugins-official/vercel
ln -sfn "$(ls -d [0-9]* | sort -V | tail -1)" current   # newest version dir
```

Caveat: `current` is NOT tracked in dotfiles (it lives in the runtime cache);
on a fresh machine it appears after the plugin installs + the next login
shell or `setup-pi.sh` run.

## Testing in-flight bonfire adapter changes

The Pi adapter runs the tagged release from GitHub (the `packages` pin in
settings), not your local `~/dev/bonfire` working copy. To test in-flight
changes, either bump and retag, or temporarily swap the entry for a local
path / restore a dev symlink under `~/.pi/agent/extensions/`. Same pin-bump
rules as pi-post (see above).

## Anvil runs from the working tree, not a global install

`~/.scripts/anvil` (dotfiles `scripts/.scripts/anvil`) execs
`node --conditions=anvil-source ~/dev/anvil/packages/cli/src/bin.ts`, so the
`anvil` every human and agent sees is whatever `~/dev/anvil` has checked out.
No build, no reinstall, no version skew. Consequences:

- **Never `npm i -g @vieko/anvil` on a machine with the checkout.**
  `~/.npm-global/bin` precedes `~/.scripts` in PATH, so a global install
  shadows the shim and pins the machine to a stale release. It happened
  2026-08-05 and again 2026-09-21 (both times as a workaround for anvil#39,
  which the `anvil-source` condition fixed). Check with `type -a anvil`: only
  `~/.scripts/anvil` should be listed. Undo with `npm rm -g @vieko/anvil`.
- **Cutting an anvil release does not touch this machine.** The tag exists
  for chaos-without-checkout, CI, and `npx`; after merging to `main`, the
  update here is `git -C ~/dev/anvil pull`.
- **Keep `~/dev/anvil` on `main`.** File-touching anvil work goes in
  `~/dev/anvil-worktrees/<branch>` like any other repo; a WIP branch checked
  out in `~/dev/anvil` is what every golem on the machine runs.
- pi-prose, pi-post, and bonfire are different: those load through pi's
  `packages` array as pinned release tags (`~/.dotfiles/AGENTS.md`, pi-prose
  section), so for them a release plus pin bump is the update path.

## Anvil worktree footguns (gtm)

Learned on GTMENG-3352 (2026-09-17). Both cost a wasted dispatch.

- **fnm's default Node must be a release build.** A fresh anvil worktree
  runs `pnpm install`, which rebuilds `better-sqlite3` from source against
  headers that nodejs.org does not publish for alphas (404, `ELIFECYCLE`,
  run dies before the agent starts). Resolved 2026-09 by setting
  `fnm default 24.21.0` and uninstalling the 26.x alpha. Two things keep it
  fixed: do not `fnm install` a pre-release, and remember that
  `FNM_RESOLVE_ENGINES=true` resolves gtm's `"node": ">=18"` to the
  *newest installed* version, so any alpha on disk wins inside the repo
  regardless of `fnm default`. If one is needed temporarily, pin a release
  Node into the golem's tree at dispatch instead:
  `summon-golem.sh -e "PATH=$HOME/.local/share/fnm/node-versions/v24.21.0/installation/bin:$PATH" ...`.
- **`agents/feedback` contracts must be hermetic per file.** Server modules
  there `import 'server-only'` (throws under vitest) and pull in clients that
  parse env at import (`@/lib/db`, `product-categories/cache`,
  `search/request-candidates`, `request-completion/flag`). A frozen contract
  that imports one of them needs `vi.mock('server-only', () => ({}))` plus
  stubs for those seams, the same way the sibling `*.test.ts` files do. If
  the contract does not stub them, the golem will "fix" it by editing
  `vitest.config.ts` (out of scope, run void) or by lazy-importing the
  clients in production code (in scope, wrong).
- **A sweep that may add a workspace dependency needs `--scope pnpm-lock.yaml`.**
  `pnpm add` in a package rewrites the root lockfile; without the scope
  entry the run voids on a change the spec required. Verify each target
  package's `package.json` for the dependency before writing "already
  depends on X" into a spec.
- **A lint-only gate does not prove a new import resolves.** eslint never
  resolves workspace packages; a file can import `@repo/shared` from a
  package that does not depend on it and lint green. `tsc` and the test
  runner both fail on it. When a sweep adds imports to a package, its gate
  needs `check-types` (or `test`) for that package, not just `lint`
  (#3776: `agents/revoa` shipped to CI missing the dep).

## History & lineage

Context for names that appear in old sessions, bonfire entries, or scratch
notes. None of this shapes current behavior.

- **bonfire 7.0 removed `/skill:bonfire start` and `/skill:bonfire handoff`.**
  `start` was redundant: cwd discovery already loads `.bonfire/index.md`.
  Handoff is better served by Pi's first-party `handoff` extension, by
  Linear, or by `pi @file` injection of a notes file.
- **forge is frozen; anvil is its successor.** The old `~/dev/forge/skills/forge`
  symlink is gone. forge was also a third consumer of the shared spinner-verb
  dictionary via `~/dev/forge/src/display.ts`; that file is gone, and anvil
  does not consume the shared verbs.
