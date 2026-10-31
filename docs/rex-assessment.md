# Rex as a replacement for Ghostty + tmux (phyrexia), 2026-10-31

Status: evaluation. Trial prep done 2026-10-31 (see "Applied" at the end).
Detail below is a snapshot of Rex beta builds; recheck the changelog
before acting on any gap.

Rex versions checked: Mac app 0.1.0 (1696), CLI/server e6592f7, API rev 8.
Sources: Rex community MCP (docs, changelog, #feedback), local configs, live probes.

## Verdict

Rex can replace Ghostty + tmux on the Mac for the agent workflow, and it
adds the most value where we hand-built tooling (agent status, construct
dispatch). A cutover today is blocked by three issues:

1. 1Password prompts per pane. Confirmed: the Rex server env has no
   secrets and PATH=/usr/bin:/bin:/usr/sbin:/sbin. Every pane is
   `/usr/bin/login -flp ... -bash` (a login shell), so `.bash_profile`
   runs `op inject` in every new pane and every `rex run`. tmux avoided
   this with a non-login `default-command` and a hydrated server env
   (`op-hydrate` -> `tmux set-environment -g`). Rex has no server-global
   env and no per-pane non-login option for interactive shells.
2. Server restarts kill every process. Many releases say "restart the
   server once". Layout restore (Mac preview.23) brings back tabs,
   splits, floats, names, IDs and cwd, as fresh shells only. Running pi
   sessions and golems die. "Upgrade without killing agents" is deferred.
3. No keyboard copy mode (accepted, not shipped). Workarounds: Find,
   prompt jumps, `rex capture | nvim`.

Scope limit: Rex has no Linux client (Linux/FreeBSD server only). Ghostty
or kitty stays on Linux hosts; a Linux box can be a Rex server that the
Mac app connects to.

## Port map

| Today | Rex | Effort |
|---|---|---|
| prefix C-a, pain-control h/j/k/l, splits | `rex.bind("ctrl+a>h", "pane.focus.left")`, `ctrl+a>ctrl+a` -> `pane.send_key` | low |
| prefix . swap window | `client.tab.move` | low |
| prefix ? keys popup | custom action -> floating pane (`pane.float`); real popups accepted | low |
| tmux-status.ts + @pi_marker status line | native: pi >=1.3 emits OSC 7501; sidebar dots, Activity, notifications, Dock badge | delete |
| tmux-resurrect | built-in layout restore (no processes, no scrollback) | none |
| tmux-name-window.sh hook | no config hooks; needs a long-running `rex do --all` script on `window_created` | medium |
| tmux-yank / OSC 52 | Rex handles OSC 52 (`clipboard_written`) | verify |
| copy-mode-vi | gap | blocked |
| nvim half of vim-tmux-navigator | `rex focus <dir>`; community vim-rex-navigator | low |
| extended-keys csi-u | Rex speaks kitty keyboard protocol; open dead-key and Shift+Enter bugs | verify |
| summon-golem.sh / summon-familiar.sh | `rex run --label --cwd --focus=false --json`, `rex split`, `rex send`/`send-key`, `rex capture`, `rex block call process`; `rex wait`/events replace sleep 15 + grep | medium |
| remind-at.sh focus/resume | `rex -C phyrexia do session.select` (needs Remote Control) + `rex run` | medium |
| op-hydrate tmux global env | no equivalent | blocked (see 1) |
| keybind-audit.sh tmux root table | `rex keymap` + app defaults; check Rex Cmd defaults vs Aerospace | medium |
| toggle-theme.sh | `client.theme.change`, `client.appearance.switch_mode` | low |
| Ghostty font/theme/padding | app Settings (plist), not Lua; "settings in config files" accepted -> not trackable in dotfiles yet | gap |
| Ghostty `global:super+shift+enter` | no global hotkey; toggle-visibility accepted. Use Aerospace exec | low |
| Ghostty alt+backspace text bind | `rex.bind` with `pane.send_key` (verify) | low |

## Advantages for our workflow

- Agent status for every session and host without our extension or
  status-line format strings, plus notifications, mute and an inbox.
- A typed automation surface for Summoner/Familiar/Golem dispatch: stable
  IDs, JSON, documented exit codes, `rex wait`, an event stream
  (`child_exited`, `program_status_changed`), Lua actions in the palette.
- iOS client and Tailscale: watch and steer phyrexia agents from a phone;
  attach chaos/scourge as Rex servers in one sidebar.
- Built-in layout restore and an agent skill (`rex skill setup`).

## Round 2: what of ours gets in the way (verified live)

- Karabiner Ctrl->Cmd rule excludes Terminal/kitty/Ghostty/Zed by bundle
  id, but not Rex (`com.superlogical.rex`). In Rex, Ctrl+C/V/X/A/F/Z/Y/T/W/N/R
  become Cmd chords: Ctrl+C copies instead of SIGINT, Ctrl+W closes, Ctrl+A
  (readline, planned prefix) selects all. The Ctrl+Shift+C/V clipboard rule
  also misses Rex. Fix: add `^com\.superlogical\.rex$` to all 8 rules.
- Bash reports no working directory (`rex block call pwd` -> `{}`). Ghostty
  injected bash shell integration; Rex does not, and .bashrc emits no OSC 7
  or OSC 133. Breaks cwd in layout restore, new-pane cwd, Go to Directory,
  `terminal.pwd_changed`, shell prompt jumps.
- terminfo not set up: TERM=xterm-256color, xterm-rex not installed, no ssh
  guard (`rex terminfo setup`; ~/.ssh/config does not exist yet).
- PATH: REX_BIN_DIR is not first (.pi/agent/bin, ~/.local/bin lead). Only
  one rex on PATH today, so harmless now; docs ask for it first.
- op inject per pane (blocker 1 above).
- Double alerts: pi `sound-on-end.ts` and the Claude Code Stop hook play
  sounds; Rex program notifications can play sounds too.
- tmux-coupled text: wrap.md/recap.md construct checks (`tmux list-windows`),
  PHYREXIA.md lexicon (plane = tmux session), claude settings tmux allows,
  tinty hook, alias summon, habit-nudges list. Cosmetic until cutover.
- Pi program status works: `program_status` shows `working app=pi`.

## Round 2: Rex patterns worth adopting

- Emit OSC 7501 from our own long-running tools (anvil gates, summon
  scripts, pr-wait.sh, remind-at): status in sidebar/phone, no pings needed.
  None of anvil/pi-post/sigil emit it today.
- Replace pane scraping (`capture-pane | grep Error`, sleep 15) with exit
  codes: `rex run --wait`, `rex wait --for`, `child_exited`, block
  `program_status`.
- Replace remind-at's pid-ancestor pane hunt with stored block IDs and
  `session.select`.
- Our scripts as Lua actions in the command palette.
- One session per worktree with labels and Collapse Other Sessions.

## Counsel review corrections

- Blocker 1: mechanism confirmed, prompt count not yet measured. Checked:
  `rex api list` has no env/shell method, `rex server run` has no env flag.
  Fix candidate: hydrate once to a 0600 file in $TMPDIR, sourced by
  .bash_profile (design option, untested).
- Karabiner fix is a prerequisite for any Rex use, including viewer-only.
- Missed coupling: tmux.conf sets FORGE_STATE_ROOT in the tmux global env;
  bash does not set it. Move to .bash_exports before cutover.
- Read feedback 1562929722755649678 (keymap-conflict CLI vs Rex defaults)
  before extending keybind-audit.sh; `rex keymap` does not show app defaults.

## Packages covered

Read: ghostty, tmux, scripts, pi, bash, nvim, claude, docs, karabiner.
Grepped for terminal coupling: all packages. Mac-relevant with no Rex
impact found: aerospace (no terminal rules), sketchybar, starship, yazi
(kitty images supported by Rex), lazygit, bat, btop, zed, opencode, amp.
Linux-only packages are out of scope (no Rex Linux client).

## Watch items

- Pi OSC 133 A clears OSC 7501 `working` (feedback 1565813108620927117),
  reported with `--tui-mode regular`; we run fullscreen. Fix in pi#11519,
  unreleased.
- Agents started through wrappers lose the agent icon (process-group leader).
- Running tmux inside Rex hides OSC 7501 from Rex; not a useful hybrid.

## Applied 2026-10-31

- Karabiner: `com.superlogical.rex` added to every terminal exclusion
  (karabiner.json and both importable copies). Ctrl chords reach Rex raw;
  Ctrl+Shift+C/V maps to Cmd+C/V like Ghostty.
- bash/.bashrc: OSC 7 + OSC 133 block, active only when
  TERM_PROGRAM=rex. Verified: `rex block call pwd` returns the cwd.
- `rex terminfo setup`: xterm-rex in ~/.terminfo, guard in
  ~/.config/rex/ssh_config, Include in ~/.ssh/config (new file).
- 1Password: four new panes each ran `op inject` and got the key; the
  user saw at least 3 prompts. Fixed the same day in .bash_profile: the
  first Rex shell per server injects once into a 0600 file in the per-user
  temp dir, keyed by the server socket's inode and birth time; later Rex
  shells source it, and any login shell deletes files for a gone or
  restarted server. Outside Rex nothing changes. Verified: three panes
  opened at once all got the key from one inject, and the user saw one
  1Password prompt per server start (retested 2026-10-31 13:31).
- Karabiner reload and Ctrl+C / Ctrl+Shift+V in Rex confirmed by the user.
- FORGE_STATE_ROOT: not moved. Nothing reads it (forge is anvil's old
  name); the tmux.conf line is dead.

Found on the way: ~/.bashrc and ~/.bash_profile on phyrexia were plain
files, not stow links, and lagged the repo (op guard message, vercel skill
self-heal, socket-firewall source). Relinked with `stow bash` the same day.
The only live-only lines (opencode and ~/.local/bin PATH entries, appended
by installers) moved into .bash_exports; .local/bin was already there.
.bash_exports also puts REX_BIN_DIR back at the front of PATH.
- `rex/` stow package with `init.lua`: prefix Ctrl+A sequences for the
  tmux keys we use, a resize mode, and three actions (`split_full`,
  `copy_cwd`, `keys_card`). Checked with `rex config check`, `rex keymap`,
  and by running each action in a throwaway session.
- Construct dispatch: `scripts/.scripts/construct-term.sh` holds the tmux
  and Rex terminal operations; `summon-familiar.sh`, `summon-golem.sh`
  and `/wrap`, `/recap` use it, and `remind-at.sh` focuses a live session's
  Rex tab or resumes an offline one in a new Rex session. Verified end to
  end in Rex: a haiku familiar window reported back, a haiku golem passed
  its gate, pinged, and closed its window; reminder resume worked live and
  offline. Focusing a tab from the CLI needs Remote Control on in the app.

- Alerts: `play-random.sh` stays silent when TERM_PROGRAM=rex, so Pi's
  sound-on-end and the Claude Code Stop hook leave turn alerts to Rex's
  program notifications (Settings, Notifications: sound, banner, badge).
- Remote Control on (Settings, Rex Server): reminders switch the app to
  the session's tab; `rex-new-window.sh` opens windows.
- New-window hotkey: Aerospace `cmd-shift-enter` runs
  `scripts/.scripts/rex-new-window.sh`; Ghostty's global binding is
  commented out for the trial.

- Key audit: `keybind-audit.sh` reads Rex's `init.lua` bindings and app
  overrides. Built-in Rex defaults wait for a CLI that lists them.

## Rex app settings (not in a config file yet)

Rex keeps appearance in the app (`defaults read com.superlogical.rex`,
keys `Workspace.*`). To match Ghostty on a new machine:

- Theme: `rex -C <host> do client.theme.import path=$HOME/.config/rex/themes/one-half-dark`
  (Ghostty's One Half Dark with our cursor colors; tracked in `rex/`).
  Import makes it the dark theme. Appearance: dark.
- Font: Settings, Terminal, Typography: Berkeley Mono, style Retina
  (`Workspace.terminalFontName`, `Workspace.terminalFontStyle`).
- Cursor: block, no blink.
- Remote Control: on (Settings, Rex Server).

User check 2026-10-31: Ghostty reloaded without its global chord,
Cmd+Shift+Enter opens one Rex window, the One Half Dark theme looks right,
and Alt+Backspace deletes a word in Pi under Rex with no extra binding.

## Trial rules (2026-10-31 to 2026-11-14)

- Do not restart or update the Rex server while a golem or familiar runs:
  a restart kills every process. Check `construct-term.sh list` and
  `anvil status` first.
- Long unattended runs stay in tmux until Rex can upgrade without killing
  agents.
- Reassess on 2026-11-14: keep, extend, or roll back.
