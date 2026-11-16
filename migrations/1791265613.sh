echo "Install the Dell XPS 13 Panther Lake speaker firmware"

if midhat-hw-dell-xps13-dx13260-ptl; then
  source "$MIDHAT_PATH/install/hardware/dell-xps13-ptl-speaker-firmware.sh"
  midhat-state set reboot-required
fi
