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
