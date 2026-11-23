#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

export PATH="$ROOT/bin:$PATH"

require_command jq
require_command lua
require_command python3

jq empty "$ROOT/config/midhat/shell.json"
pass "default shell.json is valid JSON"

jq -e '.version == 1 and (.bar.layout.left | type == "array") and (.bar.layout.center | type == "array") and (.bar.layout.right | type == "array")' "$ROOT/config/midhat/shell.json" >/dev/null
pass "default shell.json has versioned bar layout"

jq -e '
  (.bar.centerAnchor // "") as $anchor |
  any(.bar.layout.center[]; (.id // .) == $anchor)
' "$ROOT/config/midhat/shell.json" >/dev/null
pass "default center anchor exists in center layout"

jq -e '
  any(.bar.layout.center[]; (.id // .) == "midhat.clock" and (.formatAlt // "") == "d MMMM \u0027W\u0027ww yyyy")
' "$ROOT/config/midhat/shell.json" >/dev/null
pass "default clock date format has no leading zero"

ROOT="$ROOT" python3 <<'PY'
import json
import os
import sys
from pathlib import Path

root = Path(os.environ["ROOT"])
config = json.loads((root / "config/midhat/shell.json").read_text())
manifests = {}
for manifest_path in (root / "shell/plugins").glob("**/*.manifest.json"):
  data = json.loads(manifest_path.read_text())
  manifests[data.get("id", "")] = (manifest_path, data)
for manifest_path in (root / "shell/plugins").glob("**/manifest.json"):
  data = json.loads(manifest_path.read_text())
  manifests[data.get("id", "")] = (manifest_path, data)

entries = []
for section in ("left", "center", "right"):
  entries.extend(config["bar"]["layout"][section])

missing = []
bad = []
for entry in entries:
  widget_id = entry["id"] if isinstance(entry, dict) else str(entry)
  if not widget_id.startswith("midhat."):
    continue

  row = manifests.get(widget_id)
  if row is None:
    missing.append(widget_id)
    continue
  manifest_path, manifest = row

  if "bar-widget" not in manifest.get("kinds", []):
    bad.append(f"{widget_id}: missing bar-widget kind")
  entry_point = manifest.get("entryPoints", {}).get("barWidget")
  if not entry_point:
    bad.append(f"{widget_id}: missing barWidget entry point")
  elif not (manifest_path.parent / entry_point).exists():
    bad.append(f"{widget_id}: missing {entry_point}")

if missing or bad:
  for item in missing:
    print(f"missing manifest for {item}", file=sys.stderr)
  for item in bad:
    print(item, file=sys.stderr)
  sys.exit(1)
PY
pass "default bar widget ids resolve to manifests and entry points"

ROOT="$ROOT" python3 <<'PY'
import os
import re
import sys
from pathlib import Path

root = Path(os.environ["ROOT"])
home = Path.home()
pkgs_candidates = [
  root / "pkgbuilds",
]
# Checkouts differ per machine, so allow an explicit pointer at the sibling repo.
# Accepts either the midhat-pkgs checkout or its pkgbuilds/ directory.
override = os.environ.get("MIDHAT_PKGS_PATH")
if override:
  pkgs_candidates = [Path(override) / "pkgbuilds", Path(override)] + pkgs_candidates
pkgs_root = next((path for path in pkgs_candidates if path.exists()), None)
if pkgs_root is None:
  print("not ok - midhat-pkgs checkout found for PKGBUILD coverage", file=sys.stderr)
  print(
    "looked in:\n  " + "\n  ".join(str(path) for path in pkgs_candidates) +
    "\nset MIDHAT_PKGS_PATH to the midhat-pkgs checkout",
    file=sys.stderr,
  )
  sys.exit(1)
settings_pkgbuild_path = pkgs_root / "midhat-settings/PKGBUILD"
midhat_pkgbuild_path = pkgs_root / "midhat/PKGBUILD"
if not settings_pkgbuild_path.exists():
  settings_pkgbuild_path = pkgs_root / "midhat-settings-dev/PKGBUILD"
if not midhat_pkgbuild_path.exists():
  midhat_pkgbuild_path = pkgs_root / "midhat-dev/PKGBUILD"
pkgbuild = settings_pkgbuild_path.read_text()
midhat_pkgbuild = midhat_pkgbuild_path.read_text()
errors = []
package_defaults = [
  ("default/uwsm/env.d/10-midhat", "/usr/share/uwsm/env.d/10-midhat", "uwsm/env"),
  ("default/uwsm/default", None, "uwsm/default"),
  ("default/environment.d/10-midhat-fcitx.conf", "/usr/lib/environment.d/10-midhat-fcitx.conf", "environment.d/fcitx.conf"),
  ("default/fontconfig/conf.avail/50-midhat.conf", "/usr/share/fontconfig/conf.avail/50-midhat.conf", "fontconfig/fonts.conf"),
  ("default/xdg-terminal-exec/hyprland-xdg-terminals.list", "/usr/share/xdg-terminal-exec/hyprland-xdg-terminals.list", "xdg-terminals.list"),
  ("default/applications/mimeapps.list", "/usr/share/applications/mimeapps.list", "mimeapps.list"),
  ("etc/fastfetch/config.jsonc", "/etc/fastfetch/config.jsonc", "fastfetch/config.jsonc"),
  ("default/systemd/user/bt-agent.service", "/usr/lib/systemd/user/bt-agent.service", "systemd/user/bt-agent.service"),
  ("default/systemd/user/midhat-sleep-lock.service", "/usr/lib/systemd/user/midhat-sleep-lock.service", "systemd/user/midhat-sleep-lock.service"),
  ("default/systemd/user/midhat-recover-internal-monitor.service", "/usr/lib/systemd/user/midhat-recover-internal-monitor.service", "systemd/user/midhat-recover-internal-monitor.service"),
  ("default/systemd/user/midhat-migrate-notify.service", "/usr/lib/systemd/user/midhat-migrate-notify.service", "systemd/user/midhat-migrate-notify.service"),
  ("default/systemd/user/midhat-tailscale-receive.service", "/usr/lib/systemd/user/midhat-tailscale-receive.service", "systemd/user/midhat-tailscale-receive.service"),
  ("default/systemd/user/midhat-fcitx5.service", "/usr/lib/systemd/user/midhat-fcitx5.service", "systemd/user/midhat-fcitx5.service"),
  ("default/systemd/user/midhat-crash-watch.service", "/usr/lib/systemd/user/midhat-crash-watch.service", "systemd/user/midhat-crash-watch.service"),
  ("default/systemd/zram-generator.conf.d/90-midhat.conf", "/usr/lib/systemd/zram-generator.conf.d/90-midhat.conf", "systemd/zram-generator.conf.d/90-midhat.conf"),
  ("default/systemd/system/plocate-updatedb.service.d/10-midhat.conf", "/usr/lib/systemd/system/plocate-updatedb.service.d/10-midhat.conf", "systemd/system/plocate-updatedb.service.d/10-midhat.conf"),
  ("default/fonts/midhat/midhat.ttf", "/usr/share/fonts/midhat/midhat.ttf", "midhat.ttf"),
  ("default/snapper/root", "/etc/snapper/config-templates/midhat", "snapper/root"),
]

for source, destination, legacy in package_defaults:
  if not (root / source).exists():
    errors.append(f"missing package default source: {source}")
  if (root / "config" / legacy).exists():
    errors.append(f"legacy path still in config/: {legacy}")
  looped = (
    source.startswith("default/systemd/user/")
    and '"default/systemd/user/$unit.service"' in pkgbuild
    and re.search(rf"\bfor unit in [^;]*\b{re.escape(Path(source).stem)}\b", pkgbuild)
  )
  if destination and not looped and (source not in pkgbuild or destination not in pkgbuild):
    errors.append(f"PKGBUILD does not explicitly install {source} -> {destination}")

alpm_hooks = [
  "00-midhat-update-guard.hook",
  "10-midhat-hyprland-reload-pause.hook",
  "90-midhat-hyprland-reload-resume.hook",
]
for hook in alpm_hooks:
  source = f"default/libalpm/hooks/{hook}"
  destination = f"/usr/share/libalpm/hooks/{hook}"
  if not (root / source).exists():
    errors.append(f"missing package default source: {source}")
  if source not in midhat_pkgbuild or destination not in midhat_pkgbuild:
    errors.append(f"midhat PKGBUILD does not install {source} -> {destination}")

if errors:
  print("\n".join(errors), file=sys.stderr)
  sys.exit(1)
PY
pass "package-owned defaults live outside config"

grep -F 'dofile((os.getenv("MIDHAT_PATH") or "/usr/share/midhat") .. "/default/hypr/bootstrap.lua")' "$ROOT/config/hypr/hyprland.lua" >/dev/null
grep -F 'require("default.hypr.midhat")' "$ROOT/config/hypr/hyprland.lua" >/dev/null
grep -F 'package.path = home' "$ROOT/default/hypr/bootstrap.lua" >/dev/null
grep -F '/.local/state/?.lua;' "$ROOT/default/hypr/bootstrap.lua" >/dev/null
pass "Hyprland user entrypoint keeps package and state path bootstrap in defaults"

MIDHAT_PATH="$ROOT" lua <<'LUA'
package.loaded["default.hypr.midhat"] = true
package.loaded["default.hypr.require_optional"] = true
package.loaded["hypr.looknfeel"] = true
package.loaded["midhat.current.theme.hyprland"] = true
package.loaded["unrelated.module"] = true

dofile(os.getenv("MIDHAT_PATH") .. "/default/hypr/bootstrap.lua")

assert(package.loaded["default.hypr.midhat"] == nil)
assert(package.loaded["default.hypr.require_optional"] == nil)
assert(package.loaded["hypr.looknfeel"] == nil)
assert(package.loaded["midhat.current.theme.hyprland"] == nil)
assert(package.loaded["unrelated.module"] == true)
LUA
pass "Hyprland bootstrap reloads cached Mid’hat config modules"

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/home/.config/midhat"

ipc_mock_bin="$TMPDIR/ipc-mock"
mkdir -p "$ipc_mock_bin"
cat >"$ipc_mock_bin/midhat-shell" <<'SH'
#!/bin/bash
set -euo pipefail

mkdir -p "$HOME/.local/state/midhat"
printf '%s\n' "$*" >>"$HOME/.local/state/midhat/shell-ipc-calls"
printf 'ok\n'
SH
chmod +x "$ipc_mock_bin/midhat-shell"
export PATH="$ipc_mock_bin:$PATH"

cat >"$TMPDIR/home/.config/midhat/shell.json" <<'JSON'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [{ "id": "midhat.menu" }, { "id": "midhat.workspaces" }, { "id": "midhat.active-window" }],
      "center": [{ "id": "midhat.clock" }, { "id": "midhat.weather" }, { "id": "midhat.system-update" }, { "id": "midhat.tailscale" }],
      "right": [{ "id": "midhat.tray" }, { "id": "midhat.microphone" }, { "id": "midhat.bluetooth" }]
    }
  },
  "plugins": []
}
JSON

mkdir -p "$TMPDIR/home/.config/midhat/plugins/local.demo-bar"
cat >"$TMPDIR/home/.config/midhat/plugins/local.demo-bar/manifest.json" <<'JSON'
{
  "schemaVersion": 1,
  "id": "local.demo-bar",
  "name": "Demo bar",
  "version": "1.0.0",
  "author": "Test",
  "description": "Replacement bar for config tests",
  "kinds": ["bar"],
  "entryPoints": { "bar": "Bar.qml" }
}
JSON
touch "$TMPDIR/home/.config/midhat/plugins/local.demo-bar/Bar.qml"

if HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar use local.nonexistent-bar 2>/dev/null; then
  fail "bar use accepted an unknown bar option"
fi
pass "bar use rejects an unknown bar option"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar use local.demo-bar
jq -e '.bar.id == "local.demo-bar"' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
pass "shell config selects a bar option"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar reset
jq -e '.bar.id == null' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
pass "shell config resets to built-in bar option"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar move midhat.active-window right
grep -Fqx 'shell moveBarWidget midhat.active-window {"section":"right"}' \
  "$TMPDIR/home/.local/state/midhat/shell-ipc-calls"
pass "bar move accepts a positional target section"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar move midhat.active-window left
grep -Fqx 'shell moveBarWidget midhat.active-window {"section":"left"}' \
  "$TMPDIR/home/.local/state/midhat/shell-ipc-calls"
pass "bar move can restore a widget with positional syntax"

if HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar move midhat.active-window left --section right 2>/dev/null; then
  fail "bar move accepted positional and flagged target sections"
fi
pass "bar move rejects conflicting target section syntax"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar position bottom
jq -e '
  .bar.position == "bottom" and
  .plugins == []
' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
pass "shell config sets bar position"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar transparent true
jq -e '
  .bar.transparent == true and
  .bar.position == "bottom" and
  .plugins == []
' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
pass "shell config sets bar transparency"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar transparent toggle
jq -e '.bar.transparent == false' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
pass "shell config toggles bar transparency"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar set midhat.bluetooth enabled false --json
grep -Fqx 'shell setBarWidget midhat.bluetooth enabled false {}' \
  "$TMPDIR/home/.local/state/midhat/shell-ipc-calls"
pass "bar set accepts false JSON values"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar set midhat.bluetooth optional null --json
grep -Fqx 'shell setBarWidget midhat.bluetooth optional null {}' \
  "$TMPDIR/home/.local/state/midhat/shell-ipc-calls"
pass "bar set accepts null JSON values"

if HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar set midhat.bluetooth broken '{' --json 2>/dev/null; then
  fail "bar set accepted malformed JSON"
fi
pass "bar set rejects malformed JSON"

if HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" midhat-bar set midhat.bluetooth broken 'false null' --json 2>/dev/null; then
  fail "bar set accepted multiple JSON values"
fi
pass "bar set rejects multiple JSON values"

mock_bin="$TMPDIR/mock-bin"
mkdir -p "$mock_bin"

cat >"$mock_bin/midhat-refresh-config" <<'SH'
#!/bin/bash
set -euo pipefail

relative_path="${1:-}"
[[ -n $relative_path ]] || exit 1
mkdir -p "$HOME/.config/$(dirname "$relative_path")"
cp "$MIDHAT_PATH/config/$relative_path" "$HOME/.config/$relative_path"
SH

cat >"$mock_bin/midhat-restart-shell" <<'SH'
#!/bin/bash
set -euo pipefail

mkdir -p "$HOME/.local/state/midhat"
touch "$HOME/.local/state/midhat/restart-shell-called"
SH

cat >"$mock_bin/midhat-shell" <<'SH'
#!/bin/bash
[[ ${MIDHAT_TEST_SHELL_DOWN:-0} == "1" ]] && exit 1
printf 'ok\n'
SH

cat >"$mock_bin/midhat-installed-service-dropbox" <<'SH'
#!/bin/bash
set -euo pipefail

[[ ${MIDHAT_TEST_DROPBOX:-0} == "1" ]]
SH

cat >"$mock_bin/midhat-installed-service-tailscale" <<'SH'
#!/bin/bash
set -euo pipefail

[[ ${MIDHAT_TEST_TAILSCALE:-0} == "1" ]]
SH

chmod +x "$mock_bin"/*
mock_path="$mock_bin:$ROOT/bin:$PATH"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" PATH="$mock_path" MIDHAT_TEST_DROPBOX=0 MIDHAT_TEST_TAILSCALE=0 midhat-bar defaults
jq -e --slurpfile defaults "$ROOT/config/midhat/shell.json" '
  .bar == $defaults[0].bar and
  .plugins == []
' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
pass "bar defaults restores the stock bar"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" PATH="$mock_path" MIDHAT_TEST_DROPBOX=1 MIDHAT_TEST_TAILSCALE=1 midhat-bar defaults
jq -e '
  def ids: map(.id // .);
  (.bar.layout.right | ids) as $right |
  ($right | index("midhat.tray")) as $tray |
  ($right | index("midhat.tailscale") == $tray + 1) and
  ($right | index("midhat.dropbox") == $tray + 2) and
  (.bar.layout.center | ids | index("midhat.tailscale") == null)
' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
pass "bar defaults places plugins for running optional services"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" PATH="$mock_path" \
  MIDHAT_TEST_SHELL_DOWN=1 MIDHAT_TEST_DROPBOX=1 MIDHAT_TEST_TAILSCALE=1 \
  midhat-bar defaults
jq -e '
  def ids: map(.id // .);
  (.bar.layout.right | ids) as $right |
  ($right | index("midhat.tray")) as $tray |
  ($right | index("midhat.tailscale") == $tray + 1) and
  ($right | index("midhat.dropbox") == $tray + 2) and
  (.bar.layout.center | ids | index("midhat.tailscale") == null)
' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
pass "bar defaults places service widgets without a running shell"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" PATH="$mock_path" MIDHAT_TEST_DROPBOX=0 MIDHAT_TEST_TAILSCALE=0 midhat-refresh-shell
jq -e '
  def ids: map(.id // .);
  ([.bar.layout.left, .bar.layout.center, .bar.layout.right] | map(ids) | add) as $all |
  ($all | index("midhat.dropbox") == null) and
  ($all | index("midhat.tailscale") == null)
' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
pass "shell refresh keeps optional service widgets absent when services are unavailable"

HOME="$TMPDIR/home" MIDHAT_PATH="$ROOT" PATH="$mock_path" MIDHAT_TEST_DROPBOX=1 MIDHAT_TEST_TAILSCALE=1 midhat-refresh-shell
jq -e '
  def ids: map(.id // .);
  (.bar.layout.right | ids) as $right |
  ($right | index("midhat.tray")) as $tray |
  ($right | index("midhat.tailscale") == $tray + 1) and
  ($right | index("midhat.dropbox") == $tray + 2) and
  (.bar.layout.center | ids | index("midhat.tailscale") == null)
' "$TMPDIR/home/.config/midhat/shell.json" >/dev/null
[[ -f $TMPDIR/home/.local/state/midhat/restart-shell-called ]] || fail "shell refresh restarts shell"
pass "shell refresh places optional service widgets when services are available"
