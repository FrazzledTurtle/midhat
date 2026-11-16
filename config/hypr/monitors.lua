-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local midhat_gdk_scale = 2
local midhat_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(midhat_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = midhat_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
