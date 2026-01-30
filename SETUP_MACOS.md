# macOS Setup Cheatsheet

Complete guide for setting up a new macOS machine with these dotfiles.

**Target System**: scourge (Mac Mini)
**Reference System**: phyrexia (current system)
**Last Updated**: 2026-01-30

---

## PHASE 1: Initial System Setup

### 1.1 macOS System Configuration

After initial macOS installation:

```bash
# Set computer name to "scourge"
sudo scutil --set ComputerName "scourge"
sudo scutil --set HostName "scourge"
sudo scutil --set LocalHostName "scourge"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "scourge"
```

### 1.2 Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH (Apple Silicon/M-series)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 1.3 Install Required Tools via Homebrew

```bash
brew install \
  git \
  stow \
  bash \
  zoxide \
  fzf \
  bat \
  btop \
  lazygit \
  yazi \
  starship \
  tmux \
  neovim \
  kitty \
  ghostty \
  ripgrep \
  fd \
  trash-cli \
  delta \
  gh \
  gnupg \
  gpg-agent \
  pinentry-mac

# Install Nerd fonts
brew install --cask font-sf-mono-nerd-font-ligaturized

# macOS-only tools
brew install \
  aerospace \
  sketchybar \
  karabiner-elements

# Install fonts for better rendering
brew tap homebrew/cask-fonts
brew install --cask \
  font-fira-mono \
  font-fira-sans \
  font-roboto-slab
```

### 1.4 Install Node Version Managers (Optional)

```bash
# pnpm
curl -fsSL https://get.pnpm.io/install.sh | sh -

# nvm (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# npm global directory setup
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
```

### 1.5 Install Rust & Cargo (Optional)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# Follow on-screen instructions to add cargo to PATH
```

---

## PHASE 2: Clone and Setup Dotfiles

### 2.1 Clone with Submodules

```bash
cd ~
gh auth login  # Authenticate first
gh repo clone vieko/.dotfiles -- --recurse-submodules
cd .dotfiles
```

### 2.2 Install Cross-Platform Packages

```bash
stow bash
stow git
stow kitty
stow tmux
stow nvim
stow starship
stow bat
stow btop
stow lazygit
stow yazi
stow assets
stow scripts
stow ghostty  # or whichever terminal you prefer (kitty/ghostty)
stow claude  # Claude CLI settings
```

### 2.3 OS-Specific Setup for Kitty

```bash
cd ~/.config/kitty
./setup-os-link.sh
cd ~/.dotfiles
```

### 2.4 Install macOS-Specific Packages

```bash
stow macos
stow macos-keyboard
stow aerospace
stow sketchybar
stow karabiner
```

### 2.5 Git GPG Configuration

```bash
~/.scripts/setup-git-gpg.sh
```

---

## PHASE 3: macOS System Defaults Configuration

### 3.1 Apply macOS System Settings

```bash
~/.macos
# Enter password when prompted
```

This script configures:
- Dock (permanently hidden, autohide delay, animations)
- Menu bar (autohide)
- Keyboard (fastest repeat rate, full keyboard access)
- Keyboard Input Sources (Canadian + Programmers QWERTY layouts)
- Wallpaper (One Dark solid color)
- Window animations (instant)

### 3.2 Set Wallpaper Location

The wallpaper files are located at:
- `/Users/<username>/Pictures/Wallpapers/one-dark-base-solid.png` (used by default)
- Other options: `mocha-base-solid.png`, `pattern.png`, etc.

Create the directory if needed:

```bash
mkdir -p ~/Pictures/Wallpapers
# Files will be symlinked from ~/.dotfiles/assets/Pictures/Wallpapers/
```

### 3.3 Install Keyboard Layouts

```bash
cd ~/.dotfiles/macos-keyboard
./install.sh
# Log out and back in for changes to take effect
```

After login:
1. Go to **System Settings → Keyboard → Input Sources**
2. Click **+** to add new input source
3. Search for "Real Programmers QWERTY" and add it
4. Enable "Show Input menu in menu bar" to see the flag icon
5. Use **Ctrl+Space** to switch between Canadian and Programmers QWERTY layouts

---

## PHASE 4: Terminal & Shell Configuration

### 4.1 Set Default Shell to Bash

```bash
# macOS now defaults to zsh, but this setup uses bash
echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/bash
```

### 4.2 Verify PATH Configuration

The `bash/.bash_exports` file sets up:
- XDG Base Directory variables
- PATH additions for cargo, node, deno, go, homebrew, pnpm, etc.
- Editor defaults (nvim)
- FZF configuration
- Locale (en_CA.UTF-8)

Verify by opening a new terminal and running:

```bash
echo $PATH
echo $USER_OS  # Should be "macos"
```

### 4.3 Install Bat Cache

```bash
bat cache --build
```

---

## PHASE 5: Terminal Multiplexer & Editor Setup

### 5.1 Tmux Session Setup

Tmux will auto-start with default session based on hostname. For "scourge", the default session name will be "SCOURGE".

Windows created:
- `void` (terminal)
- `altar` (editor)
- `invoke` (runner)
- `coven` (logs)
- `scry` (learn)
- `arcana` (dotfiles)

To manually start:

```bash
~/.scripts/tmux-start.sh
```

### 5.2 Neovim Setup

```bash
# Neovim uses lazy.nvim for plugin management
# First launch will auto-install plugins:
nvim

