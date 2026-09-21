#!/bin/bash
# The right column is padded on ${#…}, which counts bytes under a C locale;
# `↓` and `·` are multibyte, so the row would land three columns short.
export LC_ALL=en_US.UTF-8
input=$(cat)

. "$(dirname "$0")/statusline-lib.sh"

short_model() {
  case "$1" in
    *opus*)   printf 'Opus' ;;
    *sonnet*) printf 'Sonnet' ;;
    *haiku*)  printf 'Haiku' ;;
    *fable*)  printf 'Fable' ;;
    *mythos*) printf 'Mythos' ;;
    *)        printf '%s' "$1" ;;
  esac
}

now_ms=$(( $(date +%s) * 1000 ))
us=$'\x1f'

# One jq in (columns on the first line, then one row per task) and one jq out
# (the id/content JSON for every row), whatever the row count.
{
  read -r columns
  : "${columns:=0}"
  while IFS=$'\x1f' read -r id desc model tokens window start_ms; do

    pct=$(( tokens * 100 / window ))
    color=$(ramp_color "$pct" 25 40)

    mdl=""; [ -n "$model" ] && mdl="$(short_model "$model") "
    ela=""; [ "$start_ms" -gt 0 ] && ela="$(fmt_elapsed $(( (now_ms - start_ms) / 1000 ))) · "
    tok="↓$(fmt_tokens "$tokens")"

    right_plain="${mdl}${pct}%  ${ela}${tok}"
    right="${mdl}${color}${pct}%${c_off}  ${c_muted}${ela}${tok}${c_off}"

    gap=$(( columns - ${#desc} - ${#right_plain} ))
    [ "$gap" -lt 2 ] && gap=2
    pad=$(printf '%*s' "$gap" '')
    content=$(printf "%b" "${c_muted}${desc}${c_off}${pad}${right}")

    printf '%s%s%s\n' "$id" "$us" "$content"
  done
} < <(printf '%s' "$input" | jq -r '
  ((.columns // 0) | tostring),
  ((.tasks // [])[]
   | select((.contextWindowSize | type) == "number" and .contextWindowSize > 0)
   | [ (.id // "" | tostring),
       ((.description // .label // .name // "") | gsub("\n"; " ")),
       (.model // ""),
       ((.tokenCount // 0) | floor | tostring),
       (.contextWindowSize | floor | tostring),
       ((.startTime // 0) | floor | tostring) ]
   | join("\u001f"))
' 2>/dev/null) | jq -Rc 'split("\u001f") | {id: .[0], content: .[1]}'
