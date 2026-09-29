#!/usr/bin/env python3
"""Cross-layer keybinding audit for the macOS setup (phyrexia).

Collects every chord bound by each layer that can intercept a keypress,
normalizes them to one spelling, and prints chords that appear in more
than one layer. Layers, outermost first:

  macos      com.apple.symbolichotkeys (live prefs; defaults assumed
             for ids absent from the plist)
  karabiner  complex_modifications `from` chords, with app scope
  aerospace  [mode.main.binding] in aerospace.toml
  ghostty    keybinds in the ghostty config (global: ones are system-wide)
  tmux       live `tmux list-keys -T root` (no prefix)
  pi         ~/.pi/agent/keybindings.json overrides

Scope is "global" (fires in every app), "not-terminal" (karabiner unless
terminals), or "terminal" (tmux/pi/ghostty-local). A chord shared between
a global layer and anything else is a COLLISION; two terminal-scope layers
sharing a chord is a NOTE (the innermost app wins, which may be intended).

Usage: keybind-audit.sh [--all]     # --all also dumps the full table
"""

import json
import os
import plistlib
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
DOT = os.path.join(HOME, ".dotfiles")

# --- normalization -----------------------------------------------------------

MOD_ORDER = ["ctrl", "alt", "shift", "cmd", "fn"]
MOD_ALIASES = {
    "control": "ctrl", "ctrl": "ctrl",
    "option": "alt", "opt": "alt", "alt": "alt",
    "shift": "shift",
    "command": "cmd", "cmd": "cmd", "super": "cmd", "meta": "cmd", "win": "cmd",
    "fn": "fn",
}
KEY_ALIASES = {
    "return": "enter", "enter": "enter", "escape": "esc", "esc": "esc",
    "space": "space", "spacebar": "space", "backspace": "backspace",
    "delete_or_backspace": "backspace", "period": ".", "comma": ",",
}


def chord(mods, key):
    mods = {MOD_ALIASES.get(m.lower(), m.lower()) for m in mods}
    ordered = [m for m in MOD_ORDER if m in mods]
    key = key.lower()
    key = KEY_ALIASES.get(key, key)
    key = re.sub(r"^digit_", "", key)
    return "+".join(ordered + [key])


# --- macOS symbolic hotkeys ---------------------------------------------------

MAC_MODMASK = [(0x40000, "ctrl"), (0x80000, "alt"), (0x20000, "shift"),
               (0x100000, "cmd"), (0x800000, "fn")]
MAC_KEYCODES = {
    0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c",
    9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t",
    18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
    26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "o", 32: "u", 33: "[",
    34: "i", 35: "p", 36: "enter", 37: "l", 38: "j", 39: "'", 40: "k",
    41: ";", 42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".",
    48: "tab", 49: "space", 50: "`", 51: "backspace", 53: "esc",
    96: "f5", 97: "f6", 98: "f7", 99: "f3", 100: "f8", 101: "f9",
    103: "f11", 105: "f13", 107: "f14", 109: "f10", 111: "f12", 113: "f15",
    118: "f4", 120: "f2", 122: "f1", 123: "left", 124: "right", 125: "down",
    126: "up",
}
# id -> (name, default chord or None). Only ids that can plausibly collide.
MAC_HOTKEYS = {
    7: ("focus dock", "ctrl+f3"), 12: ("focus menu bar", "ctrl+f2"),
    27: ("next window of app", "cmd+`"), 28: ("screenshot to file", "cmd+shift+3"),
    29: ("screenshot to clipboard", "ctrl+cmd+shift+3"),
    30: ("screenshot selection to file", "cmd+shift+4"),
    31: ("screenshot selection to clipboard", "ctrl+cmd+shift+4"),
    32: ("mission control", "ctrl+up"), 33: ("application windows", "ctrl+down"),
    36: ("show desktop", "f11"), 52: ("toggle dock hiding", "alt+cmd+d"),
    60: ("previous input source", "ctrl+space"), 61: ("next input source", "ctrl+alt+space"),
    64: ("spotlight", "cmd+space"), 65: ("spotlight finder window", "alt+cmd+space"),
    79: ("move left a space", "ctrl+left"), 81: ("move right a space", "ctrl+right"),
    98: ("show help menu", "shift+cmd+/"), 184: ("screenshot options", "cmd+shift+5"),
}
for i in range(118, 128):  # switch to desktop 1..10, disabled by default
    MAC_HOTKEYS[i] = (f"switch to desktop {i - 117}", None)


def mac_chord(params):
    if not params or len(params) < 3:
        return None
    _, keycode, mask = params
    mods = [name for bit, name in MAC_MODMASK if mask & bit]
    return chord(mods, MAC_KEYCODES.get(keycode, f"key{keycode}"))


