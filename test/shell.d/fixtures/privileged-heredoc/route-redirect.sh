# A plain redirect into /etc, no sudo: the command re-execs itself as root.
cat >/etc/midhat/agent.conf <<EOF
helper=$HOME/.local/share/midhat/bin/midhat-agent
EOF
