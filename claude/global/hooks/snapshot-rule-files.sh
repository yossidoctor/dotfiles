#!/usr/bin/env bash
# UserPromptSubmit hook: copy every rule file that is dirty against HEAD in a rule
# repo to /tmp/claude-rule-snapshot-<session>/<repo>/, replacing the previous
# turn's copy. The snapshot is what the turn started from, and audit-docs-on-stop.sh
# diffs against it.
#
# The rule repos are the ones the deployed rule files resolve into —
# hook_rule_roots in hook-lib.sh: the repo behind ~/.claude/CLAUDE.md and the repo
# behind the project's own CLAUDE.md. Rule files are the CLAUDE.mds and anything
# under a claude/…/skills or claude/…/agents tree.
#
# The Stop audit's unit is what THIS turn changed. A diff against HEAD carries every
# hunk any session left uncommitted, so a file touched here shows other sessions'
# work as this turn's, and a file only read here can be reported whole. A diff
# against the turn-start copy carries exactly the turn's own edits, whatever the
# tree's commit state. Only dirty files are copied: a clean file diffs against HEAD
# correctly, and an untracked one has no HEAD to compare with either way.
#
# UserPromptSubmit fires on a user's prompt and not on the continuation a Stop
# block creates, so an audit's own fixes land in the turn they answer for.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_input
[ -n "$HOOK_SESSION_ID" ] || exit 0

dest="/tmp/claude-rule-snapshot-$HOOK_SESSION_ID"
rm -rf "$dest"
mkdir -p "$dest"

hook_rule_roots | while IFS= read -r root; do
  name=$(basename "$root")
  git -C "$root" diff --name-only HEAD -- 2>/dev/null | while IFS= read -r rel; do
    case "$rel" in *.md|*.mdc|*.mdx) ;; *) continue ;; esac
    case "$rel" in
      CLAUDE.md|*/CLAUDE.md|claude/*skills/*|claude/*agents/*) ;;
      *) continue ;;
    esac
    mkdir -p "$dest/$name/$(dirname "$rel")"
    cp "$root/$rel" "$dest/$name/$rel"
  done
done
exit 0
