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
- packages in `settings.base.json`: bonfire, pi-prose, pi-post, pi-counsel
  (API breaks there need an upstream bump, not a dotfiles edit)
- `~/.dotfiles/docs/agent-maintenance.md` and `AGENTS.md` where they describe
  pi behaviour that changed

Buckets: **adopt** (new capability worth wiring in), **update** (something we
have now contradicts pi), **fixes we hit** (match Fixed items against hard
stops or tool errors in the latest `~/scratch/sessions-*-assessment-notes.md`),
**n/a** (one line total, do not enumerate).

**Drift check**, since an update often lands with a Ctrl+S or a dev package:

```bash
diff <(jq -S 'del(.lastChangelogVersion,.enabledModels)' ~/.pi/agent/settings.json) \
     <(jq -S 'del(.enabledModels)' ~/.dotfiles/pi/.pi/agent/settings.base.json)
```

Report differences and whether `setup-pi.sh` would revert something wanted.

**Report**, compact: the adopt/update/fixes buckets with the file each touches,
the drift result, then lettered options for what to do now, recommended one
marked. Previous reviews live in dotfiles git history as `chore(pi):` /
`docs(pi):` commits; check them before proposing something already done.
