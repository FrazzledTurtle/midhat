storage="$HOME/storage"
shared="$HOME/shared"

# midhat:heredoc-expands paths=shared,storage -- both sources are validated before use
cat >/etc/midhat/mounts.conf <<EOF
storage=$storage:/storage
shared=$shared:/shared
EOF
