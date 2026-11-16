#!/bin/bash

# Two hops. The scan resolves midhat_bin into helper, so the value it ends up
# judging still carries an unresolved $HOME rather than a literal path.
midhat_bin="$HOME/.local/share/midhat/bin"
helper="$midhat_bin/midhat-agent"

# midhat:heredoc-expands paths=none -- helper names the agent, no path is baked in
cat <<EOF | sudo tee /etc/udev/rules.d/99-midhat-agent.rules >/dev/null
SUBSYSTEM=="power_supply", RUN+="$helper"
EOF
