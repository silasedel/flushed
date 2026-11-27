import sys, json
from collections import deque
from PIL import Image, ImageOps, ImageFilter
src, out_png, out_json = sys.argv[1:4]
N = 32
im = Image.open(src).convert('L'); W, H = im.size; px = im.load()
# background = light pixels connected to the border (sticker rim + gray backdrop)
bg = [[False] * W for _ in range(H)]; q = deque()
for x in range(W): q += [(x, 0), (x, H - 1)]
for y in range(H): q += [(0, y), (W - 1, y)]
while q:
    x, y = q.popleft()
    if not (0 <= x < W and 0 <= y < H) or bg[y][x] or px[x, y] < 212: continue
    bg[y][x] = True; q += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
mask = Image.new('L', (W, H), 0); mp = mask.load()
for y in range(H):
    for x in range(W):
        if not bg[y][x]: mp[x, y] = 255
mask = mask.filter(ImageFilter.MinFilter(5))  # trim the anti-aliased rim
x0, y0, x1, y1 = mask.getbbox(); s = max(x1 - x0, y1 - y0); cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
box = (cx - s // 2, cy - s // 2, cx - s // 2 + s, cy - s // 2 + s)
inner = N - 2  # leave room for the outline
c = im.crop(box).filter(ImageFilter.UnsharpMask(radius=6, percent=180, threshold=2))
c = ImageOps.autocontrast(c, cutoff=2)
g = c.resize((inner * 4, inner * 4), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=2, percent=120)).resize((inner, inner), Image.BOX)
g = ImageOps.autocontrast(g, cutoff=1)
m = mask.crop(box).resize((inner, inner), Image.BOX)
RAMP = ['#3a2405', '#6e4a10', '#9a6c16', '#c8961e', '#e8b830', '#f8d458', '#ffec98', '#fffbe0']
keys = 'abcdefgh'
grid = [['.'] * N for _ in range(N)]
gp, mpp = g.load(), m.load()
for y in range(inner):
    for x in range(inner):
        if mpp[x, y] < 128: continue
        v = gp[x, y] / 255
        v = v ** 1.05  # lift mids a touch so gold reads shiny
        grid[y + 1][x + 1] = keys[min(7, int(v * 8))]
# sharpen the key features the downsample smears: drawn in source coordinates, then stamped where they cover a cell
from PIL import ImageDraw
FEAT = [('b', [(225,160),(262,146),(305,150),(302,162),(265,160),(232,172)]),
        ('b', [(348,166),(398,158),(408,172),(356,178)]),
        ('a', [(250,176),(286,168),(312,182),(284,198)]),
        ('a', [(352,182),(388,176),(404,194),(368,204)]),
        ('g', [(328,198),(346,240),(348,262),(332,266),(322,238)]),
        ('a', [(252,290),(300,296),(352,306),(370,320),(352,338),(300,334),(262,318)]),
        ('h', [(266,300),(300,305),(345,314),(360,322),(345,328),(300,324),(272,312)])]
for key, pts in FEAT:
    lay = Image.new('L', (W, H), 0); ImageDraw.Draw(lay).polygon(pts, fill=255)
    cov = lay.crop(box).resize((inner, inner), Image.BOX).load()
    for y in range(inner):
        for x in range(inner):
            if cov[x, y] > 70 and grid[y + 1][x + 1] != '.': grid[y + 1][x + 1] = key
add = [(x, y) for y in range(N) for x in range(N) if grid[y][x] == '.' and any(0 <= x + dx < N and 0 <= y + dy < N and grid[y + dy][x + dx] not in '.k' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
for x, y in add: grid[y][x] = 'k'
rows = [''.join(r) for r in grid]
pal = dict(zip(keys, RAMP)); pal['k'] = '#1e1203'
json.dump({'p': pal, 'r': rows}, open(out_json, 'w'))
K = 10
img = Image.new('RGB', (N * K * 2 + 60, N * K + 20), '#1a2018')
for y, r in enumerate(rows):
    for x, c in enumerate(r):
        if c == '.': continue
        col = tuple(int(pal[c][i:i + 2], 16) for i in (1, 3, 5))
        for yy in range(K):
            for xx in range(K): img.putpixel((10 + x * K + xx, 10 + y * K + yy), col)
        for yy in range(4):
            for xx in range(4): img.putpixel((N * K + 40 + x * 4 + xx, 10 + y * 4 + yy), col)
img.save(out_png)
print('\n'.join(rows))
