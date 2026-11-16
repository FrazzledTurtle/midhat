#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

if matches=$(rg -n 'root\.bar\.midhatPath|/bin/midhat-' "$ROOT/shell/plugins/panels" -g '*.qml'); then
  fail "panels do not resolve midhat helpers through bar paths" "$matches"
fi

pass "panels avoid bar path resolution for midhat helpers"
