#!/usr/bin/env bash
# Audit the staged rule files in a repo, in a Claude session that did not write
# them, and record a receipt on a clean pass.
#
# The fresh session is the whole point. A model reviewing its own output misses
# 64.5% of the errors it catches in someone else's, and a second pass inside the
# writing session scores worse than one pass; a separate context beats both
# (dotfiles/docs/claude/instructing-claude.md § 7, with sources). So this runs
# `claude -p`, which starts clean: no memory of the edits, no reasoning that
# produced them, nothing to defend.
#
# It reads whole files, never a diff. Two of the defect classes that motivated
# this gate are invisible in a diff: a line the turn did not touch but whose
# meaning the change broke, and a file the change never edited at all but whose
# claims it falsified. So the input is every staged rule file, plus the closure
# — every rule file they cite, and every rule file that cites them.
#
# Usage:  rule-audit.sh <repo-root>
# Exit:   0 clean, receipt written · 1 findings printed, no receipt · 2 usage
#
# The receipt keys on staged content (rule-audit-gate.sh owns its shape), so
# editing anything afterwards re-arms the gate. There is no way to assert a
# pass this script did not produce.

set -uo pipefail

root="${1:?usage: rule-audit.sh <repo-root>}"
command -v claude >/dev/null || { echo "rule-audit: claude not on PATH" >&2; exit 2; }

staged=$(git -C "$root" diff --cached --name-only --diff-filter=ACMR \
  | grep -E '(^|/)(CLAUDE\.md$|AGENTS\.md$)|(^|/)(skills|agents|output-styles)/.*\.(md|sh)$' \
  || true)
[ -n "$staged" ] || { echo "rule-audit: nothing staged in scope."; exit 0; }

# The closure: files the staged set cites, and files that cite the staged set.
# Both directions matter — a change can break a file it never touched.
closure=$(
  printf '%s\n' "$staged" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    # what this file cites
    grep -ohE '[A-Za-z0-9_./~-]+\.(md|sh)' "$root/$f" 2>/dev/null || true
    # what cites this file
    base=$(basename "$f")
    git -C "$root" grep -l -F "$base" -- '*.md' '*.sh' 2>/dev/null || true
  done | sed "s|^$root/||" | sort -u
)

# Keep only real rule files in this repo, minus the staged ones themselves.
related=$(
  printf '%s\n' "$closure" | while IFS= read -r c; do
    [ -n "$c" ] || continue
    c=${c#./}
    [ -f "$root/$c" ] || continue
    printf '%s\n' "$c"
  done | grep -E '(^|/)(CLAUDE\.md$|AGENTS\.md$)|(^|/)(skills|agents|output-styles)/.*\.(md|sh)$' \
    | sort -u | comm -23 - <(printf '%s\n' "$staged" | sort -u) || true
)

prompt=$(cat <<EOF
Audit these rule files. You did not write them — read them as a reader who has
never seen them before, and judge what is on the page rather than what was
meant.

Read each STAGED file whole, start to end. Not a diff: two defect classes hide
there — a line nobody touched whose meaning a change elsewhere broke, and a
file that was never edited but whose claims are now false.

STAGED (the files this commit adds or changes):
$(printf '%s\n' "$staged" | sed "s|^|  $root/|")

RELATED (cite the staged files, or are cited by them — read these too, and
check that every claim they make about a staged file still holds):
$(printf '%s\n' "$related" | sed "s|^|  $root/|" | head -40)

Judge each staged file against $HOME/.claude/CLAUDE.md § Hard rules — open it
and work through the rules rather than recalling them. Then, specifically:

1. Any statement about how a script behaves: RUN that script and check. Two
   false claims of exactly this kind shipped in one session because nobody
   executed the thing they described.
2. Any claim about another file: open that file and verify it still says what
   the claim says.
3. One idea stated in two places — a paragraph restating the one above it, a
   sentence whose only job is to hand off to text elsewhere.
4. A rule whose falsifier or carve-out no longer matches the rule it follows.
5. A sentence whose deletion would change no behaviour.

Tag every finding CORRECTNESS or STYLE, and report it as:
  [CORRECTNESS|STYLE] FILE:LINE — what is wrong — what it should say.

CORRECTNESS is a statement that is false about something executable or
checkable: a command that errors as written, a claim about what a script does
that running it disproves, a cited section or path that does not resolve, a
count or enumeration contradicted by the thing it counts. A reader who follows
it is misled into a wrong action.

STYLE is everything else — a falsifier narrower than its rule, an idea stated
in two places, a sentence that changes no behaviour, wording. Real findings,
but a reader following the text still lands in the right place.

If a file is genuinely clean, say so and move on; do not invent findings.
End your reply with exactly one line:
  "AUDIT CLEAN"                 no findings at all
  "AUDIT BLOCKING: <n>"         at least one CORRECTNESS finding, n = its count
  "AUDIT ADVISORY: <n>"         only STYLE findings, n = their count
EOF
)

n_staged=$(printf '%s\n' "$staged" | grep -c . || true)
echo "rule-audit: auditing $n_staged staged rule files in a fresh session..."
out=$(claude -p "$prompt" 2>&1) || { printf '%s\n' "$out" >&2; echo "rule-audit: the audit session failed." >&2; exit 1; }
printf '%s\n' "$out"

# A style finding does not withhold the receipt. The bar "zero findings" is
# unreachable against a rule set this dense: every fix is new prose and new
# prose is new surface, so the loop never terminates and finished work sits
# uncommitted behind a narrower falsifier. What the gate exists to stop is a
# false claim about something executable — the class that misleads a reader
# into a wrong action, and the class a fresh session catches by RUNNING things.
verdict=$(printf '%s' "$out" | tail -3 | grep -oE 'AUDIT (CLEAN|BLOCKING|ADVISORY)' | tail -1)
case "$verdict" in
  "AUDIT CLEAN"|"AUDIT ADVISORY")
    key=$(
      printf '%s\n' "$staged" | while IFS= read -r f; do
        [ -n "$f" ] || continue
        printf '%s %s\n' "$f" "$(git -C "$root" rev-parse ":$f" 2>/dev/null || echo missing)"
      done | shasum -a 256 | cut -d' ' -f1
    )
    # A clean pass pins the exact content. An advisory pass pins the file set
    # instead, so fixing the style findings it just reported does not re-arm the
    # gate against that very fix; the gate re-arms the moment a file outside the
    # set is staged. Its shape is rule-audit-gate.sh's to read.
    if [ "$verdict" = "AUDIT CLEAN" ]; then
      printf '%s' "$key" > "$root/.git/rule-audit-receipt"
    else
      { echo advisory; printf '%s\n' "$staged"; } > "$root/.git/rule-audit-receipt"
    fi
    echo
    if [ "$verdict" = "AUDIT CLEAN" ]; then
      echo "rule-audit: clean — receipt written. The commit will pass."
    else
      echo "rule-audit: style findings only (above) — receipt written, the commit will pass."
      echo "Fix them on the next touch of these files."
    fi
    exit 0
    ;;
esac

echo
echo "rule-audit: a correctness finding above blocks the commit — something the text claims is false about a command, a script, a path or a count. Fix those, re-stage, run again; style findings alone would have passed." >&2
exit 1
