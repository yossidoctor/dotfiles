#!/usr/bin/env bash
# Stop hook: block a stop while a rule file's cumulative diff is unaudited, handing
# that diff back so the audit sees the unit that changed. Scope is behavioural text
# — CLAUDE.md, a skill, an agent definition, a reference file a skill ships — since
# those carry prescribe/carve-out/falsifier and bind every later session; `behavioral`
# below is the predicate, and a session doc is out of scope by it.
#
# Stop is the only event that means no further Edit is coming, which is what makes
# it the sole correct place for this audit: a PostToolUse hook cannot know whether
# more edits follow, so its scope is always one Edit — and one Edit is the wrong
# unit. A rule split across three Edits passes all three slices while duplicating a
# clause, stranding a sentence whose only job was to hand off to another Edit's
# text, or chaining one more OR per case. Each clean slice then reads as evidence
# the whole is clean, so confidence rises as the defect lands. The unit that
# catches those is whole file, whole turn.
#
# Blocking, not advising. Stop fires exactly when the claim of done is made, and
# advisory text there is a reminder to audit at a scope the reader already believes
# they cleared; a block spends one turn and puts the real diff in context instead.
#
# At most one block per turn that edits rule text, enforced by a marker file holding
# the audited turn number and written on every stop. The turn is the unit because it
# separates an audit's own fixes — which land in the turn the block created, and must
# not re-arm it — from a later round of edits, which is new text no audit has seen. A
# gate keyed on "the diff changed" fails the first half and loops; one keyed on "any
# prior stop" fails the second, leaving every later round of a long session unaudited.
# It is also why the check is not `stop_hook_active`: that flag covers only the
# continuation a block creates and clears on the next user message, leaving a
# still-uncommitted doc to be re-blocked over an audit already done. Turns are
# counted from the transcript's user rows that carry prose: tool results and hook
# injections replay as user rows too, and a block's own reason replays under the
# harness's "Stop hook feedback:" prefix — counting either would number a turn
# this gate manufactured and re-block forever.
#
# A file qualifies on two counts, and needs both: it differs from what the turn
# started with, and this turn names it. The baseline is the copy
# snapshot-rule-files.sh took at the prompt, which every rule file has; a diff
# against it survives the turn committing (HEAD moves, the copy does not) and
# ignores hunks other sessions left uncommitted. HEAD is the baseline only for a
# file the snapshot never saw — one created this turn, or a session whose prompt
# predates the snapshot hook — and a tracked file with an empty HEAD diff there is
# clean, not baseline-less, and is dropped. The turn's paths alone miss a file
# rewritten by a sed or a script, since a file_path arrives only on a tool call — so
# a Bash command's own text is scanned for paths too. A file_path counts only from a
# writing tool: Read names a file the same way and rewrites nothing. The transcript
# supplies the turn boundary, its cwds, and those paths.
#
# Diffs resolve the symlink first: a rule file reaches ~/.claude and the project's
# .claude as a link out of a rule repo, and the link's own directory may track
# nothing. The rule repos are hook_rule_roots (hook-lib.sh).
#
# The brief also carries check-doc-refs.sh's findings: a `§` cite or a file path that
# stopped resolving is a defect of the same turn, and the checker sees it while the
# author does not. An edited doc gone from disk leaves nothing to audit and never
# blocks. The block reason prints to the terminal under the harness's "Stop hook
# error:" prefix, so it is one line naming the brief file; the prompt and the diff
# go in that file, which only Claude opens.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

GLOBAL_RULES="$HOME/.claude/CLAUDE.md"
STYLE_RULES="$HOME/.claude/output-styles/straight-answers.md"

hook_read_input

transcript="$HOOK_TRANSCRIPT"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

files=$(python3 - "$transcript" "$(dirname "${BASH_SOURCE[0]}")" <<'PY'
import json, os, re, subprocess, sys

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

edited, roots = [], set()
for d in rows[start:]:
    cwd = d.get("cwd")
    if cwd:
        roots.add(cwd)
    c = (d.get("message") or {}).get("content")
    if not isinstance(c, list):
        continue
    for b in c:
        if not isinstance(b, dict) or b.get("type") != "tool_use":
            continue
        p = (b.get("input") or {}).get("file_path") or ""
        if b.get("name") in WRITERS and p.endswith(DOC) and behavioral(p):
            edited.append(p)
        if b.get("name") == "Bash":
            cmd = (b.get("input") or {}).get("command") or ""
            if re.search(r"(?:^|[|&;(]|\s)(?:sed|perl|awk|python3?|tee|dd|truncate|install|cp|mv)\b", cmd) \
               or re.search(r">>?\s*[\w./~-]+\.(?:md|mdc|mdx)\b", cmd):
                for tok in re.findall(r"[\w./~-]+\.(?:md|mdc|mdx)\b", cmd):
                    tok = os.path.expanduser(tok)
                    if behavioral(tok):
                        edited.append(tok)

def git(root, *args):
    try:
        out = subprocess.run(("git", "-C", root) + args, capture_output=True,
                             text=True, timeout=15)
        return out.stdout if out.returncode == 0 else ""
    except Exception:
        return ""

mine = {os.path.realpath(p) for p in edited}
found = []
for root in sorted(roots):
    top = git(root, "rev-parse", "--show-toplevel").strip()
    if not top:
        continue
    for rel in git(top, "diff", "--name-only", "HEAD").splitlines():
        if rel.endswith(DOC):
            full = os.path.join(top, rel)
            if behavioral(full):
                found.append(full)

found.extend(edited)  # an untracked doc has no HEAD entry to be found under

seen, out = set(), []
for p in found:
    if not p or not os.path.isfile(p):
        continue
    real = os.path.realpath(p)
    if real in mine and real not in seen:
        seen.add(real)
        out.append(p)
print(turn)
print("\n".join(out))
PY
)
turn=$(printf '%s' "$files" | head -1)
files=$(printf '%s' "$files" | tail -n +2)
[ -n "$files" ] || exit 0

