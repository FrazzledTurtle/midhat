echo "Use the agent card that ships with Mid’hat"

bindings="$HOME/.config/hypr/bindings.lua"
if [[ -f $bindings ]] && grep -qF '"agent-card")' "$bindings"; then
  sed -i 's/"agent-card")/"midhat-agent-card")/' "$bindings"
fi

old="$HOME/.local/bin/agent-card"
if [[ -f $old ]] && grep -qF 'agent-card.lock' "$old"; then
  mkdir -p "$HOME/.local/share/midhat"
  mv "$old" "$HOME/.local/share/midhat/agent-card-$(date +%Y%m%d%H%M%S)"
fi
