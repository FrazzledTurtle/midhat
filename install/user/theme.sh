# Setup user theme folder and seed the default only when no theme exists yet.
mkdir -p ~/.config/midhat/themes

if [[ ! -s $HOME/.local/state/midhat/current/theme.name ]]; then
  # iso-chroot and provision-owner both run without a live session to notify.
  if [[ ${MIDHAT_SETUP_CONTEXT:-runtime} != "runtime" ]]; then
    MIDHAT_THEME_HEADLESS=1 midhat-theme-set "E Ink Mono"
    rm -f ~/.config/chromium/SingletonLock # otherwise archiso owns the Chromium singleton
  else
    midhat-theme-set "E Ink Mono"
  fi
fi
midhat-theme-set-pi --activate

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/midhat/current/theme/btop.theme" ~/.config/btop/themes/current.theme
