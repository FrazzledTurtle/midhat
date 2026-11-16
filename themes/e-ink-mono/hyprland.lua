local active = "rgba(111111ff)"
local inactive = "rgba(9a9a9aff)"

hl.config({
  general = { col = { active_border = active, inactive_border = inactive } },
  group = { col = { border_active = active, border_inactive = inactive } },
  decoration = {
    shadow = { enabled = false },
    blur = { enabled = false },
  },
})

o.window({ tag = "default-opacity" }, { opacity = "1 1" })

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_THEME", "Adwaita")
