# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run midhat-restart-xcompose to apply changes

# Include fast emoji access
include "/usr/share/midhat/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$MIDHAT_USER_NAME"
<Multi_key> <space> <e> : "$MIDHAT_USER_EMAIL"
EOF
