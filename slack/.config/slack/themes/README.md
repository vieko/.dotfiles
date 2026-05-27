# Slack custom themes

Paste-ready theme strings for Slack's **Preferences → Themes → Create a custom
theme** dialog. Slack accepts 8 comma-separated hex colors in this order:

1. Column BG (sidebar background)
2. Menu BG Hover (top nav / hovered menu bg)
3. Active Item (selected channel bg)
4. Active Item Text (text on selected channel)
5. Hover Item (channel hover bg)
6. Text Color (sidebar foreground)
7. Active Presence (online indicator dot)
8. Mention Badge (unread mention pill)

## Variants

- `one-dark.txt` — derived from `base24-one-dark` (the system default scheme
  from `tinted-theming/tinty/config.toml`). Matches kitty, nvim, sketchybar,
  and the macOS wallpaper.

## Usage

```bash
# macOS — copy to clipboard
pbcopy < ~/.config/slack/themes/one-dark.txt

# Linux (Wayland)
wl-copy < ~/.config/slack/themes/one-dark.txt

# Linux (X11)
xclip -selection clipboard < ~/.config/slack/themes/one-dark.txt
```

Then in Slack: **Preferences → Themes → scroll to "Create a custom theme" →
paste**.

## Adding a new variant

Drop another `<name>.txt` here with the 8-color string. Keep one color per
slot, uppercase hex with `#` prefix, comma-separated, no spaces.
