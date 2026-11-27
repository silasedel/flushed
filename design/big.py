import json, sys
sys.path.insert(0, sys.path[0])
from final import F as F16
from options import hx
from PIL import Image, ImageDraw, ImageFont

N = 32
class Cv:
    def __init__(s): s.g = [['.'] * N for _ in range(N)]
    def px(s, x, y, c):
        if 0 <= x < N and 0 <= y < N: s.g[y][x] = c
    def ell(s, cx, cy, rx, ry, c, only=None):
        for y in range(N):
            for x in range(N):
                if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1 and (only is None or s.g[y][x] in only): s.g[y][x] = c
    def rect(s, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1): s.px(x, y, c)
    def poly(s, pts, c):
        im = Image.new('L', (N, N), 0); ImageDraw.Draw(im).polygon(pts, fill=1)
        for y in range(N):
            for x in range(N):
                if im.getpixel((x, y)): s.g[y][x] = c
    def row(s, y, x, txt):
        for i, ch in enumerate(txt):
            if ch != ' ': s.px(x + i, y, ch)
    def outline(s, c='k'):
        add = []
        for y in range(N):
            for x in range(N):
                if s.g[y][x] == '.' and any(0 <= x + dx < N and 0 <= y + dy < N and s.g[y + dy][x + dx] not in '.' + c for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))): add.append((x, y))
        for x, y in add: s.g[y][x] = c
    def rows(s): return [''.join(r) for r in s.g]

def dbl(rows):
    out = []
    for r in rows:
        rr = ''.join(ch * 2 for ch in r); out += [rr, rr]
    return out

# ---------- Skibidi: head singing out of the bowl, lid up behind ----------
s = Cv()
s.rect(6, 1, 25, 15, 'W'); s.rect(7, 0, 24, 0, 'W'); s.rect(5, 2, 5, 14, 'W'); s.rect(26, 2, 26, 14, 'W')   # raised lid
s.rect(7, 2, 8, 14, 'w'); s.rect(23, 2, 24, 14, 'w'); s.rect(8, 1, 23, 1, 'h')                           # lid bevel
s.ell(16, 22.5, 15.5, 8.5, 'W'); s.ell(16, 21.5, 12.5, 6, 'd'); s.ell(16, 20.5, 11, 4.5, 'D', only='d')     # bowl + water
s.ell(16, 25.5, 15.5, 5.5, 'S', only='W'); s.ell(16, 24.5, 15, 5.5, 'W', only='S')                          # rim shading
s.rect(13, 15, 19, 25, 'f'); s.rect(14, 15, 15, 24, 'F')                                                     # long neck
s.ell(16, 9.5, 7.5, 8.5, 'F')                                                                                # head
s.rect(9, 2, 23, 4, 'H'); s.ell(16, 3.5, 8, 3, 'H', only='F.W'); s.row(5, 9, 'H'); s.row(5, 23, 'H')          # flat-top hair
s.rect(8, 8, 8, 11, 'f'); s.rect(24, 8, 24, 11, 'f')                                                         # ears
s.row(6, 10, 'ffff   ffff'.replace(' ', ' ')); s.row(7, 10, 'f    f f    f'[:0])
for ex in (11, 18):                                                                                          # huge eyes
    s.rect(ex, 7, ex + 3, 10, 'E'); s.rect(ex + 1, 8, ex + 2, 9, 'e'); s.px(ex + 1, 8, 'p')
    s.rect(ex - 1, 6, ex + 4, 6, 'f'); s.px(ex - 1, 7, 'f'); s.px(ex + 4, 7, 'f')
s.rect(16, 9, 16, 12, 'f')                                                                                   # nose
s.row(12, 10, 'm           m'); s.row(13, 10, 'mmmmmmmmmmmmm')                                              # grin
s.row(14, 11, 'myyyyyyyyyym'); s.row(15, 12, 'mmyyyyyyymm'); s.row(16, 14, 'mmmmmmm')
s.outline()
SKIBIDI = ({'k': '#1a1418', 'W': '#f4f2ee', 'w': '#dcd8d0', 'h': '#ffffff', 'S': '#a8a296', 'd': '#6a7458', 'D': '#4a5440',
            'H': '#241812', 'F': '#e6b088', 'f': '#b47a52', 'E': '#ffffff', 'e': '#4a8ad0', 'p': '#0a1a2a', 'm': '#2a0a0a', 'y': '#efe08a'}, s.rows())

