-- Restore workspace layouts saved by midhat-hyprland-workspace-layout-toggle.

local paths = require("default.hypr.paths")
local require_all = require("default.hypr.require_all")

local layouts_dir = paths.state_home .. "/midhat/workspace-layouts"

require_all.files(layouts_dir, "midhat.workspace-layouts", { reload = true })
