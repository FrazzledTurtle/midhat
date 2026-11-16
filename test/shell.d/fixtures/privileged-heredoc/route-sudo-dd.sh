sudo dd status=none of=/etc/midhat/boot.conf <<EOF
cmdline=$boot_params
EOF
