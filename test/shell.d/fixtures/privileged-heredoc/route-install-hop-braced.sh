tmp=/tmp/midhat-generated
cat >"$tmp" <<EOF
command=$HOME/.local/share/midhat/bin/example
EOF
sudo install -m644 "${tmp}" /etc/midhat/example.conf
