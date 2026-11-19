echo "Use the Yaru-Mono icon builder that ships with Mid’hat"

old="$HOME/.local/bin/yaru-mono"
if [[ -f $old ]] && grep -qF 'Yaru-Mono' "$old"; then
  mkdir -p "$HOME/.local/share/midhat"
  mv "$old" "$HOME/.local/share/midhat/yaru-mono-$(date +%Y%m%d%H%M%S)"
fi
