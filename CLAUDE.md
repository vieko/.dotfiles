# Dotfiles Management Guide

## Commands
- `stow .`: Symlink all dotfiles to appropriate locations
- `stow <folder>`: Symlink specific configuration folder
- `stow -t / <folder>`: Symlink system-wide configurations (may need sudo)
- `git status`: Check status of dotfiles repository
- `git diff`: View pending changes
- `git add -u`: Add modified tracked files
- `git add <file>`: Add specific file

## Style Guidelines
- **Organization**: Each application's configs belong in their own directory
- **Naming**: Use lowercase for directories and original case for config files
- **Comments**: Include brief comments for non-obvious configurations
- **Platform**: Distinguish between Linux-specific and cross-platform configs
- **Consistency**: Maintain consistent theming across applications
- **Naming Conventions**: Use camelCase for script variables
- **Shell Scripts**: Place executable scripts in the `scripts` directory
- **Environment Variables**: Define context-specific variables in respective config files

## Hyprland Note
Install Hyprland manually from releases/source and hy3 using hyprpm to prevent version mismatches.