def collect_macos():
    out = []
    try:
        raw = subprocess.run(["defaults", "export", "com.apple.symbolichotkeys", "-"],
                             capture_output=True, check=True).stdout
        live = plistlib.loads(raw).get("AppleSymbolicHotKeys", {})
    except Exception:
        return out
    for hid, (name, default) in MAC_HOTKEYS.items():
        entry = live.get(str(hid))
        if entry is None:
            if default:
                out.append((default, "macos", f"{name} [#{hid}, default]", "global"))
            continue
        if not entry.get("enabled", False):
            continue
        c = mac_chord(entry.get("value", {}).get("parameters")) or default
        if c:
            out.append((c, "macos", f"{name} [#{hid}]", "global"))
    return out


# --- karabiner ----------------------------------------------------------------

def collect_karabiner():
    out = []
    path = os.path.join(HOME, ".config/karabiner/karabiner.json")
    try:
        data = json.load(open(path))
    except Exception:
        return out
    profile = next((p for p in data.get("profiles", []) if p.get("selected")), None)
    if not profile:
        return out
    for sm in profile.get("simple_modifications", []):
        f = sm["from"].get("key_code", "?")
        t = ",".join(x.get("key_code", "?") for x in sm.get("to", []))
        out.append((chord([], f), "karabiner", f"simple: -> {t}", "global"))
    for rule in profile.get("complex_modifications", {}).get("rules", []):
        for m in rule.get("manipulators", []):
            frm = m.get("from", {})
            key = frm.get("key_code")
            if not key:
                continue
            mods = frm.get("modifiers", {}).get("mandatory", [])
            scope = "global"
            for cond in m.get("conditions", []):
                t = cond.get("type", "")
                if t == "frontmost_application_unless":
                    scope = "not-terminal"
                elif t == "frontmost_application_if":
                    scope = "terminal" if any("ghostty" in b or "kitty" in b
                                              for b in cond.get("bundle_identifiers", [])) else "app"
            to = m.get("to", [{}])[0]
            action = to.get("shell_command") or chord(to.get("modifiers", []), to.get("key_code", "?"))
            out.append((chord(mods, key), "karabiner", f"-> {os.path.basename(action)}", scope))
    return out


# --- aerospace ----------------------------------------------------------------

def collect_aerospace():
    out = []
    path = os.path.join(HOME, ".config/aerospace/aerospace.toml")
    try:
        text = open(path).read()
    except Exception:
        return out
    section = None
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("["):
            section = s
            continue
        if section != "[mode.main.binding]" or not s or s.startswith("#"):
            continue
        m = re.match(r"([\w\-]+)\s*=\s*(.+)", s)
        if not m:
            continue
        parts = m.group(1).split("-")
        out.append((chord(parts[:-1], parts[-1]), "aerospace",
                    m.group(2).strip().strip("'\"")[:40], "global"))
    return out


# --- ghostty ------------------------------------------------------------------

def collect_ghostty():
    out = []
    base = os.path.join(HOME, ".config/ghostty")
    files = [os.path.join(base, "config"), os.path.join(base, "config-current")]
    for path in files:
        try:
            text = open(path).read()
        except Exception:
            continue
        for line in text.splitlines():
            m = re.match(r"\s*keybind\s*=\s*(.+?)=(.+)", line)
            if not m:
                continue
            trig, action = m.group(1), m.group(2).strip()
            if action.startswith(("text:", "csi:", "esc:")):
                continue  # re-encodes the key for the child; not an interception
            prefixes = []
            while ":" in trig and trig.split(":", 1)[0] in ("global", "all", "unconsumed", "performable"):
                p, trig = trig.split(":", 1)
                prefixes.append(p)
            parts = trig.split("+")
            scope = "global" if "global" in prefixes else "terminal"
            out.append((chord(parts[:-1], parts[-1]), "ghostty", action[:40], scope))
    return out


# --- tmux ---------------------------------------------------------------------

def collect_tmux():
    out = []
    try:
        res = subprocess.run(["tmux", "list-keys", "-T", "root"], capture_output=True, text=True)
    except Exception:
        return out
    if res.returncode != 0:
        return out
    for line in res.stdout.splitlines():
        m = re.match(r"bind-key\s+(?:-r\s+)?-T root\s+(\S+)\s+(.*)", line)
        if not m or "Mouse" in m.group(1) or "Wheel" in m.group(1):
            continue
        key = m.group(1)
        mods = []
        while True:
            if key.startswith("C-"):
                mods.append("ctrl"); key = key[2:]
            elif key.startswith("M-"):
                mods.append("alt"); key = key[2:]
            elif key.startswith("S-"):
                mods.append("shift"); key = key[2:]
            else:
                break
        out.append((chord(mods, key), "tmux", m.group(2)[:40], "terminal"))
    return out


# --- pi -----------------------------------------------------------------------

