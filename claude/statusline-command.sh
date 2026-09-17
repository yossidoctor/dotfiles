#!/usr/bin/env bash
input=$(cat)

. "$(dirname "$0")/statusline-lib.sh"

eval "$(printf '%s' "$input" | jq -r '
def s(v): (v // "") | if type == "string" then . else tostring end;
"model=" + (s(.model.display_name) | @sh),
"effort=" + (s(.effort.level) | @sh),
"used_pct=" + ((.context_window.used_percentage) | if type == "number" then (round | tostring) else "" end | @sh),
"permission_mode=" + (s(.permission_mode) | @sh)
' 2>/dev/null)"
: "${model=}" "${effort=}" "${used_pct=}" "${permission_mode=}"
model=${model/ context)/)}

countdown() {
  local left=$(( $1 - $(date +%s) ))
  [ "$left" -lt 0 ] && left=0
  if [ "$left" -ge 86400 ]; then
    printf '%02dd %02dh' "$(( left / 86400 ))" "$(( left % 86400 / 3600 ))"
  else
    printf '%02dh %02dm' "$(( left / 3600 ))" "$(( left % 3600 / 60 ))"
  fi
}

fade() {
  local esc="$1" keep=33 bg_r=30 bg_g=30 bg_b=46
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
  model_str="${c_identity}${model}${c_off}"
  [ -n "$claude_section" ] && claude_section="${claude_section} ${model_str}" || claude_section="${model_str}"
fi

if [ -n "$used_pct" ]; then
  # Cache-read cost per turn rises with context, so the warning earns its place
  # early: a session that resets at a task boundary pays a fraction of one that
  # runs on. Sonnet's larger window moves its rungs out, not the shape.
  case "$model" in
    *Sonnet*|*sonnet*) warm_start=45; bold_start=65; alarm=80 ;;
    *)                 warm_start=25; bold_start=40; alarm=50 ;;
  esac
  ctx_color=$(ramp_color "$used_pct" "$warm_start" "$bold_start" "" "$alarm")
  if [ "$used_pct" -ge "$alarm" ]; then
    # Half-circle caps carry the badge ground as FOREGROUND, so the badge reads
    # as one rounded pill against whatever the terminal paints behind it.
    read -r a_r a_g a_b <<<"$(alarm_rgb "$used_pct" "$alarm")"
    cap="\\033[38;2;${a_r};${a_g};${a_b}m"
    ctx_str="${cap}${c_off}${ctx_color}${used_pct}%${c_off}${cap}${c_off}"
  else
    ctx_str="${ctx_color}${used_pct}%${c_off}"
  fi
  [ -n "$claude_section" ] && claude_section="${claude_section} ${ctx_str}" || claude_section="${ctx_str}"
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
  effort_str="${c_muted}(effort: ${effort_label})${c_off}"
  [ -n "$claude_section" ] && claude_section="${claude_section} ${effort_str}" || claude_section="${effort_str}"
fi

