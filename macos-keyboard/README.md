# Real Programmers Qwerty - macOS Keyboard Layout

Custom keyboard layout optimized for programming, prioritizing symbols over numbers on the number row.

## Layout Reference

### Number Row (Unshifted → Shifted)
```
` → ~
* → 1
[ → 2
{ → 3
( → 4
# → 5
^ → 6
) → 7
} → 8
] → 9
$ → 0
- → _
= → +
```

### Special Keys (Right of P)
```
& → %
! → @
```

### Alpha Keys
Standard QWERTY layout preserved for muscle memory.

## Installation

### Automatic
```bash
cd macos-keyboard
./install.sh
```

### Manual
1. Copy `RealProgQwerty.keylayout` to `~/Library/Keyboard Layouts/`
2. Log out and log back in
3. Go to **System Settings → Keyboard → Input Sources**
4. Click **+** button
5. Search for "Real Programmers Qwerty"
6. Add and select it

## Usage

- Switch layouts using the Input menu in the menu bar (flag icon)
- Or use `Ctrl + Space` / `Cmd + Space` keyboard shortcut
- Option (⌥) key provides access to special characters (©, π, ∞, etc.)

## Philosophy

This layout prioritizes programming symbols (`*`, `[`, `{`, `(`, etc.) in the unshifted position since they're used more frequently than numbers when coding. Numbers are accessed via Shift, inverting the standard keyboard behavior.

Based on concepts from:
- Michael Paulson's programming layout ideas
- Rene Rocksai's QWERTY variant

## Comparison with Standard Layout

| Key | Standard | Real Prog | Shifted |
|-----|----------|-----------|---------|
| 1   | 1 / !    | * / 1     | 1       |
| 2   | 2 / @    | [ / 2     | 2       |
| 3   | 3 / #    | { / 3     | 3       |
| 4   | 4 / $    | ( / 4     | 4       |
| 5   | 5 / %    | # / 5     | 5       |
| 6   | 6 / ^    | ^ / 6     | 6       |
| 7   | 7 / &    | ) / 7     | 7       |
| 8   | 8 / *    | } / 8     | 8       |
| 9   | 9 / (    | ] / 9     | 9       |
| 0   | 0 / )    | $ / 0     | 0       |

## Troubleshooting

### Layout doesn't appear in Input Sources
- Ensure you logged out/restarted after installation
- Check file is in `~/Library/Keyboard Layouts/` (user) not `/Library/Keyboard Layouts/` (system)
- Verify file has `.keylayout` extension

### Can't switch to the new layout
- Enable "Show Input menu in menu bar" in Keyboard settings
- Check keyboard shortcut isn't conflicting with other apps

### Want to uninstall
```bash
rm ~/Library/Keyboard\ Layouts/RealProgQwerty.keylayout
```
Then log out/restart and remove from Input Sources in System Settings.
