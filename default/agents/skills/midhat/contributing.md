# Reporting Issues and Submitting PRs

Read this when the user wants to report a Mid’hat bug, suggest a feature, or
contribute a fix.

Mid’hat lives at https://github.com/FrazzledTurtle/midhat. Verified bugs and
feature ideas go to its GitHub issues. Mid’hat split off from Omarchy for good,
so Omarchy's issue tracker, Discord and log server are not the place for
Mid’hat problems.

## Filing a Good Bug Report

Gather the version and diagnostics:

```bash
midhat version

# Generate the diagnostic log (also written to /tmp/midhat-debug.log)
midhat debug --no-sudo --print
```

The log lists installed packages and recent warnings from the journal. Read it
before attaching it and leave out anything private.

**Capture the problem on screen.** A screenshot or short recording of the bug
is often worth more than the description — see [`capture.md`](capture.md) for
`midhat capture screenshot` and `midhat screenrecord`. GitHub issue attachments
are added by drag-and-drop in the web form, so save the capture and hand the
user the file path to attach (`gh` cannot upload media).

For screen-recording failures specifically, rerun with
`MIDHAT_SCREENRECORD_DEBUG=true` and attach `/tmp/midhat-screenrecord.log`.

File the issue with `gh` when available:

```bash
gh issue create --repo FrazzledTurtle/midhat --title "..." --body "..."
```

Include: what happened, what was expected, steps to reproduce, the Mid’hat
version, and the capture.

## Submitting a PR

Never develop against `/usr/share/midhat`. Clone a working copy instead:

```bash
gh repo fork FrazzledTurtle/midhat --clone
cd midhat
```

Follow the repository's own `AGENTS.md` for style, testing, and commit
conventions. Keep commits atomic, run `./test/cli` and `./test/shell` before
pushing, and open the PR with `gh pr create`. A PR that fixes a visual problem
should include before/after captures (see [`capture.md`](capture.md)).
