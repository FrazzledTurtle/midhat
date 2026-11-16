# midhat:heredoc-expands paths=none -- the positional argument is a scalar
sudo tee /etc/midhat/example.conf <<EOF
argument=$1
command=$HOME/.local/share/midhat/bin/example
EOF
