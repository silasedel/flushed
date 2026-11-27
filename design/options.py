import json, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, sys.path[0])
from icons import ICONS as CUR

FACE = [
  '................',
  '.....kkkkkk.....',
  '...kkFFFFFFkk...',
  '..kFhhFFFFFFSk..',
  '..kFhFFFFFFFSk..',
  '.kFFFFFFFFFFFSk.',
  '.kFFFFFFFFFFFSk.',
  '.kFFFFFFFFFFFSk.',
  '.kFFFFFFFFFFFSk.',
  '.kFFFFFFFFFFFSk.',
  '.kSFFFFFFFFFSSk.',
  '..kSFFFFFFFSSk..',
  '..kSSFFFFFSSDk..',
  '...kkSSSSSSkk...',
  '.....kkkkkk.....',
  '................',
]
def face(over):
    r = [list(x) for x in FACE]
    for row, col, s in over:
        for i, ch in enumerate(s):
            if ch != ' ': r[row][col + i] = ch
    return [''.join(x) for x in r]

O = {}
O['NPC'] = CUR['icoNPC']
O['L'] = ({'k': '#2a0a0a', 'L': '#e8463c', 'h': '#ff9a8a', 'D': '#9e2420', 'c': '#3a0c0c'}, [
  '................',
  '..kkkkk.........',
  '..kLhLk.........',
  '..kLhLk.........',
  '..kLLLk.........',
  '..kLcLk.........',
  '..kLLck.........',
  '..kLcLk.........',
  '..kLLLk.........',
  '..kLLLkkkkkkkk..',
  '..kLhLLLLcLLLk..',
  '..kLLLLLcLLLLk..',
  '..kDDDDDDDDDDk..',
  '..kkkkkkkkkkkk..',
  '................',
  '................',
])
O['W'] = ({'k': '#0f2a0c', 'W': '#7dff6a', 'h': '#d8ffcc', 'D': '#3aa832'}, [
  '................',
  'kkkk..kkkk..kkkk',
  'kWhk..kWhk..kWhk',
  'kWhk..kWWk..kWWk',
  'kWWk..kWWk..kWWk',
  'kWWk..kWWk..kWWk',
  'kWWk..kWWk..kWWk',
  'kWWk..kWWk..kWWk',
  'kWWWkkWWWWkkWWWk',
  'kWWWWWWWWWWWWWWk',
  '.kWWWWWkkWWWWWk.',
  '.kDDDDk..kDDDDk.',
  '..kkkk....kkkk..',
  '................',
  '................',
  '................',
])
O['Cooked'] = ({'k': '#1a0f08', 'C': '#6b3d1c', 'c': '#9a5a2a', 'b': '#2e2724', 'B': '#ff7a2a', 'w': '#e8e2dc', 's': '#8e949c'}, [
  '....s....s......',
  '...s....s...s...',
  '....s....s.s....',
  '..kkkkk.kkkkk...',
  '.kcCCCCkCCCCCk..',
  'kcbbbbbbbbbbbCk.',
  'kCbwbwbbbwbwbCk.',
  'kCbbwbbbbbwbbCk.',
  '.kCwbwbbbwbwCk..',
  '.kCbbbbbbbbbCk..',
  '.kCbbbBkkBbbCk..',
  '.kCbBbbbbbbBCk..',
  '.kCbbbbbBbbbCk..',
  '.kCCCCCCCCCCCk..',
  '..kkkkkkkkkkk...',
  '................',
])
O['Ohio'] = ({'k': '#200a0a', 'O': '#c8202c', 'h': '#ff6a6a', 'D': '#7e1018', 'e': '#ffffff', 'p': '#1a0505', 'm': '#2a0606', 't': '#ffffff'}, [
  '.kkkk...........',
  '.kOOOkk...kkkk..',
  '.kOhhOOkkkOOOOk.',
  '.kOhOOOOOOOOOOk.',
  '.kOOOOOOOOOOOOk.',
  '.kOOeeOOOOeeOOk.',
  '.kOOepOOOOpeOOk.',
  '.kOOOOOOOOOOOOk.',
  '.kOOOOOOOOOOODk.',
  '.kOmtmtmtmtmODk.',
  '.kOOmmmmmmmODk..',
  '..kOOOOOOOODk...',
  '...kDOOOOODk....',
  '....kkDDOOk.....',
  '......kkkk......',
  '................',
])
O['Mid'] = CUR['icoMid']
O['Yapping'] = ({'k': '#2a1404', 'F': '#ffb347', 'h': '#ffe2b0', 'S': '#e08a2a', 'D': '#a85c14', 'm': '#5a1010', 't': '#ff6a8a', 'w': '#ffffff', 'l': '#ffffff'},
  face([(5, 4, 'kk'), (6, 3, 'k'), (6, 6, 'k'), (5, 9, 'kk'), (6, 8, 'k'), (6, 11, 'k'),
        (8, 4, 'kkkkkk'), (9, 3, 'kwwwwwwk'), (10, 3, 'kmmmmmmk'), (11, 4, 'kmttmk'), (12, 5, 'kkkk'),
        (3, 14, 'l'), (5, 15, 'l'), (8, 15, 'l'), (10, 14, 'l')]))
