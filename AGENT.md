# Dotfiles Agent Guide

## Commands

- `stow .`: Deploy all dotfiles configurations
- `stow <folder>`: Deploy specific configuration folder
- `stow -t / <folder>`: Deploy system-wide configs (may need sudo)
- `git status`: Check repository status
- `git diff`: View changes
- `git add -u`: Stage modified files
- `chmod +x scripts/.scripts/<script>.sh`: Make scripts executable

## Testing

- Test configurations by symlinking and checking application behavior
- Use `stow -n <folder>` for dry-run before actual deployment
- Verify scripts with `bash -n <script>.sh` for syntax checking

## Style Guidelines

- **Directory Structure**: Each app gets its own directory (lowercase names)
- **File Names**: Preserve original case for config files
- **Shell Scripts**: Place in `scripts/.scripts/` directory, use bash with proper shebang
- **Variable Naming**: Use camelCase for script variables (e.g., `DEFAULT_SESSION`)
- **Comments**: Include brief comments for non-obvious configurations
- **Consistency**: Maintain Catppuccin theming across all applications
- **Platform**: Distinguish Linux-specific vs cross-platform configs
- **Organization**: Group related configs logically within directories

## Special Notes

- Install Hyprland manually from releases/source to prevent version conflicts
- Use `hyprpm` for hy3 plugin installation with matching versions
