#!/bin/bash
input=$(cat)

. "$(dirname "$0")/statusline-lib.sh"

eval "$(printf '%s' "$input" | jq -r '
def s(v): (v // "") | if type == "string" then . else tostring end;
def pct(v): v | if type == "number" then (round | tostring) else "" end;
def epoch(v): v | if type == "number" then (floor | tostring) else "0" end;
"model=" + (s(.model.display_name) | @sh),
"effort=" + (s(.effort.level) | @sh),
"used_pct=" + (pct(.context_window.used_percentage) | @sh),
"permission_mode=" + (s(.permission_mode) | @sh),
"cache_cold=" + ((if .prompt_cache.warm == false then "1" else "" end) | @sh),
"live5=" + (pct(.rate_limits.five_hour.used_percentage) | @sh),
"live5_reset=" + (epoch(.rate_limits.five_hour.resets_at) | @sh),
"live7=" + (pct(.rate_limits.seven_day.used_percentage) | @sh),
"live7_reset=" + (epoch(.rate_limits.seven_day.resets_at) | @sh)
' 2>/dev/null)"
: "${model=}" "${effort=}" "${used_pct=}" "${permission_mode=}" "${cache_cold=}"
: "${live5=}" "${live5_reset=0}" "${live7=}" "${live7_reset=0}"
model=${model/ context)/)}
now=$(date +%s)

cols=${COLUMNS:-0}
if [ "$cols" -eq 0 ] || [ "$cols" -ge 70 ]; then form=bars
elif [ "$cols" -ge 50 ]; then form=glyph
elif [ "$cols" -ge 38 ]; then form=bare
else form=tight
fi

countdown() {
  local left=$(( $1 - now ))
  [ "$left" -lt 0 ] && left=0
  if [ "$left" -ge 86400 ]; then
    printf '%dd%02dh' "$(( left / 86400 ))" "$(( left % 86400 / 3600 ))"
  else
    printf '%dh%02dm' "$(( left / 3600 ))" "$(( left % 3600 / 60 ))"
  fi
}

fade() {
  local esc="$1" keep="${2:-33}" bg_r=30 bg_g=30 bg_b=46
  local rgb=${esc#*38;2;}; rgb=${rgb%m}
  local r=${rgb%%;*} rest=${rgb#*;} g b
  g=${rest%%;*}; b=${rest#*;}
  printf '\\033[38;2;%s;%s;%sm' \
    "$(( (r * keep + bg_r * (100 - keep)) / 100 ))" \
    "$(( (g * keep + bg_g * (100 - keep)) / 100 ))" \
    "$(( (b * keep + bg_b * (100 - keep)) / 100 ))"
}

# Indexed by fill count, not sliced from a string: substring expansion counts
# bytes under a C/POSIX locale, and these glyphs are three bytes each.
bar_filled=('' '▰' '▰▰' '▰▰▰' '▰▰▰▰' '▰▰▰▰▰')
bar_empty=('' '▱' '▱▱' '▱▱▱' '▱▱▱▱' '▱▱▱▱▱')

bar() {
  local pct="$1" fill_color="$2" track_color="$3" width=5
  [ "$pct" -gt 100 ] && pct=100
  [ "$pct" -lt 0 ] && pct=0
  local filled=$(( (pct * width + 50) / 100 ))
  printf '%s%s%s%s%s' "$fill_color" "${bar_filled[filled]}" \
    "$track_color" "${bar_empty[width - filled]}" "$c_off"
}

# ── claude section ───────────────────────────────────────────
claude_section=""

cswap_state="$HOME/.claude-swap-backup/sequence.json"

if [ -n "$model" ]; then
  claude_section+="${claude_section:+ }${c_identity}${model}${c_off}"
fi

if [ -n "$used_pct" ]; then
  case "$model" in
    *Sonnet*|*sonnet*) warm_start=45; bold_start=65; alarm=80 ;;
    *)                 warm_start=25; bold_start=40; alarm=50 ;;
  esac
  ctx_color=$(ramp_color "$used_pct" "$warm_start" "$bold_start" "" "$alarm")
  if [ "$used_pct" -ge "$alarm" ]; then
    read -r a_r a_g a_b <<<"$(alarm_rgb "$used_pct" "$alarm")"
    cap="\\033[38;2;${a_r};${a_g};${a_b}m"
    ctx_str="${cap}${c_off}${ctx_color}${used_pct}%${c_off}${cap}${c_off}"
  else
    ctx_str="${ctx_color}${used_pct}%${c_off}"
  fi
  [ -n "$cache_cold" ] && ctx_str="${c_muted}∘${c_off}${ctx_str}"
  claude_section+="${claude_section:+ }${ctx_str}"
fi

if [ -n "$effort" ]; then
  case "$effort" in
    low)    effort_label="Low" ;;
    medium) effort_label="Mid" ;;
    high)   effort_label="High" ;;
    xhigh)  effort_label="XHi" ;;
    max)    effort_label="Max" ;;
    *)      effort_label="$effort" ;;
  esac
  claude_section+="${claude_section:+ }${c_muted}·${effort_label}${c_off}"
