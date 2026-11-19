# Releasing Mid’hat

Everything is built on the tablet from a clean checkout of this repository and
published as the GitHub release tagged `repo`, which is the `[midhat]` pacman
repo.

## Packages

| Package | Source | Build needs |
| --- | --- | --- |
| `midhat` | this repository at `HEAD` | — |
| `midhat-settings` | this repository at `HEAD` | — |
| `midhat-nvim` | omarchy-nvim 2026.8.13-1, renamed | — |
| `midhat-annotate` | Tensaku 0.28.0 (MPL-2.0), renamed in `prepare()` | `rust` |
| `oskar` | OSKar 0.2.5 (MIT) plus `midhat.patch` | `rust` |
| `libinput` | Arch's 1.32.0 built against Lua 5.5 | `meson` |
| `koreader` | KOReader 2026.07.1's official arm64 `.deb` | — |

Every download is pinned by sha256 in its PKGBUILD.

## A release

1. Set the new version in `version`, `pkgbuilds/midhat/PKGBUILD` and
   `pkgbuilds/midhat-settings/PKGBUILD` (`pkgver`, `pkgrel=1`), and commit.
   `midhat` and `midhat-settings` build from the committed `HEAD`.
2. Run the tests: `./test/cli` and `./test/shell`. The shell tests that need
   `node` fail without it.
3. Build: `tools/repo/build.sh` builds every package into `out/`;
   `tools/repo/build.sh midhat` builds one.
4. Publish: `tools/repo/publish.sh` uploads the newest build of each package
   with a fresh `midhat.db`, and deletes older assets from the release.
5. On the tablet: `midhat update`. It installs the packages, then runs the new
   migrations in `migrations/`.

Bump `pkgrel` on a package whose upstream version stays the same, so pacman
sees the change.
