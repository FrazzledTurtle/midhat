#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

template="$ROOT/default/snapper/root"
limine_defaults="$ROOT/etc/limine-entry-tool.d/midhat-defaults.conf"
limine_notify_autostart="$ROOT/config/autostart/limine-snapper-notify.desktop"

grep -Fx 'NUMBER_CLEANUP="yes"' "$template" >/dev/null
grep -Fx 'NUMBER_LIMIT="5"' "$template" >/dev/null
grep -Fx 'TIMELINE_CREATE="no"' "$template" >/dev/null
! grep -Eq '^TIMELINE_(CLEANUP|LIMIT_)' "$template" || fail "Snapper template keeps timeline cleanup details out of the default config"
grep -Fx 'MAX_SNAPSHOT_ENTRIES=6' "$limine_defaults" >/dev/null || fail "Limine allows for a snapshot created before Snapper cleanup"
pass "Snapper and Limine retain update snapshots without a transient limit mismatch"

grep -Fx '[Desktop Entry]' "$limine_notify_autostart" >/dev/null
grep -Fx 'Hidden=true' "$limine_notify_autostart" >/dev/null
pass "Limine Snapper warning notifier is disabled by default"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

fake_bin="$test_tmp/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/snapper" <<'STUB'
#!/bin/bash
printf 'snapper %s\n' "$*" >>"$TEST_LOG"
STUB
chmod +x "$fake_bin/snapper"

cat >"$fake_bin/systemctl" <<'STUB'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$TEST_LOG"
STUB
chmod +x "$fake_bin/systemctl"

: >"$test_tmp/calls.log"

TEST_LOG="$test_tmp/calls.log" \
PATH="$fake_bin:$PATH" \
MIDHAT_SNAPPER_CONFIGURE_TEST=1 \
MIDHAT_PATH="$ROOT" \
MIDHAT_SNAPPER_CONFIG_PATH="$test_tmp/etc/snapper/configs/root" \
MIDHAT_SNAPPER_CONF_PATH="$test_tmp/etc/conf.d/snapper" \
  bash -euo pipefail "$ROOT/install/config/snapper.sh" >/dev/null

cmp -s "$template" "$test_tmp/etc/snapper/configs/root" || fail "snapshot configure installs the Mid’hat Snapper template"
grep -Fx 'SNAPPER_CONFIGS="root"' "$test_tmp/etc/conf.d/snapper" >/dev/null || fail "snapshot configure writes /etc/conf.d/snapper"
grep -Fx 'systemctl disable --now snapper-timeline.timer' "$test_tmp/calls.log" >/dev/null || fail "snapshot configure disables timeline snapshots"
grep -Fx 'systemctl enable --now snapper-cleanup.timer limine-snapper-sync.service' "$test_tmp/calls.log" >/dev/null || fail "snapshot configure enables cleanup and Limine snapshot sync"
pass "snapshot configure normalizes Snapper policy and services"

setup_system="$ROOT/bin/midhat-apply-system"
grep -F 'config/all.sh' "$setup_system" >/dev/null ||
  fail "system setup runs the config phase"
grep -F 'config/snapper.sh' "$ROOT/install/config/all.sh" >/dev/null ||
  fail "config phase normalizes Snapper"
pass "system setup normalizes Snapper during fresh installs"

# Checkouts differ per machine, so allow an explicit pointer at the sibling repo.
# Accepts either the midhat-pkgs checkout or its pkgbuilds/ directory.
find_midhat_pks_root() {
  local candidate
  for candidate in \
    ${MIDHAT_PKGS_PATH:+"$MIDHAT_PKGS_PATH/pkgbuilds" "$MIDHAT_PKGS_PATH"} \
    "$ROOT/../midhat-pkgs/pkgbuilds" \
    "$ROOT/../midhat/midhat-pkgs/pkgbuilds" \
    "$ROOT/../../midhat-pkgs/pkgbuilds" \
    "$ROOT/../omacom/omarchy-pkgs/pkgbuilds" \
    "$ROOT/../../omacom/omarchy-pkgs/pkgbuilds" \
    "$HOME/Work/omacom/omarchy-pkgs/pkgbuilds"; do
    if [[ -d $candidate ]]; then
      cd "$candidate" && pwd
      return 0
    fi
  done
  return 1
}

