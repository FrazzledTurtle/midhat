#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin" "$TMPDIR/home"
LOG="$TMPDIR/log"
FLAG="$TMPDIR/home/.local/state/midhat/toggles/hypr/slate.lua"

for stub in midhat-shell midhat-hook midhat-hyprland-monitor-rotate pkill pgrep setsid; do
  printf '#!/bin/bash\nprintf "%%s\\n" "%s $*" >>"$STUB_LOG"\n' "$stub" >"$TMPDIR/bin/$stub"
  chmod +x "$TMPDIR/bin/$stub"
done
ln -s "$ROOT/bin/midhat-slate" "$TMPDIR/bin/midhat-slate"

run() {
  HOME="$TMPDIR/home" PATH="$TMPDIR/bin:$PATH" MIDHAT_PATH="$ROOT" STUB_LOG="$LOG" "$@"
}

[[ $(run midhat-slate status || true) == "off" ]] || fail "slate starts off"
run midhat-slate status >/dev/null && fail "slate status exits nonzero while off"
pass "slate starts off"

run midhat-slate on
[[ -f $FLAG ]] || fail "slate on writes the Hyprland flag"
cmp -s "$FLAG" "$ROOT/default/hypr/toggles/slate.lua" || fail "slate flag is the default toggle"
[[ $(run midhat-slate status) == "on" ]] || fail "slate status reports on"
grep -qx "midhat-shell -q slate set on" "$LOG" || fail "slate on tells the shell"
pass "slate on writes the flag and tells the shell"

run midhat-slate off
[[ ! -e $FLAG ]] || fail "slate off removes the flag"
grep -qx "midhat-shell -q slate set off" "$LOG" || fail "slate off tells the shell"
pass "slate off removes the flag and tells the shell"

: >"$LOG"
run "$ROOT/bin/midhat-tablet-mode" on
[[ -f $FLAG ]] || fail "cover off turns slate on"
run "$ROOT/bin/midhat-tablet-mode" off
[[ ! -e $FLAG ]] || fail "cover on turns slate off"
pass "the cover drives slate"

run midhat-slate bogus 2>/dev/null && fail "slate rejects unknown actions"
pass "slate rejects unknown actions"
