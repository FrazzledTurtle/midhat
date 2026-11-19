echo "Replace Tensaku with Mid’hat Annotate"

if midhat-pkg-present tensaku; then
  midhat-pkg-drop tensaku
fi
midhat-pkg-add midhat-annotate

for dir in "$HOME/.config" "$HOME/.local/state"; do
  if [[ -d $dir/tensaku && ! -e $dir/midhat-annotate ]]; then
    mv "$dir/tensaku" "$dir/midhat-annotate"
  fi
done

if [[ -f $HOME/.config/imv/config ]]; then
  sed -i "s/tensaku-edit/midhat-annotate-edit/g; s/in Tensaku/in Mid’hat Annotate/" "$HOME/.config/imv/config"
fi
