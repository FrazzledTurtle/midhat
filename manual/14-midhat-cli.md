# Mid’hat CLI

Mid’hat is usually controlled through the hotkeys and the Mid’hat menu (`Super + Space`). But you can also control it through the `midhat` CLI. This is particularly helpful when you're having an AI agent work with you on customization or configuration.

The CLI has access to all the internal tooling that is used both via the menu and otherwise. You can see everything that's available by running `midhat` in the terminal.

It looks something like this:

```
~ ❯ midhat
Midhat command center

Usage:
  midhat <command> [args...]
  midhat commands [--all] [--json] [--check]
  midhat <group> --help
  midhat <group> <command> --help

Common commands:
  midhat update              Update Midhat and system packages
  midhat theme list          List available themes
  midhat theme set <name>    Apply a theme
  midhat font list           List available fonts
  midhat screenshot          Take a screenshot
  midhat debug               Print debugging information

Groups:
  agent          AI coding agent usage data
  audio          Audio input and output controls
  bar            Midhat shell bar layout and settings
  battery        Battery status helpers
  bluetooth      Bluetooth device controls
  branch         Midhat git branch management
  branding       About and screensaver branding
  brightness     Display and keyboard brightness
  capture        Screenshots and screen recording
  channel        Midhat release channel management
  clipboard      Clipboard helpers
  cmd            Command and shortcut helpers
  config         System configuration helpers
  debug          Diagnostics and support logs
  ...
```

And you can dive deeper on every group:

```
~ ❯ midhat capture
Capture commands — Screenshots and screen recording:
  midhat capture qr                                                                                                                                                                                                       Decode a QR code from a screenshot region
  midhat capture screenrecording [--fullscreen] [--with-desktop-audio] [--with-microphone-audio] [--with-webcam] [--webcam-device=<device>] [--webcam-size=<small|medium|large>] [--resolution=<size>] [--stop-recording]  Start or stop screen recording
  midhat capture screenrecording with webcam                                                                                                                                                                              Pick a webcam and start a screen recording with it
  midhat capture screenshot [smart|region|windows|fullscreen] [slurp|copy|save] [--editor=<name>]                                                                                                                         Take a screenshot
  midhat capture text                                                                                                                                                                                                     Extract text from a screenshot region with OCR
  midhat capture webcam resize <smaller|larger|reset|small|medium|large>                                                                                                                                                  Resize the active webcam recording overlay
```

Every command takes `--help` too, whether you ask a whole group (`midhat capture --help`) or a single command (`midhat capture screenshot --help`).

### Opening the menu from the terminal

The Mid’hat menu is scriptable as well, which is handy for your own keybindings. `midhat menu` opens it at the root, and you can jump straight to any point in the tree by naming it: `midhat menu summon style.theme` goes right to the theme picker, `midhat menu toggle system` opens the system menu and closes it again if it's already up, and `midhat menu close` puts it away.
