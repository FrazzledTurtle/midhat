#!/bin/bash

cat <<EOF | \
  sudo tee /etc/midhat/review.conf
ExecStart=$HOME/.local/bin/payload
EOF
