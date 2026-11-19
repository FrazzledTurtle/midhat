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

Next: Slate, the cover-off posture (a side rail, one window at a time, a Home
page), then the Notebook app (handwriting, text and live maths on one page).

## Layout

| Path | What |
| --- | --- |
| `bin/` | the `midhat-*` commands |
| `shell/` | the Quickshell desktop: bar, menu, panels, lock, notifications |
| `config/`, `default/`, `etc/` | user defaults, system defaults, /etc drop-ins |
| `themes/` | E Ink and E Ink Mono |
| `migrations/` | one-time steps `midhat update` runs on existing installs |
| `pkgbuilds/` | `midhat`, `midhat-settings`, `midhat-nvim`, `midhat-annotate`, `oskar`, `libinput` built against Lua 5.5, and `koreader` |
| `tools/rename/` | the script that turned Omarchy 4.0.5 into this tree |
| `tools/brand/` | draws the qeleshe into the logo files, greeter and icon font |
| `tools/repo/` | build the packages, publish the `[midhat]` repo |
| `tools/migrate/` | switch a running Omarchy FydeTab to Mid’hat, and back |

The tree is Omarchy 4.0.5 renamed by `tools/rename`, plus Mid’hat's own changes
on top of it.

## Build and release

```bash
tools/repo/build.sh            # every package into out/
tools/repo/build.sh midhat     # just one
tools/repo/publish.sh          # upload out/ as the [midhat] repo
```

What each package is built from, and the release steps, are in
[docs/release.md](docs/release.md).

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

## The `[midhat]` repo

The repo is a GitHub release tagged `repo` holding the packages and
`midhat.db`. `midhat-refresh-pacman` adds it to `/etc/pacman.conf`
(`default/pacman/midhat-repo.conf`), in front of the Arch Linux ARM repos.

## Tests

```bash
./test/cli
./test/shell
```

Shell tests that render QML or run JavaScript need `node`.

## Name

The display name is Mid’hat, written with the typographic apostrophe in the
desktop's own text: it never breaks quoting in a script. Identifiers and
paths use `midhat`.

## Licence

MIT. Mid’hat keeps Omarchy's copyright notice (David Heinemeier Hansson) next
to its own; see [LICENSE](LICENSE). The manual in `manual/` is still largely
Omarchy's text.

Third-party parts keep their own licences: Mid’hat Annotate is Tensaku by Jon
Kinney (MPL-2.0, itself a fork of Satty by Matthias Gabriel), OSKar is by
vladkarok (MIT), and the Calendar Clock in `shell/plugins/calendar-clock` is by
Matteo De Venuto (MIT).
