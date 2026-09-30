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
# it reads the whole project, so a hard failure anywhere in it blocks once a
# rule edit this turn has made it worth re-reading; § warnings never block.
#
# The transcript is read incrementally: a state file per session holds the
# byte offset already parsed, the turn number reached, whether that turn has
# edited a rule file, and the turn last blocked, so each stop parses only the
# rows appended since the last one. Turns are counted from transcript user rows
# carrying prose: tool results and hook injections replay as user rows too, and
# a block's own reason replays under the harness's "Stop hook feedback:" prefix,
# so counting either would number a turn this gate manufactured and re-block
# forever. At most one block per turn: the fix lands in the turn the block
# created and must not re-arm it.
#
# The block reason prints under the harness's "Stop hook error:" prefix, so it
# carries the findings themselves — they are short, and a file to open would be
# ceremony for a two-line list.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_input

transcript="$HOOK_TRANSCRIPT"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

state="${TMPDIR:-/tmp}/claude-docs-audited-${HOOK_SESSION_ID:-default}.json"

# Turn number, whether this turn edited a rule file, and the turn last blocked.
read -r turn edited blocked <<EOF2
$(python3 - "$transcript" "$state" "$(dirname "${BASH_SOURCE[0]}")" <<'PY'
import json, os, re, sys

sys.path.insert(0, sys.argv[3])
from hook_lib import behavioral

tpath, spath = sys.argv[1], sys.argv[2]
st = {"offset": 0, "turn": 0, "edited": 0, "blocked": -1}
try:
    st.update(json.load(open(spath)))
except Exception:
    pass
if os.path.getsize(tpath) < st["offset"]:
    st.update({"offset": 0, "turn": 0, "edited": 0})

DOC = (".md", ".mdc", ".mdx")
WRITERS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
BASH_WRITER = re.compile(r"(?:^|[|&;(]|\s)(?:sed|perl|awk|python3?|tee|dd|truncate|install|cp|mv)\b")
BASH_REDIRECT = re.compile(r">>?\s*[\w./~-]+\.(?:md|mdc|mdx)\b")
BASH_TOKEN = re.compile(r"(?<![\w$}./~-])[\w./~-]+\.(?:md|mdc|mdx)\b")

with open(tpath, "rb") as f:
    f.seek(st["offset"])
    for raw in f:
        try:
            d = json.loads(raw.decode(errors="replace"))
        except Exception:
            continue
        m = d.get("message") or {}
        c = m.get("content")
        if d.get("type") == "user" and m.get("role") == "user":
            text = c if isinstance(c, str) else " ".join(
                b.get("text", "") for b in c if isinstance(b, dict)) if isinstance(c, list) else ""
            if (text.strip() and "tool_use_id" not in json.dumps(c)[:200]
                    and not text.lstrip().startswith("Stop hook feedback:")):
                st["turn"] += 1
                st["edited"] = 0
        if not isinstance(c, list):
            continue
        for b in c:
            if not isinstance(b, dict) or b.get("type") != "tool_use":
                continue
            p = (b.get("input") or {}).get("file_path") or ""
            if b.get("name") in WRITERS and p.endswith(DOC) and behavioral(p):
                st["edited"] = 1
            if b.get("name") == "Bash":
                cmd = (b.get("input") or {}).get("command") or ""
                if BASH_WRITER.search(cmd) or BASH_REDIRECT.search(cmd):
                    for tok in BASH_TOKEN.findall(cmd):
                        if behavioral(os.path.join(d.get("cwd") or "", os.path.expanduser(tok))):
                            st["edited"] = 1
    st["offset"] = f.tell()
json.dump(st, open(spath, "w"))
print(st["turn"], st["edited"], st["blocked"])
PY
)
EOF2

[ "${edited:-0}" = "1" ] || exit 0
[ "${blocked:-}" = "${turn:-}" ] && exit 0

checker="${CLAUDE_PROJECT_DIR:-${HOOK_CWD:-$PWD}}/scripts/check-doc-refs.sh"
[ -x "$checker" ] || exit 0

refs=$("$checker" 2>/dev/null | grep -E '^  [A-Z]+  ' | grep -v '^  WARN  ')
[ -n "$refs" ] || exit 0

jq -c --arg t "$turn" '.blocked = ($t | tonumber)' "$state" > "$state.tmp" 2>/dev/null && mv "$state.tmp" "$state"
jq -cn --arg r "$refs" '{decision: "block", reason: ("This turn edited a rule file, and check-doc-refs.sh now finds citations anywhere in the project that do not resolve. Fix each one this turn wrote; one another session wrote is reported to the user, not rewritten:\n" + $r)}'
exit 0
