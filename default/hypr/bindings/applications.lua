-- Essential application bindings.
o.bind("SUPER + RETURN", "Terminal", { midhat = "terminal" })
o.bind("SUPER + SHIFT + RETURN", "Browser", { midhat = "browser" })
o.bind("SUPER + SHIFT + F", "File manager", { midhat = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { midhat = "nautilus-cwd" })
o.bind("SUPER + SHIFT + B", "Browser", { midhat = "browser" })
o.bind("SUPER + SHIFT + ALT + B", "Browser (private)", { midhat = "browser --private" })
o.bind("SUPER + SHIFT + N", "Editor", { midhat = "editor" })

if o.preinstalled_bindings_enabled() then
  -- Bindings for preinstalled Mid’hat applications, TUIs, and web apps.
  o.bind("SUPER + ALT + RETURN", "Tmux", { midhat = "terminal-tmux" })
  o.bind("SUPER + CTRL + RETURN", "Herdr", { midhat = "terminal-herdr" })
  o.bind("SUPER + SHIFT + M", "Music", { midhat = "spotify" })
  o.bind("SUPER + SHIFT + ALT + M", "Music TUI", { tui = "cliamp", focus = true })
  o.bind("SUPER + SHIFT + D", "Docker", { tui = "midhat-launch-docker-tui" })
  o.bind("SUPER + SHIFT + G", "Signal", { midhat = "signal" })
  o.bind("SUPER + SHIFT + O", "Obsidian", { launch = "obsidian", focus = "^obsidian$" })
  o.bind("SUPER + SHIFT + SLASH", "Passwords", { midhat = "1password" })

  o.bind("SUPER + SHIFT + A", "ChatGPT", { webapp = "https://chatgpt.com" })
  o.bind("SUPER + SHIFT + ALT + A", "Grok", { webapp = "https://grok.com" })
  o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://app.hey.com/calendar/weeks/" })
  o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://app.hey.com" })
  o.bind("SUPER + SHIFT + ALT + E", "New email", { webapp = "https://app.hey.com/messages/new?display=standalone&new_window=true" })
  o.bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/" })
  o.bind("SUPER + SHIFT + ALT + G", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
  o.bind( "SUPER + SHIFT + CTRL + G", "Google Messages", { webapp = "https://messages.google.com/web/conversations", focus = true })
  o.bind("SUPER + SHIFT + P", "Google Photos", { webapp = "https://photos.google.com/", focus = true })
  o.bind("SUPER + SHIFT + S", "Google Maps", { webapp = "https://maps.google.com/", focus = true })
  o.bind("SUPER + SHIFT + X", "X", { webapp = "https://x.com/" })
  o.bind("SUPER + SHIFT + ALT + X", "X Post", { webapp = "https://x.com/compose/post" })
end
