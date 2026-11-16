# Set identification from install inputs
if [[ -n ${MIDHAT_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$MIDHAT_USER_NAME"
fi

if [[ -n ${MIDHAT_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$MIDHAT_USER_EMAIL"
fi
