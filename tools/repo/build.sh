#!/bin/bash

# Build Mid’hat's packages into out/. midhat and midhat-settings are built from
# the committed HEAD, so commit first; the build says so when the tree is dirty.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=$root/out
mkdir -p "$out"

if [[ -n $(git -C "$root" status --porcelain --untracked-files=no) ]]; then
  echo "Note: uncommitted changes are not in these packages (they build from HEAD)." >&2
fi

# The nvim repack's upstream package is usually in pacman's cache already.
nvim_src=omarchy-nvim-2026.8.13-1-any.pkg.tar.zst
if [[ ! -f $root/pkgbuilds/midhat-nvim/$nvim_src && -f /var/cache/pacman/pkg/$nvim_src ]]; then
  cp /var/cache/pacman/pkg/$nvim_src "$root/pkgbuilds/midhat-nvim/"
fi

pkgs=("$@")
(( ${#pkgs[@]} )) || pkgs=(midhat-settings midhat midhat-nvim midhat-annotate oskar libinput koreader)
for name in "${pkgs[@]}"; do
  echo -e "\e[32m\nBuilding $name\e[0m"
  for key in "$root/pkgbuilds/$name"/keys/pgp/*.asc; do
    [[ -f $key ]] && gpg --quiet --import "$key"
  done
  (cd "$root/pkgbuilds/$name" && PKGDEST="$out" makepkg --force --nodeps --cleanbuild --noconfirm)
done

echo
ls -1 "$out"/*.pkg.tar.zst
