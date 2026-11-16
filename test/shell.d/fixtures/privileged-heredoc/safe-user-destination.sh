mkdir -p ~/.config/midhat

cat >~/.config/midhat/agent.conf <<EOF
helper=$HOME/.local/share/midhat/bin/midhat-agent
EOF

cat >"$HOME/.local/bin/midhat-shim" <<EOF
exec "$MIDHAT_PATH/bin/midhat-agent" "$@"
EOF