O['Sus'] = ({'k': '#2a2004', 'F': '#ffd84a', 'h': '#fff4b8', 'S': '#e0a820', 'D': '#a8761c', 'w': '#ffffff', 'L': '#e0a820'},
  face([(4, 3, 'kkk'), (3, 8, 'kkkk'), (5, 3, 'wwk'), (6, 3, 'wwk'), (5, 8, 'wwk'), (6, 8, 'wwk'), (7, 3, 'SSS'), (7, 8, 'SSS'), (10, 8, 'kkk')]))
O['Cooking'] = ({'k': '#121418', 'P': '#4a515c', 'p': '#6e7784', 'D': '#2a2f36', 'E': '#ffffff', 'Y': '#ffb020', 'y': '#ffe08a', 'H': '#7a4a2a', 's': '#c9d3dd'}, [
  '...s..s..s......',
  '..s..s..s.......',
  '...s..s..s......',
  '................',
  '...kkkkkkkk.....',
  '..kpPPPPPPPk....',
  '.kpPPEEEEPPPk...',
  '.kPPEEYYEEPPkkkk',
  '.kPPEYyYYEPPkHHk',
  '.kPPEYYYYEPPkkkk',
  '.kPPPEEEEPPPk...',
  '..kDPPPPPPDk....',
  '...kkkkkkkk.....',
  '................',
  '................',
  '................',
])
O['Based'] = ({'k': '#1c1604', 'F': '#ffd23f', 'h': '#fff2a6', 'S': '#d99a10', 'D': '#9a6a08', 'G': '#111111', 'g': '#5a5a6a'},
  face([(5, 2, 'kkkkkkkkkkkk'), (6, 2, 'GgGGGkkGgGGk'), (7, 3, 'GGGk  GGGk'.replace(' ', 'F')), (8, 4, 'kk    kk'.replace(' ', 'F')),
        (10, 8, 'kk'), (11, 5, 'kkk')]))
