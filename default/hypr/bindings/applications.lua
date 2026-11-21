-- Essential application bindings.
o.bind("SUPER + RETURN", "Terminal", { midhat = "terminal" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { midhat = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { midhat = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { midhat = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { midhat = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { midhat = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { midhat = "editor" })

if o.preinstalled_bindings_enabled() then
  -- Bindings for preinstalled Mid’hat applications.
  o.bind("SUPER + ALT + RETURN", "Tmux", { midhat = "terminal-tmux" })
end
