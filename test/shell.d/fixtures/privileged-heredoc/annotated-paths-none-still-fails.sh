if midhat-battery-present; then
  # midhat:heredoc-expands paths=none -- only interpolates the midhat bin path
  cat <<EOF | sudo tee "/etc/udev/rules.d/99-power-profile.rules"
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="/usr/bin/systemd-run --no-block --collect --unit=midhat-power-profile --property=After=power-profiles-daemon.service $HOME/.local/share/midhat/bin/midhat-powerprofiles-set"
SUBSYSTEM=="power_supply", ATTR{type}=="USB", RUN+="/usr/bin/systemd-run --no-block --collect --unit=midhat-power-profile --property=After=power-profiles-daemon.service $HOME/.local/share/midhat/bin/midhat-powerprofiles-set"
EOF

  sudo systemctl enable power-profiles-daemon

  sudo udevadm control --reload 2>/dev/null
  sudo udevadm trigger --subsystem-match=power_supply 2>/dev/null
fi
