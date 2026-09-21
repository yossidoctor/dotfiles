#!/bin/bash
# hook-lib.sh — shared prologue for the hooks in this directory.
# Sourced by the sibling hooks; not a hook itself (the test harness discovers
# only cases-<hook>.txt, so this file needs no case file).
#
# Interpreter startup is the dominant cost of the hook layer (~/.claude/rules/
# hot-path-scripts.md § A script on a hot path spends nothing before it knows it
# has work), so a hook
# reads the raw payload first, gates on a literal `case` over it, and parses only
# past the gate; the python3 blocks that remain do parsing work the shell cannot.
# The payload is parsed by jq only: hand-extracting a JSON string with parameter
# expansion truncates at the first escaped quote, so a gate reading a command
# field that way fails open. jq starts in a fraction of python3's time.
#
# Every hook here is deployed as a symlink into this repo, so an edit runs on the
# very next tool call of the editing session and a broken edit bricks that tool
# at once; settings.json registrations snapshot at session start, so a new hook
# needs a new session. Case files hold the banned patterns as text, so they are
# written with Write/Edit — a Bash heredoc is denied by the hook under test.
#
# Provides:
#   hook_read_raw     read the hook payload from stdin -> HOOK_INPUT, nothing else.
#                     A literal absent from HOOK_INPUT is absent from every field
#                     jq would extract, so `case "$HOOK_INPUT" in *lit*)` is a sound
#                     gate ahead of hook_parse_input.
#   hook_parse_input  HOOK_INPUT -> the fields below via one jq pass
#   hook_read_input   hook_read_raw + hook_parse_input, for hooks with no raw gate
#                     HOOK_CMD (.tool_input.command),
#                     HOOK_DESCRIPTION (.tool_input.description), HOOK_FILE_PATH
#                     (.tool_input.file_path, then .tool_input.notebook_path —
#                     NotebookEdit's own path field — then .tool_response.filePath),
#                     HOOK_TOOL_NAME (.tool_name), HOOK_NOTIFICATION_TYPE
#                     (.notification_type — the Notification payload carries
#                     the type here; the settings.json matcher is never echoed
#                     back into the input), HOOK_MESSAGE (.message),
#                     HOOK_SESSION_ID (.session_id),
#                     HOOK_CWD (.cwd), HOOK_TRANSCRIPT (.transcript_path),
#                     HOOK_RUN_IN_BACKGROUND (.tool_input.run_in_background, "true"/"false")
#   hook_command_shape [sep]
#                     HOOK_CMD -> stdout in matchable form: heredoc bodies dropped
#                     (their lines are data — a commit message or fixture naming a
#                     command is not that command), newlines mapped to [sep]
#                     (default ';', the separator the shell treats a newline as),
#                     then quoted regions removed. This is the form a command-shape
#                     regex matches against.
#   hook_command_joined [sep]
#                     the same minus the quote strip — heredocs dropped, newlines
#                     mapped to [sep], quoted content INTACT. For the hook whose
#                     target text legitimately lives inside the quotes (an argument
#                     value to read back, a code payload to inspect); matching a
#                     command SHAPE against it reads string literals as commands.
#   hook_strip_quotes stdin -> stdout; drop '...' and "..." regions in one
#                     left-to-right pass, the way the shell parses: whichever quote
#                     opens first wins, single quotes end at the next single quote,
#                     double quotes honor backslash escapes, and a backslash outside
#                     quotes escapes the next character. Backticks and $(...) are
#                     deliberately kept — their contents execute, so a command inside
#                     one is a real command. Runs under LC_ALL=C: every character it
#                     tests is ASCII, and bash 3.2 indexes a UTF-8 string by walking
#                     it from the start on every ${s:$i:1}, four times the cost.
#   hook_abspath <path>
#                     absolutize against HOOK_CWD (leading ~ expanded)
#   decide <verdict> <reason> / deny <reason> / ask <reason>
#                     emit the PreToolUse decision JSON and exit 0
#   additional_context <event-name> <msg>
#                     emit an additionalContext JSON for the given hook event and exit 0
#
# PYTHONDONTWRITEBYTECODE: the python blocks import hook_lib.py through the
# deployed link, so a compiled cache would land inside the repository.

export PYTHONDONTWRITEBYTECODE=1

hook_read_raw() {
  HOOK_INPUT=$(cat)
}

hook_read_input() {
  hook_read_raw
  hook_parse_input
}