# ---------- Sigma: gold gigachad, 3/4 view, slick hair, beard, big grin ----------
g = Cv()
g.ell(15, 12, 11, 11, 'F')                                    # skull + face
g.poly([(5, 13), (27, 12), (29, 19), (27, 25), (21, 30), (12, 30), (6, 25), (4, 18)], 'F')   # jaw mass
g.ell(13, 6, 11, 6.5, 'H', only='F'); g.poly([(3, 6), (12, 1), (25, 2), (27, 7), (20, 5), (10, 7), (5, 12)], 'H')
g.row(3, 9, 'hhhhh'); g.row(4, 7, 'hhh    hhhh'); g.row(2, 13, 'hhhhhh')                              # hair shine
g.poly([(4, 18), (10, 19), (13, 23), (20, 22), (27, 19), (28, 22), (25, 28), (19, 31), (12, 31), (6, 27)], 'B')   # beard
for (x, y) in [(7, 21), (9, 25), (12, 28), (15, 25), (18, 29), (22, 26), (24, 23), (10, 22), (14, 30), (20, 24)]: g.px(x, y, 'b')
g.ell(5.5, 14.5, 2.5, 3.5, 'E'); g.px(5, 14, 'S'); g.px(5, 15, 'S')                                      # ear
g.rect(13, 9, 17, 10, 'H'); g.rect(21, 9, 25, 10, 'H')                                                  # heavy brows
g.row(11, 13, 'SmmmS'); g.row(11, 21, 'SmmmS'); g.row(12, 14, 'SS'); g.row(12, 22, 'SS')                  # smiling squint eyes
g.rect(22, 12, 23, 17, 'L'); g.row(17, 21, 'SL'); g.row(18, 22, 'SSk'); g.px(25, 14, 'L')                # nose
g.rect(9, 12, 10, 16, 'S'); g.rect(17, 13, 19, 14, 'S')                                                    # cheek / temple shade
g.row(13, 7, 'LL'); g.row(8, 16, 'LLLL'); g.row(7, 18, 'LLL')                                             # forehead light
g.row(19, 16, 'BBBBBBBBBB'); g.row(20, 15, 'BBBBBBBBBBBB')                                                # moustache
g.row(21, 15, 'mmmmmmmmmmm'); g.row(22, 15, 'mwwwwwwwwwm'); g.row(23, 16, 'mwwwwwwwm'); g.row(24, 17, 'mmmmmmm')   # grin + teeth
g.outline()
SIGMA = ({'k': '#2a1a04', 'H': '#6b4a12', 'h': '#a87a28', 'F': '#f3cd66', 'L': '#fff3b0', 'S': '#c99a35', 'E': '#e6b850',
          'B': '#8a6418', 'b': '#b8862a', 'w': '#fffbe8', 'm': '#3a2204'}, g.rows())

# ---------- Mid: a battery stuck at 50% with a meh face ----------
MID16 = ({'k': '#143024', 'A': '#cfe6da', 'a': '#ffffff', 'M': '#7fe3b0', 'm': '#c8f7de', 'e': '#163326', 'd': '#2a3a33', 'n': '#3f9c72'}, [
  '................',
  '................',
  '................',
  '.kkkkkkkkkkkkk..',
  '.kAaaaaaaaaaAk..',
  '.kAMmMMMddddAkkk',
  '.kAMMMMMddddAkAk',
  '.kAMeeMMdeedAkAk',
  '.kAMMMMMddddAkAk',
  '.kAMMeeeeeedAkAk',
  '.kAMMMMMddddAkkk',
  '.kAnnnnnddddAk..',
  '.kAAAAAAAAAAAk..',
  '.kkkkkkkkkkkkk..',
  '................',
  '................',
])

ICONS = {
  'icoNPC': (F16['icoNPC'][0], dbl(F16['icoNPC'][1])),
  'icoMid': (MID16[0], dbl(MID16[1])),
  'icoRizz': (F16['icoRizz'][0], dbl(F16['icoRizz'][1])),
  'icoSkibidi': SKIBIDI,
  'icoSigma': SIGMA,
}

if __name__ == '__main__':
    for n, (p, r) in ICONS.items():
        assert len(r) == 32 and all(len(x) == 32 for x in r), n
        miss = {c for x in r for c in x if c != '.' and c not in p}; assert not miss, (n, miss)
    names = ['1. NPC', '2. Mid', '3. Rizz', '4. Skibidi', '5. Sigma']
    K = 6; cw = 32 * K + 40
    img = Image.new('RGB', (5 * cw + 20, 32 * K + 120), '#1a2018'); d = ImageDraw.Draw(img)
    font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 18)
    for i, (n, (p, r)) in enumerate(ICONS.items()):
        ox = 30 + i * cw; oy = 20
        for y, row in enumerate(r):
            for x, c in enumerate(row):
                if c != '.': d.rectangle([ox + x * K, oy + y * K, ox + x * K + K - 1, oy + y * K + K - 1], fill=hx(p[c]))
                if c != '.': d.point((ox + 60 + x, oy + 32 * K + 50 + y), fill=hx(p[c]))
        w = d.textlength(names[i], font=font); d.text((ox + 16 * K - w / 2, oy + 32 * K + 14), names[i], fill='#e8f0e4', font=font)
    img.save(sys.argv[1])
    if len(sys.argv) > 2: json.dump({n: {'p': p, 'r': r} for n, (p, r) in ICONS.items()}, open(sys.argv[2], 'w'))
