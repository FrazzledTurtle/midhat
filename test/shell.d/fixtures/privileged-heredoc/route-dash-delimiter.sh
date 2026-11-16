if true; then
  cat <<-EOF | sudo tee /etc/midhat/indented.conf >/dev/null
	helper=$HOME/.local/share/midhat/bin/midhat-agent
	EOF
fi
