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

pkgs=("$@")
(( ${#pkgs[@]} )) || pkgs=(midhat-settings midhat midhat-nvim midhat-annotate oskar libinput koreader)
for name in "${pkgs[@]}"; do
  echo -e "\e[32m\nBuilding $name\e[0m"
  for key in "$root/pkgbuilds/$name"/keys/pgp/*.asc; do
    if [[ -f $key ]]; then
      gpg --quiet --import "$key"
    fi
  done
  (cd "$root/pkgbuilds/$name" && PKGDEST="$out" makepkg --force --nodeps --cleanbuild --noconfirm)
done

echo
ls -1 "$out"/*.pkg.tar.zst
