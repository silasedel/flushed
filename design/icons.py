import json, sys
from PIL import Image, ImageDraw

ICONS = {
 # NPC: the blank gray background-character face
 'icoNPC': ({'k': '#1e2430', 'h': '#ffffff', 'L': '#dfe5ee', 'M': '#b3becc', 'D': '#7c8798', 'e': '#1e2430', 'q': '#5d6879'}, [
  '................',
  '.....kkkkkk.....',
  '...kkLLLLLLkk...',
  '..kLhhLLLLLLMk..',
  '..kLhLLLLLLLMk..',
  '.kLLLLLLLLLLMMk.',
  '.kLLLeeLLeeLLMk.',
  '.kLLLeeLLeeLLMk.',
  '.kLLLLLLLLLLLMk.',
  '.kMLLLLLLLLLMMk.',
  '.kMLLLqqqqLLMDk.',
  '..kMLLLLLLLMDk..',
  '..kDMMLLLMMMDk..',
  '...kkDMMMMDkk...',
  '.....kkkkkk.....',
  '................',
 ]),
 # Mid: a mint toilet-paper roll with the sheet hanging off
 'icoMid': ({'k': '#143024', 'L': '#d4fbe6', 'M': '#7fe3b0', 'D': '#3f9c72', 'h': '#ffffff', 's': '#2c6b50', 'S': '#1f4d39'}, [
  '................',
  '................',
  '................',
  '.....kkkk.......',
  '....kLLhLkkkkkk.',
  '...kLLLLLLLLLLLk',
  '..kLLMMMMkkkkkk.',
  'kkLMMMMMMMMMk...',
  'SsLMMMMMkkkMDk..',
  'SsLMMMMMMMMMDk..',
  'SsLMMMMMkkkMDk..',
  'SsLMMMMMMMMMDk..',
  'kkMMMMMMkkkDDk..',
  '..kDMMMMMMDDk...',
  '...kkkkkkkkk....',
  '................',
 ]),
 # Rizz: a rat in shades with a pink lens glare
 'icoRizz': ({'k': '#2a0709', 'H': '#4a0f14', 'h': '#8a2530', 'L': '#ff8a7a', 'R': '#ff4d4d', 'D': '#c3262c', 'd': '#7d1218', 'e': '#2a0709', 'w': '#ffd3cc'}, [
  '....kkkkkk......',
  '..kkHHHhhhkk....',
  '.kHHHhhHHHHHk...',
  'kHHhHHHHHHHHHk..',
  'kHHHHHHHkkkkkk..',
  'kHHkkLLLLLLLLk..',
  'kHkDLLLkkkkkLk..',
  'kHkdLLLLLwekLk..',
  'kkDDLLLLLLLLLLk.',
  '.kRDLLLLLLLLLLLk',
  '.kRRLLLLLLLLkkk.',
  '.kDRRLLLLLLLLk..',
  '.kDRRRLLLkkkkLLk',
  '.kdDRRRRRRRRRRRk',
  '..kdDDDRRRRRRDDk',
  '...kkkkkkkkkkkk.',
 ]),
 # Aura: a purple aura flame with a white-hot core
 'icoAura': ({'k': '#22103d', 'P': '#b77dff', 'L': '#ddbbff', 'W': '#fff4ff', 'D': '#6d34bf', 'x': '#f2dcff'}, [
  '.......k.....x..',
  '......kPk.......',
  '......kPPk..k...',
  '.x...kPLPk.kPk..',
  '....kPLLPPkPPk..',
  '...kPLLLLPPPPk..',
  '..kPPLLWLLPPPPk.',
  '..kPLLWWWLLPDPk.',
  '.kPPLWWWWWLLPDk.',
  '.kPLLWWWWWWLPDk.',
  '.kPLWWWWWWWLPDk.',
  '.kPLWWWWWWWLPDk.',
  '..kPLWWWWWLPDk..',
  '..kDPLLLLLPDDk..',
  '...kkDDDDDDkk...',
  '.....kkkkkk.....',
 ]),
 # Sigma: the golden throne, crowned
 'icoSigma': ({'k': '#3a2508', 'y': '#fff3b0', 'Y': '#f3cd66', 'G': '#e0aa3a', 'D': '#a8761c', 'x': '#fffbe0'}, [
  'x.............x.',
  '.kkkkkkkkkkkkkk.',
  '.kyyyyyyyyyyyyk.',
  '.kYYYYYYYYYYYYk.',
  '.kGYYkkkkkkkGGk.',
  '.kkYYYk.....kk..',
  '..kkYYYk........',
  '...kkYYYk.......',
  '....kGYYk.......',
  '...kGYYkk.......',
  '..kGYYkk........',
  '.kGYYkk.....kk..',
  '.kGYYkkkkkkkGGk.',
  '.kGGGGGGGGGGGGk.',
  '.kDDDDDDDDDDDDk.',
  '.kkkkkkkkkkkkkk.',
 ]),
}

def hx(c): c = c.lstrip('#'); return tuple(int(c[i:i+2], 16) for i in (0, 2, 4))

if __name__ == '__main__':
    out = sys.argv[1]
    for n, (p, r) in ICONS.items():
        assert all(len(x) == 16 for x in r), (n, [len(x) for x in r])
        assert all(ch == '.' or ch in p for x in r for ch in x), n
    K = 12; pad = 24
    img = Image.new('RGB', (len(ICONS) * (16 * K + pad) + pad, 16 * K + pad * 2 + 80), '#1a2018')
    d = ImageDraw.Draw(img)
    for i, (n, (p, r)) in enumerate(ICONS.items()):
        ox = pad + i * (16 * K + pad)
        for y, row in enumerate(r):
            for x, ch in enumerate(row):
                if ch != '.': d.rectangle([ox + x * K, pad + y * K, ox + x * K + K - 1, pad + y * K + K - 1], fill=hx(p[ch]))
        # small 3x versions underneath to judge readability at real size
        for y, row in enumerate(r):
            for x, ch in enumerate(row):
                if ch != '.': d.rectangle([ox + x * 3, pad * 2 + 16 * K + y * 3, ox + x * 3 + 2, pad * 2 + 16 * K + y * 3 + 2], fill=hx(p[ch]))
    img.save(out)
    if len(sys.argv) > 2:
        open(sys.argv[2], 'w').write(json.dumps({n: {'p': p, 'r': r} for n, (p, r) in ICONS.items()}))
