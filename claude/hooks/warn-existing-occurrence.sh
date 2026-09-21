#!/bin/bash
# PreToolUse Edit|Write hook: when the target is a rule file, hand back the lines
# where the tokens the edit adds already live, and the first line of every section
# the edit cites. Context only — never a decision.
#
# The recurring defect in rule text is a sentence that already exists: the same idea
# a second time, or a citation with a paraphrase of the cited section beside it. Both
# are properties of the whole file, and neither is visible in the Edit that adds the
# second copy — the other occurrence is out of view when the sentence is written.
# Putting that occurrence in view at the moment of the Edit is the whole mechanism;
# CLAUDE.md § Strict single SoT and ~/.claude/rules/instructional-text.md § Every
# behavioral rule carries three roles say what to do with it.
#
# Tokens are the backticked spans of new_string that old_string does not already
# carry, grepped against the file on disk with old_string's own lines excluded. A
# token found more than six times is a vocabulary word, not a second copy, and is
# dropped. A `skill` § Heading cite resolves to that skill's SKILL.md (project tree
# first, then ~/.claude/skills); a `global CLAUDE.md §` cite to ~/.claude/CLAUDE.md,
# any other `<dir> CLAUDE.md §` cite to the project's CLAUDE.md; a bare § to the
# file being edited. The cited line is printed so the author sees what is already
# owned there.
#
# A Write over an existing file replaces content the tokens would match against, so
# only its cites are checked. A Write creating a NEW file has no such content: its
# tokens are scanned against the rule files already in its own skill or agent dir,
# which is where a value it restates instead of citing already lives.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_input
case "$HOOK_TOOL_NAME" in Edit|Write) ;; *) exit 0 ;; esac
[ -n "$HOOK_FILE_PATH" ] || exit 0

# The python block below imports hook_lib and reads files, so it is the expensive
# path; it exits immediately unless the target is behavioral markdown. Gate on the
# same predicate here (hook_lib.behavioral, plus the .md* extension the block
# requires) so an ordinary code edit never pays the interpreter start.
case "$HOOK_FILE_PATH" in
  *.md|*.mdc|*.mdx) ;;
  *) exit 0 ;;
esac
real=$(realpath "$HOOK_FILE_PATH" 2>/dev/null) || real="$HOOK_FILE_PATH"
case "$real" in
  */CLAUDE.md) ;;
  */claude/*|*/.claude/*)
    case "$real" in */skills/*|*/agents/*|*/rules/*) ;; *) exit 0 ;; esac ;;
  *) exit 0 ;;
esac

ctx=$(HOOK_INPUT="$HOOK_INPUT" python3 - "$(dirname "${BASH_SOURCE[0]}")" <<'PY'
import json, os, re, sys

sys.path.insert(0, sys.argv[1])
from hook_lib import behavioral, skill_file, PROJECT_DIR

d = json.loads(os.environ["HOOK_INPUT"])
ti = d.get("tool_input") or {}
path = ti.get("file_path") or ""
if not (path.endswith((".md", ".mdc", ".mdx")) and behavioral(path)):
    sys.exit(0)

is_edit = d.get("tool_name") == "Edit"
new = (ti.get("new_string") if is_edit else ti.get("content")) or ""
old = ti.get("old_string") or ""
creating = not os.path.isfile(path)
if creating and is_edit:
    sys.exit(0)
lines = [] if creating else open(path, errors="replace").read().split("\n")
old_frags = [l.strip() for l in old.split("\n") if l.strip()]
replaced = lambda line: any(f in line for f in old_frags)
home = os.path.expanduser("~")
rel = lambda p: p.replace(home, "~")
out = []

# The rule files a new file will sit among: its own skill or agent dir, walked whole.
def siblings(p):
    d = os.path.dirname(os.path.realpath(p))
    while d != os.path.dirname(d):
        if os.path.basename(os.path.dirname(d)) in ("skills", "agents"):
            break
        d = os.path.dirname(d)
    else:
        return []
    found = []
    for root, _, files in os.walk(d):
        for f in sorted(files):
            if f.endswith((".md", ".mdc", ".mdx")):
                fp = os.path.join(root, f)
                if os.path.realpath(fp) != os.path.realpath(p):
                    found.append(fp)
    return found

if is_edit or creating:
    seen = []
    for t in re.findall(r"`([^`\n]{3,60})`", new):
        if t in old or t in seen:
            continue
        seen.append(t)
    sources = [(path, lines)] if is_edit else [
        (f, open(f, errors="replace").read().split("\n")) for f in siblings(path)]
    for t in seen[:8]:
        hits = [(f, i + 1, l.strip()) for f, fl in sources
                for i, l in enumerate(fl) if t in l and not replaced(l)]
        if not hits or len(hits) > 6:
            continue
        shown = "; ".join(
            (f"L{n}" if is_edit else f"{rel(f)}:L{n}") + f": {l[:140]}"
            for f, n, l in hits[:3])
        more = f" (+{len(hits) - 3} more)" if len(hits) > 3 else ""
        out.append(f"`{t}` is already at {shown}{more}")

# A cite runs into the prose after it, so the heading is the longest leading span of
# the phrase that some heading or bold lead in the target starts with.
CITE = re.compile(r"(?:`([a-z0-9-]+)`\s+)?(?:(global|~/\.claude/|~/[A-Za-z0-9_-]+/|project)\s*CLAUDE\.md\s+)?§\s+([A-Z][^.;:,)`*§\n]*)")
for m in CITE.finditer(new):
    if m.group(0) in old:
        continue
    skill, cl, phrase = m.group(1), m.group(2), m.group(3).strip()
    target = path
    if skill:
        target = skill_file(skill) or path
    elif cl:
        target = os.path.expanduser("~/.claude/CLAUDE.md") if cl in ("global", "~/.claude/") \
            else os.path.join(PROJECT_DIR, "CLAUDE.md")
    try:
        tlines = open(target, errors="replace").read().split("\n")
    except OSError:
        continue
    words = phrase.split()
    hit = None
    while words and not hit:
        pat = re.compile(r"^(?:#{1,6}\s+|\s*-\s+\*\*)" + re.escape(" ".join(words)), re.I)
        hit = next(((i + 1, l.strip()) for i, l in enumerate(tlines) if pat.match(l)), None)
        if not hit:
            words.pop()
    where = rel(target)
    if hit:
        out.append(f"§ {' '.join(words)} ({where}:L{hit[0]}) reads: {hit[1][:200]}")
    else:
        out.append(f"§ {phrase}: no heading or bold lead in {where} starts with it")

if out:
    owner = "its siblings already own" if creating else "the file already carries"
    print(f"Before this edit lands — what {owner} (edit the owning line, "
          "or cite without restating):\n" + "\n".join(out[:20]))
PY
)
[ -n "$ctx" ] && additional_context PreToolUse "$ctx"
exit 0
