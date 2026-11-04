#!/bin/bash
# PreToolUse Bash hook: a local file is read with the Read tool, not cat/head/tail/sed.
#
# Why: Read numbers lines (so a finding cites path:line), always counts as the
# read an Edit needs, is where Read(...) deny rules apply by construction, and
# renders images, PDFs and notebooks. A shell read gets none of that, and the
# auto-mode system prompt invites one, so text alone loses that contest.
#
# The command is split into list segments at ; && || and newlines outside
# quotes, and each segment is judged alone, so `cat a.md; ls dir` is caught by
# its first segment and an awk program's `&&` stays inside its segment.
# A relative path resolves against the session cwd as moved by any earlier
# `cd DIR` segment of the same command (`cd x && cat README.md` names x/README.md).
#
# DENIED: any segment that is ONE of these on ONE existing regular file:
#   cat [-n] [--] FILE
#   head|tail [-n N | -N] [--] FILE
#   sed -n 'Np' | 'N,Mp' FILE
#   grep [-n] [-e] PATTERN FILE, PATTERN matching every line ('' ^ $ .* ^.* .*$ ^.*$)
#   awk 'PROGRAM' FILE, PROGRAM one single-quoted word made only of an NR/FNR
#     condition (`NR>=a && NR<=b`, `1`) and/or `{print …}` of NR, FNR, $0 and
#     string literals
# The reason names the file and the Read form (offset/limit for a slice).
#
# PASSED (deliberately): a segment with a pipe, redirect, background `&` or
# substitution outside quotes (`cat a | jq`, `cat a > b`, `x=$(cat f)`), a grep
# with a real pattern, an awk printing fields or computing, several files, any
# other flag (`tail -f` belongs to enforce-foreground-polling.sh), a path under
# /dev /proc /sys, a path that does not resolve to a file — including a quoted
# path with spaces, which this whitespace split cannot rebuild, so it fails
# open — and any command holding a heredoc, whose body lines are data. A remote
# read (`ssh host cat …`) never starts with the tool name.

set -u

. "$(dirname "${BASH_SOURCE[0]}")/hook-lib.sh"

hook_read_raw
case "$HOOK_INPUT" in
  *cat*|*head*|*tail*|*sed*|*awk*) ;;
  *grep*) case "$HOOK_INPUT" in *"''"*|*'\"\"'*|*'^'*|*'$'*|*'.*'*) ;; *) exit 0 ;; esac ;;
  *) exit 0 ;;
esac
hook_parse_input
[ -z "$HOOK_CMD" ] && exit 0
case "$HOOK_CMD" in *'<<'*) exit 0 ;; esac

unquote() { local s=$1; s=${s#[\'\"]}; s=${s%[\'\"]}; printf '%s' "$s"; }

# One segment -> 0 with HIT/RANGE/TOOL set when it is a lone local file read.
judge() {
  local seg=$1 file='' tool re
  # shellcheck disable=SC2016  # literal `$(`, not an expansion
  case "$seg" in *'$('*|*'`'*) return 1 ;; esac
  case "$(printf '%s' "$seg" | hook_strip_quotes)" in *'|'*|*'&'*|*'<'*|*'>'*) return 1 ;; esac
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
    grep)
      [ "${1:-}" = "-n" ] && shift
      [ "${1:-}" = "-e" ] && shift
      [ $# -eq 2 ] || return 1
      case "$(unquote "$1")" in ''|'^'|'$'|'.*'|'^.*'|'.*$'|'^.*$') ;; *) return 1 ;; esac
      file=$2 ;;
    awk)
      # The word split breaks the program apart, so it is matched on the segment.
      re="^[[:space:]]*awk[[:space:]]+'([^']*)'[[:space:]]+([^[:space:]]+)[[:space:]]*$"
      [[ $seg =~ $re ]] || return 1
      local prog=${BASH_REMATCH[1]}
      file=${BASH_REMATCH[2]}
      # shellcheck disable=SC2016  # literal `$0`, not an expansion
      re='^(([[:space:]()0-9,<>=!&|]|F?NR)*)(\{[[:space:]]*print([[:space:],]|F?NR|\$0|"[^"]*")*;?[[:space:]]*\})?[[:space:]]*$'
      [[ $prog =~ [^[:space:]] ]] && [[ $prog =~ $re ]] || return 1
      case "${BASH_REMATCH[1]}" in *NR*) RANGE=" ${BASH_REMATCH[1]%"${BASH_REMATCH[1]##*[![:space:]]}"}" ;; esac ;;
    *) return 1 ;;
  esac
  file=$(unquote "$file")
  case "$file" in -*) return 1 ;; esac
  HIT=$(hook_abspath "$file")
  case "$HIT" in /dev/*|/proc/*|/sys/*) return 1 ;; esac
  [ -f "$HIT" ] || return 1
  TOOL=$tool
}

# A `cd [DIR]` segment moves the cwd later segments resolve against. A target
# that is not a literal existing directory (`cd -`, `cd $X`) leaves the cwd
# unknown, so later relative paths resolve nowhere and pass.
follow_cd() {
  local -a w
  read -r -a w <<EOF
$1
EOF
  [ "${w[0]:-}" = cd ] || return 1
  case ${#w[@]} in
    1) HOOK_CWD=$HOME ;;
    2) HOOK_CWD=$(hook_abspath "$(unquote "${w[1]}")")
       [ -d "$HOOK_CWD" ] || HOOK_CWD=/nonexistent ;;
    *) HOOK_CWD=/nonexistent ;;
  esac
}

segs=$(printf '%s' "$HOOK_CMD" | awk '
  BEGIN { sq = sprintf("%c", 39) }
  { s = s (NR > 1 ? "\n" : "") $0 }
  END {
    n = length(s); q = ""
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1); d = substr(s, i, 2)
      if (q != "") { if (c == q) q = ""; out = out c; continue }
      if (c == sq || c == "\"") { q = c; out = out c; continue }
      if (d == "&&" || d == "||") { out = out "\n"; i++; continue }
      out = out (c == ";" ? "\n" : c)
    }
    print out
  }')
HIT='' RANGE='' TOOL=''
while IFS= read -r seg; do
  follow_cd "$seg" && continue
  judge "$seg" && break
  HIT=''
done <<EOF
$segs
EOF
[ -z "$HIT" ] && exit 0

if [ -n "$RANGE" ]; then
  form="offset/limit for the${RANGE} slice; "
else
  form='offset/limit for a slice; '
fi
deny "${HIT} is a local file, so it is read with the Read tool (${form}allow_large past 256 KB), as its own call; the rest of this command runs after it in Bash. Read numbers lines for path:line, counts as the read an Edit needs, and is where Read deny rules apply. A ${TOOL} inside a pipeline, over several files, of a remote file, or a grep with a real pattern is untouched by enforce-read-tool.sh."
