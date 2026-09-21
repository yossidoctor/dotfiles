#!/bin/bash
# Stop hook: block a stop while a rule file this turn edited carries a citation
# that no longer resolves. Scope is behavioural text — CLAUDE.md, a skill, an
# agent definition, a reference file a skill ships — since those bind every
# later session; `behavioral` (hook_lib.py) is the predicate.
#
# This checks references and nothing else: a second review in the same context
# scores worse than reviewing once, and a model reviewing its own output misses
# most of what it catches in someone else's (dotfiles/docs/claude/
# instructing-claude.md § 7). The judgment-bearing audit is rule-audit.sh at
# commit time, in a session that did not write the files; what is here is the
# part a script decides outright.
#
# Stop is the right event for it: it fires exactly when the claim of done is
# made, and a dangling `§` cite is free to fix in that turn and expensive to
# find a week later. The check is `check-doc-refs.sh`, which the project owns —
# no findings, no block, and a project without the script never blocks.
#
# At most one block per turn, enforced by a marker file holding the audited
# turn number and written on every stop. The turn is the unit because it
# separates the fix — which lands in the turn the block created, and must not
# re-arm it — from a later round of edits. Turns are counted from transcript
# user rows carrying prose: tool results and hook injections replay as user
# rows too, and a block's own reason replays under the harness's "Stop hook
# feedback:" prefix, so counting either would number a turn this gate
# manufactured and re-block forever.
#
# The block reason prints under the harness's "Stop hook error:" prefix, so it
# carries the findings themselves — they are short, and a file to open would be
# ceremony for a two-line list.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_input

transcript="$HOOK_TRANSCRIPT"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

# A rule edit is an Edit/Write row whose file_path is markdown, or a Bash row
# naming a markdown file. A transcript carrying neither has nothing to audit,
# and grep settles that before python parses every row of it.
grep -qE '"name":"(Edit|Write|MultiEdit|NotebookEdit)".*"file_path":"[^"]*\.(md|mdc|mdx)"|"name":"Bash".*\.(md|mdc|mdx)\b' "$transcript" || exit 0

# Turn number, and whether this turn edited a rule file at all.
read -r turn edited <<EOF
$(python3 - "$transcript" "$(dirname "${BASH_SOURCE[0]}")" <<'PY'
import json, os, re, sys

sys.path.insert(0, sys.argv[2])
from hook_lib import behavioral

rows = []
for line in open(sys.argv[1], errors="replace"):
    try:
        rows.append(json.loads(line))
    except Exception:
        pass

start = 0
turn = 0
for i, d in enumerate(rows):
    m = d.get("message") or {}
    if d.get("type") == "user" and m.get("role") == "user":
        c = m.get("content")
        if isinstance(c, str):
            text = c
        elif isinstance(c, list):
            text = " ".join(b.get("text", "") for b in c if isinstance(b, dict))
        else:
            text = ""
        if (text.strip() and "tool_use_id" not in json.dumps(c)[:200]
                and not text.lstrip().startswith("Stop hook feedback:")):
            start = i
            turn += 1

DOC = (".md", ".mdc", ".mdx")
WRITERS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

edited = 0
for d in rows[start:]:
    c = (d.get("message") or {}).get("content")
    if not isinstance(c, list):
        continue
    for b in c:
        if not isinstance(b, dict) or b.get("type") != "tool_use":
            continue
        p = (b.get("input") or {}).get("file_path") or ""
        if b.get("name") in WRITERS and p.endswith(DOC) and behavioral(p):
            edited = 1
        if b.get("name") == "Bash":
            cmd = (b.get("input") or {}).get("command") or ""
            if re.search(r"(?:^|[|&;(]|\s)(?:sed|perl|awk|python3?|tee|dd|truncate|install|cp|mv)\b", cmd) \
               or re.search(r">>?\s*[\w./~-]+\.(?:md|mdc|mdx)\b", cmd):
                for tok in re.findall(r"[\w./~-]+\.(?:md|mdc|mdx)\b", cmd):
                    if behavioral(os.path.expanduser(tok)):
                        edited = 1
print(turn, edited)
PY
)
EOF

[ "${edited:-0}" = "1" ] || exit 0

checker="${CLAUDE_PROJECT_DIR:-${HOOK_CWD:-$PWD}}/scripts/check-doc-refs.sh"
[ -x "$checker" ] || exit 0

refs=$("$checker" 2>/dev/null | grep -E '^  (BROKEN|WARN|MISFILED|LINENO|NOSYM|NOFILE) ')
[ -n "$refs" ] || exit 0

fp_file="/tmp/claude-docs-audited-${HOOK_SESSION_ID:-default}.fp"
if [ -n "${turn:-}" ]; then
  seen=$(cat "$fp_file" 2>/dev/null)
  printf '%s' "$turn" > "$fp_file" 2>/dev/null || true
  [ "$seen" = "$turn" ] && exit 0
fi

python3 - "$refs" <<'PY'
import json, sys
print(json.dumps({
    "decision": "block",
    "reason": "A citation this turn edited no longer resolves. Fix each, then stop:\n" + sys.argv[1],
}))
PY
exit 0
