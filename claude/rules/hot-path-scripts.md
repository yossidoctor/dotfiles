---
paths:
  - "**/.claude/hooks/**"
  - "**/claude/hooks/**"
---

# Hot-path scripts

Loads when a hook is touched.

- **A script on a hot path spends nothing before it knows it has work.** Cheapest discriminating test first, `jq` for JSON; mechanics in the `hook-lib.sh` header. Skip: a one-shot script, where clarity wins. Falsifier: an interpreter spawned on a path that exits without acting.
