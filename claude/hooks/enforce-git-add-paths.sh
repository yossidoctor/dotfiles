#!/usr/bin/env bash
# PreToolUse Bash hook: block a `git add` that stages by sweep rather than by
# path — `-A`, `--all`, `-u`, and the tree-wide operands `.`, `./`, `..`,
# `../`, `:/`, `:(top)`.
#
# Every tree here has other sessions working in it, so a file this session
# touched routinely carries someone else's uncommitted work as well. A sweep
# stages all of it, and the damage is only visible in the commit that follows.
# Naming paths is the whole defence, and it is the shape a script can check —
# so it is checked here rather than asked for in prose (the reasoning:
# dotfiles/docs/claude/instructing-claude.md § 2).
#
# Blocked : `git add` (with or without `-C <dir>`) whose operands are a sweep
#           flag or a tree-wide token. Also `git commit -a`, which stages
#           every tracked modification and skips the index entirely.
# Allowed : - `git add <path> [<path>...]` — the intended form
#           - `git add -p` / `--patch` — hunk-by-hunk, which is ownership by
#             construction
#           - `git add --intent-to-add` / `-N`, which records a path without
#             staging content
#           - a path in a variable, a glob the shell expands (`*`), or a
#             named directory (`src/`) — unknowable here, and the commit's own
#             staged-diff read is the backstop
#           - any `git add` in a repo created this session, which cannot hold
#             another session's work — not detectable here, so it is the one
#             case that must be waived by re-running with explicit paths
#
# The deny names the fix, so the retry is one turn.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

# Cheap gate before the parse. `git -C <dir> add` puts a path between the two
# words, so this matches the verbs alone rather than the pair.
hook_read_raw
case "$HOOK_INPUT" in
  *git*add*|*git*commit*) ;;
  *) exit 0 ;;
esac
hook_parse_input
[ -z "$HOOK_CMD" ] && exit 0

cmd=$(hook_command_shape)

# `git commit -a` / `--all` bypasses the index: every tracked modification in
# the tree goes in, whoever wrote it.
if printf '%s' "$cmd" | grep -qE '(^|[;&|] *)git +(-C +[^ ]+ +)?commit\b[^;&|]*( -[a-zA-Z]*a[a-zA-Z]*( |$)| --all\b)'; then
  deny "\`git commit -a\` stages every tracked modification in the tree, including hunks another session left uncommitted. Stage the paths you wrote (\`git add <path>...\`), read \`git diff --cached\` in full, then \`git commit\` without -a."
fi

# `git add` by sweep. The operand forms that reach beyond named paths:
#   -A / --all / --no-ignore-removal   the whole tree
#   -u / --update                      every tracked modification
#   . ./ .. ../ :/ :(top)              the current or parent directory, and :/
#                                      the tree from root
if printf '%s' "$cmd" | grep -qE '(^|[;&|] *)git +(-C +[^ ]+ +)?add\b[^;&|]*( -[a-zA-Z]*[Au]| --all| --update| --no-ignore-removal| \.\.?/?( |$)| :/| :\(top\))'; then
  deny "\`git add\` by sweep stages every changed file, and a tree here usually carries another session's uncommitted work. Name the paths this session wrote: \`git add <path> [<path>...]\`. For a large set, \`git status --short\` first, then add the ones you own. (\`-p\`, \`-N\` and explicit paths pass.)"
fi

exit 0
