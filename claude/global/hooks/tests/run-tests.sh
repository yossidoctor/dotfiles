#!/usr/bin/env bash
# Table-driven tests for PreToolUse hooks. Runs the case files in TESTS_DIR
# (default: this dir) against the hooks in TESTS_DIR's parent; a project-scope
# runner delegates here through the deployed copy, ~/.claude/hooks/tests/run-tests.sh,
# with TESTS_DIR set. The install manifest a hook must be linked by is the
# install.conf.yaml at the root of whichever repo holds TESTS_DIR.
# The harness discovers one cases-<hook>.txt per sibling <hook>.sh. Each line
# is TAB-separated:
#   deny|ask|allow<TAB><command>[<TAB><cwd>]   Bash payload; optional payload cwd
#   allow_bg<TAB><command>                     Bash payload, run_in_background=true
#   bg_forced<TAB><command>                    Bash payload; asserts the hook
#                     rewrites it with updatedInput run_in_background == true
#   write_deny|write_allow<TAB><file_path><TAB><content>   Write payload
#   read_deny|read_allow<TAB><file_path>      Read payload (no content)
#   msg_deny|msg_allow<TAB><message>           Slack-message payload
#   agent_forced|agent_opus|agent_noop<TAB><tool_input JSON overrides>
#                     Agent payload: overrides merged over {"subagent_type": "x",
#                     "prompt": "p"}. agent_forced asserts updatedInput
#                     run_in_background == true, agent_opus asserts updatedInput
#                     model == "opus", agent_noop asserts the hook emits nothing
#   ctx_has|ctx_none<TAB><payload JSON>[<TAB><substring>]
#                     raw payload; ctx_has asserts additionalContext contains the
#                     substring, ctx_none asserts the hook emits nothing
# Literal \n in write content / message fields expands to a newline. Blank
# lines and lines starting with # are ignored.
#
#
# Every hook a settings.json wires is also checked to exist, be executable, and
# be deployed by install.conf.yaml — satisfied by its own link line, or by an
# entry dir-linking the hooks directory it sits in, which is how a project scope
# ships and where a per-file line would be the wrong shape.
#
# Run: bash run-tests.sh        exit 0 = all pass; failures print expected/got.

set -u

TESTS_DIR="${TESTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)}"
HOOKS_DIR="$(dirname "$TESTS_DIR")"
fail=0 total=0

# JSON in and out goes through `jq` (global CLAUDE.md § A script on a hot path):
# this harness builds a payload and reads a verdict for every one of hundreds of
# cases, so interpreter startup is the run's dominant cost.
hook_json() {  # $1=jq filter, remaining args bound as $a1, $a2 -> prints JSON
  jq -cn --arg a1 "${2:-}" --arg a2 "${3:-}" "$1"
}

# The decision field a hook emits, or the fallback when it emits nothing/garbage.
hook_field() {  # $1=jq path expression  $2=fallback
  jq -r "(.hookSpecificOutput | $1) // \"$2\"" 2>/dev/null || printf '%s' "$2"
}

