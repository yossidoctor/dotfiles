#!/bin/bash
# PreToolUse Bash hook: a local file is read with the Read tool, not cat/head/tail/sed.
#
# Why: Read numbers lines (so a finding cites path:line), always counts as the
# read an Edit needs, is where Read(...) deny rules apply by construction, and
# renders images, PDFs and notebooks. A shell read gets none of that, and the
# auto-mode system prompt invites one, so text alone loses that contest.
#
# DENIED: the whole command is ONE of these on ONE existing regular file:
#   cat [-n] [--] FILE
#   head|tail [-n N | -N] [--] FILE
#   sed -n 'Np' | 'N,Mp' FILE
# The reason names the file and the Read form (offset/limit for a slice).
#
# PASSED (deliberately): anything with a pipe, redirect, separator, heredoc or
# substitution (`cat a | jq`, `cat > f <<EOF`, `cmd; cat f`), several files,
# any other flag (`tail -f` belongs to enforce-foreground-polling.sh), a path
# under /dev /proc /sys, and a path that does not resolve to a file — including
# a quoted path with spaces, which this whitespace split cannot rebuild, so it
# fails open. A remote read (`ssh host cat …`) never starts with the tool name.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *cat*|*head*|*tail*|*sed*) ;;
  *) exit 0 ;;
esac
hook_parse_input
cmd=$(printf '%s' "$HOOK_CMD" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
[ -z "$cmd" ] && exit 0
# shellcheck disable=SC2016  # literal `$(`, not an expansion
case "$cmd" in
  *'|'*|*';'*|*'&'*|*'<'*|*'>'*|*'$('*|*'`'*|*'
'*) exit 0 ;;
esac

unquote() { local s=$1; s=${s#[\'\"]}; s=${s%[\'\"]}; printf '%s' "$s"; }

read -r -a w <<EOF
$cmd
EOF
tool=${w[0]##*/}
file='' range=''
set -- "${w[@]:1}"
case "$tool" in
  cat)
    [ "${1:-}" = "-n" ] && shift
    [ "${1:-}" = "--" ] && shift
    [ $# -eq 1 ] || exit 0
    file=$1 ;;
  head|tail)
    case "${1:-}" in
      -n) [ $# -ge 2 ] || exit 0; range=" ${2}"; shift 2 ;;
      -n[0-9]*|-[0-9]*) range=" ${1#-n}"; range=${range#-}; shift ;;
    esac
    [ "${1:-}" = "--" ] && shift
    [ $# -eq 1 ] || exit 0
    file=$1 ;;
  sed)
    [ $# -eq 3 ] && [ "$1" = "-n" ] || exit 0
    printf '%s' "$(unquote "$2")" | grep -qE '^[0-9]+(,[0-9]+)?p$' || exit 0
    range=" $(unquote "$2")"
    file=$3 ;;
  *) exit 0 ;;
esac

file=$(unquote "$file")
case "$file" in -*) exit 0 ;; esac
p=$(hook_abspath "$file")
case "$p" in /dev/*|/proc/*|/sys/*) exit 0 ;; esac
[ -f "$p" ] || exit 0

if [ -n "$range" ]; then
  form="offset/limit for the${range} slice; "
else
  form=''
fi
deny "${p} is a local file, so it is read with the Read tool (${form}allow_large past 256 KB): Read numbers lines for path:line, counts as the read an Edit needs, and is where Read deny rules apply. A ${tool} inside a pipeline, over several files, or of a remote file is untouched by enforce-read-tool.sh."
