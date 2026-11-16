hl.on("hyprland.start", function()
  -- Slow app launch fix -- set systemd vars before starting session services.
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  hl.exec_cmd("midhat-launch-shell")
  hl.exec_cmd("midhat-provision-first-run")
  hl.exec_cmd("midhat-powerprofiles-init; midhat-toggle-reading-mode sync")
  hl.exec_cmd("midhat-tablet-mode sync")
  hl.exec_cmd("sleep 3 && midhat-toggle-mic-camera on")
  hl.exec_cmd(o.launch("midhat-hyprland-monitor-watch"))
  hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))

  -- Run post-boot hooks after startup config has loaded.
  hl.exec_cmd("sleep 2 && midhat-hook post-boot")
end)

-- A reload puts monitors.lua's landscape transform back; turn the screen the
-- way the tablet was turned again.
hl.on("config.reloaded", function()
  hl.exec_cmd("midhat-hyprland-monitor-rotate reapply")
end)
