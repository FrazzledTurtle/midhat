#!/bin/bash

# Switch this FydeTab from Omarchy to Mid’hat, in place.
#
#   sudo bash ~/Work/midhat-os/tools/migrate/switch.sh
#
# Build the packages first (tools/repo/build.sh). The switch:
#   1. saves a way back: a snapper snapshot of / (packages, /etc, /var/lib),
#      a read-only btrfs snapshot of /home, and copies of the /etc files it
#      changes; notes go to /var/lib/midhat-switch/<time>/
#   2. replaces omarchy, omarchy-settings and omarchy-nvim with midhat,
#      midhat-settings and midhat-nvim in one pacman transaction, then removes
#      omarchy-keyring and plymouth
#   3. renames Omarchy's leftovers in /etc and /var/lib
#   4. moves your home to the Mid’hat names (tools/migrate/home.py, as you)
# Then reboot. tools/migrate/rollback.sh undoes all of it.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
stamp=$(date +%Y%m%d-%H%M%S)
keep=/var/lib/midhat-switch/$stamp

die() { echo -e "\e[31mswitch: $*\e[0m" >&2; exit 1; }
step() { echo -e "\e[32m\n== $*\e[0m"; }

(( EUID == 0 )) || die "run it with sudo: sudo bash $0"
user=${SUDO_USER:-}
[[ -n $user && $user != "root" ]] || die "run it with sudo from your own account, not as root"
home=$(getent passwd "$user" | cut -d: -f6)

newest() {
  ls -1 "$root"/out/"$1"-[0-9]*.pkg.tar.zst 2>/dev/null | sort -V | tail -n 1
}
pkgs=()
for name in midhat midhat-settings midhat-nvim; do
  file=$(newest "$name")
  [[ -n $file ]] || die "no $name package in $root/out; run tools/repo/build.sh first"
  pkgs+=("$file")
done

snapper list-configs 2>/dev/null | grep -q '^root ' || die "no snapper config for /, so there would be no way back"
[[ $(findmnt -no FSTYPE /home) == "btrfs" ]] && btrfs subvolume show /home &>/dev/null ||
  die "/home is not a btrfs subvolume, so there would be no way back for your home"
pacman -Q omarchy &>/dev/null || die "omarchy is not installed; nothing to switch (already on Mid’hat?)"
[[ ! -e /var/lib/pacman/db.lck ]] || die "pacman is busy (/var/lib/pacman/db.lck exists)"
for dir in .config/midhat .local/state/midhat .cache/midhat; do
  [[ ! -e $home/$dir ]] || die "$home/$dir already exists; move it away first"
done
runuser -u "$user" -- python3 "$root/tools/migrate/home.py" switch "$home" /dev/null --dry-run >/dev/null ||
  die "the home dry run failed"

cat <<EOF

This switches $(hostname) from Omarchy to Mid’hat:

  install   $(printf '%s ' "${pkgs[@]##*/}")
  remove    omarchy omarchy-settings omarchy-nvim omarchy-keyring plymouth
  rename    /etc and /var/lib leftovers, and your ~/.config/omarchy,
            ~/.local/state/omarchy and ~/.cache/omarchy with what points at them
  rollback  material goes to $keep

Close other apps first. When it is done, reboot.
EOF
read -r -p "Switch to Mid’hat now? [y/N] " answer
[[ $answer == [yY]* ]] || die "nothing changed"

mkdir -p "$keep"
install -d -o "$user" "$keep/home"
echo "$user" >"$keep/user"

step "Snapshots"
# No cleanup algorithm: snapper's number limit must not delete the way back.
snapper -c root create --description "before the Mid’hat switch" --print-number >"$keep/snapper-root"
echo "snapper root snapshot #$(<"$keep/snapper-root")"
btrfs subvolume snapshot -r /home "/home/.midhat-switch-$stamp" >/dev/null
echo "/home/.midhat-switch-$stamp" >"$keep/home-snapshot"
echo "read-only /home snapshot at /home/.midhat-switch-$stamp"
trap 'echo -e "\e[31m\nThe switch stopped before it finished; nothing after the failed step ran.\nTo go back: sudo bash $root/tools/migrate/rollback.sh $stamp\e[0m" >&2' ERR

etc_files=(
  /etc/pacman.conf
  /etc/omarchy.conf
  /etc/pam.d/omarchy-lock-password
  /etc/sddm.conf.d/zz-fydetab-omarchy.conf
  /etc/NetworkManager/conf.d/20-omarchy-dns.conf
  /etc/ssh/ssh_config.d/20-omarchy-keepalive.conf
  /etc/chromium/policies/managed/omarchy.json
  /etc/systemd/system/omarchy-provision-owner.service
  /etc/skel/.config/omarchy
  /var/lib/omarchy
)
existing=()
for f in "${etc_files[@]}"; do
  [[ -e $f ]] && existing+=("${f#/}")
