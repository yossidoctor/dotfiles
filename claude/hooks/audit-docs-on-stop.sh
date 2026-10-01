#!/bin/bash
# Stop hook: block a stop while a rule file this turn edited carries a citation
# that no longer resolves. Scope is behavioural text — CLAUDE.md, a skill, an
# agent definition, a reference file a skill ships, under a claude/ or .claude/
# tree — since those bind every later session; `behavioral` is the predicate.
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
# byte offset already parsed and whether the current turn has edited a rule
# file, so each stop parses only the rows appended since the last one. A user
# row carrying prose opens a new turn; tool results replay as user rows too and
# do not. At most one block per turn: the payload's stop_hook_active is true on
# the stop that follows a block, and the fix that block asked for must not
# re-arm it.
#
# The block reason prints under the harness's "Stop hook error:" prefix, so it
# carries the findings themselves — they are short, and a file to open would be
# ceremony for a two-line list.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_input
[ "$(printf '%s' "$HOOK_INPUT" | jq -r '.stop_hook_active')" = true ] && exit 0

transcript="$HOOK_TRANSCRIPT"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

state="${TMPDIR:-/tmp}/claude-docs-audited-${HOOK_SESSION_ID:-default}.json"

edited=$(python3 - "$transcript" "$state" <<'PY'
import json, os, re, sys

def behavioral(path):
    r = os.path.realpath(path)
    return (os.path.basename(r) == "CLAUDE.md"
            or (f"{os.sep}claude{os.sep}" in r or f"{os.sep}.claude{os.sep}" in r) and (
                f"{os.sep}skills{os.sep}" in r or f"{os.sep}agents{os.sep}" in r
                or f"{os.sep}rules{os.sep}" in r))

tpath, spath = sys.argv[1], sys.argv[2]
st = {"offset": 0, "edited": 0}
try:
    st.update(json.load(open(spath)))
except Exception:
    pass
if os.path.getsize(tpath) < st["offset"]:
    st.update({"offset": 0, "edited": 0})

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
            if text.strip() and "tool_use_id" not in json.dumps(c)[:200]:
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
print(st["edited"])
PY
)

[ "${edited:-0}" = "1" ] || exit 0

checker="${CLAUDE_PROJECT_DIR:-${HOOK_CWD:-$PWD}}/scripts/check-doc-refs.sh"
[ -x "$checker" ] || exit 0

refs=$("$checker" 2>/dev/null | grep -E '^  [A-Z]+  ' | grep -v '^  WARN  ')
[ -n "$refs" ] || exit 0

jq -cn --arg r "$refs" '{decision: "block", reason: ("This turn edited a rule file, and check-doc-refs.sh now finds citations anywhere in the project that do not resolve. Fix each one this turn wrote; one another session wrote is reported to the user, not rewritten:\n" + $r)}'
exit 0
