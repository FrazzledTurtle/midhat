echo "Install oh-my-pi (omp) via mise wrapper"

if [[ ! -f $HOME/.local/state/midhat/preinstalls-removed ]]; then
  midhat-mise-install github:can1357/oh-my-pi omp
fi
