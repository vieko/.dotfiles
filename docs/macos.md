# macOS Defaults

**Setup:**
1. Stow the assets package: `stow assets` (for wallpapers)
2. Stow the macOS package: `stow macos`
3. Run the configuration script: `~/.macos`
4. Enter password when prompted for system-level changes

**What it configures:**
- Computer name (set to "phyrexia") - commented out, requires sudo
- Dock permanently hidden (1000s delay, toggle with Option+Command+D)
- Menu bar autohides on hover (Ctrl-Fn-F2 to toggle)
- Keyboard repeat rate (fastest: KeyRepeat=1, InitialKeyRepeat=10, requires logout)
- Wallpaper (One Dark solid color from ~/Pictures/Wallpapers)
- Instant animations (dock toggle, window minimize/resize, Mission Control)
- Scale effect for minimize (faster than genie)
- Disabled dock launch animations

**Adding new settings:**
- Edit `macos/.macos` to add additional `defaults write` commands
- Group related settings under section headers for organization
- Test changes by running `~/.macos` again (safe to run multiple times)
- Based on [Mathias Bynens' dotfiles](https://github.com/mathiasbynens/dotfiles/blob/main/.macos)