run_case() {  # $1=hook-file  $2=expect  $3=field2  $4=field3 (cwd or content)
  local hook="$1" expect="$2" f2="$3" f3="${4:-}" payload out verdict
  case "$expect" in
    write_deny|write_allow)
      payload=$(hook_json '{tool_input: {file_path: $a1, content: $a2}}' "$f2" "$(printf '%b' "$f3")")
      expect=${expect#write_} ;;
    read_deny|read_allow)
      payload=$(hook_json '{tool_name: "Read", tool_input: {file_path: $a1}}' "$f2")
      expect=${expect#read_} ;;
    msg_deny|msg_allow)
      payload=$(hook_json '{tool_input: {message: $a1}}' "$(printf '%b' "$f2")")
      expect=${expect#msg_} ;;
    allow_bg)
      payload=$(hook_json '{tool_input: {command: $a1, run_in_background: true}}' "$(printf '%b' "$f2")")
      expect=allow ;;
    bg_forced)
      payload=$(hook_json '{tool_name: "Bash", tool_input: {command: $a1}}' "$(printf '%b' "$f2")")
      out=$(printf '%s' "$payload" | bash "$HOOKS_DIR/$hook")
      got=$(printf '%s' "$out" | jq -r '
        if (.hookSpecificOutput.updatedInput.run_in_background) == true
        then "true" else "unset" end' 2>/dev/null || printf 'unset')
      [ -n "$got" ] || got=unset
      [ "$got" = "true" ] && verdict=bg_forced || verdict="not-backgrounded:${out:-<empty>}"
      total=$((total + 1))
      if [ "$verdict" != "$expect" ]; then
        fail=$((fail + 1)); echo "FAIL [$hook] expected=$expect got=$verdict : $f2"
      fi
      return ;;
    ctx_has|ctx_none)
      out=$(printf '%s' "$f2" | bash "$HOOKS_DIR/$hook")
      got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
      if [ "$expect" = "ctx_none" ]; then
        [ -z "$got" ] && verdict=ctx_none || verdict="emitted:$got"
      else
        case "$got" in *"$f3"*) verdict=ctx_has ;; *) verdict="missing[$f3] in:${got:-<empty>}" ;; esac
      fi
      total=$((total + 1))
      if [ "$verdict" != "$expect" ]; then
        fail=$((fail + 1)); echo "FAIL [$hook] expected=$expect got=$verdict"
      fi
      return ;;
    agent_forced|agent_opus|agent_noop)
      payload=$(jq -cn --argjson ov "$f2" \
        '{tool_name: "Agent", tool_input: ({subagent_type: "x", prompt: "p"} + $ov)}')
      out=$(printf '%s' "$payload" | bash "$HOOKS_DIR/$hook")
      if [ "$expect" = "agent_noop" ]; then
        [ -z "$out" ] && verdict=agent_noop || verdict="emitted:$out"
      else
        key=run_in_background want=true
        [ "$expect" = "agent_opus" ] && { key=model; want=opus; }
        got=$(printf '%s' "$out" | jq -r --arg k "$key" '
          (.hookSpecificOutput.updatedInput[$k]) as $v
          | if $v == true then "true"
            elif ($v | type) == "string" then $v
            else "unset" end' 2>/dev/null || printf 'unset')
        [ -n "$got" ] || got=unset
        [ "$got" = "$want" ] && verdict=$expect || verdict="wrong-$key:${out:-<empty>}"
      fi
      total=$((total + 1))
      if [ "$verdict" != "$expect" ]; then
        fail=$((fail + 1)); echo "FAIL [$hook] expected=$expect got=$verdict : $f2"
      fi
      return ;;
    *)
      payload=$(hook_json '{tool_input: {command: $a1}}' "$(printf '%b' "$f2")")
      [ -n "$f3" ] && payload=$(printf '%s' "$payload" | jq -c --arg c "$f3" '.cwd = $c') ;;
  esac
  out=$(printf '%s' "$payload" | bash "$HOOKS_DIR/$hook")
  verdict=$(printf '%s' "$out" | hook_field '.permissionDecision' allow)
  [ -n "$verdict" ] || verdict=allow
  case "$verdict" in deny|ask) ;; *) verdict=allow ;; esac
  total=$((total + 1))
  if [ "$verdict" != "$expect" ]; then
    fail=$((fail + 1))
    echo "FAIL [$hook] expected=$expect got=$verdict : $f2"
  fi
}

for settings in "$HOOKS_DIR/../settings.json"; do
  [ -f "$settings" ] || continue
  while IFS= read -r target; do
    src="$HOOKS_DIR/$(basename "$target")"
    [ -f "$src" ] || { echo "WIRED-BUT-MISSING [$target] no such file: $src" >&2; fail=$((fail + 1)); }
    [ -x "$src" ] || { echo "WIRED-BUT-NOT-EXECUTABLE [$target] chmod +x $src" >&2; fail=$((fail + 1)); }
    repo=$(git -C "$HOOKS_DIR" rev-parse --show-toplevel 2>/dev/null)
    yaml="$repo/install.conf.yaml"
    rel="${HOOKS_DIR#$repo/}"
    grep -qF "$(basename "$target")" "$yaml" || grep -qE "^[[:space:]]+path: $rel/?$" "$yaml" \
      || { echo "WIRED-BUT-UNLINKED [$target] no install.conf.yaml entry for it or for $rel/" >&2; fail=$((fail + 1)); }
    total=$((total + 3))
  done < <(jq -r '(.hooks // {})[] | .[]? | (.hooks // [])[] | .command // empty' "$settings" \
    | grep -o '[^/]*\.sh' | sort -u)
done

for cases in "$TESTS_DIR"/cases-*.txt; do
  hook="$(basename "$cases" .txt)"
  hook="${hook#cases-}.sh"
  [ -f "$HOOKS_DIR/$hook" ] || { echo "no hook for case file: $cases" >&2; exit 2; }
  while IFS=$'\t' read -r expect f2 f3; do
    [ -z "${expect:-}" ] && continue
    case "$expect" in \#*) continue ;; esac
    run_case "$hook" "$expect" "$f2" "${f3:-}"
  done < "$cases"
done

echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
