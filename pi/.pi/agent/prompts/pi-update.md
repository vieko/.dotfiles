---
description: Review a pi release against our setup; report adopt / update / nothing
argument-hint: "[previous version, default: the older release dir still on disk]"
---
Pi was just updated. Review what changed against our setup and report what to
adopt, what needs updating, and what is noise. Read-only until I pick an option.

**Window.** Current version: `pi --version`. Previous: ${1:-the older directory
in `ls -t ~/.pi/agent/install/releases/` (since 1.1.0 `pi update` keeps
exactly the new release and the one it updated from)}. Read `CHANGELOG.md` under
`~/.pi/agent/install/releases/<current>/node_modules/@earendil-works/pi-coding-agent/`
from the current version down to, not including, the previous one. Follow the
`docs/*.md` links for anything that looks relevant; read those docs completely.

**Classify every changelog item against our surface** (all under
`~/.dotfiles/pi/.pi/agent/` unless noted):

- `settings.base.json` + `hosts/*.json` (setup-pi.sh generates the live file)
- `models.json`: `compat` flags, `modelOverrides`, pricing tiers, routing
- `keybindings.json`, `CHEATSHEET.md`, `~/.dotfiles/docs/keybindings-card.md`
- `extensions/*.ts` (extension API changes; check the types they import)
- `prompts/*.md`
- our pi packages (bonfire, pi-prose, pi-post, pi-counsel, pi-redact,
  sigil) and anvil, which pins its own pi SDK (see **Packages** below;
  fixes there go upstream, not into dotfiles)
- model names outside `models.json`: the aliases in
  `~/.dotfiles/scripts/.scripts/summon-familiar.sh` and anvil's
  `packages/core/src/node/model-resolver.ts`
- `~/.dotfiles/docs/agent-maintenance.md` and `AGENTS.md` where they describe
  pi behaviour that changed

Buckets: **adopt** (new capability worth wiring in), **update** (something we
have now contradicts pi), **fixes we hit** (match Fixed items against hard
stops or tool errors in the latest `~/scratch/sessions-*-assessment-notes.md`),
**n/a** (one line total, do not enumerate).

**Packages.** Run `~/.scripts/pi-typecheck.sh` (read-only). It typechecks
the extensions, each package (including its `pi.extensions` entries) and
anvil against the new release's types, lists the pi SDK each repo has
installed, diffs the gateway catalog against the previous release, and
flags any model id we name that the new catalog lacks. A type pass is not
the whole check: for every Changed, Breaking or Added item, search the
`~/dev` checkouts for the API it touches (`rg` over their `extensions/`,
`src/` and `integrations/pi/`) and say whether the behaviour change
reaches them. For each new catalog model, say whether it is a cheaper or
newer member of a family we already use (it may replace an alias), and
whether anvil's pinned SDK can resolve it yet.

**Drift check**, since an update often lands with a Ctrl+S or a dev package:

```bash
diff <(jq -S 'del(.lastChangelogVersion,.extensionChangelogVersions,.enabledModels)' ~/.pi/agent/settings.json) \
     <(jq -S 'del(.enabledModels)' ~/.dotfiles/pi/.pi/agent/settings.base.json)
```

Report differences and whether `setup-pi.sh` would revert something wanted.

**Report**, compact: the adopt/update/fixes buckets with the file each touches,
the drift result, then lettered options for what to do now, recommended one
marked. Previous reviews live in dotfiles git history as `chore(pi):` /
`docs(pi):` commits; check them before proposing something already done.