# Format Lua files with stylua:
stylua ~/.config/nvim

# Note: Language servers (LSP) install lazily on first use
```

### 5.3 Verify Git Configuration

```bash
git config user.name  # Should be: Vieko Franetovic
git config user.email  # Should be: 48670+vieko@users.noreply.github.com
git config user.signingkey  # Should be: 16FBF1CF29A0CDAE
```

---

## PHASE 6: macOS Window Manager & Status Bar Setup

### 6.1 AeroSpace Configuration

AeroSpace starts automatically. Configuration: `~/.config/aerospace/aerospace.toml`

Features:
- 10 workspaces (Cmd+1 through Cmd+0)
- Window focus with Cmd+H/J/K/L (vim-like)
- Window movement with Cmd+Shift+H/J/K/L
- Floating windows for: System Preferences, Zoom, KeePass, VeraCrypt, 1Password, Yubico Manager, FontBook, Karabiner, Weather

Verify AeroSpace is running:

```bash
aerospace list-workspaces
```

### 6.2 SketchyBar Configuration

SketchyBar displays at bottom with workspace indicators.

Features:
- Workspace indicators (1-10) on left
- Keyboard layout indicator (Canadian/Programmers QWERTY)
- Clock (HH:MM or MMM D HH:MM - click to toggle)
- Volume indicator
- Battery indicator with percentage
- Loom toggle button
- Theme: Base16 One Dark colors

Commands:

```bash
# Start SketchyBar:
brew services start sketchybar

# Reload config:
sketchybar --reload
```

**Important**: Grant Screen Recording permission in System Settings:
- Privacy & Security → Screen Recording → Grant access to SketchyBar

### 6.3 Keyboard Remapping (Karabiner)

Key remappings configured in Karabiner-Elements:
- Caps Lock → Left Control
- Cmd+Escape → Toggle SketchyBar visibility
- Ctrl+Space → Cycle keyboard layouts

First launch:

```bash
open -a "Karabiner-Elements"
```

If you see modifier key conflicts warning:
- Go to System Settings → Keyboard → Modifier Keys
- Select "Karabiner DriverKit VirtualHIDKeyboard" and click Restore Defaults

### 6.4 Toggle Commands

```bash
# Hide/show SketchyBar
~/.config/karabiner/scripts/toggle-sketchybar.sh
# Or: Cmd+Escape

# Toggle keyboard layout
~/.scripts/toggle-keyboard.sh
# Or: Ctrl+Space

# Toggle clock format (HH:MM ↔ MMM D HH:MM)
~/.config/sketchybar/scripts/toggle-clock.sh

