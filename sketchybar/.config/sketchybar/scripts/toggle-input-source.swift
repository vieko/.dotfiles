// Cycle to the next enabled keyboard layout via the Text Input Sources API.
// Replaces the old Ctrl+Space keystroke: symbolic hotkey 60 is disabled in
// macos/.macos so <C-Space> reaches the terminal.
import Carbon

let filter = [
  kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String,
  kTISPropertyInputSourceIsSelectCapable as String: true,
] as CFDictionary

func sourceID(_ s: TISInputSource) -> String {
  let raw = TISGetInputSourceProperty(s, kTISPropertyInputSourceID)!
  return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
}

guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
      list.count > 1 else { exit(1) }

let current = sourceID(TISCopyCurrentKeyboardInputSource().takeRetainedValue())
let index = list.firstIndex { sourceID($0) == current } ?? -1
exit(TISSelectInputSource(list[(index + 1) % list.count]) == noErr ? 0 : 1)
