#!/bin/bash
# PreToolUse Read|Edit|Write hook: deny when file_path is a symlink, or traverses
# a symlinked directory whose physical home is inside a git repository, and name
# the real path to retry with. Backstop for the global CLAUDE.md rule (§ Read,
# Edit, and Write take the physical path); this catches the call that reaches
# the tool without it.
#
# Why deny (not rewrite file_path via updatedInput): the shadow tracker keys the
# path the model sent, not the one a hook returns, so a rewritten Read and a
# rewritten Edit still land under different keys. Edit's read-precondition also
# runs upstream of PreToolUse — the call aborts before this hook is invoked, so a
# rewrite has no seam to work in.
#
# Gating Read too means the very first call lands on the real path, and the batch
# of Edits Claude emits in the same turn all pass; gating only Edit lets N Reads
# through the symlink and then denies all N Edits at once, since parallel tool
# calls see no feedback mid-batch.
#
# A symlinked directory whose target is not a repository (/tmp -> /private/tmp)
# passes: used consistently, it never desyncs the shadow tracker, and no commit
# depends on which name was used.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_input
fp="$HOOK_FILE_PATH"
[ -z "$fp" ] && exit 0

if ! [ -L "$fp" ]; then
  case "$fp" in
    */*) ;;
    *) exit 0 ;;
  esac
  dir=${fp%/*}
  base=${fp##*/}
  logical=$(cd "$dir" 2>/dev/null && pwd -L) || exit 0
  phys=$(cd "$dir" 2>/dev/null && pwd -P) || exit 0
  [ "$phys" = "$logical" ] && exit 0
  git -C "$phys" rev-parse --show-toplevel >/dev/null 2>&1 || exit 0
  deny "Path traverses a symlinked directory into a repository. Use the real path for every Read and Edit (the shadow tracker keys the path you Read): $phys/$base"
fi

# fp is a confirmed symlink (-L above). Resolve it; if resolution fails or the
# result equals the input (broken chain / readlink couldn't follow it), deny —
# editing through an unresolvable symlink is exactly the shadow-tracker desync
# this hook exists to block, so failing open here would defeat it.
real=$(readlink -f "$fp" 2>/dev/null) || real=""
if [ -z "$real" ] || [ "$real" = "$fp" ]; then
  deny "Path is a symlink that could not be resolved (broken link?): $fp. Fix the link or Edit the real target directly."
fi

deny "Path is a symlink. Use the real path for every Read and Edit (the shadow tracker keys the path you Read): $real"
