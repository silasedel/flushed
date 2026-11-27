import sys, json
sys.path.insert(0, sys.path[0])
from options import face, hx
from PIL import Image, ImageDraw, ImageFont
P = {'k': '#2a0709', 'F': '#ff5a5a', 'h': '#ffc0b8', 'S': '#d23a3a', 'D': '#8e1c20', 'w': '#ffffff', 'R': '#ff3a4a', 'r': '#b81a2a',
     'p': '#ff8fae', 'G': '#3faa3a', 'g': '#2a7a2a', 'y': '#ffd23f', 'o': '#ff8a1f', 's': '#1a1418', 'm': '#5a0d12', 't': '#ff9fb5', 'a': '#3a3a44', 'A': '#6a6a78'}
M = {}
M['Eyebrow raise'] = face([(3, 8, 'kkk'), (4, 7, 'k'), (4, 11, 'k'), (5, 3, 'kkk'), (6, 4, 'kk'), (6, 9, 'kk'), (10, 5, 'kkkk'), (9, 9, 'k')])
M['Smirk'] = face([(5, 3, 'SSS'), (5, 8, 'SSS'), (6, 4, 'kk'), (6, 9, 'kk'), (10, 4, 'kkk'), (9, 7, 'kkk'), (8, 10, 'k')])
M['Heart eyes'] = face([(5, 3, 'R R'.replace(' ', 'F')), (5, 3, 'R'), (5, 5, 'R'), (6, 3, 'RRR'), (7, 4, 'R'), (5, 8, 'R'), (5, 10, 'R'), (6, 8, 'RRR'), (7, 9, 'R'),
                        (9, 4, 'k'), (10, 5, 'kmmmk'), (9, 10, 'k'), (11, 6, 'kkk')])
M['Wink'] = face([(6, 3, 'kkk'), (5, 9, 'kk'), (6, 9, 'kk'), (9, 4, 'k'), (10, 5, 'kkkkk'), (9, 10, 'k'), (11, 8, 'tt'), (0, 13, 'w'), (1, 12, 'www'), (2, 13, 'w')])
M['Kiss lips'] = ['................', '................', '................', '................',
  '...kkk....kkk...', '..kRRRk..kRRRk..', '.kRhRRRkkRRRRRk.', 'kRRRRRRRRRRRRRRk', 'krkkkkkkkkkkkkrk',
  '.kRRRRRRRRRRRRk.', '..kRhRRRRRRRRk..', '...krRRRRRRrk...', '....kkkkkkkk....', '................', '................', '................']
M['Rose'] = ['.....kkkkk......', '....kRrRRRk.....', '...kRRkrRRRk....', '...kRrRRkRRk....', '...kRRrrRRrk....', '....krRRRrk.....',
  '.....kkGkk......', '...kk.kGk.......', '..kGGkkGk.......', '...kkgGGk.......', '......kGk.kk....', '......kGkkGGk...',
  '......kGGgkk....', '......kGk.......', '......kGk.......', '.......k........']
M['Heart on fire'] = ['..y....o....y...', '..oy..yoy..yo...', '.yoo.yooy.yooy..', '.yoooyoooyoooy..',
  '..kkkk....kkkk..', '.kRRRRk..kRRRRk.', 'kRhhRRRkkRRRRRRk', 'kRhRRRRRRRRRRRRk', 'kRRRRRRRRRRRRRRk', '.kRRRRRRRRRRRRk.',
  '..kRRRRRRRRRRk..', '...krRRRRRRrk...', '....krRRRRrk....', '.....krRRrk.....', '......krrk......', '.......kk.......']
M['Got her number'] = ['....kkkkkkkk....', '...kaAAAAAAak...', '...kAssssssAk...', '...kAsRRsRRsk...', '...kAsRRRRRsk...', '...kAsRRRRRsk...',
  '...kAssRRRssk...', '...kAsssRsssk...', '...kAssssssAk...', '...kAswwwwsAk...', '...kAsssssssk...', '...kAswwwssAk...',
  '...kAssssssAk...', '...kAAAAAAAAk...', '...kaAAkkAAak...', '....kkkkkkkk....']
for n in M:
    M[n] = [r[:16].ljust(16, '.') for r in M[n]]; assert len(M[n]) == 16, n
    assert all(c == '.' or c in P for r in M[n] for c in r), n
if __name__ == '__main__':
    K, cols = 8, 4; cw, ch = 16 * K + 60, 16 * K + 64
    img = Image.new('RGB', (cols * cw + 20, 2 * ch + 20), '#1a2018'); d = ImageDraw.Draw(img)
    font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 15)
    for i, (n, r) in enumerate(M.items()):
        ox = 40 + (i % cols) * cw; oy = 20 + (i // cols) * ch
        for y, row in enumerate(r):
            for x, c in enumerate(row):
                if c != '.': d.rectangle([ox + x * K, oy + y * K, ox + x * K + K - 1, oy + y * K + K - 1], fill=hx(P[c]))
        label = f'{chr(65 + i)}. {n}'; w = d.textlength(label, font=font)
        d.text((ox + 8 * K - w / 2, oy + 16 * K + 14), label, fill='#e8f0e4', font=font)
    img.save(sys.argv[1]); json.dump({'p': P, 'icons': M}, open(sys.argv[2], 'w'))
