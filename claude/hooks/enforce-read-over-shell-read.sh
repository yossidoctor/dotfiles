#!/bin/bash
# PreToolUse Bash hook: block reading a file through the shell when the Read tool
# is the right instrument — `sed -n '<a>,<b>p' <file>`, `cat <file>`, `head -N
# <file>`, `tail -N <file>` and their pager cousins. Read takes offset/limit
# natively, registers the file so a follow-up Edit can target it, and renders
# images and notebooks that the shell would emit as raw bytes.
#
# Blocked : a `sed -n` line-range print, a `cat`/`bat`/`less`/`more`, or a
#           `head`/`tail` carrying at most a line count, whose single operand is a
#           file under a real project tree — including when it leads a `;`- or
#           `&&`-sequenced command, since the bytes land in the transcript either
#           way. The deny maps the count onto Read: `head -N` is `limit=N`,
#           `tail -n +K` is `offset=K`, and `tail -N` is an offset counted back
#           from `wc -l`, so a `tail -N` of a file that does not exist passes.
#           Also `rg -r`, whose flag means something other than what the grep
#           habit that types it intends (see the deny below).
# Allowed : - a read feeding a pipe or a redirect — the bytes go to a filter or a
#             file rather than into the transcript, so Read cannot stand in for it
#           - `cat <<EOF` heredocs and `cat a b` concatenation — those write and
#             combine, they do not read one file
#           - any other flag (`cat -n`, `bat -p`, `head -c`): a format or a byte
#             read, not the line read Read replaces
#           - `sed -i`, substitutions, pattern prints — mutations and filters
#           - targets under /tmp, /private/tmp, a scratchpad dir, or ~/.claude
#             — throwaway and harness files (transcripts and task outputs live
#             there), where Read's registration buys nothing and the file may
#             be enormous. A ~/.claude path that is a dotbot link into a repo
#             is that repo's file and is judged as such, by its real path
#           - a path in a variable or glob — the operand is unknowable here
#
# The deny names the exact Read call, so the retry is one turn.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *'sed '*|*'cat '*|*'head '*|*'tail '*|*'bat '*|*'less '*|*'more '*|*'rg '*) ;;
  *) exit 0 ;;
esac
hook_parse_input
[ -z "$HOOK_CMD" ] && exit 0

cmd_flat=$(printf '%s' "$HOOK_CMD" | tr '\n' ' ')
strip_quotes() { tr -d "'\""; }

# `grep -r` recurses; `rg -r` takes a REPLACEMENT string and ripgrep already
# recurses by default. So `rg -r <pattern> <path>` consumes the pattern as the
# replacement and matches nothing, and `rg -rn <pattern>` rewrites every match to
# the literal `n` — both exit 0 with output that reads as a real result, which is
# how a corrupted search gets believed. Deny on the short forms typed from grep
# muscle memory; `--replace=` spelled out is a deliberate rewrite and passes.
# Matched on the command SHAPE (quotes and heredoc bodies dropped), so an echo
# or commit message that merely names the flag is not an invocation.
cmd_shape=$(hook_command_shape ' ')
case "$cmd_shape" in
  *--replace*) ;;
  *)
    if printf '%s' "$cmd_shape" | grep -qE '(^|[[:space:]&|;/])rg[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*)([[:space:]]|$)'; then
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
  file=$(printf '%s' "$cmd_flat" | awk '{print $NF}' | strip_quotes)
  case "$file" in
    -*|*,*p|"") exit 0 ;;
  esac
  range=$(printf '%s' "$cmd_flat" | grep -oE '[0-9]+,[0-9$]+p' | head -1)
  offset=${range%%,*}
  end=${range#*,}; end=${end%p}
  [ "$end" = "\$" ] || limit=$((end - offset + 1))
elif printf '%s' "$cmd_flat" | grep -qE '^[[:space:]]*(cat|bat|less|more)[[:space:]]'; then
  # Exactly one operand and no flags: `cat -n`, `cat -A`, `bat -p` and `cat a b`
  # are numbering, escaping, paging and concatenation — none is a plain file read.
  printf '%s' "$cmd_flat" | grep -qE '^[[:space:]]*(cat|bat|less|more)[[:space:]]+[^-][^[:space:]]*[[:space:]]*$' || exit 0
  file=$(printf '%s' "$cmd_flat" | awk '{print $2}' | strip_quotes)
elif printf '%s' "$cmd_flat" | grep -qE '^[[:space:]]*head[[:space:]]'; then
  # `head [-n N | -N] <file>`: the count is Read's limit; head's own default is 10.
  printf '%s' "$cmd_flat" | grep -qE '^[[:space:]]*head([[:space:]]+(-n[[:space:]]*[0-9]+|-[0-9]+))?[[:space:]]+[^-][^[:space:]]*[[:space:]]*$' || exit 0
  file=$(printf '%s' "$cmd_flat" | awk '{print $NF}' | strip_quotes)
  # The count is read right after the command word, never from the operand: a
  # `-2` inside `foo-2.txt` is part of a filename.
  limit=$(printf '%s' "$cmd_flat" | grep -oE '^[[:space:]]*head[[:space:]]+(-n[[:space:]]*|-)[0-9]+' | grep -oE '[0-9]+$')
  limit=${limit:-10}
elif printf '%s' "$cmd_flat" | grep -qE '^[[:space:]]*tail[[:space:]]'; then
  # `tail -n +K <file>` starts at line K. `tail [-n N | -N] <file>` is the last N
  # lines, which Read reaches by an offset counted back from `wc -l` once the
  # operand has resolved below.
  printf '%s' "$cmd_flat" | grep -qE '^[[:space:]]*tail([[:space:]]+(-n[[:space:]]*\+?[0-9]+|-[0-9]+))?[[:space:]]+[^-][^[:space:]]*[[:space:]]*$' || exit 0
  file=$(printf '%s' "$cmd_flat" | awk '{print $NF}' | strip_quotes)
  tail_n=$(printf '%s' "$cmd_flat" | grep -oE '^[[:space:]]*tail[[:space:]]+(-n[[:space:]]*|-)\+?[0-9]+' | grep -oE '\+?[0-9]+$')
  tail_n=${tail_n:-10}
  case "$tail_n" in
    +*) offset=${tail_n#+} ;;
    *)  tail_last=$tail_n ;;
  esac
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
# A ~/.claude path is exempt only while it resolves inside ~/.claude: the dotbot
# links there lead into a config repo, whose file this is, judged by its real path.
case "$abs" in
  /tmp/*|/private/tmp/*|*/scratchpad/*) exit 0 ;;
  "$HOME"/.claude/*)
    real=$(readlink -f "$abs" 2>/dev/null) || real=$abs
    case "$real" in "$HOME"/.claude/*) exit 0 ;; *) abs=$real ;; esac ;;
esac

if [ -n "${tail_last:-}" ]; then
  [ -f "$abs" ] || exit 0
  offset=$(( $(wc -l < "$abs" | tr -d ' ') - tail_last + 1 ))
  [ "$offset" -lt 1 ] && offset=1
fi

hint="Read(file_path=\"$abs\"${offset:+, offset=$offset}${limit:+, limit=$limit})"

deny "Use the Read tool to read a file: \`$hint\`. Read takes offset/limit natively and registers the file so a follow-up Edit can target it — a shell read leaves the file unregistered, so the Edit fails. (Pipes, redirects, heredocs, multi-file concatenation, flags beyond a line count, \`sed -i\`, and files under /tmp or a scratchpad are unaffected.)"

exit 0
