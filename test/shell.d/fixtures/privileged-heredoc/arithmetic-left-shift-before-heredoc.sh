mask=$((1 << bits))

cat >/etc/midhat/agent.conf <<EOF
helper=$HOME/.local/share/midhat/bin/midhat-agent
EOF