# ── cswap accounts (from watch cache) ────────────────────────
cswap_lines=()
any_stale=0
usage_cache="$HOME/.claude-swap-backup/cache/usage.json"
if [ -f "$usage_cache" ]; then
  cswap_rows=$(python3 -c '
import json, sys, datetime
# The active account number comes from the sequence file rather than a second
# interpreter start: the statusline redraws on every turn, and each start costs
# more than everything this block computes.
def load(path):
    try:
        return json.load(open(path))
    except Exception:
        return {}
active = load(sys.argv[2]).get("activeAccountNumber")
active = int(active) if active is not None else 0
d = json.load(open(sys.argv[1]))
def epoch(v):
    if not v:
        return 0
    try:
        return int(datetime.datetime.strptime(v[:19] + "Z", "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc).timestamp())
    except Exception:
        return 0
def num(v, dflt):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return dflt
for k in sorted(d.get("accounts") or {}, key=int):
    a = d["accounts"][k] or {}
    lg = a.get("lastGood") or {}
    fh = lg.get("five_hour") or {}
    sd = lg.get("seven_day") or {}
    sc = lg.get("scoped") or [{}]
    s0 = sc[0] or {}
    print("\t".join([k, (a.get("email") or "").split("@")[0],
        "true" if int(k) == active else "false",
        str(num(a.get("fetchedAt"), 0)),
        str(num(fh.get("pct"), -1)), str(epoch(fh.get("resets_at"))),
        str(num(sd.get("pct"), -1)), str(epoch(sd.get("resets_at"))),
        s0.get("name") or "", str(num(s0.get("pct"), -1))]))
' "$usage_cache" "$cswap_state" 2>/dev/null)

  now=$(date +%s)
  while IFS=$'\t' read -r num email is_active fetched p5 r5 p7 r7 sname spct; do
    [ -z "$num" ] && continue
    stale=$(( now - fetched > 900 ))
    marker=" "
    label="$c_dim"
    track="$c_dim"
    empty="$c_darkest"
    if [ "$is_active" = true ]; then
      marker="${c_ok}●${c_off}"
      label="$c_active"
      track="$c_track"
      empty="$c_surface"
    fi

    meters=""
    add_meter() {
      local name="$1" pct="$2" resets="$3" timed="$4"
      [ "$pct" -lt 0 ] && return
      local color; color=$(ramp_color "$pct" 40 70 muted)
      if [ "$is_active" = true ]; then
        [ "$color" = "$c_muted" ] && color="$c_active"
      else
        color=$(fade "$color")
      fi
      local seg="${label}${name}${c_off} $(bar "$pct" "$track" "$empty") ${color}$(printf '%3d%%' "$pct")${c_off}"
      if [ "$resets" -gt 0 ]; then
        seg="${seg} ${label}($(countdown "$resets"))${c_off}"
      elif [ "$timed" = timed ]; then
        seg="${seg} $(printf '%9s' '')"
      fi
      meters="${meters}   ${seg}"
    }
    add_meter 5h "$p5" "$r5" timed
    add_meter 7d "$p7" "$r7" timed
    [ -n "$sname" ] && add_meter "$sname" "$spct" 0

    row="  ${c_surface}${num}${c_off} ${marker} ${label}$(printf '%-8s' "$email")${c_off}${meters}"

    [ "$stale" = 1 ] && { row="${row}  ${c_err}stale${c_off}"; any_stale=1; }
    cswap_lines+=("$row")
  done <<< "$cswap_rows"
fi
if [ ${#cswap_lines[@]} -eq 0 ] && [ -f "$cswap_state" ]; then
  cswap_lines+=("  ${c_muted}cswap: stale${c_off}")
  any_stale=1
fi

cswap_bin="$HOME/.local/bin/cswap"
kick_stamp="$HOME/.claude-swap-backup/cache/.statusline-kick"
if [ "$any_stale" = 1 ] && [ -x "$cswap_bin" ]; then
  last_kick=0
  [ -f "$kick_stamp" ] && last_kick=$(cat "$kick_stamp" 2>/dev/null || echo 0)
  if [ $(( $(date +%s) - last_kick )) -ge 120 ]; then
    date +%s > "$kick_stamp"
    ( "$cswap_bin" auto --once --dry-run >/dev/null 2>&1 & ) &
    disown 2>/dev/null || true
  fi
fi

# ── background jobs ──────────────────────────────────────────
bg_lines=()
jobs_dir="$HOME/.claude/jobs"
daemon_lock="$HOME/.claude/daemon.lock"
daemon_live=""
daemon_pid=$(jq -r '.pid // empty | floor' "$daemon_lock" 2>/dev/null)
case "$daemon_pid" in
  ''|*[!0-9]*|0|1) ;;
  *) kill -0 "$daemon_pid" 2>/dev/null && daemon_live=1 ;;
esac
if [ -d "$jobs_dir" ] && [ -n "$daemon_live" ]; then
  bg_rows=$(python3 -c '
import json, pathlib, sys
for state_path in sorted(pathlib.Path(sys.argv[1]).glob("*/state.json")):
    try:
        d = json.loads(state_path.read_text())
    except Exception:
        continue
    if d.get("firstTerminalAt"):
        continue
    state = d.get("state") or ""
    if state not in ("working", "blocked"):
        continue
    if (d.get("updatedAt") or "")[:19] < sys.argv[2]:
        continue
    tokens = d.get("tokens")
    try:
        tokens = int(tokens)
    except (TypeError, ValueError):
        tokens = -1
    in_flight = (d.get("inFlight") or {}).get("tasks")
    try:
        in_flight = int(in_flight)
    except (TypeError, ValueError):
        in_flight = 0
    print("\t".join([state_path.parent.name, state, str(tokens), str(in_flight),
        " ".join((d.get("name") or d.get("intent") or "").split())[:34]]))
' "$jobs_dir" "$(date -u -v-12H '+%Y-%m-%dT%H:%M:%S')" 2>/dev/null)

  while IFS=$'\t' read -r short state tokens in_flight name; do
    [ -z "$short" ] && continue
    if [ "$state" = working ]; then
      state_color="$c_err"
    else
      state_color=$(ramp_color 75 40 70 muted)
    fi
    tok_str=""
    if [ "$tokens" -ge 0 ]; then
      if [ "$tokens" -ge 1000 ]; then
        tok_str="$(printf '%dk' $(( tokens / 1000 )))"
      else
        tok_str="${tokens}"
      fi
      tok_color=$(ramp_color $(( tokens / 4000 )) 40 70 muted)
      tok_str=" ${tok_color}$(printf '%5s' "$tok_str")${c_off}"
    fi
    flight_str=""
    [ "$in_flight" -gt 0 ] && flight_str=" ${c_muted}(${in_flight} in flight)${c_off}"
    bg_lines+=("  ${c_surface}${short}${c_off} ${state_color}$(printf '%-7s' "$state")${c_off}${tok_str} ${c_dim}${name}${c_off}${flight_str}")
  done <<< "$bg_rows"
fi

# ── permission mode badge ────────────────────────────────────
perm_str=""
case "$permission_mode" in
  bypassPermissions) perm_str="${c_err}bypass${c_off}" ;;
esac
if [ -n "$perm_str" ]; then
  [ -n "$claude_section" ] && claude_section="${claude_section} ${perm_str}" || claude_section="${perm_str}"
fi

# ── assemble ─────────────────────────────────────────────────
sep="${c_surface}│${c_off}"

segments=()
[ -n "$claude_section" ] && segments+=("$claude_section")

out=""
for seg in "${segments[@]}"; do
  [ -n "$out" ] && out="${out} ${sep} "
  out="${out}${seg}"
done
for line in "${cswap_lines[@]}"; do
  out="${out}\n${line}"
done
for line in "${bg_lines[@]}"; do
  out="${out}\n${line}"
done
printf '%b' "$out"
exit 0