O['Rizz'] = CUR['icoRizz']
O['Mewing'] = ({'k': '#0a1a2a', 'H': '#123250', 'h': '#2a5a88', 'L': '#9fd8ff', 'R': '#5fb4f0', 'D': '#2a78b8', 'd': '#164a78', 'e': '#0a1a2a', 'w': '#ffffff', 'f': '#ffd2b0', 'F': '#c98a6a'}, [
  '....kkkkkk......',
  '..kkHHHhhhkk....',
  '.kHHHhhHHHHHk...',
  'kHHhHHHHHHHHHk..',
  'kHHHHHHHkkkkkk..',
  'kHHkkLLLLLLLLk..',
  'kHkDLLLkkkkkLk..',
  'kHkdLLLLLwekLk..',
  'kkDDLLLLLLLLLLk.',
  '.kRDLLLLLLLLLkfk',
  '.kRRLLLLLLLLkfFk',
  '.kDRRLLLLLLLLkfk',
  '.kDRRRLLLkkkkfFk',
  '.kdDRRRRRRRRRRkk',
  '..kdDDDRRRRRRRk.',
  '...kkkkkkkkkkk..',
])
O['Mog'] = ({'k': '#0e0e14', 'F': '#c7b7a0', 'h': '#efe2d0', 'S': '#8f7d66', 'B': '#3a2a1a', 'e': '#0e0e14', 'f': '#f2d26a', 'g': '#c99a35', 'w': '#9fd6ff'}, [
  '..kkkkkkk.......',
  '.kBBBBBBBk......',
  'kBBBBBBBBBk.....',
  'kFkBBBBBkFk.....',
  'kFhFFFFFFFk.....',
  'kFkkkFkkkFk.....',
  'kFFekFFekFk.....',
  'kFFFFFFFFSk.....',
  'kFFFFkFFFSk.....',
  'kSFFFFFFSSk.....',
  'kSFkkkkFSSk.....',
  'kSSFFFFFSSk.kkk.',
  'kSSSSSSSSSkkfffk',
  '.kkSSSSSSkwkkfkk',
  '...kkkkkk..kfffk',
  '............kkk.',
])
O['Locked In'] = ({'k': '#0c1420', 'A': '#9fb3c8', 'a': '#d8e4f0', 'B': '#3e7cc0', 'b': '#7ab4f0', 'D': '#1e4a80', 'e': '#ffffff'}, [
  '.....kkkkkk.....',
  '....kAaaaAAk....',
  '...kAkkkkkkAk...',
  '...kAk....kAk...',
  '...kAk....kAk...',
  '..kkkkkkkkkkkk..',
  '..kbbbbbbbbbBk..',
  '..kbkkBBBBkkBk..',
  '..kBBkkBBkkBBk..',
  '..kBeekBBkeeBk..',
  '..kBkkkBBkkkBk..',
  '..kBBBBBBBBBBk..',
  '..kBBBkkkkBBDk..',
  '..kDDDDDDDDDDk..',
  '..kkkkkkkkkkkk..',
  '................',
])
O['Delulu'] = ({'k': '#2a0a20', 'F': '#ff9ad5', 'h': '#ffd6ef', 'S': '#e060a8', 'D': '#a83478', 'r': '#ff3f6a', 'b': '#ff6aa8', 'w': '#ffffff'},
  face([(0, 1, 'r r'), (1, 1, 'rrr'), (2, 2, 'r'), (0, 12, 'r r'), (1, 12, 'rrr'), (2, 13, 'r'), (5, 3, 'kkk'), (6, 3, 'kbk'), (7, 3, 'kkk'), (5, 8, 'kkk'), (6, 8, 'kbk'), (7, 8, 'kkk'), (8, 2, 'bb'), (8, 11, 'bb'), (10, 5, 'kFFk'), (11, 6, 'kk')]))
