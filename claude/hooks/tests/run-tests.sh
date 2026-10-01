#!/bin/bash
# Table-driven tests for PreToolUse hooks. Runs the case files in TESTS_DIR
# (default: this dir) against the hooks in TESTS_DIR's parent; a project-scope
# runner delegates here through the deployed copy, ~/.claude/hooks/tests/run-tests.sh,
# with TESTS_DIR set. The install manifest a hook must be linked by is the
# install.conf.yaml at the root of whichever repo holds TESTS_DIR.
# The harness discovers one cases-<hook>.txt per sibling <hook>.sh. Each line
# is TAB-separated:
#   deny|ask|allow<TAB><command>[<TAB><cwd>]   Bash payload; optional payload cwd
#   allow_bg<TAB><command>                     Bash payload, run_in_background=true
#   poll_deny|poll_allow<TAB><command>         Bash payload with
#                     description="poll wait" (the agent poll-wait opt-out)
#   poll_timeout<TAB><command><TAB><ms>        same payload; asserts the hook
#                     rewrites it with updatedInput timeout == ms
#   bg_forced<TAB><command>                    Bash payload; asserts the hook
#                     rewrites it with updatedInput run_in_background == true
#   bg_none<TAB><command>                      Bash payload; asserts no such
#                     rewrite and no deny — `allow` alone passes a rewrite
#   write_deny|write_allow<TAB><file_path><TAB><content>   Write payload
#   read_deny|read_allow<TAB><file_path>      Read payload (no content)
#   agent_opus|agent_noop<TAB><tool_input JSON overrides>
#                     Agent payload: overrides merged over {"subagent_type": "x",
#                     "prompt": "p"}. agent_opus asserts updatedInput
#                     model == "opus", agent_noop asserts the hook emits nothing
#   ctx_has|ctx_none<TAB><payload JSON>[<TAB><substring>]
#                     raw payload; ctx_has asserts additionalContext contains the
#                     substring, ctx_none asserts the hook emits nothing
# Literal \n in write content / message fields expands to a newline. `%HOME%`
# in a field expands to $HOME and `%FIX%` to $TESTS_FIXTURE_DIR (a fixture tree
# the calling runner builds), so a case file names no machine. Blank lines and
# lines starting with # are ignored. Case files run in parallel, one background
# job each: they are independent, and the run's cost is process spawns.
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

