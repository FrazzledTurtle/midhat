tmp=/tmp/midhat-generated
copy=$tmp
cat >"$tmp" <<EOF
command=$HOME/.local/share/midhat/bin/example
EOF
sudo install -m644 "$copy" /etc/midhat/example.conf
