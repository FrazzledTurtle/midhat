cat <<'EOF' | sudo tee /etc/udev/rules.d/99-midhat.rules >/dev/null
SUBSYSTEM=="power_supply", RUN+="/usr/bin/midhat-powerprofiles-set $HOME"
EOF

cat <<"XML" | sudo tee /etc/midhat/agent.xml >/dev/null
<config path="$HOME/.local/share/midhat" />
XML
