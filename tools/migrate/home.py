#!/usr/bin/python3
"""Move a user's home from Omarchy to Mid'hat names.

usage: home.py switch <home> <manifest> [--dry-run]
       home.py rollback <home> <manifest> <snapshot-home>

switch, run as the user after the midhat packages are installed:
  1. moves ~/.config/omarchy, ~/.local/state/omarchy, ~/.cache/omarchy to .../midhat
  2. rewrites omarchy -> midhat (OMARCHY -> MIDHAT, Omarchy -> Midhat) in the
     user's config text files, keeping http(s) URLs to Omarchy as they are
  3. renames files and folders named omarchy* in those places
  4. re-points symlinks whose target names omarchy (systemd wants links,
     agent skills, the theme and wallpaper links, the OSKar launcher...)
  5. resets the menu override, whose entries are now Mid'hat's defaults
  6. deletes the FydeTab image's restore-fydetab-repos hook, which would put
     the image's pacman.conf back over [midhat] on `midhat refresh pacman`
Every step is written to <manifest> (JSON) before the next one runs.

rollback undoes a manifest, taking original file contents from a read-only
snapshot of /home made before the switch.
"""

import json
import os
import re
import shutil
import sys

PROTECT = re.compile(
    r'https?://[^\s"\'<>`)\]}]+|\b(?:basecamp|omacom)/omarchy[\w.-]*|[\w.-]*omarchy\.org\b', re.I)
NAME = re.compile(r'omarchy|Omarchy|OMARCHY')

MOVES = ['.config/omarchy', '.local/state/omarchy', '.cache/omarchy']

# Text files under these are rewritten. ~/.config is taken whole, minus app
# data that merely mentions Omarchy (browser profiles, editor caches, notes).
REWRITE_ROOTS = ['.config', '.local/bin', '.local/share/applications',
                 '.local/share/nautilus-python', '.local/state/midhat', '.local/state/oskar',
                 '.bashrc', '.bash_profile', '.profile', '.zshrc', '.XCompose']
CONFIG_SKIP = re.compile(
    r'^\.config/(Code|ponytail|mozilla|zen|thunderbird|libreoffice|ARMSX2|OpenTubeX|kicad/[^/]+/(?!kicad_common\.json$)|'
    r'chromium|google-chrome[^/]*|microsoft-edge[^/]*|BraveSoftware)')
FILE_SKIP = re.compile(r'(\.bak[^/]*|\.orig[^/]*|~|\.omarchy-logo|\.pre-midhat)$')
MAX_SIZE = 4 << 20

# Symlinks anywhere in these are re-pointed (and renamed when named omarchy*).
LINK_ROOTS = ['.config', '.local/bin', '.local/state/midhat', '.local/share/applications', '.cache/midhat',
              '.claude', '.agents', '.codex', '.pi', '.gemini', '.hermes', '.vscode']

MENU_OVERRIDE = '.config/midhat/extensions/midhat-menu.jsonc'
MENU_DEFAULT = os.path.join(os.environ.get('MIDHAT_PATH', '/usr/share/midhat'), 'config/midhat/extensions/midhat-menu.jsonc')

IMAGE_HOOK = '.config/midhat/hooks/pre-refresh-pacman.d/restore-fydetab-repos'


def rename_text(text):
    protected = [False] * len(text)
    for m in PROTECT.finditer(text):
        protected[m.start():m.end()] = [True] * (m.end() - m.start())
    out, last = [], 0
    for m in NAME.finditer(text):
        if protected[m.start()]:
            continue
        w = m.group()
        out.append(text[last:m.start()])
        out.append({'omarchy': 'midhat', 'Omarchy': 'Midhat', 'OMARCHY': 'MIDHAT'}[w])
        last = m.end()
    out.append(text[last:])
    return ''.join(out)


def rename_name(name):
    return name.replace('omarchy', 'midhat').replace('Omarchy', 'Midhat').replace('OMARCHY', 'MIDHAT')


