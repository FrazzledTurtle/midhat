#!/usr/bin/python3
"""Build Mid'hat's branding from the qeleshe pixel mark.

usage: build.py <midhat-tree>

Writes into the tree:
  icon.txt, logo.txt             block art (About window, screensaver)
  logo.svg                       the mark as one monochrome path
  icon.png                       300x300 ink mark on a paper tile
  default/sddm/midhat/logo.png   greeter mark
  default/fonts/midhat/midhat.ttf  family renamed to "midhat", U+E900 = qeleshe

The qeleshe is Albania's white felt cap, the "hat" in Mid'hat: here the tall
southern cut, with the apostrophe of Mid’hat in its crown.
"""

import importlib.machinery
import importlib.util
import os
import struct
import subprocess
import sys

W, H = 26, 22
INK, PAPER = '#111111', '#e4e4e4'


def qeleshe():
    g = [[0] * W for _ in range(H)]
    top, base, cx = 0, 21, 13

    def inside(x, y, shrink):
        px, py = x + 0.5, y + 0.5
        if py < top + shrink or py > base - shrink:
            return False
        half = 7.0 + 4.5 * (py - top) / (base - top) - shrink
        r = 6.5 - shrink
        dx = abs(px - cx) - (half - r)
        dy = top + shrink + r - py
        if dx > 0 and dy > 0:
            return dx * dx + dy * dy <= r * r
        return abs(px - cx) <= half

    for y in range(H):
        for x in range(W):
            if inside(x, y, 0) and not inside(x, y, 2):
                g[y][x] = 1
    for y in range(17, 21):
        for x in range(W):
            if inside(x, y, 0):
                g[y][x] = 1
    # The apostrophe of Mid’hat, in the crown.
    for x, y in [(12, 5), (13, 5), (14, 5), (12, 6), (13, 6), (14, 6), (12, 7), (13, 7), (14, 7),
                 (14, 8), (13, 9), (12, 10)]:
        g[y][x] = 1
    return g


def crop(g):
    rows = [y for y in range(H) if any(g[y])]
    cols = [x for x in range(W) if any(g[y][x] for y in range(H))]
    return [row[cols[0]:cols[-1] + 1] for row in g[rows[0]:rows[-1] + 1]]


def block_art(g):
    lines = [''.join('██' if c else '  ' for c in row).rstrip() for row in g]
    return '\n'.join('  ' + l if l else '' for l in lines) + '\n'


def svg_path(g):
    """Horizontal runs, merged down while identical, each a closed rectangle.
    Rectangles overlap their upper neighbour by a hair so no seam shows."""
    h, w = len(g), len(g[0])
    runs = []
    for y in range(h):
        x = 0
        while x < w:
            if g[y][x]:
                x0 = x
                while x < w and g[y][x]:
                    x += 1
                runs.append([x0, x, y, y + 1])
            else:
                x += 1
    merged = []
    for r in runs:
        for m in merged:
            if m[0] == r[0] and m[1] == r[1] and m[3] == r[2]:
                m[3] = r[3]
                break
        else:
            merged.append(r)
    eps = 0.02
    parts = []
    for x0, x1, y0, y1 in merged:
        top = max(0, y0 - eps)
        parts.append('M%g %gH%gV%gH%gZ' % (x0, top, x1, y1, x0))
    return ''.join(parts), w, h


def write_svg(path, d, w, h, fill='#000'):
    with open(path, 'w') as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">'
                '<path fill="%s" d="%s"/></svg>\n' % (w, h, w * 10, h * 10, fill, d))


def magick(*args):
    subprocess.run(['magick', *args], check=True)


def font_module(tree):
    path = os.path.join(tree, 'bin/midhat-dev-font')
    loader = importlib.machinery.SourceFileLoader('midhat_dev_font', path)
    spec = importlib.util.spec_from_loader('midhat_dev_font', loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def rename_font(path, old, new):
    """Rewrite every name-table string, replacing old with new."""
    d = open(path, 'rb').read()
    mod_tables = {}
    n = struct.unpack('>H', d[4:6])[0]
    for i in range(n):
        off = 12 + i * 16
        tag = d[off:off + 4].decode('latin-1')
        s, l = struct.unpack('>II', d[off + 8:off + 16])
        mod_tables[tag] = d[s:s + l]
    name = mod_tables['name']
    fmt, count, soff = struct.unpack('>HHH', name[:6])
    recs, strings = [], b''
    for i in range(count):
        pid, eid, lid, nid, ln, off = struct.unpack('>HHHHHH', name[6 + i * 12:18 + i * 12])
        raw = name[soff + off:soff + off + ln]
        enc = 'utf-16-be' if pid in (0, 3) else 'latin-1'
        text = raw.decode(enc).replace(old, new)
        data = text.encode(enc)
        recs.append((pid, eid, lid, nid, len(data), len(strings)))
        strings += data
    out = struct.pack('>HHH', 0, count, 6 + 12 * count)
    out += b''.join(struct.pack('>HHHHHH', *r) for r in recs) + strings
    mod_tables['name'] = out
    return mod_tables


def main():
    if len(sys.argv) != 2:
        print(__doc__.strip().split('\n')[2], file=sys.stderr)
        return 2
    tree = os.path.abspath(sys.argv[1])
    g = crop(qeleshe())
    art = block_art(g)
    for name in ('icon.txt', 'logo.txt'):
        open(os.path.join(tree, name), 'w').write(art)

    d, w, h = svg_path(g)
    write_svg(os.path.join(tree, 'logo.svg'), d, w, h)

    tmp = os.path.join(tree, '.brand-tmp.svg')
    write_svg(tmp, d, w, h, INK)
    try:
        magick('-background', 'none', '-density', '600', tmp, '-resize', '220x220',
               '-gravity', 'center', '-background', PAPER, '-extent', '300x300',
               os.path.join(tree, 'icon.png'))
        magick('-background', 'none', '-density', '600', tmp, '-resize', 'x188',
               os.path.join(tree, 'default/sddm/midhat/logo.png'))
    finally:
        os.unlink(tmp)

    fontdir = os.path.join(tree, 'default/fonts/midhat')
    ttf = os.path.join(fontdir, 'midhat.ttf')
    font = font_module(tree)
    tables = rename_font(ttf, 'omarchy', 'midhat')
    head = bytearray(tables['head'])
    struct.pack_into('>I', head, 8, 0)
    tables['head'] = bytes(head)
    open(ttf, 'wb').write(font.assemble(tables))
    contours = font.contours_from_svg(d, (0, 0, w, h))
    font.add_glyph(ttf, 0xE900, 'midhat', contours)
    print('branding written: %dx%d mark, %d contours' % (w, h, len(contours)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
