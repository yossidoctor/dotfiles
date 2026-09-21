#!/bin/bash
# statusline-lib.sh — palette and color ramp shared by statusline-command.sh and
# subagent-statusline.sh; sourced, not run. Colors are Catppuccin Mocha shades:
# c_ok, c_err, c_identity and c_muted are a cache of the palette in
# starship/starship.toml (SoT); c_surface, c_active, c_track, c_dim and
# c_darkest are the meter greys and exist only here.
#
#   ramp_color <pct> <warm> <bold> [muted] [alarm]
#     muted-grey below <warm>; red deepening from <warm>, bold from <bold>;
#     `muted` softens the red and drops bold. From <alarm> (when given, and not
#     muted) the ramp switches to a filled pill: bold white on a red ground that
#     deepens with <pct>, because past that point a deeper foreground red reads
#     as less urgent once the channels bottom out.
#   alarm_rgb <pct> <alarm>
#     the pill ground as "r g b", shared by the badge body and its end-caps.
#   glyph_for_pct <pct>
#     one Block Elements cell, ▁ through █ in eight 12.5% steps.
#   ctx_warm_default / ctx_bold_default
#     the context-percentage ramp's warm and bold rungs for every model but
#     Sonnet, read by both statusline scripts; Sonnet's wider window has its own
#     rungs in statusline-command.sh.

ctx_warm_default=25
ctx_bold_default=40

# Marks the account cswap is currently on. Single-column, so it occupies the same
# width as the blank the inactive rows carry there; g_stale replaces either when
# the usage cache is older than 15 minutes.
g_active='●'
g_stale='◌'

meter_glyphs=('▁' '▂' '▃' '▄' '▅' '▆' '▇' '█')
glyph_for_pct() {
  local i=$(( $1 * 8 / 100 ))
  [ "$i" -gt 7 ] && i=7
  [ "$i" -lt 0 ] && i=0
  printf '%s' "${meter_glyphs[i]}"
}

# Prefixes a color rather than replacing it, so the attribute rides whatever
# role follows it.
c_italic='\033[3m'

c_err='\033[38;2;243;139;168m'
c_identity='\033[38;2;137;180;250m'
c_muted='\033[38;2;108;112;134m'
c_surface='\033[38;2;69;71;90m'
c_ok='\033[38;2;166;227;161m'
c_active='\033[38;2;122;126;149m'
c_track='\033[38;2;99;103;124m'
c_dim='\033[38;2;66;68;88m'
c_darkest='\033[38;2;54;56;74m'
c_off='\033[0m'

fmt_tokens() {
  local t="$1"
  if [ "$t" -ge 1000000 ]; then
    printf '%d.%01dM' $(( t / 1000000 )) $(( t % 1000000 / 100000 ))
  elif [ "$t" -ge 1000 ]; then
    printf '%d.%01dk' $(( t / 1000 )) $(( t % 1000 / 100 ))
  else
    printf '%d' "$t"
  fi
}

fmt_elapsed() {
  local secs="$1"
  [ "$secs" -lt 0 ] && secs=0
  if [ "$secs" -ge 3600 ]; then
    printf '%dh%dm' $(( secs / 3600 )) $(( secs % 3600 / 60 ))
  elif [ "$secs" -ge 60 ]; then
    printf '%dm%ds' $(( secs / 60 )) $(( secs % 60 ))
  else
    printf '%ds' "$secs"
  fi
}

alarm_rgb() {
  local pct="$1" alarm="$2" span=$(( 100 - $2 ))
  [ "$span" -lt 1 ] && span=1
  [ "$pct" -gt 100 ] && pct=100
  local t=$(( (pct - alarm) * 100 / span ))
  printf '%s %s %s' \
    "$(( 244 - t * 30 / 100 ))" \
    "$(( 63 - t * 45 / 100 ))" \
    "$(( 94 - t * 55 / 100 ))"
}

ramp_color() {
  local pct="$1" warm="$2" bold="$3" muted="${4:-}" alarm="${5:-}"
  if [ "$pct" -lt "$warm" ]; then
    printf '%s' "$c_muted"
    return
  fi
  if [ "$muted" != muted ] && [ -n "$alarm" ] && [ "$pct" -ge "$alarm" ]; then
    printf '\\033[1;38;2;255;255;255;48;2;%s;%s;%sm' $(alarm_rgb "$pct" "$alarm")
    return
  fi
  [ "$pct" -gt 100 ] && pct=100
  local red=255 top=200 mid=80 floor=0 bold_attr=1
  if [ "$muted" = muted ]; then red=200 top=180 mid=120 floor=60 bold_attr=0; fi
  if [ "$pct" -lt "$bold" ]; then
    local range=$(( bold - warm ))
    local chan=$(( top - (pct - warm) * (top - mid) / range ))
    printf '\\033[38;2;%s;%s;%sm' "$red" "$chan" "$chan"
  else
    local range=$(( 100 - bold ))
    local chan=$(( mid - (pct - bold) * (mid - floor) / range ))
    [ "$chan" -lt "$floor" ] && chan=$floor
    if [ "$bold_attr" = 1 ]; then
      printf '\\033[1;38;2;%s;%s;%sm' "$red" "$chan" "$chan"
    else
      printf '\\033[38;2;%s;%s;%sm' "$red" "$chan" "$chan"
    fi
  fi
}
