-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Mid’hat's bootstrap keeps path setup out of this user config.
dofile((os.getenv("MIDHAT_PATH") or "/usr/share/midhat") .. "/default/hypr/bootstrap.lua")

-- Disable all Mid’hat default bindings. Add your own in hypr/bindings.lua.
-- midhat_default_bindings = false
--
-- Or disable only bindings for Mid’hat's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- midhat_preinstalled_bindings = false

-- Load Mid’hat defaults.
require("default.hypr.midhat")

-- Put your personal overrides in these files. They're loaded after Mid’hat's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })
