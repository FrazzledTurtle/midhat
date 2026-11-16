#!/usr/bin/python3
"""Rename an Omarchy source tree to Mid'hat.

usage: rename.py <omarchy-tree> <out-tree> [--report FILE]

Copies the tree (without .git, themes/, and Mid'hat's own tools/ and
pkgbuilds/) to <out-tree>, renaming paths and contents:

  omarchy -> midhat     OMARCHY -> MIDHAT     Omarchy -> Midhat or Mid'hat

Prose gets the display name "Mid’hat", written with the typographic
apostrophe U+2019: it is quote-neutral in every language, so a phrase is
spelled the same in a script and in the test that greps for it. Identifiers
(class names, regex alternatives, --flag=Omarchy, camelCase) get "Midhat".
In code files only strings, comments and heredocs can carry the display
name. Upstream URLs (http/https, basecamp/omarchy, omarchy.org) are kept as
they are, since they point at Omarchy itself, and so are the test fixtures
that are copies of files old Omarchy releases shipped: their contents stay,
since migrations recognise them by checksum, and only their paths change.

Every rewritten file is checked: bash -n, luac -p, json parse and
py_compile must pass after if they passed before, or the tool fails.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SKIP_TOP = {'.git', 'themes', 'tools', 'pkgbuilds'}
DISPLAY = 'Mid\u2019hat'
VERBATIM = tuple('test/shell.d/fixtures/%s/' % d for d in ('kitty', 'neovim-clipboard', 'legacy-icon-font'))
IDENT = 'Midhat'

PROTECT = re.compile(
    r'https?://[^\s"\'<>`)\]}]+'
    r'|\b(?:basecamp|omacom)/omarchy[\w.-]*'
    r'|[\w.-]*omarchy\.org\b',
    re.I)

JSON_DISPLAY_KEYS = {'label', 'name', 'displayName', 'description', 'title',
                     'author', 'summary', 'tooltip', 'subtitle'}


def rename_part(s):
    return s.replace('omarchy', 'midhat').replace('Omarchy', IDENT).replace('OMARCHY', 'MIDHAT')


# --- context trackers ------------------------------------------------------
# Each returns a list of booleans, True where an apostrophe is harmless:
# comments, double-quoted strings, heredoc bodies, prose.

def bash_safe(text):
    n = len(text)
    safe = [False] * n
    stack = ['code']
    depth = [0]
    pending = []
    heredoc = []
    i = 0
    while i < n:
        ctx = stack[-1]
        c = text[i]
        if ctx == 'heredoc':
            end = text.find('\n', i)
            end = n if end < 0 else end
            delim, strip = heredoc[-1]
            line = text[i:end]
            if (line.lstrip('\t') if strip else line) == delim:
                stack.pop()
                heredoc.pop()
                if pending:
                    heredoc.append(pending.pop(0))
                    stack.append('heredoc')
            else:
                for k in range(i, end):
                    safe[k] = True
            i = end + 1
            continue
        safe[i] = ctx in ('dq', 'sq', 'ansi', 'comment')
        if ctx == 'comment':
            if c == '\n':
                stack.pop()
                continue
            i += 1
            continue
        if ctx == 'sq':
            if c == "'":
                stack.pop()
            i += 1
            continue
        if ctx == 'ansi':
            if c == '\\':
                i += 2
                continue
            if c == "'":
                stack.pop()
            i += 1
            continue
        if ctx == 'dq':
            if c == '\\':
                safe[i:i + 2] = [True] * len(safe[i:i + 2])
                i += 2
                continue
            if c == '"':
                stack.pop()
                i += 1
                continue
            if text.startswith('$(', i):
                stack.append('sub')
                depth.append(0)
                i += 2
                continue
            if text.startswith('${', i):
                stack.append('param')
                depth.append(0)
                i += 2
                continue
            if c == '`':
                stack.append('bt')
                depth.append(0)
                i += 1
                continue
            i += 1
            continue
        # code-like contexts: code, sub, param, bt
        if c == '\\':
            i += 2
            continue
        if text.startswith("$'", i):
            stack.append('ansi')
            i += 2
            continue
        if c == "'":
            stack.append('sq')
            i += 1
            continue
        if c == '"':
            stack.append('dq')
            i += 1
            continue
        if text.startswith('$(', i):
            stack.append('sub')
            depth.append(0)
            i += 2
            continue
        if text.startswith('${', i):
            stack.append('param')
            depth.append(0)
            i += 2
            continue
        if c == '`':
            if ctx == 'bt':
                stack.pop()
                depth.pop()
            else:
                stack.append('bt')
                depth.append(0)
            i += 1
            continue
        if ctx == 'param':
            if c == '{':
                depth[-1] += 1
            elif c == '}':
                if depth[-1] == 0:
                    stack.pop()
                    depth.pop()
                else:
                    depth[-1] -= 1
            i += 1
            continue
        if ctx == 'sub':
            if c == '(':
                depth[-1] += 1
            elif c == ')':
                if depth[-1] == 0:
                    stack.pop()
                    depth.pop()
                    i += 1
                    continue
                depth[-1] -= 1
        if c == '#' and (i == 0 or text[i - 1] in ' \t\n;|&('):
            stack.append('comment')
            safe[i] = True
            i += 1
            continue
        if text.startswith('<<', i) and not text.startswith('<<<', i):
            m = re.match(r'<<(-?)[ \t]*(["\']?)([A-Za-z_][\w]*)\2', text[i:])
            if m:
                pending.append((m.group(3), m.group(1) == '-'))
                i += m.end()
                continue
        if c == '\n' and pending:
            heredoc.append(pending.pop(0))
            stack.append('heredoc')
        i += 1
    return safe


def clike_safe(text, line_comment, block=None, template=False):
    """QML/JS/CSS (//, /* */), Lua (--, --[[ ]]), Python (#, triple quotes)."""
    n = len(text)
    safe = [False] * n
    i = 0
    lua = line_comment == '--'
    py = line_comment == '#'
    while i < n:
        c = text[i]
        if lua and re.match(r'--\[(=*)\[', text[i:i + 8]):
            eq = re.match(r'--\[(=*)\[', text[i:]).group(1)
            end = text.find(']' + eq + ']', i)
            end = n if end < 0 else end + len(eq) + 2
            safe[i:end] = [True] * (end - i)
            i = end
            continue
        if lua and re.match(r'\[(=*)\[', text[i:i + 6]):
            eq = re.match(r'\[(=*)\[', text[i:]).group(1)
            end = text.find(']' + eq + ']', i)
            end = n if end < 0 else end + len(eq) + 2
            safe[i:end] = [True] * (end - i)
            i = end
            continue
        if text.startswith(line_comment, i):
            end = text.find('\n', i)
            end = n if end < 0 else end
            safe[i:end] = [True] * (end - i)
            i = end
            continue
        if block and text.startswith(block[0], i):
            end = text.find(block[1], i + len(block[0]))
            end = n if end < 0 else end + len(block[1])
            safe[i:end] = [True] * (end - i)
            i = end
            continue
        if py and (text.startswith('"""', i) or text.startswith("'''", i)):
            q = text[i:i + 3]
            end = text.find(q, i + 3)
            end = n if end < 0 else end + 3
            if q == '"""':
                safe[i:end] = [True] * (end - i)
            i = end
            continue
        if c in '"\'' or (template and c == '`'):
            j = i + 1
            while j < n and text[j] != c:
                if text[j] == '\\':
                    j += 1
                elif text[j] == '\n' and c != '`':
                    break
                j += 1
            end = min(j + 1, n)
            safe[i:end] = [True] * (end - i)
            i = end
            continue
        i += 1
    return safe


def hash_lines_safe(text, keys=()):
    """Config files: '#'/';' comment lines, plus the values of display keys."""
    safe = [False] * len(text)
    pos = 0
    key_re = re.compile(r'^\s*(%s)(\[[^\]]*\])?\s*=' % '|'.join(map(re.escape, keys))) if keys else None
    for line in text.splitlines(keepends=True):
        s = line.lstrip()
        if s.startswith('#') or s.startswith(';'):
            safe[pos:pos + len(line)] = [True] * len(line)
        elif key_re:
            m = key_re.match(line)
            if m:
                safe[pos + m.end():pos + len(line)] = [True] * (len(line) - m.end())
        pos += len(line)
    return safe


def json_safe(text):
    safe = [False] * len(text)
    pat = re.compile(r'"(%s)"\s*:\s*"((?:[^"\\\n]|\\.)*)"' % '|'.join(JSON_DISPLAY_KEYS))
    for m in pat.finditer(text):
        safe[m.start(2):m.end(2)] = [True] * (m.end(2) - m.start(2))
    for m in re.finditer(r'(?m)^\s*//.*$', text):
        safe[m.start():m.end()] = [True] * (m.end() - m.start())
    return safe


def md_safe(text):
    safe = [True] * len(text)
    for m in re.finditer(r'(?ms)^(```|~~~).*?^\1[^\n]*$', text):
        safe[m.start():m.end()] = [False] * (m.end() - m.start())
    for m in re.finditer(r'`[^`\n]+`', text):
        safe[m.start():m.end()] = [False] * (m.end() - m.start())
    return safe


# --- file kinds ------------------------------------------------------------

def kind_of(path, text):
    base = os.path.basename(path)
    first = text.split('\n', 1)[0]
    if first.startswith('#!'):
        if re.search(r'\b(bash|sh)\b', first):
            return 'bash'
        if 'python' in first:
            return 'python'
        return 'other'
    name = base[:-4] if base.endswith('.tpl') else base
    ext = os.path.splitext(name)[1].lower()
    if base.endswith('.hook'):
        return 'ini-hook' if text.lstrip().startswith('[') else 'bash'
    if ext in ('.sh', '.bash', '.sample') or (ext == '' and '/bash/' in path):
        return 'bash'
    if ext == '.lua':
        return 'lua'
    if ext in ('.qml', '.js', '.mjs', '.css'):
        return 'js'
    if ext == '.py':
        return 'python'
    if ext == '.md':
        return 'md'
    if ext in ('.json', '.jsonc'):
        return 'json'
    if ext == '.desktop':
        return 'desktop'
    if ext in ('.service', '.timer', '.socket', '.target', '.path', '.slice', '.mount'):
        return 'systemd'
    if ext in ('.conf', '.toml', '.yaml', '.yml', '.ini', '.rules', '.list', '.plymouth',
               '.link', '.network', '.tmux', '.kdl', '.theme'):
        return 'hash'
    return 'other'


def safe_map(kind, text):
    if kind == 'bash':
        return bash_safe(text)
    if kind == 'lua':
        return clike_safe(text, '--')
    if kind == 'js':
        return clike_safe(text, '//', ('/*', '*/'), template=True)
    if kind == 'python':
        return clike_safe(text, '#')
    if kind == 'md':
        return md_safe(text)
    if kind == 'json':
        return json_safe(text)
    if kind == 'desktop':
        return hash_lines_safe(text, ('Name', 'GenericName', 'Comment', 'Description', 'Author'))
    if kind == 'systemd':
        return hash_lines_safe(text, ('Description',))
    if kind == 'ini-hook':
        return hash_lines_safe(text, ('Description',))
    if kind == 'hash':
        return hash_lines_safe(text, ('Description', 'Name', 'Comment'))
    return [False] * len(text)


def isolated(text, i, j):
    prev = text[i - 1] if i > 0 else ''
    nxt = text[j] if j < len(text) else ''
    return not (prev.isalnum() or prev == '_' or nxt.isalnum() or nxt == '_')


ZONED = ('json', 'desktop', 'systemd', 'ini-hook')


def prose(text, i, j, kind):
    prev = text[i - 1] if i > 0 else ''
    nxt = text[j] if j < len(text) else ''
    after = text[j + 1] if j + 1 < len(text) else ''
    if prev and (prev.isalnum() or prev in '_./=|:-@$\\%#~+'):
        return False
    if prev == '"' and nxt == '"' and kind != 'json':
        return False
    if nxt == '' or nxt in ' \t\n,!?;)]*"`’':
        return True
    if nxt == "'" and text[j:j + 2] == "'s" and not (j + 2 < len(text) and text[j + 2].isalnum()):
        return True
    if nxt in '.:' and (after == '' or after in ' \t\n"\'`)'):
        return True
    return False


def transform(path, text):
    kind = kind_of(path, text)
    protected = [False] * len(text)
    for m in PROTECT.finditer(text):
        protected[m.start():m.end()] = [True] * (m.end() - m.start())
    safe = safe_map(kind, text)
    out, last, display = [], 0, 0
    for m in re.finditer(r'omarchy|Omarchy|OMARCHY', text):
        i, j = m.span()
        if protected[i]:
            continue
        word = m.group()
        if word == 'Omarchy':
            zoned = kind in ZONED and safe[i] and isolated(text, i, j)
            if zoned or (safe[i] and prose(text, i, j, kind)):
                rep = DISPLAY
                display += 1
            else:
                rep = IDENT
        else:
            rep = rename_part(word)
        out.append(text[last:i])
        out.append(rep)
        last = j
    out.append(text[last:])
    new = re.sub('\\b([Aa])n (Mid\u2019hat|Midhat)\\b', r'\1 \2', ''.join(out))
    return new, kind, display


# --- validation ------------------------------------------------------------

def check(kind, path_for_tool, text):
    """Return True when the file parses (None when no checker applies)."""
    with tempfile.NamedTemporaryFile('w', suffix=os.path.splitext(path_for_tool)[1], delete=False) as f:
        f.write(text)
        tmp = f.name
    try:
        if kind == 'bash':
            return subprocess.run(['bash', '-n', tmp], capture_output=True).returncode == 0
        if kind == 'lua':
            return subprocess.run(['luac', '-p', tmp], capture_output=True).returncode == 0
        if kind == 'python':
            return subprocess.run([sys.executable, '-c', 'import ast,sys; ast.parse(open(sys.argv[1]).read())', tmp],
                                  capture_output=True).returncode == 0
        if kind == 'json' and path_for_tool.endswith('.json') and not path_for_tool.endswith('.tpl'):
            try:
                json.loads(text)
                return True
            except ValueError:
                return False
        return None
    finally:
        os.unlink(tmp)


def is_text(data):
    if b'\0' in data:
        return False
    try:
        data.decode('utf-8')
        return True
    except UnicodeDecodeError:
        return False


def main():
    args = sys.argv[1:]
    report_path = None
    if '--report' in args:
        k = args.index('--report')
        report_path = args[k + 1]
        del args[k:k + 2]
    if len(args) != 2:
        print(__doc__.strip().split('\n')[2], file=sys.stderr)
        return 2
    src, dst = map(os.path.abspath, args)
    if os.path.exists(dst) and os.listdir(dst):
        print('rename: %s is not empty' % dst, file=sys.stderr)
        return 1

    files = changed = renamed = display_total = 0
    problems, display_lines = [], []
    for root, dirs, names in os.walk(src):
        rel_root = os.path.relpath(root, src)
        if rel_root == '.':
            dirs[:] = [d for d in dirs if d not in SKIP_TOP]
        dirs.sort()
        for name in sorted(names):
            rel = os.path.normpath(os.path.join(rel_root, name))
            if rel_root == '.' and name in SKIP_TOP:
                continue
            verbatim = rel.startswith(VERBATIM)
            new_rel = rename_part(rel)
            spath, dpath = os.path.join(src, rel), os.path.join(dst, new_rel)
            os.makedirs(os.path.dirname(dpath), exist_ok=True)
            if os.path.exists(dpath) or os.path.lexists(dpath):
                problems.append('path collision: %s -> %s' % (rel, new_rel))
                continue
            files += 1
            renamed += new_rel != rel
            if verbatim:
                shutil.copy2(spath, dpath, follow_symlinks=False)
                continue
            if os.path.islink(spath):
                os.symlink(rename_part(os.readlink(spath)), dpath)
                continue
            data = open(spath, 'rb').read()
            if not is_text(data):
                shutil.copy2(spath, dpath)
                continue
            text = data.decode('utf-8')
            new, kind, display = transform(rel, text)
            if new != text:
                changed += 1
                display_total += display
                before = check(kind, rel, text)
                after = check(kind, rel, new)
                if before is True and after is not True:
                    problems.append('%s (%s) no longer parses' % (new_rel, kind))
                if display:
                    for ln in new.splitlines():
                        if DISPLAY in ln:
                            display_lines.append('%s: %s' % (new_rel, ln.strip()[:160]))
            with open(dpath, 'w', encoding='utf-8') as f:
                f.write(new)
            shutil.copystat(spath, dpath)

    left = subprocess.run(['grep', '-rIil', 'omarchy', dst], capture_output=True, text=True).stdout.split()
    print('files: %d, contents changed: %d, paths renamed: %d, display names: %d'
          % (files, changed, renamed, display_total))
    print('files still mentioning omarchy (upstream URLs only): %d' % len(left))
    if report_path:
        with open(report_path, 'w') as f:
            f.write('\n'.join(display_lines) + '\n')
    for p in problems:
        print('PROBLEM: ' + p, file=sys.stderr)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