class Manifest:
    def __init__(self, path, dry):
        self.path, self.dry, self.ops = path, dry, []

    def add(self, **op):
        self.ops.append(op)
        if not self.dry:
            tmp = self.path + '.tmp'
            with open(tmp, 'w') as f:
                json.dump(self.ops, f, indent=1)
            os.replace(tmp, self.path)


def walk_files(home, rel_root):
    top = os.path.join(home, rel_root)
    if os.path.isfile(top) and not os.path.islink(top):
        yield rel_root
        return
    for root, dirs, files in os.walk(top):
        dirs[:] = [d for d in dirs if d != '.git']
        for f in files:
            yield os.path.relpath(os.path.join(root, f), home)


def is_text(path):
    try:
        if os.path.getsize(path) > MAX_SIZE:
            return False
        data = open(path, 'rb').read()
        if b'\0' in data:
            return False
        data.decode('utf-8')
        return True
    except (OSError, UnicodeDecodeError):
        return False


def switch(home, manifest_path, dry):
    m = Manifest(manifest_path, dry)
    report = []

    for rel in MOVES:
        new = rename_name(rel)
        if os.path.lexists(os.path.join(home, new)):
            sys.exit('home: %s already exists; nothing was changed' % new)

    # 1. move the three Omarchy folders
    for rel in MOVES:
        src, dst = os.path.join(home, rel), os.path.join(home, rename_name(rel))
        if os.path.isdir(src) and not os.path.islink(src):
            if not dry:
                os.rename(src, dst)
            m.add(op='move', old=rel, new=rename_name(rel))

    def orig_of(rel):
        for old in MOVES:
            new = rename_name(old)
            if rel == new or rel.startswith(new + '/'):
                return old + rel[len(new):]
        return rel

    def here(roots):
        # A dry run moves nothing, so the moved folders keep their old names.
        if not dry:
            return roots
        back = {rename_name(old): old for old in MOVES}
        return [back.get(r, r) for r in roots]

    # 2. rewrite contents
    seen = set()
    for root in here(REWRITE_ROOTS):
        for rel in walk_files(home, root):
            path = os.path.join(home, rel)
            if rel in seen or os.path.islink(path):
                continue
            seen.add(rel)
            if rel.startswith('.config/') and CONFIG_SKIP.match(rel):
                continue
            if FILE_SKIP.search(rel) or not is_text(path):
                continue
            text = open(path, encoding='utf-8').read()
            new = rename_text(text)
            if rel.startswith('.config/hypr/') and rel.endswith('.lua'):
                new = new.replace("Mid'hat", 'Mid’hat')
            if new != text:
                if not dry:
                    st = os.stat(path)
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new)
                    os.chmod(path, st.st_mode)
                m.add(op='write', path=rel, orig=orig_of(rel))

    # 3. rename files and folders named omarchy*, deepest first
    renames = []
    for root in here(REWRITE_ROOTS):
        top = os.path.join(home, root)
        if not os.path.isdir(top):
            continue
        for dirpath, dirs, files in os.walk(top, topdown=False):
            dirs[:] = [d for d in dirs if d != '.git']
            if '/.git' in dirpath:
                continue
            for name in files + dirs:
                if NAME.search(name) and not FILE_SKIP.search(name):
                    p = os.path.join(dirpath, name)
                    if os.path.islink(p):
                        continue
                    rel = os.path.relpath(p, home)
                    if rel.startswith('.config/') and CONFIG_SKIP.match(rel):
                        continue
                    renames.append(rel)
    for rel in dict.fromkeys(renames):
        new = os.path.join(os.path.dirname(rel), rename_name(os.path.basename(rel)))
        if os.path.lexists(os.path.join(home, new)):
            report.append('kept %s: %s already exists' % (rel, new))
            continue
        if not dry:
            os.rename(os.path.join(home, rel), os.path.join(home, new))
        m.add(op='rename', old=rel, new=new)

    # 4. symlinks
    for root in here(LINK_ROOTS):
        top = os.path.join(home, root)
        if not os.path.isdir(top):
            continue
        for dirpath, dirs, files in os.walk(top):
            dirs[:] = [d for d in dirs if d != '.git' and not os.path.islink(os.path.join(dirpath, d))]
            links = [n for n in files + os.listdir(dirpath) if os.path.islink(os.path.join(dirpath, n))]
            for name in dict.fromkeys(links):
                p = os.path.join(dirpath, name)
                target = os.readlink(p)
                if not NAME.search(target) and not NAME.search(name):
                    continue
                # Links into an Omarchy source checkout (~/omarchy) go to the
                # packaged copy, since no ~/midhat checkout exists.
                checkout = os.path.join(home, 'omarchy') + '/'
                if target.startswith(checkout):
                    target_new = '/usr/share/omarchy/' + target[len(checkout):]
                else:
                    target_new = target
                new_target = rename_name(target_new)
                new_rel = os.path.join(os.path.relpath(dirpath, home), rename_name(name))
                old_rel = os.path.relpath(p, home)
                if new_rel != old_rel and os.path.lexists(os.path.join(home, new_rel)):
                    report.append('kept link %s: %s already exists' % (old_rel, new_rel))
                    continue
                if not dry:
                    os.unlink(p)
                    os.symlink(new_target, os.path.join(home, new_rel))
                m.add(op='link', old=old_rel, new=new_rel, old_target=target, new_target=new_target)
                dangling = new_target if os.path.isabs(new_target) else os.path.join(dirpath, new_target)
                if not dry and not os.path.exists(dangling):
                    report.append('link %s points at missing %s' % (new_rel, new_target))

    # 5. the menu override's entries are Mid'hat's defaults now
    override = os.path.join(home, MENU_OVERRIDE)
    if os.path.isfile(override) and os.path.isfile(MENU_DEFAULT):
        if not dry:
            shutil.copy2(override, override + '.pre-midhat')
            shutil.copyfile(MENU_DEFAULT, override)
        m.add(op='write', path=MENU_OVERRIDE, orig='.config/omarchy/extensions/omarchy-menu.jsonc')

    # 6. the image hook that restores the FydeTab pacman.conf
    hook = os.path.join(home, orig_of(IMAGE_HOOK) if dry else IMAGE_HOOK)
    if os.path.isfile(hook) and not os.path.islink(hook):
        if not dry:
            os.unlink(hook)
        m.add(op='delete', path=IMAGE_HOOK, orig=orig_of(IMAGE_HOOK))

    counts = {}
    for op in m.ops:
        counts[op['op']] = counts.get(op['op'], 0) + 1
    print('home: %s' % ', '.join('%d %s' % (v, k) for k, v in sorted(counts.items())))
    for line in report:
        print('home: ' + line)
    return 0


