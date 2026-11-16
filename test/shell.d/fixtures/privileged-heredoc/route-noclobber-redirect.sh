# `>|` is a plain redirect with noclobber overridden, not a redirect into a pipe.
cat >|/etc/midhat/agent.conf <<EOF
helper=$HOME/.local/share/midhat/bin/midhat-agent
EOF