fi

case "$permission_mode" in
  bypassPermissions) claude_section+="${claude_section:+  }${c_err}bypass${c_off}" ;;
esac

# ── account rows ─────────────────────────────────────────────
# Each row opens with a color escape so it never begins with whitespace, which
# the renderer trims — that pulled the inactive rows a column left of the active one.
account_lines=()
any_stale=0

meter_bodies=()
meter_cds=()
meter_cd_colors=()
add_meter() {
  local name="$1" pct="$2" resets="$3"
  [ "$pct" -lt 0 ] && return
  local color; color=$(ramp_color "$pct" 40 70 muted)
  if [ "$is_active" = true ]; then
    [ "$color" = "$c_muted" ] && color="$c_active"
  else
    color=$(fade "$color")
  fi
  local body
  case "$form" in
    bars)  body="${label}${name}${c_off} $(bar "$pct" "$track" "$empty") ${color}$(printf '%3d%%' "$pct")${c_off}" ;;
    glyph) body="${label}${name}${c_off} ${color}$(glyph_for_pct "$pct")$(printf '%2d%%' "$pct")${c_off}" ;;
    *)     body="${color}$(glyph_for_pct "$pct")$(printf '%2d%%' "$pct")${c_off}" ;;
  esac
  local cd=""
  [ "$form" != tight ] && [ "$resets" -gt 0 ] && cd=$(countdown "$resets")
  meter_bodies+=("$body")
  meter_cds+=("$cd")
  meter_cd_colors+=("$(fade "$label" 70)")
}

join_meters() {
  local sep=" " cd_width=6 i last=$(( ${#meter_bodies[@]} - 1 )) out="" cd slot
  case "$form" in
    bars)  sep="  " ;;
    tight) cd_width=0 ;;
  esac
  for i in "${!meter_bodies[@]}"; do
    out+="${meter_bodies[i]}"
    cd=${meter_cds[i]}
    slot=$(( cd_width + 1 ))
    if [ -n "$cd" ]; then
      out+=" ${meter_cd_colors[i]}${cd}${c_off}"
      slot=$(( slot - 1 - ${#cd} ))
    fi
    if [ "$i" -lt "$last" ]; then
      [ "$cd_width" -gt 0 ] && out+=$(printf '%*s' "$slot" '')
      out+="$sep"
    fi
  done
  printf '%s' "$out"
}

render_row() {
  local email="$1" stale="$2"
  local marker="${c_off} " label="$c_dim" track="$c_dim" empty="$c_darkest"
  if [ "$is_active" = true ]; then
    label="$c_active"; track="$c_track"; empty="$c_surface"
    [ -n "$email" ] && marker="${c_ok}${g_active}${c_off}"
    [ "$stale" = 1 ] && marker="${c_err}${g_stale}${c_off}"
  elif [ "$stale" = 1 ]; then
    marker="$(fade "$c_err")${g_stale}${c_off}"
  fi
  meter_bodies=(); meter_cds=(); meter_cd_colors=()
  add_meter 5h "$p5" "$r5"
  add_meter 7d "$p7" "$r7"
  [ -n "$sname" ] && add_meter "$sname" "$spct" 0
  if [ -n "$email" ]; then
    printf '%s' "${marker} ${c_italic}${label}$(printf '%-6s' "$email")${c_off}  $(join_meters)"
  else
    printf '%s' "${marker} $(join_meters)"
  fi
}

usage_cache="$HOME/.claude-swap-backup/cache/usage.json"
if [ -f "$usage_cache" ]; then
  state_in="$cswap_state"
  [ -f "$state_in" ] || state_in=/dev/null
  cswap_rows=$(jq -r -s '
    def num(v; d): if (v | type) == "number" then (v | floor)
                   elif (v | type) == "string" then (((v | tonumber?) // d) | floor)
                   else d end;
    def epoch(v): if (v | type) == "string" and (v | length) >= 19
                  then ((v[:19] + "Z") | fromdateiso8601? // 0) else 0 end;
    (.[1].activeAccountNumber // 0) as $active
    | (.[0].accounts // {}) as $acc
    | ($acc | keys | map(tonumber) | sort | map(tostring))[] as $k
    | ($acc[$k] // {}) as $a
    | ($a.lastGood // {}) as $lg
    | ($lg.five_hour // {}) as $fh
    | ($lg.seven_day // {}) as $sd
    | (($lg.scoped // [{}])[0] // {}) as $s0
    | [ $k, (($a.email // "") | split("@")[0]),
        (if ($k | tonumber) == $active then "true" else "false" end),
        (num($a.fetchedAt; 0) | tostring),
        (num($fh.pct; -1) | tostring), (epoch($fh.resets_at) | tostring),
        (num($sd.pct; -1) | tostring), (epoch($sd.resets_at) | tostring),
        ($s0.name // ""), (num($s0.pct; -1) | tostring) ]
    | @tsv' "$usage_cache" "$state_in" 2>/dev/null)

  while IFS=$'\t' read -r num email is_active fetched p5 r5 p7 r7 sname spct; do
    [ -z "$num" ] && continue
    stale=$(( now - fetched > 900 ))
    [ "$stale" = 1 ] && any_stale=1
    if [ "$is_active" = true ]; then
      [ -n "$live5" ] && { p5=$live5; r5=$live5_reset; }
      [ -n "$live7" ] && { p7=$live7; r7=$live7_reset; }
    fi
    account_lines+=("$(render_row "$email" "$stale")")
  done <<< "$cswap_rows"
fi
if [ ${#account_lines[@]} -eq 0 ]; then
  if [ -n "$live5" ] || [ -n "$live7" ]; then
    is_active=true sname="" p5=${live5:--1} r5=$live5_reset p7=${live7:--1} r7=$live7_reset
    account_lines+=("$(render_row "" 0)")
  elif [ -f "$cswap_state" ]; then
    account_lines+=("${c_off}  ${c_muted}cswap: stale${c_off}")
    any_stale=1
  fi
fi

cswap_bin="$HOME/.local/bin/cswap"
kick_stamp="$HOME/.claude-swap-backup/cache/.statusline-kick"
if [ "$any_stale" = 1 ] && [ -x "$cswap_bin" ]; then
  last_kick=0
  [ -f "$kick_stamp" ] && last_kick=$(cat "$kick_stamp" 2>/dev/null || echo 0)
  if [ $(( now - last_kick )) -ge 120 ]; then
    printf '%s\n' "$now" > "$kick_stamp"
    ( "$cswap_bin" auto --once --dry-run >/dev/null 2>&1 & )
  fi
fi

# ── assemble ─────────────────────────────────────────────────
out="$claude_section"
for line in "${account_lines[@]}"; do
  out="${out}\n${line}"
done
printf '%b' "$out"
exit 0
