#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/home" "$TMPDIR/bin"
calls="$TMPDIR/calls"

cat >"$TMPDIR/bin/midhat-shell" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$MIDHAT_TEST_CALLS"
printf 'ok\n'
SH
chmod +x "$TMPDIR/bin/midhat-shell"

run_enable() {
  HOME="$TMPDIR/home" \
    MIDHAT_PATH="$ROOT" \
    MIDHAT_TEST_CALLS="$calls" \
    PATH="$TMPDIR/bin:$ROOT/bin:$PATH" \
    midhat-plugin-enable "$@"
}

run_enable midhat.active-window --section right >/dev/null
grep -Fqx 'shell enablePlugin midhat.active-window {"section":"right"}' "$calls" ||
  fail "plugin enable did not combine activation and placement"
pass "plugin enable combines activation and placement in one shell mutation"

run_enable midhat.clock --before midhat.weather >/dev/null
grep -Fqx 'shell enablePlugin midhat.clock {"before":"midhat.weather"}' "$calls" ||
  fail "plugin enable did not preserve relative placement"
pass "plugin enable forwards relative placement"

run_enable midhat.dropbox >/dev/null
grep -Fqx 'shell enablePlugin midhat.dropbox {}' "$calls" ||
  fail "plugin enable did not use manifest-default placement"
pass "plugin enable leaves default placement to the registry"

if run_enable midhat.bar --section right >/dev/null 2>&1; then
  fail "plugin enable accepted placement for a full bar"
fi
pass "plugin enable rejects placement for full bars"
