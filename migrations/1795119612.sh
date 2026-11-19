echo "Use the Calendar Clock that ships with Mid’hat instead of the plugin clone"

clone="$HOME/.config/midhat/plugins/matteodevenuto.clock"
if [[ -d $clone && ! -L $clone ]]; then
  mkdir -p "$HOME/.local/share/midhat"
  mv "$clone" "$HOME/.local/share/midhat/calendar-clock-clone-$(date +%Y%m%d%H%M%S)"
fi

shell_json="$HOME/.config/midhat/shell.json"
if [[ -f $shell_json ]] && grep -qF '"matteodevenuto.clock"' "$shell_json"; then
  sed -i 's/"matteodevenuto\.clock"/"midhat.calendar-clock"/g' "$shell_json"
fi
