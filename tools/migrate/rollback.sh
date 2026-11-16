#!/bin/bash

# Undo a Mid’hat switch made by tools/migrate/switch.sh.
#
#   sudo bash ~/Work/midhat-os/tools/migrate/rollback.sh <time>
#
# <time> is the folder name under /var/lib/midhat-switch/ (switch.sh prints
# it). Your home goes back first, step by step from the switch's manifest,
# with the original files taken from the read-only /home snapshot. Then
# snapper puts / back as it was in the snapshot taken before the switch:
# the Omarchy packages, /etc, /var/lib. Reboot afterwards.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
die() { echo -e "\e[31mrollback: $*\e[0m" >&2; exit 1; }

(( EUID == 0 )) || die "run it with sudo: sudo bash $0 <time>"
stamp=${1:-}
keep=/var/lib/midhat-switch/$stamp
[[ -n $stamp && -d $keep ]] || die "usage: $0 <time>, one of: $(ls /var/lib/midhat-switch 2>/dev/null | tr '\n' ' ')"

user=$(<"$keep/user")
home=$(getent passwd "$user" | cut -d: -f6)
snapshot=$(<"$keep/snapper-root")
home_snapshot=$(<"$keep/home-snapshot")
manifest=$keep/home/home.json
[[ -d $home_snapshot ]] || die "the /home snapshot $home_snapshot is gone"

cat <<EOF

This puts $(hostname) back on Omarchy:
  home  undo the switch's $(jq length "$manifest" 2>/dev/null || echo 0) steps in $home
  /     snapper undochange $snapshot..0 (everything on / since the switch)
EOF
read -r -p "Roll back now? [y/N] " answer
[[ $answer == [yY]* ]] || die "nothing changed"

if [[ -f $manifest ]]; then
  manifest_copy=$(mktemp)
  cp "$manifest" "$manifest_copy"
  chmod 644 "$manifest_copy"
  runuser -u "$user" -- python3 "$root/tools/migrate/home.py" rollback "$home" "$manifest_copy" \
    "$home_snapshot/${home#/home/}"
  rm -f "$manifest_copy"
fi

# This also removes /var/lib/midhat-switch/$stamp, which was made after the
# snapshot.
snapper -c root undochange "$snapshot..0"

cat <<EOF

Back on Omarchy. Once you are happy, free the space of the /home snapshot:
  sudo btrfs subvolume delete $home_snapshot

EOF
read -r -p "Reboot now? [Y/n] " answer
[[ $answer == [nN]* ]] || systemctl reboot
