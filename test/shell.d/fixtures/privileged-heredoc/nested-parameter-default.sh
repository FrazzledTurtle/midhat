#!/bin/bash

# midhat:heredoc-expands paths=none -- review regression fixture
sudo tee /etc/midhat/review.conf >/dev/null <<EOF
ExecStart=${target:-$HOME/.local/bin/payload}
EOF
