echo "Install OSKar from the [midhat] repo in place of the plugin clone"

midhat-pkg-add oskar

registration="$HOME/.config/midhat/plugins/io.github.vladkarok.oskar"
if [[ -d $registration && ! -L $registration ]]; then
  mkdir -p "$HOME/.local/share/midhat"
  mv "$registration" "$HOME/.local/share/midhat/oskar-clone-$(date +%Y%m%d%H%M%S)"
fi

/usr/bin/oskar setup --migrate-source
