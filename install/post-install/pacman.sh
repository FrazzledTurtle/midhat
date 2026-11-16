# The tablet image ships its own pacman.conf (Arch Linux ARM plus the board
# repos); Mid’hat only adds its [midhat] repo in front of them.
if ! grep -q '^\[midhat\]' /etc/pacman.conf; then
  section=$(<"$MIDHAT_PATH/default/pacman/midhat-repo.conf")
  awk -v section="$section" '
    !done && /^\[/ && $0 != "[options]" { print section; print ""; done = 1 }
    { print }
    END { if (!done) { print ""; print section } }
  ' /etc/pacman.conf >/etc/pacman.conf.new
  mv /etc/pacman.conf.new /etc/pacman.conf
fi

# Wait for CUPS to own the file, the way midhat-settings does, so pacman does
# not turn the override into a .pacnew during ISO package installation.
if [[ -f $MIDHAT_PATH/etc-overrides/cups-cups-files.conf && -f /etc/cups/cups-files.conf ]]; then
  install -m 0640 -o root -g cups "$MIDHAT_PATH/etc-overrides/cups-cups-files.conf" /etc/cups/cups-files.conf
  rm -f /etc/cups/cups-files.conf.pacnew
fi

source "$MIDHAT_INSTALL/hardware/pacman.sh"