done
tar -C / -cpf "$keep/etc.tar" "${existing[@]}"

step "pacman.conf"
sed -i -E '/^IgnorePkg[[:space:]]*=/ { s/[[:space:]]+(omarchy|omarchy-settings|omarchy-keyring|omarchy-nvim)\b//g; /^IgnorePkg[[:space:]]*=[[:space:]]*$/d }' /etc/pacman.conf
sed -i -E '\#^NoExtract[[:space:]]*=[[:space:]]*etc/mkinitcpio\.conf\.d/(omarchy_hooks|thunderbolt_module)\.conf$#d' /etc/pacman.conf
repo_url=$(sed -n 's/^Server = //p' "$root/default/pacman/midhat-repo.conf")
if grep -q '^\[midhat\]' /etc/pacman.conf; then
  echo "[midhat] is already listed"
elif curl -fsIL --max-time 15 "$repo_url/midhat.db" -o /dev/null; then
  section=$(<"$root/default/pacman/midhat-repo.conf")
  awk -v section="$section" '
    !done && /^\[/ && $0 != "[options]" { print section; print ""; done = 1 }
    { print }
    END { if (!done) { print ""; print section } }
  ' /etc/pacman.conf >/etc/pacman.conf.new
  mv /etc/pacman.conf.new /etc/pacman.conf
  echo "added [midhat]"
else
  echo "[midhat] is not published yet; add it later with midhat-refresh-pacman"
fi
grep -n -E '^(IgnorePkg|NoExtract)' /etc/pacman.conf || true

step "Packages"
# The running desktop must not reload its config while the files it reads are
# swapped; the reboot at the end starts it fresh.
/usr/bin/omarchy-hyprland-reload-guard pause || true
# --ask 4 answers "remove the conflicting omarchy package?" with yes; pacman
# still shows the transaction and asks before doing it.
pacman -U --ask 4 "${pkgs[@]}"
pacman -Q midhat midhat-settings midhat-nvim
leftover=()
for name in omarchy-keyring plymouth; do
  pacman -Q "$name" &>/dev/null && leftover+=("$name")
done
(( ${#leftover[@]} == 0 )) || pacman -Rns --noconfirm "${leftover[@]}"

step "System leftovers"
move_renamed() {
  local old=$1 new=$2
  [[ -e $old ]] || return 0
  sed 's/omarchy/midhat/g; s/Omarchy/Mid’hat/g' "$old" >"$new"
  chmod --reference="$old" "$new"
  rm -f "$old"
  echo "$old -> $new"
}
rm -f /etc/omarchy.conf
if [[ -e /etc/pam.d/omarchy-lock-password ]]; then
  cp -a /etc/pam.d/omarchy-lock-password /etc/pam.d/midhat-lock-password
  rm -f /etc/pam.d/omarchy-lock-password
  echo "/etc/pam.d/omarchy-lock-password -> midhat-lock-password"
fi
move_renamed /etc/sddm.conf.d/zz-fydetab-omarchy.conf /etc/sddm.conf.d/zz-fydetab-midhat.conf
move_renamed /etc/NetworkManager/conf.d/20-omarchy-dns.conf /etc/NetworkManager/conf.d/20-midhat-dns.conf
move_renamed /etc/ssh/ssh_config.d/20-omarchy-keepalive.conf /etc/ssh/ssh_config.d/20-midhat-keepalive.conf
move_renamed /etc/chromium/policies/managed/omarchy.json /etc/chromium/policies/managed/midhat.json
if [[ -e /etc/systemd/system/omarchy-provision-owner.service || -L /etc/systemd/system/omarchy-provision-owner.service ]]; then
  systemctl disable omarchy-provision-owner.service &>/dev/null || true
  rm -f /etc/systemd/system/omarchy-provision-owner.service
  systemctl daemon-reload
  echo "removed the finished first-boot unit omarchy-provision-owner.service"
fi
rm -rf /etc/skel/.config/omarchy
if [[ -d /var/lib/omarchy && ! -e /var/lib/midhat ]]; then
  mv /var/lib/omarchy /var/lib/midhat
  echo "/var/lib/omarchy -> /var/lib/midhat"
fi

step "Your home"
runuser -u "$user" -- python3 "$root/tools/migrate/home.py" switch "$home" "$keep/home/home.json"

step "Done"
left=$(find /etc /var/lib /usr/local -xdev -iname '*omarchy*' -not -name '*.omarchy.bak' -not -path '/var/lib/midhat-switch/*' 2>/dev/null || true)
[[ -z $left ]] || { echo "Still named omarchy (left alone):"; echo "$left"; }
cat <<EOF

Mid’hat is installed. Rollback material: $keep
To undo: sudo bash $root/tools/migrate/rollback.sh $stamp

EOF
read -r -p "Reboot now? [Y/n] " answer
[[ $answer == [nN]* ]] || systemctl reboot