# JSON in and out goes through `jq` (~/.claude/rules/hot-path-scripts.md § A script on a hot path):
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
    allow_bg)
      payload=$(hook_json '{tool_input: {command: $a1, run_in_background: true}}' "$(printf '%b' "$f2")")
      expect=allow ;;
    poll_deny|poll_allow)
      payload=$(hook_json '{tool_input: {command: $a1, description: "poll wait"}}' "$(printf '%b' "$f2")")
      expect=${expect#poll_} ;;
    poll_timeout)
      payload=$(hook_json '{tool_input: {command: $a1, description: "poll wait"}}' "$(printf '%b' "$f2")")
      out=$(printf '%s' "$payload" | bash "$HOOKS_DIR/$hook")
      got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.timeout // "unset"' 2>/dev/null)
      [ -n "$got" ] || got=unset
      [ "$got" = "$f3" ] && verdict=$f3 || verdict="timeout=$got"
      total=$((total + 1))
      if [ "$verdict" != "$f3" ]; then
        fail=$((fail + 1)); echo "FAIL [$hook] expected timeout=$f3 got=$verdict : $f2"
      fi
      return ;;
    bg_forced|bg_none)
      payload=$(hook_json '{tool_name: "Bash", tool_input: {command: $a1}}' "$(printf '%b' "$f2")")
      out=$(printf '%s' "$payload" | bash "$HOOKS_DIR/$hook")
      got=$(printf '%s' "$out" | jq -r '
        if (.hookSpecificOutput.updatedInput.run_in_background) == true then "true"
        elif (.hookSpecificOutput.permissionDecision // "allow") != "allow" then "denied"
        else "unset" end' 2>/dev/null || printf 'unset')
      [ -n "$got" ] || got=unset
      if [ "$expect" = bg_forced ]; then
        [ "$got" = "true" ] && verdict=bg_forced || verdict="not-backgrounded:${out:-<empty>}"
      else
        [ "$got" = "unset" ] && verdict=bg_none || verdict="rewritten:${out:-<empty>}"
      fi
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
    agent_opus|agent_noop)
      payload=$(jq -cn --argjson ov "$f2" '{tool_name: "Agent", tool_input: ({subagent_type: "x", prompt: "p"} + $ov)}')
      out=$(printf '%s' "$payload" | bash "$HOOKS_DIR/$hook")
      if [ "$expect" = "agent_noop" ]; then
        [ -z "$out" ] && verdict=agent_noop || verdict="emitted:$out"
      else
        got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.model // "unset"' 2>/dev/null || printf 'unset')
        [ -n "$got" ] || got=unset
        [ "$got" = "opus" ] && verdict=$expect || verdict="wrong-model:${out:-<empty>}"
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

settings="$HOOKS_DIR/../settings.json"
if [ -f "$settings" ]; then
  repo=$(git -C "$HOOKS_DIR" rev-parse --show-toplevel 2>/dev/null)
  yaml="$repo/install.conf.yaml"
  rel="${HOOKS_DIR#"$repo"/}"
  while IFS= read -r target; do
    src="$HOOKS_DIR/$(basename "$target")"
    [ -f "$src" ] || { echo "WIRED-BUT-MISSING [$target] no such file: $src" >&2; fail=$((fail + 1)); }
    [ -x "$src" ] || { echo "WIRED-BUT-NOT-EXECUTABLE [$target] chmod +x $src" >&2; fail=$((fail + 1)); }
    grep -qF "$(basename "$target")" "$yaml" || grep -qE "(^|[[:space:]:])$rel/?$" "$yaml" \
      || { echo "WIRED-BUT-UNLINKED [$target] no install.conf.yaml entry for it or for $rel/" >&2; fail=$((fail + 1)); }
    total=$((total + 3))
  done < <(jq -r '(.hooks // {})[] | .[]? | (.hooks // [])[] | .command // empty' "$settings" \
    | grep -o '[^/]*\.sh' | sort -u)
fi

run_file() {  # $1=cases file -> FAIL lines, then "#SUMMARY <total> <fail>"
  local cases="$1" hook expect f2 f3
  hook="$(basename "$cases" .txt)"; hook="${hook#cases-}.sh"
  total=0 fail=0
  while IFS=$'\t' read -r expect f2 f3; do
    [ -z "${expect:-}" ] && continue
    case "$expect" in \#*) continue ;; esac
    f2=${f2//%HOME%/$HOME}; f3=${f3//%HOME%/$HOME}
    f2=${f2//%FIX%/${TESTS_FIXTURE_DIR:-}}; f3=${f3//%FIX%/${TESTS_FIXTURE_DIR:-}}
    run_case "$hook" "$expect" "$f2" "${f3:-}"
  done < "$cases"
  echo "#SUMMARY $total $fail"
}

out=$(mktemp -d "${TMPDIR:-/tmp}/hooktests.XXXXXX")
for cases in "$TESTS_DIR"/cases-*.txt; do
  hook="$(basename "$cases" .txt)"; hook="${hook#cases-}.sh"
  [ -f "$HOOKS_DIR/$hook" ] || { echo "no hook for case file: $cases" >&2; rm -rf "$out"; exit 2; }
  run_file "$cases" > "$out/$(basename "$cases")" &
done
wait
for f in "$out"/*; do
  grep -v '^#SUMMARY' "$f"
  read -r _ t fl < <(grep '^#SUMMARY' "$f")
  total=$((total + t)); fail=$((fail + fl))
done
rm -rf "$out"

echo "$((total - fail))/$total passed"
[ "$fail" -eq 0 ]
