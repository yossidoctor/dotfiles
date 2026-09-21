#!/bin/bash
# SessionStart (startup) hook: one colored systemMessage line reminding the
# session that the `/mattpocock-skills:ask-matt` router exists. Banner only —
# emits no decision and reads nothing from the payload.

set -u

esc=$'\033'
p="${esc}[1;38;2;168;85;247m"
s="${esc}[1;38;2;236;72;153m"
r="${esc}[0m"
banner="${p}use${r} ${s}/mattpocock-skills:ask-matt${r} ${p}router!${r}"
jq -nc --arg m "$banner" '{systemMessage: $m}'