hook_parse_input() {
  eval "$(printf '%s' "$HOOK_INPUT" | jq -r '
def s(v): (v // "") | if type == "string" then . else "" end;
def var($n; v): $n + "=" + (s(v) | @sh);
var("HOOK_CMD"; .tool_input.command),
var("HOOK_DESCRIPTION"; .tool_input.description),
var("HOOK_FILE_PATH"; .tool_input.file_path // .tool_input.notebook_path // .tool_response.filePath),
var("HOOK_TOOL_NAME"; .tool_name),
var("HOOK_NOTIFICATION_TYPE"; .notification_type),
var("HOOK_MESSAGE"; .message),
var("HOOK_SESSION_ID"; .session_id),
var("HOOK_CWD"; .cwd),
var("HOOK_TRANSCRIPT"; .transcript_path),
"HOOK_RUN_IN_BACKGROUND=" + (if .tool_input.run_in_background == true then "true" else "false" end)
' 2>/dev/null)"
  : "${HOOK_CMD=}" "${HOOK_DESCRIPTION=}" "${HOOK_FILE_PATH=}" "${HOOK_TOOL_NAME=}" "${HOOK_NOTIFICATION_TYPE=}"
  : "${HOOK_MESSAGE=}" "${HOOK_SESSION_ID=}" "${HOOK_CWD=}" "${HOOK_TRANSCRIPT=}"
  : "${HOOK_RUN_IN_BACKGROUND=false}"
}

hook_strip_heredocs() {
  # No heredoc operator — `<<`, optional `-`, optional quote, a delimiter word;
  # `<<<` is a herestring — means nothing to drop, and the python parse below
  # is the single most expensive thing a Bash hook does. Pass the text through.
  local src re="(^|[^<])<<-?[[:space:]]*['\"]?[A-Za-z_]"
  src=$(cat)
  [[ $src =~ $re ]] || { printf '%s' "$src"; return; }
  printf '%s' "$src" | python3 -c '
import re, sys
src = sys.stdin.read()
out, pos = [], 0
op = re.compile(r"<<-?\s*([\x27\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
while (m := op.search(src, pos)):
    line_end = src.find("\n", m.end())
    if line_end == -1:
        out.append(src[pos:]); pos = len(src); break
    out.append(src[pos:line_end + 1])
    delim = m.group(2)
    body = re.compile(r"^[ \t]*" + re.escape(delim) + r"[ \t]*$", re.M)
    d = body.search(src, line_end + 1)
    pos = d.end() if d else len(src)
out.append(src[pos:])
sys.stdout.write("".join(out))
'
}

hook_strip_quotes() {
  local s out='' i=0 ch j n LC_ALL=C
  s=$(cat)
  n=${#s}
  while [ "$i" -lt "$n" ]; do
    ch=${s:$i:1}
    case "$ch" in
      "'")
        j=$((i + 1))
        while [ "$j" -lt "$n" ] && [ "${s:$j:1}" != "'" ]; do j=$((j + 1)); done
        i=$((j + 1))
        ;;
      '"')
        j=$((i + 1))
        while [ "$j" -lt "$n" ]; do
          case "${s:$j:1}" in
            '\') j=$((j + 2)) ;;
            '"') break ;;
            *) j=$((j + 1)) ;;
          esac
        done
        i=$((j + 1))
        ;;
      '\')
        if [ $((i + 1)) -lt "$n" ]; then out+=${s:$((i + 1)):1}; fi
        i=$((i + 2))
        ;;
      *)
        out+=$ch
        i=$((i + 1))
        ;;
    esac
  done
  printf '%s' "$out"
}

hook_command_joined() {  # $1=newline replacement (default ';')
  printf '%s' "$HOOK_CMD" | hook_strip_heredocs | tr '\n' "${1:-;}"
}

hook_command_shape() {  # $1=newline replacement (default ';')
  hook_command_joined "${1:-;}" | hook_strip_quotes
}

hook_abspath() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    "~"|"~/"*) printf '%s' "${1/#\~/$HOME}" ;;
    *) printf '%s' "${HOOK_CWD:-$PWD}/$1" ;;
  esac
}

decide() {  # $1=allow|ask|deny  $2=reason
  jq -cn --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}
deny() { decide deny "$1"; }
ask()  { decide ask  "$1"; }

additional_context() {  # $1=hookEventName  $2=message
  jq -cn --arg e "$1" --arg m "$2" \
    '{hookSpecificOutput: {hookEventName: $e, additionalContext: $m}}'
  exit 0
}
