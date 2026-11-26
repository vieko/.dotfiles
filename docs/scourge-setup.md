# Scourge (Mac Mini) setup

Waiting on physical access. `nvim-highlight-colors` auto-clones on first
launch (lazy-lock.json is gitignored). `pi update` installs the pinned
packages from `pi/.pi/agent/settings.json`.

```bash
git clone git@github.com:vieko/.dotfiles ~/.dotfiles
cd ~/.dotfiles
stow bash git ghostty tmux nvim starship bat btop lazygit yazi assets \
     claude pi agents \
     macos macos-keyboard aerospace sketchybar
git clone git@github.com:vieko/anvil   ~/dev/anvil    # anvil skill symlink target (successor to forge)
brew install tree-sitter-cli  # required by nvim-treesitter main branch
pi update   # installs the pinned packages from settings.json
~/.macos
# If git signing fails on first commit:
~/.scripts/setup-git-gpg.sh
```

Then sanity-test: `wacom` alias triggers `restart-wacom.sh` cleanly.
