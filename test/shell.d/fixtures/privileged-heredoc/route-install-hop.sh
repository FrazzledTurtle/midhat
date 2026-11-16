tmp=$(mktemp)

cat >"$tmp" <<EOF
#!/bin/bash
exec "$HOME/.local/share/midhat/bin/midhat-agent" "$@"
EOF

sudo install -m 0755 "$tmp" /usr/local/bin/midhat-agent-shim