# Open Loom
~/.config/sketchybar/scripts/toggle-loom.sh
```

---

## PHASE 7: Development Environment Setup

### 7.1 GitHub CLI Authentication

```bash
gh auth login
# Follow prompts to authenticate
# Verify:
gh auth status
```

### 7.2 GPG Setup for Git Signing

```bash
# GPG program path is set to ~/.scripts/gpg-wrapper.sh
# The wrapper auto-detects the correct GPG binary

# Verify git commit signing works:
git config gpg.program  # Should be ~/.scripts/gpg-wrapper.sh
git -c user.signingkey=16FBF1CF29A0CDAE -c commit.gpgsign=true commit --allow-empty -m "test" && git reset --soft HEAD~1
```

### 7.3 Linear CLI (Optional)

```bash
# Store API token
echo "your-token-here" > ~/.linear_api_token
chmod 600 ~/.linear_api_token

# Token is auto-loaded from bash/.bash_exports
```

### 7.4 Claude CLI Setup (Optional)

```bash
# Already stowed, verify installation:
which claude
claude --version

# Configure if needed:
claude settings
```

---

## PHASE 8: Post-Setup Verification

### 8.1 Environment Check

```bash
# Verify all key tools are installed:
command -v git && echo "✓ git"
command -v stow && echo "✓ stow"
command -v bash && echo "✓ bash"
command -v nvim && echo "✓ nvim"
command -v tmux && echo "✓ tmux"
command -v kitty && echo "✓ kitty"
command -v sketchybar && echo "✓ sketchybar"
command -v aerospace && echo "✓ aerospace"
command -v zoxide && echo "✓ zoxide"
command -v fzf && echo "✓ fzf"
command -v starship && echo "✓ starship"
command -v gh && echo "✓ gh"
```

### 8.2 Configuration Check

```bash
# Verify all symlinks are created:
ls -la ~/.config/nvim/init.lua
ls -la ~/.config/tmux/tmux.conf
ls -la ~/.config/kitty/kitty.conf
ls -la ~/.config/sketchybar/sketchybarrc
ls -la ~/.config/aerospace/aerospace.toml
ls -la ~/.config/karabiner/karabiner.json

# Verify bash exports:
echo $EDITOR  # Should be "nvim"
echo $USER_OS  # Should be "macos"
echo $XDG_CONFIG_HOME  # Should be ~/.config
```

### 8.3 System Defaults Verification

```bash
# Check macOS defaults were applied:
defaults read com.apple.dock autohide  # Should be 1 (true)
defaults read NSGlobalDomain _HIHideMenuBar  # Should be 1 (true)
defaults read NSGlobalDomain KeyRepeat  # Should be 1
defaults read NSGlobalDomain InitialKeyRepeat  # Should be 10
```

### 8.4 Test Window Management

```bash
# Open a few applications and test AeroSpace:
open -a "System Preferences"  # Should be floating
open -a "Finder"  # Should be tiled

# Test workspace switching:
# Press Cmd+1 through Cmd+0 to switch workspaces
# Watch SketchyBar update the active workspace indicator

# Test keyboard layout switching:
# Press Ctrl+Space to switch between Canadian and Programmers QWERTY
```

---

## TROUBLESHOOTING

### SketchyBar doesn't appear or shows blank

```bash
# Reload SketchyBar
sketchybar --reload

# Check bar state:
sketchybar --query bar

# Grant Screen Recording permission:
# System Settings → Privacy & Security → Screen Recording
# Add SketchyBar if not listed
```

### AeroSpace workspace indicators not showing in SketchyBar

```bash
# The config uses hardcoded workspaces 1-10 instead of dynamic queries
# This was intentional to avoid startup timing issues
# Verify aerospace integration:
aerospace list-workspaces --all

# Trigger manual update:
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=1
```

### Karabiner not recognizing key remaps

```bash
# Restart Karabiner:
killall "Karabiner-Elements" 2>/dev/null; open -a "Karabiner-Elements"

# Check System Settings → Keyboard → Modifier Keys
# If "Karabiner DriverKit VirtualHIDKeyboard" shows conflicts, click "Restore Defaults"

