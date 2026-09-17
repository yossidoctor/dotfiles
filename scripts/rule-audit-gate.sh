#!/usr/bin/env bash
# Commit gate: a staged rule file needs an audit receipt naming its exact
# content, or the commit stops. Shared by every rule repo's pre-commit hook —
# it takes the repo root and knows nothing else.
#
# Rule files are behavioural text: CLAUDE.md, a skill, an agent definition, a
# reference a skill ships. They bind every later session, and a defect in one
# is read as intent by every session after it. Session docs, READMEs and code
# are out of scope.
#
# Why a receipt rather than an audit here: the audit has to run somewhere with
# no authorship history. A model reviewing its own output misses 64.5% of the
# errors it catches in someone else's, and a second review inside the writing
# session scores worse than no second review at all (dotfiles/docs/claude/
# instructing-claude.md § 7). So the gate cannot BE the audit — it can only
# refuse a commit that has not had one.
#
# The receipt is keyed to content, not to filenames: every staged rule file's
# blob hash, sorted, hashed together. Edit a file after auditing and the key
# changes, so the gate re-arms. There is no "I already audited" to assert.
#
# Usage:  rule-audit-gate.sh <repo-root>
# Exit:   0 clean or nothing in scope · 1 audit required (prints how)
#
# To audit and record a receipt, run the fresh-context auditor:
#   ~/dotfiles/scripts/rule-audit.sh <repo-root>
# It reads every staged rule file whole, plus every file they cite and every
# file that cites them, in a session that did not write them.

set -uo pipefail

root="${1:?usage: rule-audit-gate.sh <repo-root>}"
[ -d "$root/.git" ] || [ -f "$root/.git" ] || exit 0

# Staged rule files. A skill's own scripts count: a skill and the script it
# names are one instruction.
staged=$(git -C "$root" diff --cached --name-only --diff-filter=ACMR \
  | grep -E '(^|/)(CLAUDE\.md$|AGENTS\.md$)|(^|/)(skills|agents|output-styles)/.*\.(md|sh)$' \
  || true)
[ -n "$staged" ] || exit 0

# Content key: the blob hash of each staged rule file, in path order.
key=$(
  printf '%s\n' "$staged" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s %s\n' "$f" "$(git -C "$root" rev-parse ":$f" 2>/dev/null || echo missing)"
  done | shasum -a 256 | cut -d' ' -f1
)

receipt="$root/.git/rule-audit-receipt"
[ -f "$receipt" ] && [ "$(cat "$receipt" 2>/dev/null)" = "$key" ] && exit 0

count=$(printf '%s\n' "$staged" | grep -c . || true)
{
  printf '%s\n' "$staged" | sed 's/^/  /'
  echo
  echo "rule-audit: $count staged rule file(s) above have no audit receipt for their current content."
  echo "Run the auditor, which reads them in a session that did not write them:"
  echo
  echo "  bash ~/dotfiles/scripts/rule-audit.sh $root"
  echo
  echo "It writes the receipt on a clean pass. Editing a file afterwards re-arms this gate."
} >&2
exit 1
