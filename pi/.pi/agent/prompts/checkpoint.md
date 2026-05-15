---
description: Label the current point in the session tree
argument-hint: "<label>"
---
Label the current leaf of this session's tree with: $@

Use `pi.setLabel(leafId, "$@")` semantics. This makes the current point easy
to find in `/tree` later — useful before a risky change you might want to
roll back to.

Confirm the label was set and remind me the easiest way to jump back here
(`/tree`, then filter to labeled-only with Ctrl+L).
