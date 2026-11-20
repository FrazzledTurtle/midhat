#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/bin" "$TMPDIR/home"
LOG="$TMPDIR/log"
FLAG="$TMPDIR/home/.local/state/midhat/toggles/hypr/slate.lua"

for stub in midhat-shell midhat-hook midhat-hyprland-monitor-rotate pkill pgrep setsid hyprctl; do
  printf '#!/bin/bash\nprintf "%%s\\n" "%s $*" >>"$STUB_LOG"\n' "$stub" >"$TMPDIR/bin/$stub"
  chmod +x "$TMPDIR/bin/$stub"
done
ln -s "$ROOT/bin/midhat-slate" "$TMPDIR/bin/midhat-slate"

run() {
  HOME="$TMPDIR/home" PATH="$TMPDIR/bin:$PATH" MIDHAT_PATH="$ROOT" STUB_LOG="$LOG" "$@"
}

# A hyprctl that answers activewindow with $ACTIVE and logs dispatches.
fake_hyprctl() {
  cat >"$TMPDIR/bin/hyprctl" <<'SH'
#!/bin/bash
case $1 in
  activewindow) printf '%s\n' "$ACTIVE" ;;
  clients) printf '[]\n' ;;
  dispatch) printf 'dispatch %s\n' "$2" >>"$STUB_LOG" ;;
esac
SH
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

ids=$(cd "$ROOT/shell/plugins" && cat $(find . -name '*manifest.json') | jq -r '.id // empty' | sort -u)
missing=$(jq -r '.slate.bar.layout[][] | .id' "$ROOT/config/midhat/shell.json" | sort -u | comm -23 - <(printf '%s\n' "$ids"))
[[ -z $missing ]] || fail "the rail layout only uses existing widgets" "$missing"
pass "the rail layout only uses existing widgets"

actions=$(jq -r '.barWidget.schema[] | select(.key == "action") | .options[]' "$ROOT/shell/plugins/bar/widgets/SlateButton.manifest.json" | sort)
unknown=$(jq -r '.slate.bar.layout[][] | select(.id == "midhat.slate-button") | .action' "$ROOT/config/midhat/shell.json" | sort -u | comm -23 - <(printf '%s\n' "$actions"))
[[ -z $unknown ]] || fail "rail buttons use known actions" "$unknown"
for action in $actions; do
  grep -q "^    $action: {" "$ROOT/shell/plugins/bar/widgets/SlateButton.qml" || fail "slate button implements $action"
done
pass "rail buttons use known actions"

fake_hyprctl
tiled='{"address":"0x1","floating":false,"fullscreen":0,"workspace":{"name":"1"}}'
: >"$LOG"
ACTIVE=$tiled run midhat-slate fit
[[ ! -s $LOG ]] || fail "fit does nothing outside Slate"
run midhat-slate on >/dev/null
: >"$LOG"
ACTIVE=$tiled run midhat-slate fit
grep -q 'dispatch hl.dsp.window.fullscreen({ mode = "maximized", action = "set" })' "$LOG" || fail "fit maximizes the focused tiled window"
for skip in '{"address":"0x1","floating":true,"fullscreen":0,"workspace":{"name":"1"}}' \
  '{"address":"0x1","floating":false,"fullscreen":1,"workspace":{"name":"1"}}' \
  '{"address":"0x1","floating":false,"fullscreen":0,"workspace":{"name":"split"}}' '{}'; do
  : >"$LOG"
  ACTIVE=$skip run midhat-slate fit
  [[ ! -s $LOG ]] || fail "fit leaves floating, maximized, split and missing windows alone" "$skip"
done
run midhat-slate off >/dev/null
pass "fit keeps only the focused tiled window maximized, and only in Slate"
