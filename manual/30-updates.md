# Updates

Mid’hat and your packages are kept up to date via _Update > Midhat_ in the Mid’hat menu (`Super + Space`).

Mid’hat itself is installed as regular pacman packages from the [midhat] repository, published as the `repo` release of [the Mid’hat repository](https://github.com/FrazzledTurtle/midhat). An update installs the latest Mid’hat packages, runs any pending migrations to get your system in sync, and updates all system packages from Arch Linux ARM, the FydeTab's [fyde] repository and [AUR](https://aur.archlinux.org/) (if you have installed any AUR packages).

When new releases are made, a circle arrow icon will appear to the right of your clock. Click it and the update process will start.

![update-available](images/update-available.webp)

### Warning about direct pacman/yay updates

If you're already familiar with Arch, you might be tempted to just run `pacman -Syu` or `yay -Syu` yourself, but if you do that, you'll miss the snapshot, migrations, and configuration updates that Mid’hat runs together with new packages. That's why Mid’hat will actually stop a direct system upgrade and point you to `midhat update` instead. (If you really know what you're doing, the guard will tell you how to bypass it for a single transaction.)

### Rolling back bad updates

If you ever have a problem after doing an update, you can rollback your system to the snapshot taken before the update. The FydeTab boots through U-Boot, which has no snapshot menu yet, so list the snapshots with `sudo snapper list` and roll back from a terminal.

If somehow your configuration files have been corrupted, you can also perform a Mid’hat reinstall using `midhat reinstall` in the terminal. This will reinstall all the default Mid’hat packages, reset all the configuration files. Note that all your user config changes to the Mid’hat defaults will be overwritten doing this!
