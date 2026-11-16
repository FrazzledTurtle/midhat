echo "Relink agent skill symlinks to default/agents/skills/midhat"

mkdir -p ~/.agents/skills ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills
ln -sfn "$MIDHAT_PATH/default/agents/skills/midhat" ~/.agents/skills/midhat
ln -sfn "$MIDHAT_PATH/default/agents/skills/midhat" ~/.claude/skills/midhat
ln -sfn "$MIDHAT_PATH/default/agents/skills/midhat" ~/.codex/skills/midhat
ln -sfn "$MIDHAT_PATH/default/agents/skills/midhat" ~/.pi/agent/skills/midhat
