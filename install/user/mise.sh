# Upgrades must not delete the version a running process is executing from:
# mise up would prune the old install dir out from under a live session.
mise settings set upgrade.auto_prune false

midhat-mise-install codex
midhat-mise-install claude
midhat-mise-install crush
midhat-mise-install gemini
midhat-mise-install gh
midhat-mise-install copilot
midhat-mise-install opencode
midhat-mise-install npm:playwright playwright
midhat-mise-install pi
midhat-mise-install github:can1357/oh-my-pi omp
midhat-mise-install npm:@xai-official/grok grok
# Cursor's own installer links the same path, so a re-provision keeps it.
midhat-cmd-missing cursor-agent && midhat-mise-install cursor-agent
midhat-mise-install npm:@kitlangton/ghui ghui
midhat-mise-install aqua:modem-dev/hunk hunk
if midhat-cmd-missing muse; then
  midhat-mise-install "http:muse[url=https://api.meta.ai/muse-launcher.sh,bin=muse,version_list_url=https://api.meta.ai/muse-code/channels/muse-stable,version_json_path=.version]" muse
fi
