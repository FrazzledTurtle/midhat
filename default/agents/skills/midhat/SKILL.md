---
name: midhat
description: >
  REQUIRED for end-user customization of Linux desktop, window manager, or system config.
  Use when editing ~/.config/hypr/, ~/.config/midhat/,
  ~/.config/alacritty/, ~/.config/foot/, ~/.config/kitty/, or ~/.config/ghostty/.
  Triggers: Hyprland, window rules, animations, keybindings, monitors, gaps, borders,
  blur, opacity, midhat-shell, bar, terminal config, themes, background,
  night light, idle, lock screen, screenshots, reminders, layer rules, workspace
  settings, display config, and user-facing midhat commands. Excludes Mid’hat
  source development through `midhat dev link` workflows.
---

# Mid’hat Skill

Manage [Mid’hat](https://omarchy.org/) Linux systems - a beautiful, modern, opinionated Arch Linux distribution with Hyprland.

This skill is for end-user customization on installed systems.
It is not for contributing to Mid’hat source code.

## When This Skill MUST Be Used

**ALWAYS invoke this skill for end-user requests involving ANY of these:**

- Editing ANY file in `~/.config/hypr/` (window rules, animations, keybindings, monitors, etc.)
- Editing `~/.config/midhat/shell.json` (status bar layout, widgets)
- Editing terminal configs (alacritty, foot, kitty, ghostty)
- Editing ANY file in `~/.config/midhat/`
- Window behavior, animations, opacity, blur, gaps, borders
- Layer rules, workspace settings, display/monitor configuration
- Themes, backgrounds, fonts, appearance changes
- User-facing `midhat` commands (`midhat theme ...`, `midhat refresh ...`, `midhat restart ...`, etc.)
- Screenshots, screen recording, reminders, night light, idle behavior, lock screen

**If you're about to edit a config file in ~/.config/ on this system, STOP and use this skill first.**

**Do NOT use this skill for Mid’hat development tasks** (editing the Mid’hat source tree, creating migrations, or running `midhat dev ...` workflows).

## Topic Guides

Deeper instructions for common areas live next to this file. Read the
matching guide before starting:

- [`hyprland.md`](hyprland.md) - keybindings, monitors, window rules, and other Hyprland config
- [`plugins.md`](plugins.md) - the Mid’hat shell: bar layout, widgets, plugins, idle behavior
- [`theming.md`](theming.md) - themes, backgrounds, and fonts
- [`hooks.md`](hooks.md) - automation hooks that run on system events
- [`capture.md`](capture.md) - screenshots, screen recordings, OCR text capture, and file sharing
- [`contributing.md`](contributing.md) - reporting Mid’hat bugs and submitting fixes upstream

## Critical Safety Rules

For privileged commands, follow the Privilege Escalation rules below: `sudo` when a terminal is available for the password prompt, `pkexec` when it is not. Do not wrap commands that already manage privilege elevation themselves.

**For end-user customization tasks, NEVER modify anything in `/usr/share/midhat/`** - but READING is safe and encouraged.

This directory is owned by the midhat package. Any local changes will be
overwritten on the next `midhat update`.

```
/usr/share/midhat/     # READ-ONLY - NEVER EDIT (reading is OK)
├── bin/                    # Command source (packaged binaries are on PATH)
├── config/                 # Default config templates
├── themes/                 # Stock themes
├── default/                # System defaults
├── shell/                  # Midhat shell source and defaults
├── migrations/             # Update migrations
└── install/                # Installation scripts
```

**Reading `/usr/share/midhat/` is SAFE and useful** - do it freely to:
- Understand how midhat commands work: `midhat theme set --help` or `cat $(which midhat-theme-set)`
- See default configs before customizing: `cat "$MIDHAT_PATH/config/midhat/shell.json"`
- Check stock theme files to copy for customization
- Reference default hyprland settings: `cat /usr/share/midhat/default/hypr/*`

**Always use these safe locations instead:**
- `~/.config/` - User configuration (safe to edit)
- `~/.config/midhat/themes/<custom-name>/` - Custom themes
- `~/.config/midhat/hooks/` - Custom automation hooks

If the request is to develop Mid’hat itself, this skill is out of scope. Follow repository development instructions instead of this skill.

## Privilege Escalation

For an interactive script or command run in a visible terminal, use `sudo` for
privileged work. Mid’hat may grant passwordless `sudo` access to particular
commands, and the terminal is the appropriate place to request a password
when one is needed.

Use `pkexec` only when the caller cannot interact with a terminal or cannot
enter a password there, such as a command launched by an agent or a graphical
background process. Do not replace `sudo` with `pkexec` merely because a
command changes system state.

## System Architecture

Mid’hat is built on:

| Component | Purpose | Config Location |
|-----------|---------|-----------------|
| **Arch Linux** | Base OS | `/etc/`, `~/.config/` |
| **Hyprland** | Wayland compositor/WM | `~/.config/hypr/` |
| **Mid’hat shell** | Status bar + notifications (Quickshell) | `~/.config/midhat/shell.json` |
| **Launcher/menus** | Quickshell menu | `~/.config/midhat/extensions/midhat-menu.jsonc` |
| **Alacritty/Foot/Kitty/Ghostty** | Terminals | `~/.config/<terminal>/` |
| **Mid’hat OSD** | On-screen display | Quickshell plugin |

## Command Discovery

Mid’hat ships a single `midhat` CLI that dispatches to all `midhat-*` binaries via `midhat <group> <action>`. Always prefer this form — it is self-documenting and stable. The underlying `midhat-*` binaries still exist on `PATH` and remain safe to read for source.

```bash
# List every documented command and its summary (--all includes hidden commands)
midhat commands

# Show the commands inside a group
midhat theme --help
midhat refresh --help
midhat restart --help

# Show help for a specific command (does not execute it)
midhat theme set --help

# Machine-readable listing (binary, route, summary, args, aliases)
midhat commands --json

# Read a command's source to understand it
cat $(which midhat-theme-set)
```

### Command Groups

Run `midhat --help` for the full list. The most common groups:

| Group | Purpose | Example |
|-------|---------|---------|
| `midhat refresh` | Reset config to defaults (backs up first) | `midhat refresh shell` |
| `midhat restart` | Restart a service/app | `midhat restart shell` |
| `midhat toggle` | Toggle feature on/off | `midhat toggle nightlight` |
| `midhat theme` | Theme management | `midhat theme set <name>` |
| `midhat bar` | Bar layout and widgets | `midhat bar move midhat.clock --section right` |
| `midhat plugin` | Manage/clone shell plugins | `midhat plugin clone midhat.clock` |
| `midhat hook` | Install automation hooks | `midhat hook install theme-set <script>` |
| `midhat install` | Install optional software / packages | `midhat install docker dbs` |
| `midhat launch` | Launch apps | `midhat launch browser` |
| `midhat capture` | Screenshots and recordings | `midhat capture screenshot` |
| `midhat reminder` | Desktop notification reminders | `midhat reminder 15 "Pickup Jack"` |
| `midhat pkg` | Package management | `midhat pkg add <pkg>` |
| `midhat setup` | Interactive setup wizards | `midhat setup security fingerprint` |
| `midhat update` | System updates | `midhat update` |

## Configuration Locations

Hyprland config lives in `~/.config/hypr/` — see [`hyprland.md`](hyprland.md).
The Mid’hat shell (bar, notifications, plugins, idle) is configured in
`~/.config/midhat/shell.json` — see [`plugins.md`](plugins.md).

### Terminals

```
~/.config/alacritty/alacritty.toml
~/.config/foot/foot.ini
~/.config/kitty/kitty.conf
~/.config/ghostty/config
```

**Command:** `midhat restart terminal`

### Other Configs

| App | Location |
|-----|----------|
| btop | `~/.config/btop/btop.conf` |
| fastfetch | `/etc/fastfetch/config.jsonc` default; `~/.config/fastfetch/config.jsonc` user override |
| lazygit | `~/.config/lazygit/config.yml` |
| starship | `~/.config/starship.toml` |
| git | `~/.config/git/config` |

## Safe Customization Patterns

### Edit User Config Directly

For simple changes, edit files in `~/.config/`:

```bash
# 1. Read current config
cat ~/.config/hypr/bindings.lua

# 2. Backup before changes
cp ~/.config/hypr/bindings.lua ~/.config/hypr/bindings.lua.bak.$(date +%s)

# 3. Make changes with Edit tool

# 4. Apply changes
# - Hyprland: auto-reloads on save, but MUST validate with `hyprctl reload` and `hyprctl configerrors`
# - Midhat shell: shell.json and user plugin code under ~/.config/midhat/plugins/ hot-reload on save
# - Menus/launcher: ~/.config/midhat/extensions/midhat-menu.jsonc hot-reloads on save
# - Terminals: apply with `midhat restart terminal` (reloads running terminals; foot picks changes up in new windows)
```

### Reset to Defaults -- ALWAYS SEEK USER CONFIRMATION BEFORE RUNNING

When customizations go wrong:

```bash
# Reset specific config (creates backup automatically)
midhat refresh shell
midhat refresh hyprland

# The refresh command:
# 1. Backs up current config with timestamp
# 2. Copies default from $MIDHAT_PATH/config/
# 3. Restarts the component where the refresh needs it (e.g. `refresh shell`)
```

## System Commands

```bash
midhat update                  # Full system update
midhat version                 # Show Midhat version
midhat debug --no-sudo --print # Debug info (ALWAYS use these flags)
midhat system lock             # Lock screen
midhat system shutdown         # Shutdown
midhat system reboot           # Reboot
```

**IMPORTANT:** Always run `midhat debug` with `--no-sudo --print` flags to avoid interactive sudo prompts that will hang the terminal.

## Troubleshooting

```bash
# Get debug information (ALWAYS use these flags to avoid interactive prompts)
midhat debug --no-sudo --print

# Reset specific config to defaults
midhat refresh <app>

# Refresh specific config file
# config-file path is relative to ~/.config/
# eg. `midhat refresh config hypr/hyprland.lua` will refresh ~/.config/hypr/hyprland.lua
midhat refresh config <config-file>

# Full reinstall of configs (nuclear option)
midhat reinstall
```

## Decision Framework

When user requests system changes:

1. **Is it a stock midhat command?** Use it directly
2. **Is it a config edit?** Edit in `~/.config/`, never `/usr/share/midhat/`
3. **Is it a theme customization?** Follow [`theming.md`](theming.md); create a NEW custom theme directory
4. **Is it automation?** Follow [`hooks.md`](hooks.md); use `midhat hook install` and the hook `.d` directories
5. **Is it a package install?** Use `midhat pkg add <pkgs...>` (or `midhat pkg aur add <pkgs...>` for AUR-only packages)
6. **Is it built-in shell/plugin code?** Follow [`plugins.md`](plugins.md); clone it with `midhat plugin clone`, never edit the packaged copy
7. **Unsure if command exists?** Run `midhat commands` (or `midhat <group> --help` for one group)

### Reminder Requests

When the user asks to set a reminder, use `midhat reminder <minutes> [message]` directly. Convert natural language durations to minutes and title-case short reminder labels when appropriate.

```bash
midhat reminder 15 "Pickup Jack"
midhat reminder 60 "Check laundry"
midhat reminder show
midhat reminder clear
```

## Out of Scope

This skill intentionally does not cover Mid’hat source development. Do not use this skill for:
- Editing files in `/usr/share/midhat/` (`bin/`, `config/`, `default/`, `shell/`, `themes/`, `migrations/`, etc.)
- Creating or editing migrations
- Running `midhat dev ...` commands

## Example Requests

- "Change my theme to catppuccin" -> `midhat theme set catppuccin`
- "Add a keybinding for Super+E to open file manager" -> Check existing bindings first, call `hl.unbind` if needed, then `o.bind` in `~/.config/hypr/bindings.lua`
- "Configure my external monitor" -> Edit `~/.config/hypr/monitors.lua`
- "Make the window gaps smaller" -> Edit `~/.config/hypr/looknfeel.lua`
- "Turn on night light" -> `midhat toggle nightlight` (for time-based schedules, edit `~/.config/hypr/hyprsunset.conf` profiles, then `midhat restart hyprsunset`)
- "Set a reminder to pickup jack in 15 minutes" -> `midhat reminder 15 "Pickup Jack"`
- "Show my reminders" -> `midhat reminder show`
- "Clear all reminders" -> `midhat reminder clear`
- "Customize the catppuccin theme colors" -> Overlay: put an edited `colors.toml` in `~/.config/midhat/themes/catppuccin/`, then re-apply the theme (see `theming.md`)
- "Run a script every time I change themes" -> Install it with `midhat hook install theme-set <script>`
- "Change how workspace labels are rendered" -> Clone `midhat.workspaces`, which switches the bar to `<username>.workspaces`, then edit the clone
- "Lock after ten minutes" -> Set `idle.lock` to `600` in `~/.config/midhat/shell.json`
- "Reset shell/bar to defaults" -> `midhat refresh shell`
- "Record my screen" -> `midhat screenrecord --fullscreen`, then `midhat screenrecord --stop-recording` (see `capture.md`)
- "Report this bug to Mid’hat" -> Gather diagnostics and a capture of the problem, then file it (see `contributing.md`)
