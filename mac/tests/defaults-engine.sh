#!/bin/bash
# Exercises mac/defaults-lib.sh on scratch plists, which `defaults` takes as
# path domains: five types written once, a re-run writing nothing, check mode
# naming a drifted key without touching it, and a refused write named. Run by
# hand:  bash mac/tests/defaults-engine.sh   — exits 1 at the first failure.
# -currentHost is not covered: `defaults` refuses it on a path domain.
set -uo pipefail
check=false
. "$(dirname "${BASH_SOURCE[0]}")/../defaults-lib.sh"
dom=$scratch/dom.plist

fail() { echo "FAIL: $1" >&2; exit 1; }
apply() {
  defaults write "$dom" i -int 42
  defaults write "$dom" b -bool true
  defaults write "$dom" f -float 1.0
  defaults write "$dom" s -string scale
  defaults write "$dom" a -array one two
  defaults write "$dom" d -dict-add 64 '<dict><key>enabled</key><false/></dict>'
}

apply
[ "$(( $(wc -w <<<"$written") ))" = 6 ] || fail "6 writes expected, written:$written"
[ -z "$failed" ] || fail "unexpected miss:$failed"

written=''
apply
[ -z "$written" ] || fail "re-apply wrote:$written"

command defaults write "$dom" s -string genie
check=true
out=$(defaults write "$dom" s -string scale)
[ "$out" = "$dom s: genie → scale" ] || fail "check output: $out"
[ "$(command defaults read "$dom" s)" = genie ] || fail "check mode wrote"
check=false

defaults write /nonexistent/dir/x.plist k -int 1 2>/dev/null
case "$failed" in *"failed: /nonexistent/dir/x.plist k"*) ;; *) fail "miss not named:$failed" ;; esac

echo "defaults-engine: ok"
