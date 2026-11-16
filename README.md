# Mid’hat

Mid’hat is a calm pen-and-touch operating system for the FydeTab Duo and,
later, other tablets and tablet PCs. Nothing else: no desktops, no laptops
without a touch screen.

It runs Arch Linux ARM with Hyprland and a Quickshell desktop. It split off for
good from [Omarchy](https://github.com/basecamp/omarchy) 4.0.5, keeping its
commands, shell and update machinery, and goes its own way from there:

- **One device first.** Only what works on the FydeTab is offered; the menu has
  no x86, Limine, Plymouth or Chromium web-app entries.
- **The E Ink look.** Paper and ink themes (E Ink, E Ink Mono) with Edward
  Lear's 1848 drawings of Albania, a black-and-white screensaver, and the
  qeleshe, the white felt cap of northern Albania, as the mark.
- **One agent.** Claude, built in.
- **Its own updates.** Packages come from the `[midhat]` repo, published from
  this repository; nothing changes unless it is built here.

Next: tablet input (tablet mode when the keyboard cover comes off, the
on-screen keyboard by itself, auto-rotate, touch gestures), then the Notebook
app (handwriting, text and live maths on one page).

## Layout

| Path | What |
| --- | --- |
| `bin/` | the `midhat-*` commands |
| `shell/` | the Quickshell desktop: bar, menu, panels, lock, notifications |
| `config/`, `default/`, `etc/` | user defaults, system defaults, /etc drop-ins |
| `themes/` | E Ink and E Ink Mono |
| `migrations/` | one-time steps `midhat update` runs on existing installs |
| `pkgbuilds/` | `midhat`, `midhat-settings`, `midhat-nvim`, `libinput` built against Lua 5.5, and `koreader` |
| `tools/rename/` | the script that turned Omarchy 4.0.5 into this tree |
| `tools/brand/` | draws the qeleshe into the logo files, greeter and icon font |
| `tools/repo/` | build the packages, publish the `[midhat]` repo |
| `tools/migrate/` | switch a running Omarchy FydeTab to Mid’hat, and back |

The tree is Omarchy 4.0.5 renamed by `tools/rename`, plus Mid’hat's own changes
on top of it.

## Build

```bash
tools/repo/build.sh            # all three packages into out/
tools/repo/build.sh midhat     # just one
```

`midhat` and `midhat-settings` are built from the committed `HEAD`, so commit
first. `midhat-nvim` repacks omarchy-nvim 2026.8.13 under Mid’hat's names.

`libinput` is Arch's 1.32.0 linked against Lua 5.5, the Lua Hyprland uses, so
libinput Lua plugins such as the pen hold don't crash Hyprland. It needs `meson`
and isn't in the default set: `tools/repo/build.sh libinput`.

`koreader` repacks KOReader's official arm64 build with a matching window app
id and a desktop file that claims only ebook formats: `tools/repo/build.sh koreader`.

## Switch an Omarchy FydeTab to Mid’hat

```bash
tools/repo/build.sh
sudo bash tools/migrate/switch.sh
```

It snapshots `/` (snapper) and `/home` (btrfs) first, swaps the packages in one
pacman transaction, removes `omarchy-keyring` and `plymouth`, renames the
leftovers in `/etc` and `/var/lib`, and moves your home to the new names:
`~/.config/omarchy` becomes `~/.config/midhat`, and everything pointing at it
follows. Reboot afterwards. To undo it:

```bash
sudo bash tools/migrate/rollback.sh <time>   # the time switch.sh printed
```

## Publish the `[midhat]` repo

```bash
gh repo create FrazzledTurtle/midhat --public --source . --push
tools/repo/publish.sh
```

The repo is a GitHub release tagged `repo` holding the packages and
`midhat.db`. `midhat-refresh-pacman` adds it to `/etc/pacman.conf`
(`default/pacman/midhat-repo.conf`), in front of the Arch Linux ARM repos.

## Tests

```bash
./test/shell
```

Some tests need `node`. Against Omarchy 4.0.5 on the same tablet, the rename
adds one known failure: `hyprland-default-config-test.sh` writes old Omarchy
bindings inline and the migration recognises those by checksum, which the
rename changes. That migration is for Omarchy 3 installs and long done here.

## Name

The display name is Mid’hat, written with the typographic apostrophe in the
desktop's own text: it never breaks quoting in a script. Identifiers and
paths use `midhat`.

## Licence

MIT. Mid’hat keeps Omarchy's copyright notice (David Heinemeier Hansson) next
to its own; see [LICENSE](LICENSE). The inherited manual in `manual/` still
describes Omarchy's features and will be rewritten.
