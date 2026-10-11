#!/bin/bash
# PreToolUse Bash hook: the working-tree discards and lease pushes —
# `reset --hard`, `branch -D`, `tag -d`,
# `checkout --`, `clean`, `stash drop|clear`, `push --force-with-lease` — prompt
# only outside a sandbox worktree (`<repo>/.worktrees/<name>`). A settings
# `ask` rule prompts even when a hook allows (permission rules match command text,
# never cwd), so these live here instead of in the `ask` list.
#
# ponytail: "in a worktree" = `/.worktrees/` appears anywhere in the command or in
# cwd, so a command naming a worktree path while discarding in a main checkout
# passes unprompted. Resolve each git call's -C / cd target if that ever bites.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *git*) ;;
  *) exit 0 ;;
esac
hook_parse_input

re='git( [^;&|]*)? (reset --hard|branch -D|tag -d|checkout --( |$)|clean( |$)|stash (drop|clear)|push [^;&|]*--force-with-lease)'
[[ $(hook_command_shape) =~ $re ]] || exit 0

case "$HOOK_CMD$HOOK_CWD" in
  */.worktrees/*) exit 0 ;;
esac
decide ask "risky git outside a sandbox worktree: ${BASH_REMATCH[0]}"