# Pi editor defaults that matter for tmux/karabiner overlap (pi docs/keybindings.md).
# Overrides in keybindings.json replace these per action.
PI_DEFAULTS = {
    "tui.editor.cursorLeft": ["ctrl+b"], "tui.editor.cursorRight": ["ctrl+f"],
    "tui.editor.cursorWordLeft": ["alt+left", "ctrl+left", "alt+b"],
    "tui.editor.cursorWordRight": ["alt+right", "ctrl+right", "alt+f"],
    "tui.editor.cursorLineStart": ["ctrl+a"], "tui.editor.cursorLineEnd": ["ctrl+e"],
    "tui.editor.deleteCharForward": ["ctrl+d"], "tui.editor.deleteWordBackward": ["ctrl+w", "alt+backspace"],
    "tui.editor.deleteToLineStart": ["ctrl+u"], "tui.editor.deleteToLineEnd": ["ctrl+k"],
    "tui.editor.yank": ["ctrl+y"], "tui.editor.undo": ["ctrl+-"],
    "tui.editor.historyPrevious": ["ctrl+p"], "tui.editor.historyNext": ["ctrl+n"],
    "tui.input.newLine": ["shift+enter", "ctrl+j"], "tui.input.copy": ["ctrl+c"],
    "tui.altScreen.search": ["ctrl+shift+f"],
    "app.clear": ["ctrl+c"], "app.exit": ["ctrl+d"], "app.suspend": ["ctrl+z"],
    "app.editor.external": ["ctrl+g"], "app.clipboard.pasteImage": ["ctrl+v"],
    "app.model.select": ["ctrl+l"], "app.model.cycleForward": ["ctrl+p"],
    "app.model.cycleBackward": ["shift+ctrl+p"], "app.thinking.toggle": ["ctrl+t"],
    "app.tools.expand": ["ctrl+o"], "app.message.copy": ["ctrl+x"],
}


def collect_pi():
    out = []
    path = os.path.join(HOME, ".pi/agent/keybindings.json")
    data = dict(PI_DEFAULTS)
    try:
        data.update(json.load(open(path)))
    except Exception:
        pass
    for action, keys in data.items():
        for k in (keys if isinstance(keys, list) else [keys]):
            parts = k.split("+")
            out.append((chord(parts[:-1], parts[-1]), "pi", action, "terminal"))
    return out


# --- report -------------------------------------------------------------------

def main():
    show_all = "--all" in sys.argv
    rows = []
    for fn in (collect_macos, collect_karabiner, collect_aerospace,
               collect_ghostty, collect_tmux, collect_pi):
        rows.extend(fn())

    by_chord = {}
    for c, layer, action, scope in rows:
        by_chord.setdefault(c, []).append((layer, action, scope))

    def overlaps(a, b):
        if "global" in (a, b):
            return True
        return (a == b) or ({a, b} == {"not-terminal", "app"})

    collisions, notes = [], []
    for c, entries in sorted(by_chord.items()):
        pairs = [(x, y) for i, x in enumerate(entries) for y in entries[i + 1:]
                 if x[0] != y[0] and overlaps(x[2], y[2])]
        if not pairs:
            continue
        if any(x[2] == "global" or y[2] == "global" for x, y in pairs):
            collisions.append((c, entries))
        else:
            notes.append((c, entries))

    # principle checks: Ctrl chords owned by the OS, Cmd chords owned by TUIs
    ctrl_at_os = [(c, e) for c, es in by_chord.items() for e in es
                  if e[2] == "global" and e[0] in ("macos",) and c.startswith("ctrl+")]
    cmd_in_term = [(c, e) for c, es in by_chord.items() for e in es
                   if e[0] in ("tmux", "pi") and "cmd+" in c]

    def dump(title, items):
        print(f"\n== {title} ({len(items)})")
        for c, entries in items:
            print(f"  {c}")
            for layer, action, scope in entries:
                print(f"      {layer:<10} {scope:<13} {action}")

    dump("COLLISIONS: chord shared with a global layer", collisions)
    dump("NOTES: chord shared between terminal-scope layers", notes)
    print(f"\n== PRINCIPLE: Ctrl chords held by macOS ({len(ctrl_at_os)})")
    for c, (layer, action, scope) in sorted(ctrl_at_os):
        print(f"  {c:<22} {action}")
    print(f"\n== PRINCIPLE: Cmd chords bound inside the terminal ({len(cmd_in_term)})")
    for c, (layer, action, scope) in sorted(cmd_in_term):
        print(f"  {c:<22} {layer} {action}")

    if show_all:
        print(f"\n== ALL ({len(rows)})")
        for c, layer, action, scope in sorted(rows):
            print(f"  {c:<26} {layer:<10} {scope:<13} {action}")

    return 1 if collisions else 0


if __name__ == "__main__":
    sys.exit(main())
