#!/bin/bash
# The right column is padded on ${#…}, which counts bytes under a C locale;
# `↓` and `·` are multibyte, so the row would land three columns short.
export LC_ALL=en_US.UTF-8
set -u
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

align_left()  { printf '%s%*s' "$2" $(( $1 - ${#2} )) ''; }
align_right() { printf '%*s%s' $(( $1 - ${#2} )) '' "$2"; }
widen() { [ "${#2}" -gt "${!1}" ] && printf -v "$1" '%s' "${#2}"; return 0; }

now_ms=$(( $(date +%s) * 1000 ))
us=$'\x1f'

# One jq in (columns on the first line, then one row per task) and one jq out
# (the id/content JSON for every row), whatever the row count.
{
  read -r columns
  : "${columns:=0}"
  n=0 w_mdl=0 w_pct=0 w_eff=0 w_ela=0 w_tok=0
  while IFS=$'\x1f' read -r id desc model effort tokens window start_ms; do
    pct=$(( tokens * 100 / window ))
    ids[n]=$id descs[n]=$desc pcts[n]="$pct%"
    colors[n]=$(ramp_color "$pct" "$ctx_warm_default" "$ctx_bold_default")
    mdls[n]=""; [ -n "$model" ] && mdls[n]=$(short_model "$model")
    effs[n]=""; [ -n "$effort" ] && effs[n]=$(effort_label "$effort")
    elas[n]=""; [ "$start_ms" -gt 0 ] && elas[n]=$(fmt_elapsed $(( (now_ms - start_ms) / 1000 )))
    toks[n]="↓$(fmt_tokens "$tokens")"
    widen w_mdl "${mdls[n]}"; widen w_pct "${pcts[n]}"; widen w_eff "${effs[n]}"
    widen w_ela "${elas[n]}"; widen w_tok "${toks[n]}"
    n=$(( n + 1 ))
  done

  i=0
  while [ "$i" -lt "$n" ]; do
    mdl=""; [ "$w_mdl" -gt 0 ] && mdl="$(align_left "$w_mdl" "${mdls[i]}") "
    pct=$(align_right "$w_pct" "${pcts[i]}")
    eff=""
    if [ "$w_eff" -gt 0 ]; then
      mark=" ·"; [ -z "${effs[i]}" ] && mark="  "
      eff="${mark}$(align_left "$w_eff" "${effs[i]}")"
    fi
    ela=""
    if [ "$w_ela" -gt 0 ]; then
      mark=" · "; [ -z "${elas[i]}" ] && mark="   "
      ela="$(align_right "$w_ela" "${elas[i]}")${mark}"
    fi
    tok=$(align_right "$w_tok" "${toks[i]}")

    right_plain="${mdl}${pct}${eff}  ${ela}${tok}"
    right="${mdl}${colors[i]}${pct}${c_off}${c_muted}${eff}  ${ela}${tok}${c_off}"

    gap=$(( columns - ${#descs[i]} - ${#right_plain} ))
    [ "$gap" -lt 2 ] && gap=2
    pad=$(printf '%*s' "$gap" '')
    content=$(printf "%b" "${c_muted}${descs[i]}${c_off}${pad}${right}")

    printf '%s%s%s\n' "${ids[i]}" "$us" "$content"
    i=$(( i + 1 ))
  done
} < <(printf '%s' "$input" | jq -r '
  ((.columns // 0) | tostring),
  ((.tasks // [])[]
   | select((.contextWindowSize | type) == "number" and .contextWindowSize > 0)
   | [ (.id // "" | tostring),
       ((.description // .label // .name // "") | gsub("\n"; " ")),
       (.model // ""),
       (.effort // "" | if type == "number" then floor | tostring else . end),
       ((.tokenCount // 0) | floor | tostring),
       (.contextWindowSize | floor | tostring),
       ((.startTime // 0) | floor | tostring) ]
   | join("\u001f"))
' 2>/dev/null) | jq -Rc 'split("\u001f") | {id: .[0], content: .[1]}'
