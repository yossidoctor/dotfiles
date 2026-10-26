#!/bin/bash
# PreToolUse Bash hook: a local file is read with the Read tool, not cat/head/tail/sed.
#
# Why: Read numbers lines (so a finding cites path:line), always counts as the
# read an Edit needs, is where Read(...) deny rules apply by construction, and
# renders images, PDFs and notebooks. A shell read gets none of that, and the
# auto-mode system prompt invites one, so text alone loses that contest.
#
# The command is split into list segments at ; && || and newlines, and each
# segment is judged alone, so `cat a.md; ls dir` is caught by its first segment.
#
# DENIED: any segment that is ONE of these on ONE existing regular file:
#   cat [-n] [--] FILE
#   head|tail [-n N | -N] [--] FILE
#   sed -n 'Np' | 'N,Mp' FILE
# The reason names the file and the Read form (offset/limit for a slice).
#
# PASSED (deliberately): a segment with a pipe, redirect, background `&` or
# substitution (`cat a | jq`, `cat a > b`, `x=$(cat f)`), several files, any
# other flag (`tail -f` belongs to enforce-foreground-polling.sh), a path under
# /dev /proc /sys, a path that does not resolve to a file — including a quoted
# path with spaces, which this whitespace split cannot rebuild, so it fails
# open — and any command holding a heredoc, whose body lines are data. A remote
# read (`ssh host cat …`) never starts with the tool name.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *cat*|*head*|*tail*|*sed*) ;;
  *) exit 0 ;;
esac
hook_parse_input
[ -z "$HOOK_CMD" ] && exit 0
case "$HOOK_CMD" in *'<<'*) exit 0 ;; esac

unquote() { local s=$1; s=${s#[\'\"]}; s=${s%[\'\"]}; printf '%s' "$s"; }

# One segment -> 0 with HIT/RANGE/TOOL set when it is a lone local file read.
judge() {
  local seg=$1 file='' tool
  # shellcheck disable=SC2016  # literal `$(`, not an expansion
  case "$seg" in *'|'*|*'&'*|*'<'*|*'>'*|*'$('*|*'`'*) return 1 ;; esac
  local -a w
  read -r -a w <<EOF
$seg
EOF
  [ "${#w[@]}" -gt 1 ] || return 1
  tool=${w[0]##*/} RANGE=''
  set -- "${w[@]:1}"
  case "$tool" in
    cat)
      [ "${1:-}" = "-n" ] && shift
      [ "${1:-}" = "--" ] && shift
      [ $# -eq 1 ] || return 1
      file=$1 ;;
    head|tail)
      case "${1:-}" in
        -n) [ $# -ge 2 ] || return 1; RANGE=" $2"; shift 2 ;;
        -n[0-9]*|-[0-9]*) RANGE=" ${1#-n}"; RANGE=${RANGE#-}; shift ;;
      esac
      [ "${1:-}" = "--" ] && shift
      [ $# -eq 1 ] || return 1
      file=$1 ;;
    sed)
      [ $# -eq 3 ] && [ "$1" = "-n" ] || return 1
      printf '%s' "$(unquote "$2")" | grep -qE '^[0-9]+(,[0-9]+)?p$' || return 1
      RANGE=" $(unquote "$2")"
      file=$3 ;;
    *) return 1 ;;
  esac
  file=$(unquote "$file")
  case "$file" in -*) return 1 ;; esac
  HIT=$(hook_abspath "$file")
  case "$HIT" in /dev/*|/proc/*|/sys/*) return 1 ;; esac
  [ -f "$HIT" ] || return 1
  TOOL=$tool
}

segs=$(printf '%s\n' "$HOOK_CMD" | awk '{ gsub(/&&|\|\||;/, "\n"); print }')
HIT='' RANGE='' TOOL=''
while IFS= read -r seg; do
  judge "$seg" && break
  HIT=''
done <<EOF
$segs
EOF
[ -z "$HIT" ] && exit 0

if [ -n "$RANGE" ]; then
  form="offset/limit for the${RANGE} slice; "
else
  form=''
fi
deny "${HIT} is a local file, so it is read with the Read tool (${form}allow_large past 256 KB), as its own call; the rest of this command runs after it in Bash. Read numbers lines for path:line, counts as the read an Edit needs, and is where Read deny rules apply. A ${TOOL} inside a pipeline, over several files, or of a remote file is untouched by enforce-read-tool.sh."
