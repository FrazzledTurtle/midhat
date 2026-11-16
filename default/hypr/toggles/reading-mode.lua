-- Reading mode: a grey screen without animations (midhat-toggle-reading-mode).
local paths = require("default.hypr.paths")

hl.config({
  decoration = {
    screen_shader = paths.midhat_path .. "/default/hypr/shaders/reading-mode.frag",
  },

  animations = {
    enabled = false,
  },
})
