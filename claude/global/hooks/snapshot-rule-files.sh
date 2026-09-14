#!/usr/bin/env bash
# UserPromptSubmit hook: copy every rule file in each rule repo to
# /tmp/claude-rule-snapshot-<session>/<repo>/, replacing the previous turn's copy.
# The snapshot is what the turn started from, and audit-docs-on-stop.sh diffs
# against it.
#
# The rule repos are the ones the deployed rule files resolve into —
# hook_rule_roots in hook-lib.sh: the repo behind ~/.claude/CLAUDE.md and the repo
# behind the project's own CLAUDE.md. Rule files are the CLAUDE.mds and every
# markdown file under a claude/…/skills or claude/…/agents tree, tracked or not.
#
# The Stop audit's unit is what THIS turn changed, and the turn-start copy is the
# only baseline that measures it: HEAD moves when the turn commits, so a diff
# against HEAD reports an edited-then-committed rule file as clean, and it carries
# every hunk any other session left uncommitted, so a file only read here would be
# reported whole. Copying every rule file, clean or dirty, costs a few hundred small
# copies per prompt and leaves no file without a baseline.
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
  git -C "$root" ls-files --cached --others --exclude-standard -- \
      'CLAUDE.md' '*/CLAUDE.md' 'claude/*skills/*' 'claude/*agents/*' 2>/dev/null \
    | while IFS= read -r rel; do
        case "$rel" in *.md|*.mdc|*.mdx) ;; *) continue ;; esac
        [ -f "$root/$rel" ] || continue
        mkdir -p "$dest/$name/$(dirname "$rel")"
        cp "$root/$rel" "$dest/$name/$rel"
      done
done
exit 0
