import sys, json
sys.path.insert(0, sys.path[0])
from options import face, hx
from PIL import Image, ImageDraw, ImageFont
P = {'k': '#0c2238', 'F': '#6fc8ff', 'h': '#d6f0ff', 'S': '#3f9ae0', 'D': '#2a6aa8', 'B': '#6fc8ff', 'b': '#bfe7ff', 'w': '#ffffff', 'e': '#0c2238', 'g': '#33485c', 'm': '#0c2238', 'y': '#ffe27a'}
M = {}
M['Battery 50%'] = [
 '................','................','................','.kkkkkkkkkkkkk..','.kbwwwwwwwwwwk..','.kbBBBBBggggbkkk',
 '.kbBBBBBggggbkbk','.kbBeeBBgeegbkbk','.kbBBBBBggggbkbk','.kbBBeeeeeegbkbk','.kbBBBBBggggbkkk','.kbSSSSSggggbk..',
 '.kbbbbbbbbbbbk..','.kkkkkkkkkkkkk..','................','................']
M['Meh face'] = face([(5, 3, 'DDD'), (5, 8, 'DDD'), (6, 3, 'kkk'), (6, 8, 'kkk'), (10, 5, 'kkkkk')])
M['5/10 card'] = ['................', 'kkkkkkkkkkkkkkkk', 'kwwwwwwwwwwwwwwk', 'kwbbbbbbbbbbbbwk', 'kwwwwwwwwwwwwwwk', 'kwkkkwwkwkwkkkwk', 'kwkwwwwkwkwkwkwk', 'kwkkkwkwwkwkwkwk', 'kwwwkwkwwkwkwkwk', 'kwkkkwkwwkwkkkwk', 'kwwwwwwwwwwwwwwk', 'kwbbbbbbbwwwwwwk', 'kwwwwwwwwwwwwwwk', 'kSSSSSSSSSSSSSSk', 'kkkkkkkkkkkkkkkk', '................']
M['Lukewarm glass'] = [
 '................','..kkkkkkkkkkkk..','..kwhwwwwwwwwk..','..kwhwwwwwwwwk..','..kwhwwwwwwwwk..','..kwhwwwwwwwwk..',
 '..kwhbwbbwbbwk..','..kbBBbBBbBBBk..','...kBBBBBBBBk...','...kBhBBBBBBk...','...kBhBBBBBSk...','...kBBBBBBBSk...',
 '...kSBBBBBBSk...','...kwSSSSSSwk...','...kkkkkkkkkk...','................']
M['Yawn face'] = face([(6, 3, 'kkk'), (6, 8, 'kkk'), (8, 6, 'kkk'), (9, 5, 'kmmmk'), (10, 5, 'kmmmk'), (11, 6, 'kkk'), (1, 13, 'z'), (0, 14, 'zz')])
M['Shrug face'] = face([(4, 3, 'k'), (4, 6, 'k'), (4, 8, 'k'), (4, 11, 'k'), (5, 4, 'kk'), (5, 9, 'kk'), (6, 4, 'kk'), (6, 9, 'kk'), (9, 5, 'k'), (10, 6, 'kkk'), (9, 9, 'k'),
                        (8, 0, 'kk'), (7, 0, 'k'), (8, 14, 'kk'), (7, 15, 'k')])
M['Loading 50%'] = [
 '................','................','................','................','.kkkkkkkkkkkkkk.','kbwwwwwwwwwwwwwk',
 'kbBBBBBBgggggggk','kbBhBhBBgggggggk','kbBBBBBBgggggggk','kbSSSSSSgggggggk','.kkkkkkkkkkkkkk.','................',
 '...k.k..k..k....','................','................','................']
M['Participation trophy'] = [
 '................','..kkkkkkkkkkkk..','.kBkbbBBBBBBkBk.','kBkkbBBBBBBBkkBk','kBk.kbBBBBBk.kBk','.kk.kbBBBBBk.kk.',
 '....kbBBBBSk....','.....kBBBSk.....','......kBSk......','......kBSk......','.....kkBSkk.....','....kwwwwwwk....',
 '....kgkgkgkk....','....kwwwwwwk....','...kkkkkkkkkk...','................']
for n in M:
    M[n] = [r[:16].ljust(16, '.') for r in M[n]]
    assert len(M[n]) == 16, n
P['z'] = '#bfe7ff'
if __name__ == '__main__':
    K, cols = 8, 4
    cw, ch = 16 * K + 60, 16 * K + 64
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
