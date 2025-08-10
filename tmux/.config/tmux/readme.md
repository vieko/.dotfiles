# Tmux Configuration

## Installation

1. Install TPM (Tmux Plugin Manager):
   ```bash
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

2. Reload tmux configuration:
   ```bash
   tmux source-file ~/.config/tmux/tmux.conf
   ```

3. Install plugins using TPM:
   - Press `prefix + I` (default: `Ctrl+a + I`) to install plugins

## Key Optimizations

- **Simplified decorators**: Replaced resource-heavy Unicode characters with simple spaces
- **Organized configuration**: Clear section headers with visual separators for maintainability
- **Enhanced documentation**: Added descriptive comments throughout configuration
- **Plugin structure**: Moved TPM initialization to end with clear section headers

## Plugin Version Pinning (Recommended)

For stability and security, consider pinning plugin versions in `tmux.conf`:

```bash
# Instead of:
set -g @plugin 'tmux-plugins/tmux-yank'

# Use specific commits:
set -g @plugin 'tmux-plugins/tmux-yank@v2.3.0'
```

Check plugin releases at their respective GitHub repositories for stable versions.

## Usage

- Prefix key: `Ctrl+a`
- Plugin management: `prefix + I` (install), `prefix + U` (update)
- Reload config: `tmux source-file ~/.config/tmux/tmux.conf`
