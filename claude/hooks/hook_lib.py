# hook_lib.py — predicates shared by the python blocks inside the sibling hooks.
# Imported with sys.path pointed at this directory; not a hook itself.
#
#   behavioral(path)   True for text that prescribes behaviour: a CLAUDE.md, or a
#                      skill / agent file and the references it ships. A session doc
#                      (testsuite, RCA, ADR, handoff) records what happened and is out.
#   skill_file(name)   the SKILL.md a bare skill name resolves to — the project's
#                      .claude/skills first, then the global ~/.claude/skills — or None.
import os

GLOBAL_SKILLS = os.path.expanduser("~/.claude/skills")
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
SKILL_TREES = (
    os.path.join(PROJECT_DIR, ".claude", "skills"),
    GLOBAL_SKILLS,
)


def behavioral(path):
    r = os.path.realpath(path)
    return (os.path.basename(r) == "CLAUDE.md"
            or f"{os.sep}claude{os.sep}" in r and (
                f"{os.sep}skills{os.sep}" in r or f"{os.sep}agents{os.sep}" in r))


def skill_file(name):
    for tree in SKILL_TREES:
        p = os.path.join(tree, name, "SKILL.md")
        if os.path.isfile(p):
            return p
    return None
