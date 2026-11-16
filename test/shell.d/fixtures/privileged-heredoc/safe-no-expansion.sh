cat <<EOF | sudo tee /etc/udev/rules.d/99-midhat.rules >/dev/null
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="/usr/bin/midhat-powerprofiles-set"
EOF
