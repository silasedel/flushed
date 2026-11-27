import json, sys
sys.path.insert(0, sys.path[0])
from options import O, hx
from PIL import Image, ImageDraw, ImageFont

F = {}
F['icoNPC'] = O['NPC']
F['icoMid'] = ({'k': '#143024', 'P': '#f4fff8', 'S': '#bfe8d2', 'l': '#a6d8bd', 'M': '#2fae6e', 'm': '#7fe3b0', 'f': '#d4f5e2'}, [
  '..kkkkkkkkkk....',
  '..kPPPPPPPPPkk..',
  '..kPllllPPPkfPk.',
  '..kPPPPPPPPkkkk.',
  '..kPllPllllPPPk.',
  '..kPPMMMMPPPPPk.',
  '..kPMMPPMMPPPPk.',
  '..kPMMPPPPPPPPk.',
  '..kPMMPPPMMMMPk.',
  '..kPMMPPPPPPPPk.',
  '..kPMMPPMMPPPPk.',
  '..kPPMMMMPPPPPk.',
  '..kPPPPPPPPPPPk.',
  '..kPPPPPPPPPPPk.',
  '..kSSSSSSSSSSSk.',
  '..kkkkkkkkkkkkk.',
])
p, r = O['Mewing']
F['icoRizz'] = ({**p, 'H': '#4a0f14', 'h': '#8a2530', 'L': '#ff8a7a', 'R': '#ff4d4d', 'D': '#c3262c', 'd': '#7d1218', 'k': '#2a0709', 'e': '#2a0709'}, r)
F['icoSkibidi'] = ({'k': '#1a1024', 'W': '#ffffff', 'w': '#e9e4f2', 'S': '#a99cc0', 'D': '#6d5f88', 'H': '#3a2414', 'F': '#ffd2a8', 'f': '#d99a72', 'e': '#1a1024', 'E': '#ffffff', 'm': '#5a0d1a', 't': '#ff6a8a', 'x': '#c58bff'}, [
  'kkkkk...........',
  'kWWWk...........',
  'kWwSkk..kkkkk...',
  'kWwSk..kHHHHHk..',
  'kWwSk.kHHHHHHHk.',
  'kWwSk.kFkkFkkFk.',
  'kWwSk.kFEeFEeFk.',
  'kWwSk.kFFFFFFFk.',
  'kWwSkkkFkmmmkFkk',
  'kWwWWWkFkttkFkWk',
  'kSwWwWWkkkkkWwWk',
  'kSSwWWWWWWWWWWSk',
  '.kkSSwwWWWWWSSk.',
  '....kkSwWWSkk...',
  '....kSSwWWSSk...',
  '...kkkkkkkkkkk..',
])
F['icoSigma'] = ({'k': '#2a1a04', 'H': '#5a3e10', 'h': '#8a6420', 'F': '#f3cd66', 'L': '#fff3b0', 'S': '#c99a35', 'D': '#8a6418', 'e': '#2a1a04', 'N': '#b8862a', 'x': '#fffbe0'}, [
  'x..kkkkkkkkk...x',
  '..kHHhhhhHHHk...',
  '.kHHHhHHHHHHHk..',
  '.kHkkkkkkkkkHk..',
  '.kkLLLFFFFFFkk..',
  '.kFkkkFFFkkkFk..',
  '.kFFekFFFkeFFk..',
  'kFLFFFFkFFFFFSk.',
  'kSLFFFFkkFFFFSk.',
  'kSFLFFFFFFFFSSk.',
  'kSSFFkkkkkkFSSk.',
  'kSSFFFFFFFFFSSk.',
  'kDSSFFFkFFFSSDk.',
  '.kDSSSSSSSSSDk..',
  '.kNkDDDDDDDkNk..',
  'kNNNkNNNNNkNNNk.',
])

if __name__ == '__main__':
    for n, (p, r) in F.items():
        assert len(r) == 16 and all(len(x) == 16 for x in r), (n, [len(x) for x in r])
        assert all(c == '.' or c in p for x in r for c in x), n
    names = ['1. NPC', '2. Mid', '3. Rizz', '4. Skibidi', '5. Sigma']
    K = 10; cw = 16 * K + 40
    img = Image.new('RGB', (5 * cw + 20, 16 * K + 80), '#1a2018'); d = ImageDraw.Draw(img)
    font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 18)
    for i, (n, (p, r)) in enumerate(F.items()):
        ox = 30 + i * cw; oy = 20
        for y, row in enumerate(r):
            for x, c in enumerate(row):
                if c != '.': d.rectangle([ox + x * K, oy + y * K, ox + x * K + K - 1, oy + y * K + K - 1], fill=hx(p[c]))
        w = d.textlength(names[i], font=font); d.text((ox + 8 * K - w / 2, oy + 16 * K + 18), names[i], fill='#e8f0e4', font=font)
    img.save(sys.argv[1])
    if len(sys.argv) > 2: json.dump({n: {'p': p, 'r': r} for n, (p, r) in F.items()}, open(sys.argv[2], 'w'))
