#!/bin/bash

# Publish the newest package of each name in out/ as the [midhat] pacman repo:
# the GitHub release tagged "repo" holds the packages plus midhat.db and
# midhat.files, which is what default/pacman/midhat-repo.conf points at.
# Assets of older package versions are deleted from the release.

set -euo pipefail

gh_repo=${MIDHAT_GH_REPO:-FrazzledTurtle/midhat}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
out=$root/out
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

gh repo view "$gh_repo" >/dev/null 2>&1 || {
  echo "GitHub repo $gh_repo does not exist yet. Create it first, for example:" >&2
  echo "  gh repo create $gh_repo --public --source $root --push" >&2
  exit 1
}

declare -A newest
for file in "$out"/*.pkg.tar.zst; do
  name=$(bsdtar -xOf "$file" .PKGINFO | sed -n 's/^pkgname = //p')
  if [[ -z ${newest[$name]:-} ]] || (( $(vercmp "$(bsdtar -xOf "$file" .PKGINFO | sed -n 's/^pkgver = //p')" \
    "$(bsdtar -xOf "${newest[$name]}" .PKGINFO | sed -n 's/^pkgver = //p')") > 0 )); then
    newest[$name]=$file
  fi
done
(( ${#newest[@]} > 0 )) || { echo "No packages in $out; run tools/repo/build.sh first." >&2; exit 1; }

cp "${newest[@]}" "$stage/"
(cd "$stage" && repo-add --quiet midhat.db.tar.gz ./*.pkg.tar.zst)
# Release assets cannot be symlinks, so the names pacman asks for are copies.
for db in db files; do
  cp --remove-destination "$(readlink -f "$stage/midhat.$db.tar.gz")" "$stage/midhat.$db"
done

gh release view repo --repo "$gh_repo" >/dev/null 2>&1 ||
  gh release create repo --repo "$gh_repo" --title "[midhat] package repo" \
    --notes "Rolling pacman repo for Mid’hat. Add default/pacman/midhat-repo.conf to /etc/pacman.conf." --latest=false

gh release upload repo --repo "$gh_repo" --clobber "$stage"/*
keep=$(cd "$stage" && ls -1)
gh release view repo --repo "$gh_repo" --json assets --jq '.assets[].name' | while read -r asset; do
  grep -qxF "$asset" <<<"$keep" || gh release delete-asset repo "$asset" --repo "$gh_repo" --yes
done

echo "Published: $(cd "$stage" && ls -1 ./*.pkg.tar.zst | xargs -n1 basename | tr '\n' ' ')"
