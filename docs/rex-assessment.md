# Rex as a replacement for Ghostty + tmux (phyrexia), 2026-10-31

Status: kept (decided 2026-11-14, see "Reassessment 2026-11-14"). Rex is
the daily terminal on phyrexia. Trial prep done 2026-10-31 (see "Applied").
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
  Started 2026-11-20 as one session per work stream: `-S <stream>` on
  the summon scripts opens construct windows in that session (Rex
  cannot move a tab between sessions: `window move` and `move` stay
  inside one session), and a pi tab alone in an unnamed session renames
  it (below).

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
  reported with `--tui-mode regular`; we run fullscreen. Fixed in pi#11519,
  shipped in pi 1.5.0 (regular mode no longer writes OSC 133).
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

- Golem status: the summon-golem runner reports OSC 7501 under its own
  record id `golem` (working while anvil runs, then done or error), only
  to a terminal, with short messages. Tested in Rex: working mid-run;
  error after a red gate, window kept; done after a green gate (`-k`);
  the pi-post ping still arrives; nothing written when not on a terminal.
  A green window closes after 10s, so `done` is brief; `error` stays.
- Deferred after two counsel reviews: OSC 7501 in pr-wait.sh (it runs
  detached, with no terminal), a Lua events watchdog (Rex's exit event
  fires for the tab's shell, not typed commands; it dies on restarts),
  and the Rex agent skill (read `rex skill show` first, then use
  `rex skill setup`). Keep tmux-status.ts while tmux stays the fallback.
- remind-at alert: keep launchd for timing (Rex timers die with the
  server). Once Rex pushes program status to the phone, consider a small
  Rex tab reporting `blocked`/`kind=question` in place of the modal alert;
  it would lose the Snooze and Later buttons and need Rex running.

- Rex agent skill installed 2026-10-31 (`rex skill setup`): stub skill in
  `~/.agents/skills/rex` (gitignored) and `~/.claude/skills/rex`, Claude Code
  and Codex SessionStart hooks. Session naming started off and has been on
  since 2026-11-03 (`rex skill setup --session-naming`, which rewrites the
  tracked Claude Code hook). Pi has no hook and needs
  none (REX_SESSION/REX_BLOCK are in its env). It covers non-Pi terminals;
  pi-post stays the agent-to-agent channel.

## Linux hosts (chaos, 2026-11-13)

chaos runs a personal Rex server that joins the tailnet as its own
device, `chaos-rex.tailc2994c.ts.net`. Rex on Linux is a server only;
the Mac app and CLI connect to it. To set up another Linux host:

1. Install the preview package (needs sudo; on Fedora, first
   `sudo dnf remove Rex` if the unrelated package is there):
   `curl -fsSL https://pkgs.superlogical.com/rex/install.sh | sh -s -- --channel preview`
2. `stow rex-server`. Its drop-in adds `--tailscale --tailscale-hostname
   %H-rex` to `rex.service`. `rex server install -- --tailscale` does not
   work on Linux: it takes no server flags there.
3. `loginctl enable-linger` (once), then
   `systemctl --user daemon-reload && systemctl --user enable --now rex.socket rex.service`.
   Enabling the service, not only the socket, brings the tailnet listener
   up at boot instead of on the first local `rex` command.
4. `rex server status` prints a Tailscale sign-in link; approve the
   device as vieko@github.
5. On the Mac: `rex hosts add <host> https://<host>-rex.tailc2994c.ts.net`,
   and Add Remote Host in the app (CLI hosts do not sync to the app yet).

The package's systemd trigger printed "Failed to start transient service
unit" during install; it did not stop the install. chaos's shell does not
auto-attach tmux, so a Rex tab there opens a plain login shell.

## Rex app settings (not in a config file yet)

Rex keeps appearance in the app (`defaults read com.superlogical.rex`,
keys `Workspace.*`). To match Ghostty on a new machine:

- Theme: `rex -C <host> do client.theme.import path=$HOME/.config/rex/themes/one-half-dark`
  (Ghostty's One Half Dark with our cursor colors; tracked in `rex/`).
  Import makes it the dark theme. Appearance: dark.
- Font: Settings, Terminal, Typography: Berkeley Mono, style Retina, size
  14 to match Ghostty's macOS `font-size` (`Workspace.terminalFontName`,
  `Workspace.terminalFontStyle`, `Workspace.terminalFontPointSize`).
  Cmd+= zoom does not persist; set the size here.
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

## Reassessment 2026-11-14: keep

Decision: keep Rex as the daily terminal. tmux stays installed as the
fallback for a run that must survive a Rex server restart. Ghostty stays
configured.

Evidence from the trial:

- 59 of 60 constructs from 2026-10-31 to 2026-11-13 ran in Rex tabs
  (`~/scratch/logs/summons.log`), long golems included; the one other was
  a print-mode familiar. The "long runs stay in tmux" rule was not used.
- The laptop restarted a few times on its own. Tabs came back, running
  sessions stopped, no work lost that the user saw.
- Keys: no problems seen. Golem and agent status in the sidebar and the
  Activity view (Working, Done) helped. Agents used the Rex skill.
- 1Password: the user typed the password once per tab after restarts. The
  cause was the per-server cache lock: restored panes waited 20s for the
  first pane's prompt, and after a reboot 1Password wants the typed
  password, which takes longer, so each pane ran its own inject. Fixed in
  `7961432` (wait while the lock's shell lives, up to 5 minutes; a pane
  that waited on a failed prompt does not prompt again). Tested with a
  stub `op`: three panes and a 30s approval give one inject. Confirm on
  the next reboot: one prompt in total.

Rex status checked (changelog to Mac preview.30 and Server & CLI
preview.19, 2026-11-13):

- Still open: scrollback in layout restore, server restart without
  killing processes (1565320686338052178, deferred), keyboard copy mode
  (1558373508117958686, accepted), settings in config files
  (1556737365475598464, accepted), a CLI that lists built-in shortcuts
  (1562929722755649678 active, 1565309554022031464 deferred), public block
  plugins, push notifications to iOS (1562899915489808545 accepted; agent
  state push 1566890849713918244 deferred).
- Shipped: global Toggle Visibility (`client.visibility.toggle`, Mac
  preview.25); not needed, Aerospace already opens windows. App relaunch
  for updates keeps programs running (Mac preview.26); a server restart
  still kills them. Pi OSC 133 vs 7501 (1565813108620927117) is fixed in
  Pi 1.5.0.
- Copy mode stopgaps from the community: `tomarrell/rex-tmux-copy` (the
  pane's scrollback in tmux copy mode, in a floating pane) and a floating
  nvim gist in the copy mode thread. Not adopted.

Deferred items, decided:

- Lua events watchdog: dropped. `child_exited` still fires for the tab's
  shell, and the watchdog dies on restarts; the pi-post ping covers it.
- OSC 7501 in `pr-wait.sh`: dropped. It runs detached with no terminal.
- remind-at alert as a Rex tab: not now. Rex does not push program
  status to the phone yet. Recheck when push notifications ship.
- keybind-audit Rex defaults: waiting for a CLI that lists them.

Rules from now on:

- Update or restart the Rex server only when `construct-term.sh list`
  and `anvil status` show nothing running. On 2026-11-14 the server ran
  preview.14 while the app shipped preview.18; preview.19 fixes lost
  sessions on server start and stop.
- A run that must survive a server restart or update goes in tmux.
- Activity customization is in Settings, Notifications, Program Activity
  (per state: tab marks, notifications, Dock badge, sound; include idle)
  and grouping by session or by priority. The text in a row comes from
  the program's OSC 7501 report, so our own tools can say more.
  Applied 2026-11-14: settings per state (Blocked and Error: everything
  on; Done: no sound; Working: tab dots only; idle off; each process on;
  group by priority), prefix `a` opens Activity, familiars start with
  `pi --name <brief slug>` so their rows name the task, and a stopped
  golem says why: gate green, void, setup failed before the agent ran,
  gate red after N attempts, or idle when stopped by the user. Before,
  every non-green golem said "failed (exit 1)".
- Pi reports a turn that ends on a question as `done`, the same as
  finished work. `question-status.ts` (2026-11-15) adds a child record
  (`id=question`, `blocked`, `kind=question`) when a turn ends on a
  lettered menu, with the options and the recommended one as the row
  text, and clears it on the next prompt. Pi's own record is untouched;
  check both with `rex block call program_status`.
- Hand-started Pi sessions in one repo all read `π - gtm` in the
  sidebar. `tab-title.ts` (2026-11-20) names an unnamed session from its
  first prompt (issue key, else non-default branch, else a 2-4 word
  slug) and sets the title to that name. After the first turn, a cheap
  model (Haiku 4.5) replaces it with a 2-5 word title, using Claude
  Code's naming rules. Inside Rex, during runs longer than 5s, it also writes a
  status line of 14 words or fewer as an OSC 7501 child record
  (`id=focus`). Rex shows the most recently updated record in the
  working capsule (verified 2026-11-20), so the line is resent after
  each pi root report. Rex shows the capsule only for working rows.
  When a run ends the record becomes `idle` with a one-line outcome
  ("PR #42 opened; waiting on review"). Rex lists it in the hover card
  as "Status". On two unfocused tabs (2026-11-20) the row stayed under
  Done with one blue dot and showed no extra row; a `done` child looked
  the same, and `idle` was picked because it cannot count as a second
  finished task. Not yet checked: a focused tab, and an error run.
  Rex session name: Rex's agent guide (`rex __internal skill`) asks
  agents to label their session in 2-4 dashed words and to replace
  generated labels. A pi tab that is the only pane in its session
  renames a Rex-generated label ("misty-moor") or one it set itself to
  the pi session name. Rex has no "generated" flag; the word list comes
  from the server binary, and a missing word only skips the rename.
  Shared sessions and chosen labels are left alone (verified
  2026-11-20).
  Tests: `node --experimental-strip-types --test
  pi/.pi/agent/tests/tab-title.test.ts`; prompt eval against your own
  sessions: `pi/.pi/agent/tests/tab-title-eval.mts [title|focus|outcome]`.
- Recheck the open items in a month (reminder `rex-open-items-recheck`).
