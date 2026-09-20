#!/usr/bin/env bash
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
columns=$(printf '%s' "$input" | jq -r '.columns // 0')

printf '%s' "$input" | jq -r '
  (.tasks // [])[]
  | select((.contextWindowSize | type) == "number" and .contextWindowSize > 0)
  | [ (.id // "" | tostring),
      ((.description // .label // .name // "") | gsub("\n"; " ")),
      (.model // ""),
      ((.tokenCount // 0) | floor | tostring),
      (.contextWindowSize | floor | tostring),
      ((.startTime // 0) | floor | tostring) ]
  | join("\u001f")
' 2>/dev/null | while IFS=$'\x1f' read -r id desc model tokens window start_ms; do

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

  jq -cn --arg i "$id" --arg c "$content" '{id:$i,content:$c}'
done
