---
paths:
  - "**/.claude/hooks/**"
  - "**/claude/hooks/**"
---

# Hot-path scripts

- **A script on a hot path spends nothing before it knows it has work.** Cheapest discriminating test first, since every matching tool call waits on it; mechanics in the `hook-lib.sh` header. Skip: a one-shot script, where clarity wins.