# Verify Karabiner has accessibility permissions:
# System Settings → Privacy & Security → Accessibility
# Check "Karabiner-Elements" is listed and enabled
```

### Keyboard layouts not switching (Programmers QWERTY not found)

```bash
# Verify layout file is installed:
ls ~/Library/Keyboard\ Layouts/RealProgQwerty.keylayout

# If missing, reinstall:
cd ~/.dotfiles/macos-keyboard
./install.sh

# Log out and back in

# Verify in System Settings:
# System Settings → Keyboard → Input Sources
# Should list: Canadian, Programmers QWERTY
```

### Git commit signing fails

```bash
# Verify GPG wrapper path:
cat ~/.gitconfig | grep gpg.program

# Test GPG directly:
gpg --version

# If GPG not found, install:
brew install gnupg

# Re-run setup script:
~/.scripts/setup-git-gpg.sh

# Test signing:
git -c commit.gpgsign=true commit --allow-empty -m "test"
git log --show-signature -1
```

### Tmux session not auto-starting

```bash
# Verify script is executable:
ls -la ~/.scripts/tmux-start.sh

# Manually run:
~/.scripts/tmux-start.sh

# Check session name for "scourge":
tmux list-sessions  # Should show "SCOURGE" session

# Add to shell profile if auto-start desired:
# Add to ~/.bashrc: exec ~/.scripts/tmux-start.sh
```

---

## QUICK REFERENCE: Key Files & Locations

| Component | Config Path | Purpose |
|-----------|------------|---------|
| **Bash** | `~/.bashrc`, `~/.bash_exports` | Shell configuration, environment variables |
| **Git** | `~/.gitconfig`, `~/.gitconfig-macos` | Git settings, GPG signing, aliases |
| **Neovim** | `~/.config/nvim/` | Editor configuration |
| **Tmux** | `~/.config/tmux/tmux.conf` | Terminal multiplexer |
| **Kitty** | `~/.config/kitty/kitty.conf` | Terminal emulator |
| **Starship** | `~/.config/starship.toml` | Shell prompt |
| **AeroSpace** | `~/.config/aerospace/aerospace.toml` | Window manager |
| **SketchyBar** | `~/.config/sketchybar/sketchybarrc` | Status bar |
| **Karabiner** | `~/.config/karabiner/karabiner.json` | Keyboard remapping |
| **Scripts** | `~/.scripts/` | Utility scripts |
| **macOS Setup** | `~/.macos` | System defaults script |
| **Wallpapers** | `~/Pictures/Wallpapers/` | Desktop backgrounds |
| **Keyboard Layout** | `~/Library/Keyboard Layouts/` | Custom keyboard layouts |

---

## INSTALLATION ORDER SUMMARY

1. Install Homebrew
2. Install core tools (git, stow, bash, etc.)
3. Install macOS-specific tools (aerospace, sketchybar, karabiner)
4. Clone dotfiles with submodules
5. Stow cross-platform packages
6. Run kitty setup script
7. Stow macOS packages
8. Run `~/.macos` system defaults
9. Install keyboard layout
10. Authenticate git/github/gpg
11. Start SketchyBar and AeroSpace
12. Configure Karabiner (accessibility permissions)
13. Test everything

---

## COLOR SCHEME REFERENCE (Base16 One Dark)

Used consistently across SketchyBar, AeroSpace plugins, and terminal themes:

```
BASE00 = #282c34  (Background)
BASE07 = #c8ccd4  (Foreground)
BASE08 = #e06c75  (Red - critical)
BASE09 = #d19a66  (Orange - warning)
BASE0A = #e5c07b  (Yellow)
BASE0B = #98c379  (Green - positive)
BASE0D = #61afef  (Blue - active)
BASE0E = #c678dd  (Purple - accent)
```

---

## ADDITIONAL RESOURCES

- **Dotfiles Repository**: https://github.com/vieko/.dotfiles
- **AeroSpace GitHub**: https://github.com/nikitabobko/AeroSpace
- **SketchyBar GitHub**: https://github.com/FelixKratz/SketchyBar
- **Karabiner-Elements**: https://karabiner-elements.pqrs.org/
- **Neovim**: https://neovim.io/
- **Tmux**: https://github.com/tmux/tmux