report=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  r=$(realpath "$f" 2>/dev/null) || r="$f"
  [ -n "$r" ] || r="$f"
  root=$(git -C "$(dirname "$r")" rev-parse --show-toplevel 2>/dev/null) || root=""
  rel="${r#$root/}"
  snap="/tmp/claude-rule-snapshot-${HOOK_SESSION_ID:-default}/$(basename "${root:-/}")/$rel"
  if [ -n "$root" ] && [ -f "$snap" ]; then
    d=$(diff -U3 --label "a/$rel" --label "b/$rel" "$snap" "$r" 2>/dev/null)
    [ -n "$d" ] || continue
    report="$report

=== $f ===
$d"
    continue
  fi
  d=$(git -C "$(dirname "$r")" diff -U3 -- "$(basename "$r")" 2>/dev/null)
  if [ -z "$d" ]; then
    if git -C "$(dirname "$r")" ls-files --error-unmatch -- "$(basename "$r")" >/dev/null 2>&1; then
      continue
    fi
    d=$(git -C "$(dirname "$r")" diff -U3 --no-index /dev/null "$(basename "$r")" 2>/dev/null | head -400)
    [ -n "$d" ] && d="(no tracked baseline — whole file follows)
$d"
  fi
  [ -n "$d" ] || d="(no diff available — audit the file's own text at $f)"
  report="$report

=== $f ===
$d"
done <<EOF
$files
EOF

[ -n "$report" ] || exit 0

checker="${CLAUDE_PROJECT_DIR:-${HOOK_CWD:-$PWD}}/scripts/check-doc-refs.sh"
refs=""
[ -x "$checker" ] && refs=$("$checker" 2>/dev/null | grep -E '^  (BROKEN|WARN|MISFILED|LINENO|NOSYM|NOFILE) ')
[ -n "$refs" ] && report="$report

=== check-doc-refs.sh — a cite or path that no longer resolves ===
$refs"

fp_file="/tmp/claude-docs-audited-${HOOK_SESSION_ID:-default}.fp"
if [ -n "$turn" ]; then
  seen=$(cat "$fp_file" 2>/dev/null)
  printf '%s' "$turn" > "$fp_file" 2>/dev/null || true
  [ "$seen" = "$turn" ] && exit 0
fi

brief_file="/tmp/claude-doc-audit-${HOOK_SESSION_ID:-default}.md"

python3 - "$GLOBAL_RULES" "$report" "$brief_file" "$STYLE_RULES" <<'PY'
import json, sys
rules, report, brief_path, style_rules = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
brief = f"""A rule file changed this turn. Audit the CUMULATIVE diff below — not the last Edit.

Each Edit was already audited in isolation and each passed. That is exactly what a
per-Edit audit can tell you, and it does not compose: the defects that survive are
the ones no single Edit contains. Hunt those, against this diff:

- One idea stated twice across two Edits — a sentence that only hands off to text
  another Edit added, a second paragraph restating the first, a heading whose body
  the next paragraph repeats. Both read fine alone; together one is dead.
- A falsifier that grew an OR per case, or a carve-out naming the one shape that
  prompted it, assembled across calls.
- A fix that landed beside the rule it belongs to because the rewrite happened in
  a different Edit than the addition.
- A step, section, or numbered list split when the change was one unit — renumbering
  is the tell.
- Sentences that would leave behaviour unchanged if deleted. Judge the sentence, not
  the intent; 'true' is not the bar.

Rule source — open and read it, do not audit from memory: {rules}
  § Making things — Is it true · Does it live in one place · Is it the minimal shape ·
  How the edit lands.
Also open {style_rules} — § Communication style lives there, and a subagent does not
load it from an output style.

Fix what you find, then report. If the diff is genuinely clean, say so plainly and
stop — a clean verdict against THIS unit is the thing that was missing, not a
formality to repeat.
{report}"""

with open(brief_path, "w") as fh:
    fh.write(brief)

reason = f"doc-audit gate: audit the rule diff. Brief: {brief_path}"
print(json.dumps({"decision": "block", "reason": reason}))
PY
exit 0
