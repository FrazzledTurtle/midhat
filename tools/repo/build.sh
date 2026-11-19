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
missing=()
for name in "${pkgs[@]}"; do
  mapfile -t -O "${#missing[@]}" missing < <(
    cd "$root/pkgbuilds/$name" && source ./PKGBUILD && pacman -T "${makedepends[@]}" || true
  )
done
if command -v cargo >/dev/null; then
  for i in "${!missing[@]}"; do
    if [[ ${missing[i]} == "rust" ]]; then
      unset 'missing[i]'
    fi
  done
fi
if (( ${#missing[@]} )); then
  echo "Install the build tools first: sudo pacman -S --needed ${missing[*]}" >&2
  exit 1
fi

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
