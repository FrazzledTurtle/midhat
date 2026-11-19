echo "Apply Mid’hat's browser policy to Zen in /opt/zen-browser-bin"

source "$MIDHAT_PATH/install/helpers/browser-policy.sh"

zen=/opt/zen-browser-bin/distribution
if [[ -x /opt/zen-browser-bin/zen-bin ]]; then
  if [[ -f $zen/policies.json ]]; then
    browser_policy_firefox_merge_preferences "$zen"
  else
    browser_policy_setup_firefox_distribution "$zen"
  fi
fi

if [[ -f /usr/lib/firefox/distribution/policies.json ]]; then
  browser_policy_firefox_merge_preferences /usr/lib/firefox/distribution
fi
