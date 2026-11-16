# Mid’hat update process

This document describes the intended update behavior now that Mid’hat is
package-backed. It covers the blessed update path plus what happens when a user attempts to
bypass it:

1. `midhat update` — the blessed interactive Mid’hat update flow.
2. `sudo pacman -Syu` — guarded by Mid’hat and aborted with instructions unless
   the user explicitly bypasses the guard.

The design goal is:

- `midhat update` owns the visible update pipeline: package transaction,
  migrations, post-update hooks, update-state refresh, and restart checks.
- Migrations run per-user after pacman finishes, because they may need `$HOME`,
  DBus/session state, a graphical session, sudo, or user interaction.
- Users who bypass `midhat update` are nudged back by the pacman guard; if they
  explicitly bypass it, their session is notified when migrations are pending.

## State and coordination files

| Path | Owner | Purpose |
| --- | --- | --- |
| `${XDG_RUNTIME_DIR:-/tmp}/midhat-update.lock` | user | Prevent overlapping update runs. Owned by `midhat-update-lock`; compatibility wrappers inherit/respect it. |
| `/tmp/midhat-update.log` | user | Transcript of `midhat update`, used by `midhat-update-analyze-logs`. |
| `~/.local/state/midhat/current/` | user | Generated active theme, selected theme name, and current background symlink. |
| `~/.local/state/midhat/migrations/` | user | Per-user migration markers. |
| `~/.local/state/midhat/reboot-required` | user | Optional reboot marker checked by `midhat-update-restart`. |
| `~/.local/state/midhat/restart-*-required` | user | Optional service/app restart markers checked by `midhat-update-restart`. The shell needs no marker: it is restarted unconditionally after every update. |

## Migration layout

See [`migrations.md`](migrations.md) for the full migration model, authoring
guidelines, and troubleshooting notes.

Migrations live in:

```text
migrations/*.sh
```

They run as the current user through:

```bash
midhat-migrate
```

Completion state is per-user:

```text
~/.local/state/midhat/migrations/<migration filename>
```

Every user gets a chance to run every migration. Migrations run as the user;
privileged work should invoke the appropriate helper or privilege prompt.
Migrations must be idempotent; if one user already applied a machine-wide repair,
the migration should no-op for other users.

For watchers and diagnostics, `midhat-migrate --pending` prints pending
migration names and exits `0` when any are pending. When no migrations are
pending, it prints nothing and exits non-zero.

## Raw pacman guard

The `midhat` package installs an ALPM pre-transaction hook alongside its guard
binary:

```text
/usr/share/libalpm/hooks/00-midhat-update-guard.hook
/usr/bin/midhat-update-pacman-guard
```

It triggers on package upgrades and runs:

```bash
midhat-update-pacman-guard
```

The guard detects direct pacman system-upgrade commands like `pacman -Syu` or
`pacman --sync --refresh --sysupgrade`. If the upgrade was not launched by an
Mid’hat update command, the hook exits non-zero with `AbortOnFail`, which stops
the transaction before packages are changed.

`midhat-update-system-pkgs`, `midhat-refresh-pacman`, `midhat-reinstall-pkgs`,
and the v4 upgrader run pacman through:

```bash
env MIDHAT_UPDATE_PACMAN=1 pacman ...
```

so the guard allows Midhat-owned update flows. A user can intentionally bypass
the guard with:

```bash
sudo env MIDHAT_ALLOW_DIRECT_PACMAN=1 pacman -Syu
```

The guard does not start `midhat update` itself because pacman is already in a
transaction setup path; it only aborts with instructions.

The `midhat` package also installs ALPM hooks for `midhat-settings` /
`midhat-settings-dev` installs and upgrades. The pre-transaction hook runs
`midhat-hyprland-reload-guard pause` to disable live Hyprland config reloads
while `/usr/share/midhat/default/hypr/**` is replaced. The post-transaction
hook runs `midhat-hyprland-reload-guard resume`, forces one `hyprctl reload`,
and restores the session's previous `misc.disable_autoreload` and
`debug.suppress_errors` values.

## Path 1: `midhat update`

High-level flow:

```text
midhat-update
  ├─ ensure transcript logging through script(1) → /tmp/midhat-update.log
  ├─ midhat-update-lock
  │    └─ acquire the update lock and run midhat-update inside it
  ├─ midhat-update-requires-free-space
  │    └─ check free space on / and warn below the configured threshold
  ├─ confirm unless -y
  ├─ create snapper snapshot, if snapper is installed
  ├─ midhat-update-stay-awake start
  ├─ run package updates, migrations, hooks, and log analysis
  ├─ midhat-update-status
  │    └─ refresh or clear the shell update indicator
  ├─ midhat-update-stay-awake stop
  │    └─ release the sleep inhibitor and restore shell idle state, if changed
  └─ midhat-update-restart
```

Important behavior:

- In dev-link mode, `midhat update` fast-forwards the active checkout from its
  configured upstream before changing system packages or running migrations.
- The free-space requirement uses a 10 GiB threshold and stops the update before
  confirmation when it is not met. If free space cannot be determined, the
  check is silently skipped. Set `MIDHAT_UPDATE_FORCE=1` to bypass the check.
