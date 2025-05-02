# OpenCode.md - Dotfiles Management Guide

## Commands
- `stow .`: Symlink all dotfiles to appropriate locations
- `stow <folder>`: Symlink specific configuration folder
- `stow -t / <folder>`: Symlink system-wide configurations (may need sudo)
- `git status`: Check status of dotfiles repository
- `git diff`: View pending changes
- `git add -u`: Add modified tracked files
- `git add <file>`: Add specific file

## Style Guidelines
- **Organization**: Each application's configs in its own directory
- **Naming**: Lowercase directories, original case for config files
- **Comments**: Brief comments for non-obvious configurations
- **Platform**: Distinguish Linux-specific and cross-platform configs
- **Consistency**: Maintain consistent theming across applications
- **Variables**: Use camelCase for script variables
- **Shell Scripts**: Place executable scripts in `scripts/.scripts/`
- **Environment Variables**: Define context-specific variables in respective config files
- **Theming**: Use Catppuccin themes (Mocha/Latte) for consistent appearance

## Hyprland Note
Install Hyprland manually from releases/source and hy3 using hyprpm to prevent version mismatches.