def rollback(home, manifest_path, snapshot):
    ops = json.load(open(manifest_path))
    for op in reversed(ops):
        kind = op['op']
        if kind == 'link':
            new = os.path.join(home, op['new'])
            if os.path.islink(new):
                os.unlink(new)
            os.symlink(op['old_target'], os.path.join(home, op['old']))
        elif kind == 'rename':
            os.rename(os.path.join(home, op['new']), os.path.join(home, op['old']))
        elif kind in ('write', 'delete'):
            src = os.path.join(snapshot, op['orig'])
            dst = os.path.join(home, op['path'])
            shutil.copy2(src, dst)
            if dst.endswith('midhat-menu.jsonc') and os.path.exists(dst + '.pre-midhat'):
                os.unlink(dst + '.pre-midhat')
        elif kind == 'move':
            os.rename(os.path.join(home, op['new']), os.path.join(home, op['old']))
    print('home: rolled back %d steps' % len(ops))
    return 0


def main():
    a = sys.argv[1:]
    if len(a) >= 3 and a[0] == 'switch':
        return switch(os.path.abspath(a[1]), a[2], '--dry-run' in a)
    if len(a) == 4 and a[0] == 'rollback':
        return rollback(os.path.abspath(a[1]), a[2], os.path.abspath(a[3]))
    print(__doc__.strip().split('\n\n')[1], file=sys.stderr)
    return 2


if __name__ == '__main__':
    sys.exit(main())