- `midhat update` checks/runs migrations in the same visible terminal via
  `midhat-migrate` after pacman finishes.
- A failure should leave enough output in `/tmp/midhat-update.log` and the
  terminal transcript to debug.

## Path 2: direct `sudo pacman -Syu` attempt

High-level flow:

```text
sudo pacman -Syu
  ├─ pre-transaction guard aborts and tells the user to run midhat update
  └─ if explicitly bypassed, upgrades midhat and related packages
  └─ at that user's next login
       ├─ graphical-session.target starts
       ├─ midhat-migrate-notify.service starts after it
       ├─ midhat-migrate-notify checks midhat-migrate --pending
       ├─ if this user has missing migration state, show notification
       └─ click opens terminal: midhat-migrate
```

Login is deliberately the only trigger. A watcher on the packaged migration
directory cannot distinguish a bypassed `pacman -Syu` from the package
transaction inside a normal `midhat update`, so it fired notifications for
migrations that `midhat-migrate` was about to apply in the visible update
terminal. The retired unit was `midhat-update-user-notify.path`.

Retiring that watcher through a migration cannot come in time for the update
that retires it: pacman writes the migration directory, the watcher fires, and
only then does `midhat-migrate` reach the migration that stops it. So the
notifier also refuses to run while `midhat update` holds its
`$XDG_RUNTIME_DIR/midhat-update.lock`, which covers the stale watcher and any
trigger added later — during an update, every pending migration is by
definition already being applied a step away. It checks again after waiting for
the notification server, since that wait is long enough for an update to start
underneath it.

The notifier reads only its own user's runtime directory, never the `/tmp` path
`midhat-update` falls back to when `XDG_RUNTIME_DIR` is unset. A shared lock
file belongs to whoever created it first, so honouring it would let one user
silence another user's notification. Missing an update and showing a redundant
toast is the better failure.

Suppression is why `midhat-update-stay-awake` starts its sleep inhibitor with
the lock descriptor closed. That inhibitor outlives the step that starts it, so
an update killed before cleanup would otherwise leave it holding the flock
indefinitely — blocking later updates and, now that the notifier reads the same
lock, silencing migration notifications at every login.

Fallbacks:

- `midhat-provision-first-run` enables `midhat-migrate-notify.service`, which also
  covers users created after install: their per-user migration markers are
  missing, so their first login prompts them to run every shipped migration.
- The package ships `midhat-update-user-notify.service` as a symlink onto
  `midhat-migrate-notify.service`. Users set up before the rename hold an
  absolute `graphical-session.target.wants` symlink to the old path, and the
  migration that repoints it only runs for users who run an update — the
  opposite of who the notifier is for. The alias can be dropped once installs
  have run migration `1785095882`.
- The notifier is ordered after `graphical-session.target`, so an action that
  launches through `uwsm-app` cannot block the target that gates UWSM's app
  daemon.
- The notifier waits for a live notification server before sending, because
  `graphical-session.target` can be reached before the shell claims
  `org.freedesktop.Notifications`.
- The notifier is only a prompt. It does not run migrations in the background.
- A session that is already open when another user updates is not re-checked;
  it picks the migrations up at its next login, or whenever that user runs
  `midhat-migrate` or `midhat update`.
- Direct pacman updates do not run `midhat-hook post-update` unless the user
  explicitly runs that hook; without a package-update marker, the only pending
  state we can derive is missing per-user migration markers.

## Shell update indicator

The bar widget `midhat.system-update` runs:

```bash
midhat-update-available
```

`midhat-update-available` checks the active Mid’hat sources for updates:

- new upstream commits for the active dev-linked checkout
- `midhat-dev`, when installed
- otherwise `midhat`, when installed

The dev check fetches the checkout's configured upstream before comparing it
with `HEAD`. A failed fetch is quiet and falls back to the existing remote-
tracking state.

Exit codes:

- `0` — Mid’hat updates are available; stdout is the update list.
- non-zero — no Mid’hat updates are available; stdout says Mid’hat is up to date.

The widget runs this check on shell startup and every six hours. Clicking the
update icon launches `midhat-update` in a floating terminal.

## Update-related binaries

This inventory is intentionally opinionated. Some commands are useful as stable
leaf commands; others exist mostly because the old update flow accreted small
scripts.

