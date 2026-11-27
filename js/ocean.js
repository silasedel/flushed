// Krillion — pixel-art ocean renderer.
// Everything is drawn into a low-resolution canvas and scaled up with nearest-neighbour.
// World coordinates are in meters below the surface (negative = sky).
(function () {
  'use strict';

  // ---------- helpers ----------
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  function hash(n) { // deterministic 0..1
    n = (n | 0) * 374761393 + 668265263; n = (n ^ (n >>> 13)) * 1274126177; n = n ^ (n >>> 16);
    return ((n >>> 0) % 100000) / 100000;
  }
  function hex(h) { const n = parseInt(h.slice(1), 16); return [n >> 16, (n >> 8) & 255, n & 255]; }
  const rgb = (c, a) => a === undefined ? `rgb(${c[0] | 0},${c[1] | 0},${c[2] | 0})` : `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${a})`;
  const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];

  // ---------- zones ----------
  const WATER = [
    [0, '#6fb3bf'], [120, '#4f8f9b'], [200, '#3f6b74'], [500, '#34555b'], [1000, '#2b3f31'],
    [2500, '#203022'], [4000, '#25183a'], [5000, '#1b1130'], [6000, '#200a26'], [7200, '#15041a'],
  ].map(([m, h]) => [m, hex(h)]);
  function waterColor(m) {
    if (m <= WATER[0][0]) return WATER[0][1];
    for (let i = 1; i < WATER.length; i++) {
      if (m <= WATER[i][0]) { const [m0, c0] = WATER[i - 1], [m1, c1] = WATER[i]; return mix(c0, c1, (m - m0) / (m1 - m0)); }
    }
    return WATER[WATER.length - 1][1];
  }
  const ZONES = [
    { name: 'Bowl', from: 0, to: 200 },
    { name: 'Pipes', from: 200, to: 1000 },
    { name: 'Sewer', from: 1000, to: 4000 },
    { name: 'Rat Kingdom', from: 4000, to: 6000 },
    { name: 'Brainrot Core', from: 6000, to: 99999 },
  ];
  const zoneIndex = m => m < 200 ? 0 : m < 1000 ? 1 : m < 4000 ? 2 : m < 6000 ? 3 : 4;
  // The shrimp's 0 m sits OFF meters below the drawn surface so the dive screen starts underwater.
  let OFF = 275; const dz = m => m - OFF;

  // ---------- sprites ----------
  // Each sprite: rows of chars, palette maps char -> color. '.' is transparent.
  const SPR = {
    // tier icons (16x16, outlined)
    icoSkibidi: { p: {'k': '#1c0a30', 'W': '#c58bff', 'w': '#a868f0', 'h': '#ead6ff', 'S': '#7a3fd0', 'd': '#4a2280', 'D': '#2e1258', 'H': '#241812', 'F': '#e6b088', 'f': '#b47a52', 'E': '#ffffff', 'e': '#4a8ad0', 'p': '#0a1a2a', 'm': '#2a0a0a', 'y': '#efe08a'}, r: [
      '......kWWWWWWWWWWWWWWWWWWk......',
      '.....kWWhhhhhHHHHHHhhhhhWWk.....',
      '....kWWwwHHHHHHHHHHHHHHHwWWk....',
      '....kWWwwHHHHHHHHHHHHHHHwWWk....',
      '....kWWwwHHHHHHHHHHHHHHHwWWk....',
      '....kWWwwHHHHHHHHHHHHHFHwWWk....',
      '....kWWwwFffffffFffffffwwWWk....',
      '....kWWwwFfEEEEfFfEEEEfwwWWk....',
      '....kWWwfFFEpeEFFFEpeEFwfWWk....',
      '....kWWwfFFEeeEFfFEeeEFFfWWk....',
      '....kWWwfFFEEEEFfFEEEEFwfWWk....',
      '....kWWwfFFFFFFFfFFFFFFwfWWk....',
      '....kWWwwFmFFFFFfFFFFFmwwWWk....',
      '....kWWwwFmmmmmmmmmmmmmwwWWk....',
      '....kWWwwWFmyyyyyyyyyymwwWWk....',
      '.....kWWWWWFmmyyyyyyymmWWWk.....',
      '...kkWWWWddDFFmmmmmmmddWWWWkk...',
      '..kWWWWdDDDDDFFFFFFfDDDDdWWWWk..',
      '.kWWWdDDDDDDDfFFffffDDDDDDdWWWk.',
      'kWWWdDDDDDDDDfFFffffDDDDDDDdWWWk',
      'kWWWdDDDDDDDDfFFffffDDDDDDDdWWWk',
      'kWWddDDDDDDDDfFFffffDDDDDDDddWWk',
      'WWWWddDDDDDDDfFFffffDDDDDDddWWWW',
      'kWWWddddDDDDDfFFffffDDDDddddWWWk',
      'kWWWWddddddDDfFFffffDddddddWWWWk',
      'kWWWWWWddddddfffffffdddddWWWWWWk',
      '.kWWWWWWWddddddddddddddWWWWWWWk.',
      '..kWWWWWWWWWWWWWWWWWWWWWWWWWWk..',
      '...kkSWWWWWWWWWWWWWWWWWWWWSkk...',
      '.....kkSSSWWWWWWWWWWWWSSSkk.....',
      '.......kkkkSSSSSSSSSSkkkk.......',
      '...........kkkkkkkkkk...........',
    ] },
    icoNPC: { p: {'k': '#1e2430', 'h': '#ffffff', 'L': '#dfe5ee', 'M': '#b3becc', 'D': '#7c8798', 'e': '#1e2430', 'q': '#5d6879'}, r: [
      '................................',
      '................................',
      '..........kkkkkkkkkkkk..........',
      '..........kkkkkkkkkkkk..........',
      '......kkkkLLLLLLLLLLLLkkkk......',
      '......kkkkLLLLLLLLLLLLkkkk......',
      '....kkLLhhhhLLLLLLLLLLLLMMkk....',
      '....kkLLhhhhLLLLLLLLLLLLMMkk....',
      '....kkLLhhLLLLLLLLLLLLLLMMkk....',
      '....kkLLhhLLLLLLLLLLLLLLMMkk....',
      '..kkLLLLLLLLLLLLLLLLLLLLMMMMkk..',
      '..kkLLLLLLLLLLLLLLLLLLLLMMMMkk..',
      '..kkLLLLLLeeeeLLLLeeeeLLLLMMkk..',
      '..kkLLLLLLeeeeLLLLeeeeLLLLMMkk..',
      '..kkLLLLLLeeeeLLLLeeeeLLLLMMkk..',
      '..kkLLLLLLeeeeLLLLeeeeLLLLMMkk..',
      '..kkLLLLLLLLLLLLLLLLLLLLLLMMkk..',
      '..kkLLLLLLLLLLLLLLLLLLLLLLMMkk..',
      '..kkMMLLLLLLLLLLLLLLLLLLMMMMkk..',
      '..kkMMLLLLLLLLLLLLLLLLLLMMMMkk..',
      '..kkMMLLLLLLqqqqqqqqLLLLMMDDkk..',
      '..kkMMLLLLLLqqqqqqqqLLLLMMDDkk..',
      '....kkMMLLLLLLLLLLLLLLMMDDkk....',
      '....kkMMLLLLLLLLLLLLLLMMDDkk....',
      '....kkDDMMMMLLLLLLMMMMMMDDkk....',
      '....kkDDMMMMLLLLLLMMMMMMDDkk....',
      '......kkkkDDMMMMMMMMDDkkkk......',
      '......kkkkDDMMMMMMMMDDkkkk......',
      '..........kkkkkkkkkkkk..........',
      '..........kkkkkkkkkkkk..........',
      '................................',
      '................................',
    ] },
    icoMid: { p: {'h': '#d6f0ff', 'S': '#3f9ae0', 'F': '#6fc8ff', 'D': '#2a6aa8', 'k': '#0c2238'}, r: [
      '................................',
      '................................',
      '..........kkkkkkkkkkkk..........',
      '..........kkkkkkkkkkkk..........',
      '......kkkkFFFFFFFFFFFFkkkk......',
      '......kkkkFFFFFFFFFFFFkkkk......',
      '....kkFFhhhhFFFFFFFFFFFFSSkk....',
      '....kkFFhhhhFFFFFFFFFFFFSSkk....',
      '....kkFFhhFFFFFFFFFFFFFFSSkk....',
      '....kkFFhhFFFFFFFFFFFFFFSSkk....',
      '..kkFFDDDDDDFFFFDDDDDDFFFFSSkk..',
      '..kkFFDDDDDDFFFFDDDDDDFFFFSSkk..',
      '..kkFFkkkkkkFFFFkkkkkkFFFFSSkk..',
      '..kkFFkkkkkkFFFFkkkkkkFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkSSFFFFkkkkkkkkkkFFFFSSSSkk..',
      '..kkSSFFFFkkkkkkkkkkFFFFSSSSkk..',
      '....kkSSFFFFFFFFFFFFFFSSSSkk....',
      '....kkSSFFFFFFFFFFFFFFSSSSkk....',
      '....kkSSSSFFFFFFFFFFSSSSDDkk....',
      '....kkSSSSFFFFFFFFFFSSSSDDkk....',
      '......kkkkSSSSSSSSSSSSkkkk......',
      '......kkkkSSSSSSSSSSSSkkkk......',
      '..........kkkkkkkkkkkk..........',
      '..........kkkkkkkkkkkk..........',
      '................................',
      '................................',
    ] },
    icoRizz: { p: {'D': '#8e1c20', 'h': '#ffc0b8', 'F': '#ff5a5a', 'k': '#2a0709', 'S': '#d23a3a'}, r: [
      '................................',
      '................................',
      '..........kkkkkkkkkkkk..........',
      '..........kkkkkkkkkkkk..........',
      '......kkkkFFFFFFFFFFFFkkkk......',
      '......kkkkFFFFFFFFFFFFkkkk......',
      '....kkFFhhhhFFFFkkkkkkFFSSkk....',
      '....kkFFhhhhFFFFkkkkkkFFSSkk....',
      '....kkFFhhFFFFkkFFFFFFkkSSkk....',
      '....kkFFhhFFFFkkFFFFFFkkSSkk....',
      '..kkFFkkkkkkFFFFFFFFFFFFFFSSkk..',
      '..kkFFkkkkkkFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFkkkkFFFFFFkkkkFFFFSSkk..',
      '..kkFFFFkkkkFFFFFFkkkkFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFFFFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFkkFFFFFFSSkk..',
      '..kkFFFFFFFFFFFFFFkkFFFFFFSSkk..',
      '..kkSSFFFFkkkkkkkkFFFFFFSSSSkk..',
      '..kkSSFFFFkkkkkkkkFFFFFFSSSSkk..',
      '....kkSSFFFFFFFFFFFFFFSSSSkk....',
      '....kkSSFFFFFFFFFFFFFFSSSSkk....',
      '....kkSSSSFFFFFFFFFFSSSSDDkk....',
      '....kkSSSSFFFFFFFFFFSSSSDDkk....',
      '......kkkkSSSSSSSSSSSSkkkk......',
      '......kkkkSSSSSSSSSSSSkkkk......',
      '..........kkkkkkkkkkkk..........',
      '..........kkkkkkkkkkkk..........',
      '................................',
      '................................',
    ] },
    icoAura: { p: {'k': '#22103d', 'P': '#b77dff', 'L': '#ddbbff', 'W': '#fff4ff', 'D': '#6d34bf', 'x': '#f2dcff'}, r: [
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
    ] },
    icoSigma: { p: {'a': '#3a2405', 'b': '#6e4a10', 'c': '#9a6c16', 'd': '#c8961e', 'e': '#e8b830', 'f': '#f8d458', 'g': '#ffec98', 'h': '#fffbe0', 'k': '#1e1203'}, r: [
      '............kkkkkk..............',
      '..........kkcabaackkk...........',
      '.........kbbceaebcaaakk.........',
      '........kabbccdaaaaaaaak........',
      '.......kbaaccbceccbaaaak........',
      '......kabcccbeffdddddegck.......',
      '......kaccbacffffddddcegck......',
      '......kbbbbbedfeecccbcdfek......',
      '.....kbbabcccfffededcedfgk......',
      '.....kaabccegffbbbbbbeeegk......',
      '.....kaacbcgfebbfeaaabbbbk......',
      '.....kcbbadgeedcaaaacbdaaak.....',
      '.....kcgfaffefdcdcaachdaaak.....',
      '.....kfehcfffeedcaaadgdaack.....',
      '.....kbbgbdfefffdcbbfgdcddk.....',
      '.....kaggcbffeedbbabeggdaek.....',
      '.....kcdgbcdeebeebbcfggcek......',
      '......kffaebcccgaababcddbk......',
      '......kedbecbbbdaccbbbedbk......',
      '......kdceccdaaeahhhaaacdk......',
      '......kecdebbaadaahhhhhadk......',
      '......kfccdbbaacaadaaaacbk......',
      '......kgcccbbaacaaaaabdcck......',
      '......kfgabbbaadaaaabbgbek......',
      '.....keffgcabaacaaaaabebk.......',
      '.....kdfffgfbaaccaaaaabbk.......',
      '.....kefffeffcaaddbbabcek.......',
      '......kfffeeedcaabbababck.......',
      '.......kfefeefecaaaaaabck.......',
      '........keefffdbbbcbabkk........',
      '.........kkefedcekkkkk..........',
      '...........kkkkkk...............',
    ] },
    fatberg: { p: { s: 'S' }, r: [
      '......ssss..sss.........',
      '...sssssssssssssss......',
      '.sssssssssssssssssssss..',
      'ssssssssssssssssssssssss',
      'ssssssssssssssssssssssss',
      '.ssssssssssssssssssssss.',
      '...sssss..ssssssss.sss..',
    ] },
    sock: { p: { w: '#eef2f6', r: '#e6554e', g: '#b7c0c9' }, r: [
      'wwwww...',
      'rrrrr...',
      'wwwww...',
      'rrrrr...',
      'wwwww...',
      'wwwwwww.',
      'wwwwwwww',
      '.gggggg.',
    ] },
    airpod: { p: { w: '#f5f7fa', g: '#c4cbd3', k: '#5a6470' }, r: [
      '.www.',
      'wwwkw',
      'wwwww',
      '.wwg.',
      '..wg.',
      '..wg.',
      '..wg.',
      '..gg.',
    ] },
    toothbrush: { p: { b: '#3fb3ff', w: '#ffffff', B: '#1f7fcc' }, r: [
      '..........wwww',
      'bbbbbbbbbbbBBB',
      '.BBBBBBBBBB...',
    ] },
    soap: { p: { p: '#ff9fc4', P: '#ffd0e3', d: '#d96b98' }, r: [
      '.pppppppp.',
      'pPPPPppppp',
      'pPpppppppp',
      'pppppppppd',
      '.dddddddd.',
    ] },
    auraBlob: { p: { G: '#c58bff', g: '#7a3fd0', k: '#1a0b2a', m: '#1a0b2a' }, r: [
      '....gggg....',
      '..gGGGGGGg..',
      '.gGGkGGkGGg.',
      '.gGGGGGGGGg.',
      'gGGGGGGGGGGg',
      'gGGGGmmGGGGg',
      'gGGGGGGGGGGg',
      '.gGGGGGGGGg.',
      'g.gg.gg.gg.g',
    ] },
    sludge: { p: { G: '#7dff6a', g: '#3faa3a', k: '#0b1a0b', m: '#0b1a0b' }, r: [
      '....gggg....',
      '..gGGGGGGg..',
      '.gGGkGGkGGg.',
      '.gGGGGGGGGg.',
      'gGGGGGGGGGGg',
      'gGGGGmmGGGGg',
      'gGGGGGGGGGGg',
      '.gGGGGGGGGg.',
      'g.gg.gg.gg.g',
    ] },
    ratking: { p: { g: '#8b8f9c', G: '#a7abb7', k: '#ff3355', p: '#ffa3b8', t: '#ff9fb5', n: '#ff7f9c', c: '#ffd54a', C: '#ff3355' }, r: [
      '.c.c.c..........',
      '.cCcCc..........',
      '.ccccc..........',
      '..pp............',
      '.pggg...........',
      'ngkggggg........',
      'gggggggggg......',
      '.gGGGGGgggg.....',
      '..ggggggggg.....',
      '..g.g...g.g.ttt.',
      '...........t...t',
      '............ttt.',
    ] },
    rat: { p: { g: '#8b8f9c', G: '#a7abb7', k: '#ff3355', p: '#ffa3b8', t: '#ff9fb5', n: '#ff7f9c' }, r: [
      '..pp............',
      '.pggg...........',
      'ngkggggg........',
      'gggggggggg......',
      '.gGGGGGgggg.....',
      '..ggggggggg.....',
      '..g.g...g.g.ttt.',
      '...........t...t',
      '............ttt.',
    ] },
    tproll: { p: { o: '#aeb8c2', W: '#f4f7fa', g: '#7d8894', c: '#5a6470' }, r: [
      '...oooooooo.',
      '..oWWWWWWWWo',
      '.oWWWWggWWWo',
      '.oWWWgccgWWo',
      '.oWWWgccgWWo',
      '.oWWWWggWWWo',
      '.oWWWWWWWWWo',
      '.oWWWWWWWWWo',
      '.oWWWWWWWWWo',
      '.oWWWWWWWWWo',
      '..oWWWWWWWWo',
      '...ooooooWWo',
      '.........oWo',
      '..........o.',
    ] },
    goldtoilet: { p: { T: '#f3cd66', t: '#fff0a8', S: '#b8862a', w: '#ffe08a' }, r: [
      '..TTTTTTTTTTTT..',
      '..TttttttttttT..',
      '..TttttttttttT..',
      '..TTTTTTTTTTTT..',
      '.....TttttT.....',
      '.SSSSSSSSSSSSSS.',
      'STTTTTTTTTTTTTTS',
      'STttttttttttttTS',
      '.STttttwwtttttS.',
      '..STttttttttTS..',
      '...STTTTTTTTS...',
      '....STttttTS....',
      '....STttttTS....',
      '...SSTTTTTTSS...',
      '..SSSSSSSSSSSS..',
    ] },
    toilet: { p: { T: '#e4ebf1', t: '#ffffff', S: '#8d9aa7', w: '#9fd6e0' }, r: [
      '..TTTTTTTTTTTT..',
      '..TttttttttttT..',
      '..TttttttttttT..',
      '..TTTTTTTTTTTT..',
      '.....TttttT.....',
      '.SSSSSSSSSSSSSS.',
      'STTTTTTTTTTTTTTS',
      'STttttttttttttTS',
      '.STttttwwtttttS.',
      '..STttttttttTS..',
      '...STTTTTTTTS...',
      '....STttttTS....',
      '....STttttTS....',
      '...SSTTTTTTSS...',
      '..SSSSSSSSSSSS..',
    ] },
    duck1: { p: { y: '#ffd23f', h: '#fff2a6', k: '#141414', o: '#ff8a1f', d: '#d99a10' }, r: [
      '.....yyyy.......',
      '....yyyyyy......',
      '....yhykyyoo....',
      '....yyyyyyooo...',
      '.....yyyyyy.....',
      '......yyyy......',
      '.yy..yyyyyyyy...',
      'yyyyyyhhhyyyyy..',
      'yyyyyhhyyyyyyyy.',
      'yyyyyyyyyyyyyyy.',
      '.yyyyyyyyyyyyyd.',
      '..dyyyyyyyyyyd..',
      '...dddddddddd...',
    ] },
    duck0: { p: { y: '#ffd23f', h: '#fff2a6', k: '#141414', o: '#ff8a1f', d: '#d99a10' }, r: [
      '.....yyyy.......',
      '....yyyyyy......',
      '....yhykyyoo....',
      '....yyyyyyooo...',
      '.....yyyyyy.....',
      '.y....yyyy......',
      'yyy..yyyyyyyy...',
      'yyyyyyhhhyyyyy..',
      'yyyyyhhyyyyyyyy.',
      'yyyyyyyyyyyyyyy.',
      '.yyyyyyyyyyyyyd.',
      '..dyyyyyyyyyyd..',
      '...dddddddddd...',
    ] },
    shrimp0: { p: { R: '#e8463c', H: '#ff8f73', D: '#a3262a', K: '#1a0b0b', A: '#ffb29c', L: '#c9372f', T: '#ff6a55' }, r: [
      '...........A..A.',
      '..........A..A..',
      '.....RRRRRRA.A..',
      '...RRHHHHHRRA...',
      '..RHRRRRRRRRRR..',
      'TRRDRRDRRDRRKRR.',
      'TTRRRRRRRRRRRRRR',
      'T..DRRDRRDRRRR..',
      '....L.L.L.L.L...',
      '...L.L.L.L.L....',
    ] },
    shrimp1: { p: { R: '#e8463c', H: '#ff8f73', D: '#a3262a', K: '#1a0b0b', A: '#ffb29c', L: '#c9372f', T: '#ff6a55' }, r: [
      '...........A...A',
      '..........A..A..',
      '.....RRRRRRA.A..',
      '...RRHHHHHRRA...',
      '..RHRRRRRRRRRR..',
      'TRRDRRDRRDRRKRR.',
      'TTRRRRRRRRRRRRRR',
      'T..DRRDRRDRRRR..',
      '...L.L.L.L.L....',
      '....L.L.L.L.L...',
    ] },
    boat: { p: { F: '#f0607a', N: '#121a2c', W: '#8fbfd0' }, r: [
      '...........FN...............',
      '.........FFFN...............',
      '.......FFFFFN...............',
      '........FFFFN...............',
      '............N...............',
      '............N...............',
      '............N...............',
      '............N...............',
      '............N...............',
      '.........NNNNNNNNN..........',
      '..........NWNNNNNN..........',
      '..........NWNNNNNN....NNNN..',
      '.NN.......NNNNNNNNNNNNNN....',
      'NNNNNNNNNNNNNNNNNNNNNNNN....',
      'NNNNNNNNNNNNNNNNNNNNNNN.....',
      '.NNNNNNNNNNNNNNNNNNNNN......',
    ] },
    fish: { p: { a: '#8a4b14', b: '#ffc94a', c: '#fff1b8', d: '#f08a24', k: '#1a1206' }, r: [
      '.....aaa.....',
      '...aabbbaa..a',
      '..abkbbbbbaaa',
      '.abbbbbbdbbda',
      '.accccbbdbbda',
      '..acccbbbaaaa',
      '...aaaaaa...a',
    ] },
    fish2: { p: { a: '#7eeaf5', b: '#3cc8dc', c: '#bdf6fb', d: '#1d7d92', k: '#08202a' }, r: [
      '......dd.........',
      '.....dbbd........',
      '...dddbbbdd...dd.',
      '..dbbbbbbbbd.dbbd',
      '.dbaaaaabbbbdbbd.',
      'dbakaaaaabbbbbd..',
      'dbaaaaaaabbbbbd..',
      '.dccccaabbbbdbbd.',
      '..dcccbbbbbd.dbbd',
      '...dddbbbdd...dd.',
      '.....dbbd........',
      '......dd.........',
    ] },
    silhouette: { p: { s: 'S' }, r: [
      '....ss.....',
      's..ssssss..',
      'ssssssssss.',
      'sssssssssss',
      'ssssssssss.',
      's..ssssss..',
      '....ss.....',
    ] },
    minifish: { p: { s: 'S' }, r: [
      '.sss..s',
      'sssssss',
      '.sss..s',
    ] },
    whale: { p: { s: 'S' }, r: [
      '.........ssssssss.........',
      '......ssssssssssssss......',
      '...ssssssssssssssssssss...',
      'ss.sssssssssssssssssssss..',
      'sssssssssssssssssssssssss.',
      'ss..ssssssssssssssssssssss',
      '......ssssssssssssssss....',
      '...........ss.....s.......',
    ] },
    hatchet: { p: { a: '#b8c7d9', b: '#7f93ab', g: '#7ff3ff' }, r: [
      '.aaa..',
      'baaaa.',
      'bagaa.',
      '.aaab.',
      '..ab..',
    ] },
    squid: { p: { r: '#e6554e', R: '#ff8a78', d: '#8f2a2a', k: '#2a0a0c' }, r: [
      '....r....',
      '...rRr...',
      '..rRRrr..',
      '..rRRrr..',
      '..rRrrd..',
      '..rrrrd..',
      '..rkrkd..',
      '...rrd...',
      '..r.r.r..',
      '.r..r..r.',
      '.r.r.r.r.',
      'r..r.r..r',
      'r.r...r.r',
    ] },
    jelly: { p: { a: '#ff8fd1', b: '#ffd6f0', c: '#c05aa0', d: '#e070b8', w: '#ffffff' }, r: [
      '..bbbb..',
      '.bwaaab.',
      'bwaaaadb',
      'baaaaadb',
      'dddddddd',
      'c.c.c.c.',
      '.c.c.c.c',
      'c.c.c.c.',
      '.c...c..',
    ] },
    jelly2: { p: { a: '#7ff3ff', b: '#d7fbff', c: '#3bb6c9' }, r: [
      '.bbbb.',
      'baaaab',
      'aaaaaa',
      'c.cc.c',
      'c.c..c',
      '.c.c..',
    ] },
    angler: { p: { b: '#3a4a66', B: '#4e6286', d: '#222c40', e: '#9fb6d6', M: '#0a0d18', T: '#e8eef5', s: '#6a7f9e', W: '#ffffff' }, r: [
      '.....sssss............',
      '....s.....s...........',
      '...s.......s....d.....',
      '..s.........s..dd.....',
      '.WW......BBBBBbbbd..dd',
      'WWWW...BBBBBebbbbbddd.',
      'WWWW..BBbbbbbbbbbbbdd.',
      '.WW..bMMMMMbbbbbbbbbd.',
      '.....bTMTMTMbbbbbbbbdd',
      '.....bMMMMMMbbbbbbbbbd',
      '.....bTMTMTMbbbbbbbbdd',
      '......bMMMMbbbbbbbd.d.',
      '.......bbbbbbbbbdd....',
      '.........ddddd........',
    ] },
    eel: { p: { a: '#3c2f4f', b: '#5a4775', g: '#ff6ad5' }, r: [
      'aaaa..........',
      'abbaa.........',
      'aaaabbaaa.....',
      '..aaaaabbaaaag',
    ] },
    vamp: { p: { a: '#6b1f2f', b: '#952b42', e: '#7ff3ff' }, r: [
      '..aaaa..',
      '.abbbba.',
      '.abeeba.',
      'aabbbbaa',
      'a.a..a.a',
      'a..aa..a',
    ] },
    worm: { p: { w: '#e9e2d0', r: '#e8463c' }, r: [
      'rr',
      'rr',
      'w.',
      'w.',
      '.w',
      '.w',
      'w.',
      'w.',
    ] },
    bubbles: { p: { o: '#9fc4dc', h: '#e6f4fc', i: '#33597a' }, r: [
      '...oooo.........',
      '.oo.iii.oo......',
      '.ohhiiiii.o.....',
      'ohhiiiiiiiio....',
      'ohiiiiiiiiio....',
      'oiiiiiiiiiio....',
      'oiiiiiiiiiio....',
      '.oiiiiiiiio.ooo.',
      '.ooiiiiiioo.o..o',
      '...oooo..ohhio..',
      '......ooo.oiio..',
      '.....ohho.ooo...',
      '.....oiio.......',
      '......ooo.......',
    ] },
    coral: { p: { r: '#e6554e', R: '#ff8a78', d: '#a3302f' }, r: [
      'R...R...r',
      'R..r.R..r',
      '.R.r.R.r.',
      '.R..r..r.',
      '..R.r.r..',
      '..Rrrrd..',
      '...Rrd...',
      '....r....',
      '....d....',
      '..Rrrrd..',
    ] },
    squidIcon: { p: { a: '#d6384a', R: '#e8454f', H: '#ff7a80', r: '#a52a35', k: '#3a0a10' }, r: [
      '.a...a.....a.',
      '.a....a...a..',
      'a.a...a..a..a',
      'a..a..a..a.a.',
      '.a.a.a...a.a.',
      '.a..aa..a..a.',
      '..a.a.a.a.a..',
      '..a..aaa.aa..',
      '...a.aaaaa...',
      '....aaaaa....',
      '....HRRRR....',
      '....HkRkR....',
      '....HRRRR....',
      '....HRRRR....',
      '...rHRRRRr...',
      '..rrHRRRRrr..',
      '...rHRRRRr...',
      '....HRRRR....',
      '....rRRRr....',
      '.....RRR.....',
      '......R......',
    ] },
    curl0: { p: { R: '#ec4b55', H: '#ff8a8a', r: '#b8323f', d: '#7a1e2a', k: '#1a0b0b', a: '#ef6a78', l: '#c43c4a' }, r: [
      '......aaaaa.....',
      '....aa.....aa...',
      '...a..aaaaa..a..',
      '..a..a.....a....',
      '.a..a...........',
      '.a.a..rrrrr.....',
      '..a.rRHRHRHr....',
      '...rRRHRHRHRr...',
      '..rkkRRHRHRHRr..',
      '.rRkkRRRRRRRRRr.',
      'rRRRRRRRRRRRRRr.',
      '.rr.lrRRRRRRRRRr',
      '....l.lrRRRRRRRr',
      '..rr.l.lrRRRRRr.',
      '.rRRr..rRRRRRr..',
      'rRRRRrrRRRRRr...',
      '.rRRRRRRRRrr....',
      '..rrrrrrrr......',
    ] },
    curl1: { p: { R: '#ec4b55', H: '#ff8a8a', r: '#b8323f', d: '#7a1e2a', k: '#1a0b0b', a: '#ef6a78', l: '#c43c4a' }, r: [
      '.....aaaaa......',
      '...aa.....aa....',
      '...a..aaaaa..a..',
      '..a..a.....a....',
      '.a..a...........',
      '.a.a..rrrrr.....',
      '..a.rRHRHRHr....',
      '...rRRHRHRHRr...',
      '..rkkRRHRHRHRr..',
      '.rRkkRRRRRRRRRr.',
      'rRRRRRRRRRRRRRr.',
      '.rr.lrRRRRRRRRRr',
      '....l.lrRRRRRRRr',
      '..rr.l.lrRRRRRr.',
      '.rRRr..rRRRRRr..',
      'rRRRRrrRRRRRr...',
      '.rRRRRRRRRrr....',
      '..rrrrrrrr......',
    ] },
    shrimpGold: { p: { R: '#f3cd66', H: '#fff0a8', r: '#c99a35', d: '#8a6418', k: '#3a2a08', a: '#ffe08a', l: '#d8a845' }, r: [
      '......aaaaa.....',
      '....aa.....aa...',
      '...a..aaaaa..a..',
      '..a..a.....a....',
      '.a..a...........',
      '.a.a..rrrrr.....',
      '..a.rRHRHRHr....',
      '...rRRHRHRHRr...',
      '..rkkRRHRHRHRr..',
      '.rRkkRRRRRRRRRr.',
      'rRRRRRRRRRRRRRr.',
      '.rr.lrRRRRRRRRRr',
      '....l.lrRRRRRRRr',
      '..rr.l.lrRRRRRr.',
      '.rRRr..rRRRRRr..',
      'rRRRRrrRRRRRr...',
      '.rRRRRRRRRrr....',
      '..rrrrrrrr......',
    ] },
    octo: { p: { p: '#ff7f9e', P: '#ffb3c6', w: '#ffffff', k: '#2a0a14', d: '#c2506e' }, r: [
      '..pppp..',
      '.pPPppp.',
      'pPpppppp',
      'pwkppwkp',
      'pppppppd',
      '.p.pp.d.',
      'p.p..p.d',
      '.p....p.',
    ] },
    shrimpIcon: { p: { r: '#e6554e', R: '#ff8a78', d: '#a3302f', k: '#1a0b0b', a: '#ffb29c' }, r: [
      '..a.a.....',
      '.a...a....',
      'a....Rrrr.',
      '....Rrrrrr',
      '...Rrrkrrd',
      '..Rrr.....',
      '..Rrd.....',
      '..rrd.....',
      '...rrrrd..',
      '....drrrd.',
      '......rd..',
    ] },
    plankton: { p: { a: '#7fe9ff', b: '#3bb6c9' }, r: [
      '...aa...',
      '..a..a..',
      '...aa...',
      '.aa..aa.',
      'a..aa..a',
      '.aa..aa.',
    ] },
    turtle: { p: { a: '#6aa84f', b: '#3d7a32', c: '#a7d18a', k: '#111' }, r: [
      '..c........c..',
      '.cc.aaaaa..cc.',
      '...abababa.ckc',
      '..ababababacccc',
      '...abababa....',
      '.cc.aaaaa..cc.',
      '..c........c..',
    ] },
  };
  // Pre-render sprites into offscreen canvases (and silhouettes on demand by color).
  const cache = {};
  function sprite(name, tint) {
    const key = name + (tint || '');
    if (cache[key]) return cache[key];
    const s = SPR[name]; const h = s.r.length, w = Math.max(...s.r.map(r => r.length));
    const c = document.createElement('canvas'); c.width = w; c.height = h; const x = c.getContext('2d');
    for (let j = 0; j < h; j++) for (let i = 0; i < s.r[j].length; i++) {
      const ch = s.r[j][i]; if (ch === '.') continue;
      let col = tint || s.p[ch];
      if (tint && tint[0] === '~') { // shade-preserving tint: recolor by the original pixel's brightness
        const t = hex(tint.slice(1)); const o = /^#/.test(s.p[ch]) ? hex(s.p[ch]) : [180, 180, 180];
        const lum = (0.3 * o[0] + 0.59 * o[1] + 0.11 * o[2]) / 255;
        col = lum < 0.16 ? '#0a1222' : rgb(t.map(v => Math.min(255, v * (0.5 + 0.7 * lum))));
      }
      x.fillStyle = col; x.fillRect(i, j, 1, 1);
    }
    // flipped copy
    const f = document.createElement('canvas'); f.width = w; f.height = h; const fx = f.getContext('2d');
    fx.translate(w, 0); fx.scale(-1, 1); fx.drawImage(c, 0, 0);
    return (cache[key] = { c, f, w, h });
  }
  function drawSprite(ctx, name, x, y, flip, tint) {
    const s = sprite(name, tint); ctx.drawImage(flip ? s.f : s.c, Math.round(x), Math.round(y));
    return s;
  }

  // Pixel cloud generator
  function makeCloud(seed) {
    const w = 26 + Math.floor(hash(seed) * 26), h = 10 + Math.floor(hash(seed + 7) * 6);
    const c = document.createElement('canvas'); c.width = w; c.height = h; const x = c.getContext('2d');
    const blobs = [];
    const n = 3 + Math.floor(hash(seed + 3) * 3);
    for (let i = 0; i < n; i++) {
      const bx = 5 + (w - 10) * (i / (n - 1 || 1)), r = 3 + hash(seed + i * 11) * (h * 0.45);
      blobs.push([bx, h - r - 1, r]);
    }
    blobs.push([w / 2, h - 3, w * 0.42]);
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      let inside = false;
      for (const [bx, by, r] of blobs) {
        if (j > h - 2) break;
        const dx = (i - bx) / (r === w * 0.42 ? r : r), dy = (j - by) / (r === w * 0.42 ? 3 : r);
        if (dx * dx + dy * dy <= 1) { inside = true; break; }
      }
      if (inside) { x.fillStyle = j > h * 0.66 ? '#d6e6f2' : '#ffffff'; x.fillRect(i, j, 1, 1); }
    }
    return c;
  }

  // ---------- state ----------
  const O = {
    canvas: null, ctx: null, W: 0, H: 0, scale: 3,
    view: 'title', reduced: false, tmix: 1,
    shrimpM: 0, shrimpFrom: 0, shrimpTo: 0, tweenT0: 0, tweenDur: 0,
    topM: -9999, ppm: 0,
    t: 0, last: 0, bubbles: [], clouds: [], dims: 0,
    onDepth: null, showShrimp: false, sinking: false,
  };

  function resize() {
    const dpr = 1; const cw = window.innerWidth, ch = window.innerHeight;
    O.scale = cw < 700 ? 2 : (cw > 1900 ? 4 : 3);
    O.W = Math.ceil(cw / O.scale); O.H = Math.ceil(ch / O.scale);
    O.canvas.width = O.W * dpr; O.canvas.height = O.H * dpr;
    O.ppm = O.H / 420; // ~420 m visible
    OFF = Math.ceil(gameAnchor() * 420) + 15; // keep the surface just above the screen during a dive
    O.ctx.imageSmoothingEnabled = false;
  }

  function viewTop() {
    const H = O.H, ppm = O.ppm;
    if (O.view === 'title') return -(H * (window.innerWidth < 700 ? 0.5 : 0.61)) / ppm;
    if (O.view === 'results') return -(H * (window.innerWidth < 700 ? 0.45 : 0.58)) / ppm;
    if (O.view === 'menu') return -(H * 0.3) / ppm;
    if (O.view === 'intro') return -(H * 0.42) / ppm;
    return shrimpWorld() - (H * gameAnchor()) / ppm;
  }
  const gameAnchor = () => window.innerWidth < 700 ? 0.74 : 0.62;
  const shrimpWorld = () => O.shrimpM + OFF; // shrimp floats a little below the surface at 0 m
  const shrimpX = () => Math.round(O.W * (O.sxf !== undefined ? O.sxf : (window.innerWidth < 700 ? 0.08 : 0.1)));

  // ---------- drawing ----------
  function disc(ctx, cx, cy, r) { for (let y = -r; y <= r; y++) { const w = Math.floor(Math.sqrt(r * r - y * y)); ctx.fillRect(cx - w, cy + y, w * 2 + 1, 1); } }
  function drawSky(ctx, yTop, ySurf) {
    if (ySurf <= 0) return;
    // bathroom wall: white tiles with grey grout, a little shading toward the floor line
    const T = 14, top = 0, bot = Math.ceil(ySurf);
    ctx.fillStyle = '#e3eaef'; ctx.fillRect(0, top, O.W, bot);
    ctx.fillStyle = '#d4dde4'; ctx.fillRect(0, Math.max(0, bot - Math.round(bot * 0.25)), O.W, Math.round(bot * 0.25));
    ctx.fillStyle = '#c2ccd5';
    for (let y = bot % T; y < bot; y += T) ctx.fillRect(0, y, O.W, 1);
    for (let x = 0; x < O.W; x += T) ctx.fillRect(x, 0, 1, bot);
    ctx.fillStyle = 'rgba(255,255,255,0.55)';
    for (let y = bot % T; y < bot; y += T) for (let x = 0; x < O.W; x += T) ctx.fillRect(x + 2, y + 2, 3, 1);
    // ceiling lamp, top right
    if (ySurf > 60) {
      const cx = Math.round(O.W * 0.86), r = Math.max(6, Math.round(O.H * 0.035));
      ctx.fillStyle = '#7d8894'; ctx.fillRect(cx, 0, 1, r * 2);
      for (let k = 4; k >= 1; k--) { ctx.fillStyle = `rgba(255, 236, 170, ${0.09 * (5 - k) / 4})`; disc(ctx, cx, r * 3, r + k * 6); }
      ctx.fillStyle = '#5a6470'; ctx.fillRect(cx - r, r * 2, r * 2 + 1, 3);
      ctx.fillStyle = '#fff3b0'; disc(ctx, cx, r * 3, r); ctx.fillStyle = '#ffffff'; disc(ctx, cx - Math.round(r * 0.3), r * 3 - Math.round(r * 0.3), Math.round(r * 0.35));
    }
  }

  function drawWater(ctx, ySurf) {
    const ppm = O.ppm; const start = Math.max(0, Math.floor(ySurf));
    const band = 3;
    for (let y = start; y < O.H; y += band) {
      const m = O.topM + y / ppm;
      const c = waterColor(lerp(dz(m), Math.max(0, m) * 6, O.tmix));
      // retro banding: quantise
      ctx.fillStyle = rgb([Math.round(c[0] / 4) * 4, Math.round(c[1] / 4) * 4, Math.round(c[2] / 4) * 4]);
      ctx.fillRect(0, y, O.W, band);
    }
  }

  function drawRays(ctx, ySurf) {
    // Diagonal light shafts that fade through the sunlight & twilight zones.
    const ppm = O.ppm;
    const yEnd = Math.min(O.H, ySurf + 900 * ppm);
    if (yEnd <= 0) return;
    for (let r = 0; r < 5; r++) {
      const base = (hash(r * 91) * O.W * 1.3) - O.W * 0.15 + Math.sin(O.t * 0.15 + r) * 8;
      const width = 6 + hash(r * 7) * 14;
      for (let y = Math.max(0, Math.floor(ySurf)); y < yEnd; y += 2) {
        const m = O.topM + y / ppm;
        const a = 0.09 * (1 - O.tmix) * (1 - clamp(m / 900, 0, 1)) * (0.7 + 0.3 * Math.sin(O.t * 0.5 + r * 2));
        if (a <= 0.005) continue;
        ctx.fillStyle = `rgba(210,245,255,${a.toFixed(3)})`;
        ctx.fillRect(Math.round(base - (y - ySurf) * 0.35), y, Math.round(width), 2);
      }
    }
  }

  function drawSurface(ctx, ySurf) {
    if (ySurf < -40 || ySurf > O.H + 10) return;
    const y = Math.round(ySurf);
    const skyCol = '#d4dde4';
    for (let x = 0; x < O.W; x++) {
      const w = Math.round(1.6 + Math.sin(x * 0.035 + O.t * 0.9) * 1.3 + Math.sin(x * 0.011 - O.t * 0.5) * 0.9);
      if (w > 0) { ctx.fillStyle = skyCol; ctx.fillRect(x, y, 1, w); }
      ctx.fillStyle = '#c4eef3'; ctx.fillRect(x, y + w, 1, 1);
      ctx.fillStyle = '#4f8f9b'; ctx.fillRect(x, y + w + 1, 1, 1);
    }
    // the toilet the duck got flushed down, sitting on the waterline
    const big = O.view === 'title' || O.view === 'intro';
    const k = O.view === 'results' ? 2 : big ? (window.innerWidth < 700 ? 4 : 5) : 3;
    const bs = sprite('toilet');
    const cxF = O.view === 'results' ? 0.1 : big ? (window.innerWidth < 700 ? 0.24 : 0.17) : 0.17;
    const bx = Math.round(O.W * cxF - bs.w * k / 2);
    O.toiletCX = bx + bs.w * k / 2;
    const surfAt = Math.round(1.6 + Math.sin((bx + bs.w * k / 2) * 0.035 + O.t * 0.9) * 1.3);
    const ty = y + surfAt - (bs.h - 2) * k;
    ctx.drawImage(bs.c, bx, ty, bs.w * k, bs.h * k);
    if (O.view === 'title' || O.view === 'intro') drawDuckInBowl(ctx, bs, bx, ty, k);
  }

  // The duck sits in the bowl on the title screen; starting a game flushes it:
  // it sloshes side to side, then circles the bowl, spinning and shrinking until it's sucked down.
  const FLUSH_SWIRL = 2100, FLUSH_DROP = 750;
  function flushP() { return O.flushT0 ? (performance.now() - O.flushT0) / FLUSH_SWIRL : -1; }
  function drawDuckInBowl(ctx, bs, bx, ty, k) {
    const p = O.view === 'intro' ? (O.reduced ? 1 : flushP()) : -1;
    const cx = bx + Math.round(bs.w * k / 2), rimY = ty + 6 * k, bowlR = 6.5 * k;
    const ds = sprite('duck' + (p >= 0 ? Math.floor(O.t * 12) % 2 : 0));
    const ds0 = k * 0.42; // duck size relative to the toilet
    if (p >= 0 && p < 1.1) {
      // churning water: a spiral of foam that tightens as the flush goes down
      const n = 26, sw = Math.min(1, Math.max(0, (p - 0.15) / 0.85));
      for (let i = 0; i < n; i++) {
        const a = O.t * (6 + sw * 22) + i * (Math.PI * 2 / n);
        const r = bowlR * (1 - sw * 0.6) * (0.55 + 0.45 * ((i * 7) % 5) / 4);
        ctx.fillStyle = i % 3 ? '#9fd6e0' : '#ffffff';
        ctx.fillRect(Math.round(cx + Math.cos(a) * r), Math.round(rimY + 2 + Math.sin(a) * r * 0.25), 2, 2);
      }
      // splashes jumping out of the bowl
      if (p < 0.8) for (let i = 0; i < 4; i++) {
        const a = -Math.PI / 2 + (Math.random() - 0.5) * 2.4, d = 6 + Math.random() * bowlR * 1.4;
        ctx.fillStyle = Math.random() < 0.5 ? '#ffffff' : '#9fd6e0';
        ctx.fillRect(Math.round(cx + Math.cos(a) * d), Math.round(rimY - 2 + Math.sin(a) * d * 0.9), 2, 2);
      }
    }
    if (p >= 1) { ctx.drawImage(bs.c, 0, 7, bs.w, bs.h - 7, bx, ty + 7 * k, bs.w * k, (bs.h - 7) * k); return; }
    let dx = 0, dy = 0, rot = 0, s = ds0;
    if (p < 0) { dy = Math.sin(O.t * 1.8) * 1.5; rot = Math.sin(O.t * 1.3) * 0.08; }
    else if (p < 0.35) { // slosh side to side, harder and harder
      const q = p / 0.35; dx = Math.sin(O.t * 16) * bowlR * 0.45 * q; dy = -Math.abs(Math.cos(O.t * 16)) * k * 1.2 * q; rot = Math.sin(O.t * 16) * 0.5 * q;
    } else { // circle the bowl, spinning and shrinking, then gone
      const q = (p - 0.35) / 0.65, a = O.t * (8 + q * 18);
      dx = Math.cos(a) * bowlR * 0.5 * (1 - q); dy = Math.sin(a) * bowlR * 0.14 * (1 - q) + q * k * 2;
      rot = q * q * 22; s = ds0 * (1 - Math.pow(q, 1.4) * 0.9);
    }
    const cy = rimY + 2 - ds.h * ds0 / 2 + dy;
    ctx.save(); ctx.translate(Math.round(cx + dx), Math.round(cy)); ctx.rotate(rot);
    ctx.drawImage(ds.c, Math.round(-ds.w * s / 2), Math.round(-ds.h * s / 2), Math.round(ds.w * s), Math.round(ds.h * s)); ctx.restore();
    ctx.drawImage(bs.c, 0, 7, bs.w, bs.h - 7, bx, ty + 7 * k, bs.w * k, (bs.h - 7) * k); // bowl front hides the duck's bottom
  }

  function zoneCreatures(z, rnd) {
    // returns a floating thing for zone z: bowl junk, pipe junk, sewer life, rat royalty, brainrot sludge
    const pick = arr => arr[Math.floor(rnd * arr.length) % arr.length];
    if (z === 0) return pick(['bubbles', 'soap', 'tproll', 'toothbrush', 'bubbles', 'goldfish']);
    if (z === 1) return pick(['airpod', 'goldfish', 'sock', 'tproll', 'toothbrush', 'bubbles', 'soap']);
    if (z === 2) return pick(['rat', 'sludge', 'sock', 'airpod', 'rat', 'goldfish', 'tproll']);
    if (z === 3) return pick(['ratking', 'rat', 'sludge', 'auraBlob', 'rat']);
    return pick(['sludge', 'auraBlob', 'ratking', 'auraBlob', 'sludge']);
  }

  function glow(ctx, x, y, r, col, a) {
    // stepped octagonal glow so it reads as a soft pixel halo rather than a square
    for (let i = r; i > 0; i -= 2) {
      ctx.fillStyle = rgb(col, (a * 0.6 * (1 - i / (r + 1))).toFixed(3));
      const k = Math.round(i * 0.55);
      ctx.fillRect(Math.round(x - i), Math.round(y - k), i * 2, k * 2);
      ctx.fillRect(Math.round(x - k), Math.round(y - i), k * 2, i * 2);
    }
  }

  function drawFar(ctx) {
    // Far parallax silhouettes (darker shapes moving slowly)
    const ppm = O.ppm * 0.55; const top = O.topM * 0.55; const CH = 70;
    const c0 = Math.floor(top / CH) - 1, c1 = Math.floor((top + O.H / ppm) / CH) + 1;
    for (let c = c0; c <= c1; c++) {
      if (c < 1) continue;
      const n = 1 + Math.floor(hash(c * 5 + 1) * 2);
      for (let k = 0; k < n; k++) {
        const s = c * 13 + k * 101;
        const m = c * CH + hash(s) * CH; const y = (m - top) * ppm;
        if (y < -20 || y > O.H + 20) continue;
        const realM = O.topM + y / O.ppm; if (realM < 25) continue;
        const wc = waterColor(lerp(dz(realM), Math.max(0, realM) * 22, O.tmix));
        const tint = rgb(mix(wc, [4, 10, 22], 0.35));
        const dir = hash(s + 3) > 0.5 ? 1 : -1; const sp = (2 + hash(s + 4) * 4) * dir;
        const big = hash(s + 9) > 0.9 && dz(realM) > 600;
        const shallow = dz(realM) < 450;
        const name = big ? 'fatberg' : shallow ? (hash(s + 7) > 0.5 ? 'sock' : 'tproll') : 'rat';
        const w = big ? 24 : 16; const span = O.W + w * 2;
        let x = ((hash(s + 2) * span + O.t * sp) % span + span) % span - w;
        drawSprite(ctx, name, x, y, dir < 0, tint);
      }
    }
  }

  function drawCreatures(ctx) {
    const ppm = O.ppm; const CH = 55;
    const c0 = Math.floor(O.topM / CH) - 1, c1 = Math.floor((O.topM + O.H / ppm) / CH) + 1;
    for (let c = c0; c <= c1; c++) {
      if (c < 0) continue;
      const midM = c * CH + CH / 2; const z = zoneIndex(dz(midM));
      const n = hash(c * 7) > 0.45 ? 1 : (hash(c * 11) > 0.75 ? 2 : 0);
      for (let k = 0; k < n; k++) {
        const s = c * 97 + k * 31 + 5;
        const type = zoneCreatures(z, hash(s));
        const m = c * CH + 6 + hash(s + 1) * (CH - 12);
        let y = (m - O.topM) * ppm;
        if (y < -30 || y > O.H + 30) continue;
        const dir = hash(s + 2) > 0.5 ? 1 : -1;
        const sp = ['bubbles', 'tproll', 'soap', 'sock', 'airpod', 'toothbrush', 'sludge', 'auraBlob'].includes(type) ? 1.4 + hash(s + 3) * 2 : 4 + hash(s + 3) * 7;
        const span = O.W + 40;
        const x = ((hash(s + 4) * span + O.t * sp * dir) % span + span) % span - 20;
        const ph = hash(s + 5) * 6.28;
        const sil = rgb(mix(waterColor(Math.max(0, dz(c * CH))), [3, 8, 18], 0.55));
        if (type === 'goldfish') {
          drawSprite(ctx, 'fish', x, y + Math.round(Math.sin(O.t * 2 + ph)), dir < 0, '~#ff8a3d');
        } else if (type === 'sludge' || type === 'auraBlob' || type === 'ratking') {
          const bob = Math.round(Math.sin(O.t * 1.6 + ph) * 2);
          const g = type === 'sludge' ? [125, 255, 106] : type === 'auraBlob' ? [197, 139, 255] : [255, 213, 74];
          glow(ctx, x + 6, y + 5 + bob, 9, g, 0.18 + 0.06 * Math.sin(O.t * 2 + ph));
          drawSprite(ctx, type, x, y + bob, dir < 0);
        } else if (type === 'school') {
          for (let f = 0; f < 6; f++) {
            const fx = x + (f % 3) * 15 + Math.sin(O.t * 2 + f) * 1.5, fy = y + Math.floor(f / 3) * 9 + (f % 2) * 4;
            drawSprite(ctx, 'fish2', fx, fy, dir < 0);
          }
        } else if (type === 'fish' || type === 'hatchet' || type === 'turtle') {
          drawSprite(ctx, 'minifish', x, y + Math.round(Math.sin(O.t * 2 + ph)), dir < 0, sil);
        } else if (type === 'lantern') {
          // little bioluminescent fish: dot pattern + glow
          const tw = 0.5 + 0.5 * Math.sin(O.t * 3 + ph);
          glow(ctx, x + 3, y + 1, 4, [127, 243, 255], 0.18 * tw);
          ctx.fillStyle = '#1b2a3a'; ctx.fillRect(Math.round(x), Math.round(y), 6, 3);
          ctx.fillStyle = `rgba(127,243,255,${0.5 + 0.5 * tw})`; ctx.fillRect(Math.round(x + 1), Math.round(y + 1), 1, 1); ctx.fillRect(Math.round(x + 3), Math.round(y + 2), 1, 1);
        } else if (type === 'jelly' || type === 'jelly2' || type === 'vamp' || type === 'squidIcon' || type === 'bubbles') {
          const bob = Math.sin(O.t * 1.5 + ph) * 3; y += bob;
          const g = type === 'jelly' ? [255, 143, 209] : type === 'squidIcon' ? [236, 75, 75] : [127, 243, 255];
          if (z >= 2) glow(ctx, x + 4, y + 3, 7, g, 0.14 + 0.06 * Math.sin(O.t * 2 + ph));
          drawSprite(ctx, type, x, y, false);
        } else if (type === 'angler') {
          drawSprite(ctx, 'angler', x, y, dir > 0);
          const lx = dir > 0 ? x + 19 : x + 2; const flick = 0.6 + 0.4 * Math.sin(O.t * 4 + ph);
          glow(ctx, lx, y + 5, 6, [255, 255, 255], 0.3 * flick);
        } else if (type === 'eel') {
          const wig = Math.round(Math.sin(O.t * 3 + ph) * 1);
          drawSprite(ctx, 'eel', x, y + wig, dir < 0);
          glow(ctx, dir < 0 ? x : x + 13, y + 3 + wig, 3, [255, 106, 213], 0.25);
        } else {
          const bob = Math.round(Math.sin(O.t * 2 + ph) * 1);
          drawSprite(ctx, type, x, y + bob, dir < 0);
        }
      }
    }
  }

  function drawSnow(ctx) {
    // marine snow / particles drifting; slightly faster parallax than camera
    const n = O.reduced ? 25 : 70;
    const camPx = O.topM * O.ppm * 1.15;
    for (let i = 0; i < n; i++) {
      const x = (hash(i * 3 + 1) * O.W + Math.sin(O.t * 0.3 + i) * 3) % O.W;
      const sp = 3 + hash(i * 5) * 5;
      const y = ((hash(i * 7) * O.H - camPx + O.t * sp) % O.H + O.H) % O.H;
      const m = O.topM + y / O.ppm; if (m < 4) continue;
      const deep = dz(m) > 1000;
      ctx.fillStyle = deep ? (i % 9 === 0 ? (dz(m) > 4000 ? 'rgba(255,110,200,0.6)' : 'rgba(125,255,106,0.55)') : 'rgba(170,210,170,0.28)') : 'rgba(230,250,255,0.35)';
      ctx.fillRect(Math.round(x), Math.round(y), 1, 1);
    }
  }

  function drawKelp(ctx) {
    // metal drain pipes running down both edges through the bowl and the pipes zone
    const mid = dz(O.topM + O.H / O.ppm / 2);
    const a = clamp((mid - 40) / 120, 0, 1) * (1 - clamp((mid - 1400) / 400, 0, 1));
    if (a <= 0.02 || O.tmix > 0.9) return;
    ctx.globalAlpha = a * (1 - O.tmix);
    const pipes = [[0.015, 9], [0.065, 6], [0.93, 7], [0.975, 9]];
    const scroll = Math.round(O.topM * O.ppm) % 34;
    pipes.forEach(([fx, w], i) => {
      const x = Math.round(O.W * fx - w / 2);
      ctx.fillStyle = '#4c5660'; ctx.fillRect(x, 0, w, O.H);
      ctx.fillStyle = '#6e7b86'; ctx.fillRect(x + 1, 0, 2, O.H);
      ctx.fillStyle = '#323a41'; ctx.fillRect(x + w - 2, 0, 2, O.H);
      for (let y = -scroll + i * 9; y < O.H; y += 34) { // flanged joints with rivets
        ctx.fillStyle = '#5d6872'; ctx.fillRect(x - 2, y, w + 4, 4);
        ctx.fillStyle = '#88949f'; ctx.fillRect(x - 2, y, w + 4, 1);
        ctx.fillStyle = '#2a3036'; ctx.fillRect(x - 1, y + 2, 1, 1); ctx.fillRect(x + w, y + 2, 1, 1);
      }
    });
    ctx.globalAlpha = 1;
  }
  function drawTrench(ctx) {
    const ppm = O.ppm; const startM = 1000 + OFF;
    const yStart = (startM - O.topM) * ppm; if (yStart > O.H) return;
    const floorM = 7120 + OFF; const yFloor = (floorM - O.topM) * ppm;
    for (let y = Math.max(0, Math.floor(yStart)); y < O.H; y += 2) {
      const m = O.topM + y / ppm;
      const t = clamp((m - startM) / 300, 0, 1) * (0.25 + 0.75 * clamp((m - startM) / 4800, 0, 1));
      const nL = Math.sin(m * 0.031) * 6 + Math.sin(m * 0.11) * 3 + hash(Math.floor(m / 6)) * 4;
      const nR = Math.sin(m * 0.027 + 2) * 6 + Math.sin(m * 0.09) * 3 + hash(Math.floor(m / 6) + 999) * 4;
      const wl = Math.max(0, t * O.W * 0.27 + nL), wr = Math.max(0, t * O.W * 0.27 + nR);
      const zc = wallColors(dz(m));
      ctx.fillStyle = zc[3]; ctx.fillRect(0, y, Math.round(wl), 2); ctx.fillRect(Math.round(O.W - wr), y, Math.round(wr) + 1, 2);
      ctx.fillStyle = zc[0]; if (wl > 2) ctx.fillRect(Math.round(wl) - 2, y, 2, 2); if (wr > 2) ctx.fillRect(Math.round(O.W - wr), y, 2, 2);
      if (hash(Math.floor(m) + 77) > 0.985 && wr > 10) { const gx = O.W - wr * (0.3 + hash(Math.floor(m)) * 0.5); glow(ctx, gx, y, 4, [125, 255, 106], 0.3 + 0.2 * Math.sin(O.t * 2 + m)); ctx.fillStyle = '#c8ffbf'; ctx.fillRect(Math.round(gx), y, 1, 1); }
      if (hash(Math.floor(m) + 41) > 0.985 && wl > 10) { const gx = wl * (0.3 + hash(Math.floor(m) + 3) * 0.5); glow(ctx, gx, y, 4, [255, 143, 209], 0.3 + 0.2 * Math.sin(O.t * 2.3 + m)); ctx.fillStyle = '#ffc4ea'; ctx.fillRect(Math.round(gx), y, 1, 1); }
    }
    // sewer bricks: staggered rows, lit top edge, slime and gold specks
    const BH = 10, BW = 20;
    const r0 = Math.floor((O.topM * ppm) / BH) - 1, r1 = Math.ceil(((O.topM * ppm) + O.H) / BH) + 1;
    for (let r = r0; r <= r1; r++) {
      const yb = Math.round(r * BH - O.topM * ppm); const m = O.topM + (yb + BH / 2) / ppm;
      if (m < startM + 40) continue;
      const t = clamp((m - startM) / 300, 0, 1) * (0.25 + 0.75 * clamp((m - startM) / 4800, 0, 1));
      for (const side of [0, 1]) {
        const wall = t * O.W * 0.27 + Math.sin(m * (side ? 0.027 : 0.031) + side * 2) * 6;
        const off = (r % 2) * (BW / 2);
        for (let c = 0; c * BW - off < wall - 4; c++) {
          const s = r * 131 + c * 17 + side * 7919;
          const w = BW - 2, h = BH - 2;
          let x = c * BW - off;
          if (side) x = O.W - x - w;
          const y = yb;
          const zc = wallColors(dz(m));
          ctx.fillStyle = zc[0]; ctx.fillRect(x, y, w, h);
          ctx.fillStyle = zc[1]; ctx.fillRect(x, y, w, 1); ctx.fillRect(x, y, 1, h);
          ctx.fillStyle = zc[2]; ctx.fillRect(x + 1, y + h - 1, w - 1, 1); ctx.fillRect(x + w - 1, y + 1, 1, h - 1);
          if (hash(s + 4) > 0.82) { ctx.fillStyle = zc[4]; ctx.fillRect(x + 2 + Math.floor(hash(s + 6) * (w - 5)), y + h - 1, 2, 2 + Math.floor(hash(s + 7) * 3)); } // drips
        }
      }
    }
    // the Brainrot Core: a glowing neon pool with sludge creatures bubbling up
    if (yFloor < O.H + 60 && !O.endless) {
      ctx.fillStyle = '#12030f'; ctx.fillRect(0, Math.round(yFloor), O.W, O.H);
      for (let x = 0; x < O.W; x += 2) { const w = Math.sin(x * 0.08 + O.t * 2) * 2; ctx.fillStyle = (x >> 3) % 2 ? '#ff3fb4' : '#7dff6a'; ctx.fillRect(x, Math.round(yFloor + w), 2, 2); }
      for (let i = 0; i < 5; i++) {
        const vx = Math.round(O.W * (0.15 + i * 0.18) + hash(i * 5) * 16);
        glow(ctx, vx, yFloor - 4, 14, i % 2 ? [255, 63, 180] : [125, 255, 106], 0.16 + 0.06 * Math.sin(O.t * 2 + i));
        drawSprite(ctx, i % 2 ? 'auraBlob' : 'sludge', vx - 6, yFloor - 10 + Math.round(Math.sin(O.t * 1.7 + i) * 2));
        for (let b = 0; b < 4; b++) {
          const by = yFloor - 12 - ((O.t * 12 + b * 9 + i * 7) % 40);
          ctx.fillStyle = i % 2 ? 'rgba(255,120,210,0.35)' : 'rgba(150,255,140,0.35)'; ctx.fillRect(vx + Math.round(Math.sin(O.t * 3 + b) * 2), Math.round(by), 1, 1);
        }
      }
    }
  }

  // wall colours by depth: [face, highlight, shadow, mortar, drip]
  function wallColors(m) {
    if (m < 4000) return ['#2e3d2d', '#43573f', '#1b241a', '#151d15', 'rgba(125,255,106,0.55)'];
    if (m < 6000) return ['#2f2244', '#43325f', '#1b1229', '#140d1f', 'rgba(255,213,74,0.6)'];
    return ['#3a1236', '#56204f', '#1e081c', '#16061a', 'rgba(255,63,180,0.65)'];
  }

  function drawLurker(ctx, ySurf) {
    // the title screen's rubber duck, bobbing on the water before the flush
    return; // the duck now waits in the toilet bowl (drawDuckInBowl)
    const ds = sprite('duck0');
    const x = Math.round(O.W * 0.72), y = Math.round(ySurf - ds.h * 2 + 6 + Math.sin(O.t * 1.6) * 1.5);
    ctx.globalAlpha = O.tmix; ctx.drawImage(ds.c, x, y, ds.w * 2, ds.h * 2); ctx.globalAlpha = 1;
  }
  function drawShrimp(ctx) {
    if (!O.showShrimp) return;
    if (O.view === 'intro' && O.flushT0 && flushP() < 1 && !O.reduced) return; // still spinning in the bowl
    const sx = shrimpX(); const sy = (shrimpWorld() - O.topM) * O.ppm;
    if (sy < -20 || sy > O.H + 20) return;
    const frame = Math.floor(O.t * (O.sinking ? 10 : 4)) % 2;
    const bob = O.sinking ? 0 : Math.round(Math.sin(O.t * 2.2) * 1.5);
    const m = O.shrimpM;
    if (m > 800) glow(ctx, sx + 8, sy + 5, 18, [140, 220, 255], clamp((m - 800) / 3000, 0, 1) * 0.08);
    const cs = sprite('duck' + frame); const k2 = 1;
    glow(ctx, sx + cs.w / 2, Math.round(sy) + bob + cs.h / 2, 12, [255, 214, 60], 0.18);
    ctx.drawImage(cs.c, sx, Math.round(sy) + bob, cs.w * k2, cs.h * k2);
    // idle bubbles
    if (!O.reduced && Math.random() < (O.sinking ? 0.5 : 0.04)) O.bubbles.push({ x: sx + 12 + Math.random() * 4, y: sy, vy: -(8 + Math.random() * 10), life: 3 });
  }

  function drawBubbles(ctx, dt) {
    const camV = O.camV || 0; // m/s camera velocity, bubbles stream upward relative to screen
    for (let i = O.bubbles.length - 1; i >= 0; i--) {
      const b = O.bubbles[i];
      b.y += (b.vy - camV * O.ppm) * dt; b.x += Math.sin(O.t * 4 + i) * 0.15; b.life -= dt;
      if (b.life <= 0 || b.y < -5) { O.bubbles.splice(i, 1); continue; }
      ctx.fillStyle = 'rgba(200,240,255,0.7)';
      const big = b.big ? 2 : 1;
      ctx.fillRect(Math.round(b.x), Math.round(b.y), big, big);
      if (b.big) { ctx.fillStyle = 'rgba(255,255,255,0.9)'; ctx.fillRect(Math.round(b.x), Math.round(b.y), 1, 1); }
    }
  }

  function vignette(ctx) {
    const m = O.topM + O.H / O.ppm / 2;
    const a = clamp((dz(m) - 1500) / 5000, 0, 0.55);
    if (a <= 0) return;
    const steps = 6;
    for (let i = 0; i < steps; i++) {
      const pad = Math.round((i + 1) * Math.min(O.W, O.H) * 0.035);
      ctx.fillStyle = `rgba(0,0,6,${(a / steps).toFixed(3)})`;
      ctx.fillRect(0, 0, O.W, pad); ctx.fillRect(0, O.H - pad, O.W, pad);
      ctx.fillRect(0, 0, pad, O.H); ctx.fillRect(O.W - pad, 0, pad, O.H);
    }
  }

  function frame(now) {
    const dt = Math.min(0.05, (now - (O.last || now)) / 1000); O.last = now; O.t += dt;
    // shrimp tween
    if (O.tweenDur > 0) {
      const p = clamp((now - O.tweenT0) / O.tweenDur, 0, 1);
      const e = p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2;
      O.shrimpM = lerp(O.shrimpFrom, O.shrimpTo, e); O.sinking = p < 1;
      if (O.onDepth) O.onDepth(O.shrimpM, p >= 1);
      if (p >= 1) { O.tweenDur = 0; O.sinking = false; }
    }
    // flush: once the swirl ends, the duck drops out under the toilet into the water
    if (O.flushT0 && !O.flushDropped && (O.reduced || flushP() >= 1)) {
      O.flushDropped = true; O.shrimpFrom = O.shrimpM; O.shrimpTo = -OFF + 150; O.tweenT0 = now; O.tweenDur = FLUSH_DROP;
      for (let i = 0; i < 18; i++) O.bubbles.push({ x: shrimpX() + Math.random() * 16, y: (shrimpWorld() - O.topM) * O.ppm, vy: -(10 + Math.random() * 30), life: 1.6, big: Math.random() < 0.5 });
    }
    // shrimp glides between its idle spot and center stage during a descent
    const sxTarget = O.sxTarget !== null && O.sxTarget !== undefined ? O.sxTarget : (window.innerWidth < 700 ? 0.08 : 0.1);
    O.sxf = O.sxf === undefined ? sxTarget : O.sxf + (sxTarget - O.sxf) * (O.reduced ? 1 : 1 - Math.exp(-dt * 3));
    const target = viewTop();
    const prev = O.topM;
    if (O.topM < -5000 || O.reduced) O.topM = target;
    else O.topM += (target - O.topM) * (1 - Math.exp(-dt * (O.sinking ? 9 : 2.6)));
    O.camV = dt > 0 ? (O.topM - prev) / dt : 0;

    const tm = O.view === 'game' || O.view === 'intro' ? 0 : 1;
    O.tmix = O.reduced ? tm : O.tmix + (tm - O.tmix) * (1 - Math.exp(-dt * 2.2));
    const ctx = O.ctx; const ySurf = (0 - O.topM) * O.ppm;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, O.W, O.H);
    const fp = O.view === 'intro' && !O.reduced ? flushP() : -1;
    if (fp > 0.15 && fp < 1) { const a = Math.sin(fp * Math.PI) * 1.6; ctx.setTransform(1, 0, 0, 1, Math.round((Math.random() - 0.5) * 2 * a), Math.round((Math.random() - 0.5) * 2 * a)); }
    drawSky(ctx, 0, ySurf);
    // dusk over the sky on the results screen
    O.dusk = (O.dusk || 0) + ((O.view === 'results' ? 1 : 0) - (O.dusk || 0)) * (O.reduced ? 1 : 1 - Math.exp(-dt * 2));
    if (O.dusk > 0.01 && ySurf > 0) { ctx.fillStyle = `rgba(22,30,46,${(0.78 * O.dusk).toFixed(3)})`; ctx.fillRect(0, 0, O.W, Math.ceil(ySurf) + 3); }
    drawWater(ctx, ySurf);
    drawRays(ctx, ySurf);
    drawFar(ctx);
    drawKelp(ctx);
    drawTrench(ctx);
    if (O.tmix < 0.98) { ctx.globalAlpha = 1 - O.tmix; drawCreatures(ctx); ctx.globalAlpha = 1; }
    drawLurker(ctx, ySurf);
    drawSnow(ctx);
    drawSurface(ctx, ySurf);
    drawShrimp(ctx);
    drawBubbles(ctx, dt);
    vignette(ctx);
    requestAnimationFrame(frame);
  }

  // ---------- public API ----------
  const Ocean = {
    ZONES, zoneIndex, waterColor, drawSprite, sprite,
    init(canvas) {
      O.canvas = canvas; O.ctx = canvas.getContext('2d');
      for (let i = 0; i < 9; i++) O.clouds.push(makeCloud(i * 19 + 3));
      resize(); window.addEventListener('resize', resize);
      requestAnimationFrame(frame);
    },
    setView(v, instant) { O.view = v; O.showShrimp = v === 'game' || v === 'intro'; if (instant) O.topM = viewTop(); },
    setReduced(r) { O.reduced = !!r; },
    setEndless(v) { O.endless = !!v; },
    // first prompt: flush the duck down the toilet, then drop it into the water under the toilet
    flush() {
      O.flushT0 = performance.now(); O.flushDropped = false;
      const f = ((O.toiletCX || O.W * 0.2) - 8) / O.W; O.sxTarget = f; O.sxf = f;
      O.shrimpM = -OFF + 6; O.tweenDur = 0; O.sinking = false;
    },
    setDepth(m, opts = {}) {
      if (opts.instant || O.reduced) { O.shrimpM = m; O.tweenDur = 0; O.sinking = false; if (O.onDepth) O.onDepth(m, true); return 0; }
      O.shrimpFrom = O.shrimpM; O.shrimpTo = m; O.tweenT0 = performance.now();
      O.tweenDur = opts.duration || clamp(900 + Math.abs(m - O.shrimpM) * 1.6, 900, 2800);
      for (let i = 0; i < 14; i++) O.bubbles.push({ x: shrimpX() + 6 + Math.random() * 10, y: (shrimpWorld() - O.topM) * O.ppm, vy: -(10 + Math.random() * 25), life: 2.5, big: Math.random() < 0.4 });
      return O.tweenDur;
    },
    get depth() { return O.shrimpM; },
    burst(n = 10) { for (let i = 0; i < n; i++) O.bubbles.push({ x: shrimpX() + Math.random() * 16, y: (shrimpWorld() - O.topM) * O.ppm, vy: -(12 + Math.random() * 20), life: 2, big: Math.random() < 0.5 }); },
    set onDepth(fn) { O.onDepth = fn; },
    setShrimpX(f) { O.sxTarget = f; },
    // CSS-pixel screen position helpers for DOM overlays
    depthToScreenY(d) { return ((OFF + d) - O.topM) * O.ppm * O.scale; },
    screenYToDepth(y) { return y / (O.ppm * O.scale) + O.topM - OFF; },
    shrimpScreen() { return { x: (shrimpX() + 8) * O.scale, y: ((shrimpWorld() - O.topM) * O.ppm + 5) * O.scale }; },
  };
  window.Ocean = Ocean;
})();
