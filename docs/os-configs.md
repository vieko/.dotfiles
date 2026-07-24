# OS-Specific Configuration

Cross-platform setup details for this dotfiles repo. Referenced from `AGENTS.md`.

## OS-Specific Setup Scripts

**Git GPG configuration** requires running a setup script when switching between operating systems:

```bash
~/.scripts/setup-git-gpg.sh
```

This script automatically detects the OS and updates the git `gpg.program` path to point to the correct location (`/Users/$USER` on macOS, `/home/$USER` on Linux).

**When to run:**
- After fresh stowing on a new system
- When switching between macOS and Linux
- If git commit signing fails with "gpg not found" errors

## OS-Specific Configuration Pattern

**Kitty terminal** uses a symlink-based approach:

1. Main config: `kitty.conf` (contains defaults)
2. OS-specific configs: `os-macos.conf`, `os-linux.conf`
3. Symlink: `os-current.conf` → points to the correct OS config
4. Run `./setup-os-link.sh` after stowing to create the symlink
5. Main config includes `os-current.conf` at the END (so it overrides defaults)

**Ghostty terminal** uses the same symlink pattern (Ghostty supports config
includes via `config-file`):

1. Main config: `config` (shared defaults)
2. OS-specific configs: `config-macos`, `config-linux`
3. Symlink: `config-current` → points to the correct OS config (gitignored)
4. Run `./setup-os-link.sh` after stowing to create the symlink
5. `config` ends with `config-file = config-current` so OS values override the defaults

**Required on a fresh machine (especially macOS):** if `setup-os-link.sh` is not
run, `config-current` is missing and only the shared base config loads — non-fatal,
but the OS-specific overrides (font size, `macos-option-as-alt`, single-instance,
etc.) are silently skipped.

This pattern can be reused for other tools that don't support environment variables.

## Clipboard Configuration

**Neovim** clipboard integration:

- `clipboard = "unnamedplus"` in `nvim/lua/config/options.lua`
- Neovim auto-detects clipboard tool: `pbcopy/pbpaste` on macOS, `wl-copy` on Wayland, `xclip` on X11
- Do NOT hardcode clipboard commands in configs

**Tmux** clipboard integration:

- Uses `tmux-yank` plugin (auto-detects OS)
- Copy mode: `Space` to start selection, `y` to copy to system clipboard
- Integrates seamlessly with system clipboard on both macOS and Linux