pkgs_root=$(find_midhat_pks_root) || fail "midhat-pkgs checkout is available for packaging coverage"
settings_pkgbuild="$pkgs_root/midhat-settings-dev/PKGBUILD"
midhat_pkgbuild="$pkgs_root/midhat-dev/PKGBUILD"

grep -F 'cp -a default/. "$pkgdir/usr/share/midhat/default/"' "$settings_pkgbuild" >/dev/null || fail "midhat-settings package bundles default/"
grep -F 'install -Dm644 default/snapper/root \' "$settings_pkgbuild" >/dev/null || fail "midhat-settings package installs Snapper template source"
grep -F '"$pkgdir/etc/snapper/config-templates/midhat"' "$settings_pkgbuild" >/dev/null || fail "midhat-settings package installs Snapper template destination"
grep -F "'snapper'" "$midhat_pkgbuild" >/dev/null || fail "midhat package depends on snapper"
grep -F "'limine-snapper-sync'" "$midhat_pkgbuild" >/dev/null || fail "midhat package depends on limine-snapper-sync"
grep -F 'cp -a install "$pkgdir/usr/share/midhat/"' "$midhat_pkgbuild" >/dev/null || fail "midhat package bundles install scripts"
grep -F 'cp -a migrations "$pkgdir/usr/share/midhat/"' "$midhat_pkgbuild" >/dev/null || fail "midhat package bundles migrations"
pass "midhat-pkgs packages Snapper template, setup, and migration coverage"

# Same per-machine checkout problem as midhat-pkgs; MIDHAT_ISO_PATH points at it.
find_midhat_iso_root() {
  local candidate
  for candidate in \
    ${MIDHAT_ISO_PATH:+"$MIDHAT_ISO_PATH"} \
    "$ROOT/../midhat-iso" \
    "$ROOT/../midhat/midhat-iso" \
    "$ROOT/../../midhat-iso" \
    "$ROOT/../omacom/omarchy-iso" \
    "$ROOT/../../omacom/omarchy-iso" \
    "$HOME/Work/omacom/omarchy-iso"; do
    if [[ -d $candidate ]]; then
      cd "$candidate" && pwd
      return 0
    fi
  done
  return 1
}

iso_root=$(find_midhat_iso_root) || fail "midhat-iso checkout is available for installer coverage"
configurator="$iso_root/configs/airootfs/root/configurator"
phases="$iso_root/configs/airootfs/usr/share/midhat-iso/orchestrator/phases_impl.py"
manifest="$iso_root/manifests/fresh-4-semantic.json"

! grep -F 'snapshot_config' "$configurator" >/dev/null || fail "ISO does not ask archinstall to create Snapper timeline config"

# The phases/manifest assertions cover the newer ISO orchestrator structure.
# Skip them when the checkout predates that layout.
if [[ -f $phases && -f $manifest ]]; then
  ! grep -F '_configure_snapper_root' "$phases" >/dev/null || fail "ISO does not duplicate Mid’hat Snapper setup"
  grep -F 'run_system_finalizer' "$phases" >/dev/null || fail "ISO runs packaged system setup"
  grep -F '/etc/systemd/system/timers.target.wants/snapper-cleanup.timer' "$manifest" >/dev/null || fail "fresh ISO manifest has snapper-cleanup timer enabled"
  ! grep -F '/etc/systemd/system/timers.target.wants/snapper-timeline.timer' "$manifest" >/dev/null || fail "fresh ISO manifest does not enable snapper timeline timer"
fi
pass "midhat-iso delegates Snapper setup to packaged system setup"
