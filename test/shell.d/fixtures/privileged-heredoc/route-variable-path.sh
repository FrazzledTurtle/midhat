DROP_IN=/etc/systemd/system/midhat-agent.service.d/override.conf

cat <<EOF | sudo tee "$DROP_IN" >/dev/null
[Service]
ExecStart=$MIDHAT_PATH/bin/midhat-agent
EOF