| Binary | Current purpose | Keep? / Question |
| --- | --- | --- |
| `midhat-update` | Public user command. Adds transcript logging, confirmation, snapshot, and restart checks around the locked, sleep-inhibited update pipeline. | **Keep.** This is the blessed entry point and orchestrates the update pipeline. |
| `midhat-update-lock` | Hidden command wrapper that holds the per-user update lock while its child runs. | **Keep internal/hidden.** Isolates update concurrency and lock descriptor handling. |
| `midhat-update-stay-awake` | Hidden helper that starts or stops update-owned sleep and idle inhibition, restoring only the state it changed. | **Keep internal/hidden.** Keeps inhibitor ownership and cleanup together. |
| `midhat-update-status` | Hidden helper that refreshes or clears the shell update indicator after rechecking available updates. | **Keep internal/hidden.** Keeps shell status synchronization out of the main pipeline. |
| `midhat-update-confirm` | Gum confirmation copy for `midhat update`. | **Question.** Could be inlined into `midhat-update`; separate file only helps keep copy isolated. |
| `midhat-update-dev` | Fast-forwards the active dev-linked checkout from its configured upstream; no-ops for package-backed installs. | **Keep.** Runs before package updates so a checkout conflict stops the update before system mutation. |
| `midhat-update-keyring` | Ensures Mid’hat keyring and Arch keyring are current before the main transaction. | **Keep, but review.** It uses targeted `pacman -Sy` for keyring bootstrapping; acceptable for this special case but should remain tightly scoped. |
| `midhat-update-system-pkgs` | Runs `sudo env MIDHAT_UPDATE_PACMAN=1 pacman -Syu --noconfirm` with targeted transition `--overwrite` entries so the ALPM guard allows the transaction and early package-layout conflicts are handled. | **Keep for now.** Small leaf command, clear/testable. |
| `midhat-migrate` | Public migration command. Waits for pacman, then runs all pending migrations for the current user. Supports `--pending`. | **Keep.** This replaces the discarded `midhat-update-user-finalize` name and no longer needs `--force`. |
| `midhat-update-pacman-guard` | ALPM pre-transaction guard that aborts direct `pacman -Syu` style upgrades unless Mid’hat set `MIDHAT_UPDATE_PACMAN=1` or the user explicitly set `MIDHAT_ALLOW_DIRECT_PACMAN=1`. | **Keep internal/hidden.** This is what nudges users back to `midhat update`. |
| `midhat-migrate-notify` | Internal login-time notification helper. Uses `midhat-migrate --pending` and shows a notification only when this user has pending migrations. | **Keep internal/hidden.** Clear name now that the public command is `midhat-migrate`. |
| `midhat-update-user-notify` | Hidden compatibility wrapper for `midhat-migrate-notify`. | **Temporary.** Keep only for old callers. |
| `midhat-update-available` | Update checker for shell widget and post-update refresh. | **Keep.** Could eventually be renamed `midhat-update-check`, but current name matches widget semantics. |
| `midhat-update-aur-pkgs` | Updates AUR packages with `yay -Sua` if foreign packages exist and AUR is reachable. | **Question.** Mid’hat is package-backed now, but users may still install AUR packages. Keep for now. |
| `midhat-update-mise` | Runs `mise up` for mise-managed tools. | **Keep.** Mise-managed tools are intentionally part of the blessed update path. |
| `midhat-update-orphan-pkgs` | Lists orphans and prompts before removal; noninteractive mode never removes. | **Keep for now.** Safe because it is prompt-only. |
| `midhat-update-analyze-logs` | Scans `/tmp/midhat-update.log` for known failure patterns, currently initramfs generation. | **Keep/expand.** Useful safety net; should grow only for high-signal checks. |
| `midhat-update-restart` | Prompts for reboot after kernel/Hyprland updates, restarts components with `restart-*-required` markers, and always restarts the shell. | **Keep.** Important final step; may eventually include service-restart checks. |
| `midhat-update-firmware` | Manual firmware update command using fwupd. Not part of the normal update pipeline. | **Keep separate.** Firmware is not a routine system update step. |
| `midhat-update-time` | Restarts `systemd-timesyncd`. | **Question.** Not really an update command. Consider renaming/moving under system/time maintenance. |

## Closed decisions

1. **Migrations run per-user from the update pipeline**
   - `midhat update` runs `midhat-migrate` after pacman finishes.
   - Package-time migration runners do not apply migrations inside pacman.
   - Every user has per-user migration markers, and migrations must be
     idempotent when they repair machine-wide state.

2. **Migration notification naming**
   - The real helper is `midhat-migrate-notify`, started by
     `midhat-migrate-notify.service`.
   - `midhat-update-user-notify` remains only as a hidden compatibility wrapper.

3. **Update pipeline ownership**
   - `midhat-update` owns the full update pipeline now.

4. **Mise remains in the blessed update path**
   - `midhat-update-mise` intentionally runs as part of `midhat update`.

5. **Orphan cleanup stays in the update path for now**
   - It is prompt-only and never removes packages noninteractively.

6. **Direct pacman user follow-up is based on actual migration state**
   - Direct `sudo pacman -Syu` no longer uses a fake user-update marker.
   - User notifications are shown only when `midhat-migrate --pending` finds
     missing per-user migration state.

## Remaining concerns

1. **Pacman guard scope**
   - The guard detects direct pacman sysupgrade invocations and allows Mid’hat
     commands that set `MIDHAT_UPDATE_PACMAN=1`.
   - We may regret blocking some legitimate package-manager frontends or
     maintenance flows. Keep an eye on what should be allowed versus redirected
     to `midhat update`.

2. **Pacnew/pacsave handling is still missing**
   - Package-backed Mid’hat should warn about or help process `.pacnew` and
     `.pacsave` files after updates.