O['Aura'] = CUR['icoAura']
O['Goated'] = ({'k': '#1e1408', 'F': '#f1e4c8', 'h': '#ffffff', 'S': '#c9b48e', 'H': '#8a6a4a', 'j': '#c99a6a', 'e': '#ffcc2a', 'p': '#1e1408', 'n': '#d88a8a'}, [
  '.kk..........kk.',
  'kHjk........kjHk',
  'kHkjk......kjkHk',
  '.kkHjkkkkkkjHkk.',
  'kFkkHFFFFFFHkkFk',
  'kFFkFhhFFFFFkFFk',
  '.kkFeepFFpeeFkk.',
  '...kFFFFFFFFk...',
  '...kFFFFFFFFk...',
  '...kSFFFFFFSk...',
  '....kSFnnFSk....',
  '....kSSkkSSk....',
  '.....kSFFSk.....',
  '.....kFFFFk.....',
  '......kFFk......',
  '.......kk.......',
])
O['Final Boss'] = ({'k': '#120a10', 'Y': '#f3cd66', 'y': '#fff0a8', 'r': '#ff3f6a', 'B': '#eeeae4', 'b': '#ffffff', 'S': '#a8a29a', 'e': '#ff2a3a', 'E': '#120a10'}, [
  '..k...kk...k....',
  '.kYk.kyyk.kYk...',
  '.kYYkYrYYkYYk...',
  '.kkkkkkkkkkkk...',
  '.kBbbBBBBBBBSk..',
  'kBbBBBBBBBBBBSk.',
  'kBBEEEBBBEEEBSk.',
  'kBBEeEBBBEeEBSk.',
  'kBBEEEBBBEEEBSk.',
  'kSBBBBBkBBBBBSk.',
  '.kSBBBkkkBBBSk..',
  '..kSBBBBBBBSk...',
  '..kBkBkBkBkBk...',
  '..kkBkBkBkBkk...',
  '...kkkkkkkkk....',
  '................',
])
O['Sigma'] = CUR['icoSigma']
O['Skibidi'] = ({'k': '#3a2508', 'T': '#f3cd66', 't': '#fff0a8', 'S': '#b8862a', 'F': '#ffd6b0', 'f': '#d9a07a', 'e': '#ffffff', 'p': '#1a0a04', 'm': '#5a1010'}, [
  '..kkkkkkkkkkkk..',
  '..kTttttttttTk..',
  '..kTTTTTTTTTTk..',
  '..kkkkkkkkkkkk..',
  '....kkFFFFkk....',
  '...kFFFFFFFFk...',
  '...kFepFFepFk...',
  '.kkkFFFFFFFFkkk.',
  'kTtkFkmmmmkFktTk',
  'kTTkfFkkkkFfkTTk',
  '.kTTkkkkkkkkTTk.',
  '..kSTTTTTTTTSk..',
  '...kSTTTTTTSk...',
  '....kSTttTSk....',
  '...kkSTTTTSkk...',
  '..kkkkkkkkkkkk..',
])

def hx(c): c = c.lstrip('#'); return tuple(int(c[i:i+2], 16) for i in (0, 2, 4))

if __name__ == '__main__':
    out = sys.argv[1]
    bad = []
    for n, (p, r) in O.items():
        if len(r) != 16 or any(len(x) != 16 for x in r): bad.append((n, [len(x) for x in r]))
        miss = {ch for x in r for ch in x if ch != '.' and ch not in p}
        if miss: bad.append((n, miss))
    if bad: print(bad); sys.exit(1)
    K, cols = 8, 5
    cw, ch = 16 * K + 40, 16 * K + 64
    rows = (len(O) + cols - 1) // cols
    img = Image.new('RGB', (cols * cw + 20, rows * ch + 20), '#1a2018')
    d = ImageDraw.Draw(img)
    try: font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 17)
    except Exception: font = ImageFont.load_default()
    for i, (n, (p, r)) in enumerate(O.items()):
        ox = 20 + (i % cols) * cw + 20; oy = 20 + (i // cols) * ch
        d.rectangle([ox - 12, oy - 8, ox + 16 * K + 12, oy + 16 * K + 44], fill='#222a20')
        for y, row in enumerate(r):
            for x, c in enumerate(row):
                if c != '.': d.rectangle([ox + x * K, oy + y * K, ox + x * K + K - 1, oy + y * K + K - 1], fill=hx(p[c]))
        label = f'{i + 1}. {n}'
        w = d.textlength(label, font=font)
        d.text((ox + 8 * K - w / 2, oy + 16 * K + 14), label, fill='#e8f0e4', font=font)
    img.save(out)
