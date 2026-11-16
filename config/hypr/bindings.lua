-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   midhat menu keybindings --print

-- To disable every Mid’hat default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.midhat"), then add
-- only the bindings you want below:
--   midhat_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   midhat_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Mid’hat root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Mid’hat menu", "midhat-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "midhat-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "midhat-shell shell toggle midhat.emojis")
