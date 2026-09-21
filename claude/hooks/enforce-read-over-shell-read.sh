#!/bin/bash
# PreToolUse Bash hook: block reading a file through the shell when the Read tool
# is the right instrument — `sed -n '<a>,<b>p' <file>` and `cat <file>`. Read takes
# offset/limit natively, registers the file so a follow-up Edit can target it, and
# renders images and notebooks that the shell would emit as raw bytes.
#
# Blocked : a `sed -n` line-range print, or a `cat`, whose single operand is a
#           file under a real project tree — including when it leads a `;`- or
#           `&&`-sequenced command, since the bytes land in the transcript either
#           way. Also `rg -r`, whose flag means something other than what the
#           grep habit that types it intends (see the deny below).
# Allowed : - a read feeding a pipe or a redirect — the bytes go to a filter or a
#             file rather than into the transcript, so Read cannot stand in for it
#           - `cat <<EOF` heredocs and `cat a b` concatenation — those write and
#             combine, they do not read one file
#           - `sed -i`, substitutions, pattern prints — mutations and filters
#           - targets under /tmp, /private/tmp, a scratchpad dir, or ~/.claude
#             — throwaway and harness files (transcripts and task outputs live
#             there), where Read's registration buys nothing and the file may
#             be enormous
#           - a path in a variable or glob — the operand is unknowable here
#
# The deny names the exact Read call, so the retry is one turn.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *'sed '*|*'cat '*|*'rg '*) ;;
  *) exit 0 ;;
esac
hook_parse_input
[ -z "$HOOK_CMD" ] && exit 0

cmd_flat=$(printf '%s' "$HOOK_CMD" | tr '\n' ' ')

# `grep -r` recurses; `rg -r` takes a REPLACEMENT string and ripgrep already
# recurses by default. So `rg -r <pattern> <path>` consumes the pattern as the
# replacement and matches nothing, and `rg -rn <pattern>` rewrites every match to
# the literal `n` — both exit 0 with output that reads as a real result, which is
# how a corrupted search gets believed. Deny on the short forms typed from grep
# muscle memory; `--replace=` spelled out is a deliberate rewrite and passes.
case "$cmd_flat" in
  *--replace*) ;;
  *)
    if printf '%s' "$cmd_flat" | grep -qE '(^|[[:space:]&|;/])rg[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*)([[:space:]]|$)'; then
      deny "\`rg -r\` is ripgrep's --replace flag, not grep's recursive flag — ripgrep already recurses. As written the next argument is consumed as a replacement string, so the search either matches nothing or prints every match rewritten, and exits 0 either way. Drop the \`-r\`: \`rg <pattern> <path>\`. Use \`-e <pattern>\` when the pattern starts with a dash, and spell out \`--replace=<text>\` if a rewrite really is what you want."
    fi
    ;;
esac

# A whole-file read is still a whole-file read when other work is sequenced after
# it, so judge the FIRST stage rather than the command as a whole. A read feeding
# a pipe or a redirect is genuinely different — the bytes go to a filter or a
# file, not into the transcript — so those two operators still pass everything.
stage=$(printf '%s' "$cmd_flat" | sed -E 's/[;&]+.*$//')
[ -z "$stage" ] && exit 0
printf '%s' "$stage" | grep -qE '[|><]' && exit 0
cmd_flat=$stage

offset=""
limit=""

if printf '%s' "$cmd_flat" | grep -qE '^[[:space:]]*sed[[:space:]]+-n[[:space:]]'; then
  # Must carry a line-range print script; a pattern print is a filter, not a read.
  printf '%s' "$cmd_flat" | grep -qE "['\"]?[0-9]+,[0-9\$]+p['\"]?" || exit 0
  file=$(printf '%s' "$cmd_flat" | awk '{print $NF}' | tr -d "'\"")
  case "$file" in
    -*|*,*p|"") exit 0 ;;
  esac
  range=$(printf '%s' "$cmd_flat" | grep -oE '[0-9]+,[0-9$]+p' | head -1)
  offset=${range%%,*}
  end=${range#*,}; end=${end%p}
  [ "$end" = "\$" ] || limit=$((end - offset + 1))
elif printf '%s' "$cmd_flat" | grep -qE '^[[:space:]]*cat[[:space:]]'; then
  # Exactly one operand and no flags: `cat -n`, `cat -A`, and `cat a b` are
  # numbering, escaping, and concatenation — none is a plain file read.
  printf '%s' "$cmd_flat" | grep -qE '^[[:space:]]*cat[[:space:]]+[^-][^[:space:]]*[[:space:]]*$' || exit 0
  file=$(printf '%s' "$cmd_flat" | awk '{print $2}' | tr -d '"'"'"'')
else
  exit 0
fi

[ -z "$file" ] && exit 0

# An unresolvable operand has no Read call to name.
case "$file" in
  *'$'*|*'*'*|*'`'*|*'?'*) exit 0 ;;
esac

abs=$(hook_abspath "$file")

# Throwaway and harness-internal trees: Read buys nothing there, and a transcript
# or task-output file is large enough that a bounded shell range is the better tool.
case "$abs" in
  /tmp/*|/private/tmp/*|"$HOME"/.claude/*|*/scratchpad/*) exit 0 ;;
esac

if [ -n "$limit" ]; then
  hint="Read(file_path=\"$abs\", offset=$offset, limit=$limit)"
elif [ -n "$offset" ]; then
  hint="Read(file_path=\"$abs\", offset=$offset)"
else
  hint="Read(file_path=\"$abs\")"
fi

deny "Use the Read tool to read a file: \`$hint\`. Read takes offset/limit natively and registers the file so a follow-up Edit can target it — a shell read leaves the file unregistered, so the Edit fails. (Pipes, redirects, heredocs, multi-file concatenation, \`sed -i\`, and files under /tmp or a scratchpad are unaffected.)"

exit 0
