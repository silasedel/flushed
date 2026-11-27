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
    [2400, '#203022'], [3600, '#25183a'], [4300, '#1b1130'], [4600, '#200a26'], [5800, '#15041a'],
  ].map(([m, h]) => [m, hex(h)]);
  function waterColor(m) {
    if (m <= WATER[0][0]) return WATER[0][1];
    for (let i = 1; i < WATER.length; i++) {
      if (m <= WATER[i][0]) { const [m0, c0] = WATER[i - 1], [m1, c1] = WATER[i]; return mix(c0, c1, (m - m0) / (m1 - m0)); }
    }
    return WATER[WATER.length - 1][1];
  }
  // Zone depths are tuned to score: in a 7-prompt game ~400 pts reaches the Rat Kingdom, ~500 the Brainrot Core,
  // and past ~600 it goes full rainbow insanity (and keeps escalating).
  const Z_RAT = 3600, Z_CORE = 4600, Z_MAD = 5600;
  const ZONES = [
    { name: 'Bowl', from: 0, to: 200 },
    { name: 'Pipes', from: 200, to: 1000 },
    { name: 'Sewer', from: 1000, to: Z_RAT },
    { name: 'Rat Kingdom', from: Z_RAT, to: Z_CORE },
    { name: 'Brainrot Core', from: Z_CORE, to: 99999 },
  ];
  const zoneIndex = m => m < 200 ? 0 : m < 1000 ? 1 : m < Z_RAT ? 2 : m < Z_CORE ? 3 : 4;
  // The shrimp's 0 m sits OFF meters below the drawn surface so the dive screen starts underwater.
  let OFF = 275; const dz = m => m - OFF;

  // ---------- sprites ----------
  // Each sprite: rows of chars, palette maps char -> color. '.' is transparent.
  const SPR = {
    // ---- floating junk, zone by zone ----
    partyMouseCF: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#7dff6a', 'c': '#ff3fb4', 'y': '#ffffff'}, r: [
      '......................y.........',
      '......................H.........',
      '.....................HHH........',
      '....................kHccc.......',
      '...................kccHHH.......',
      '..................khHHHHH.......',
      '.................khHHHHHHHk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      '......khhGGGGGGGGGGGGGGGGGGGgk..',
      '.....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '....khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '....khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '....khtGGGGGGGGGGGGGGGGGGGGGggkk',
      '....ttGGGGGGGGGGGGGGGGGGggggkk..',
      '...t.khGGGGGGGGGGGGGGGGgkkkk....',
      '.tt...khgGGGGGGGGGGGGggkk.......',
      't......kkhggggGGgGGggkkhhk......',
      't......khgkkkkhgkhgkk.khgk......',
      '.......khgk..khgkhgk...kk.......',
      '........kk....kk.kk.............',
    ] },
    partyMouseBF: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#4ad0ff', 'c': '#ffe14a', 'y': '#ffffff'}, r: [
      '......................y.........',
      '......................H.........',
      '.....................HHH........',
      '....................kHccc.......',
      '...................kccHHH.......',
      '..................khHHHHH.......',
      '.................khHHHHHHHk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      '......khhGGGGGGGGGGGGGGGGGGGgk..',
      '.....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '....khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '....khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '....khtGGGGGGGGGGGGGGGGGGGGGggkk',
      '....ttGGGGGGGGGGGGGGGGGGggggkk..',
      '...t.khGGGGGGGGGGGGGGGGgkkkk....',
      '.tt...khgGGGGGGGGGGGGggkk.......',
      't......kkhggggGGgGGggkkhhk......',
      't......khgkkkkhgkhgkk.khgk......',
      '.......khgk..khgkhgk...kk.......',
      '........kk....kk.kk.............',
    ] },
    partyMouseF: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#ff3fb4', 'c': '#7dff6a', 'y': '#ffffff'}, r: [
      '......................y.........',
      '......................H.........',
      '.....................HHH........',
      '....................kHccc.......',
      '...................kccHHH.......',
      '..................khHHHHH.......',
      '.................khHHHHHHHk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      '......khhGGGGGGGGGGGGGGGGGGGgk..',
      '.....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '....khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '....khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '....khtGGGGGGGGGGGGGGGGGGGGGggkk',
      '....ttGGGGGGGGGGGGGGGGGGggggkk..',
      '...t.khGGGGGGGGGGGGGGGGgkkkk....',
      '.tt...khgGGGGGGGGGGGGggkk.......',
      't......kkhggggGGgGGggkkhhk......',
      't......khgkkkkhgkhgkk.khgk......',
      '.......khgk..khgkhgk...kk.......',
      '........kk....kk.kk.............',
    ] },
    crownMouseF: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#000', 'c': '#000', 'y': '#ffffff'}, r: [
      '...................Y..Y..Y......',
      '...................YYYYYYY......',
      '...................YYYrYYY......',
      '...................YYYYYYY......',
      '...................khhk.........',
      '..................khGGhk........',
      '.................khGppGhkkk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      '......khhGGGGGGGGGGGGGGGGGGGgk..',
      '.....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '....khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '....khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '....khtGGGGGGGGGGGGGGGGGGGGGggkk',
      '....ttGGGGGGGGGGGGGGGGGGggggkk..',
      '...t.khGGGGGGGGGGGGGGGGgkkkk....',
      '.tt...khgGGGGGGGGGGGGggkk.......',
      't......kkhggggGGgGGggkkhhk......',
      't......khgkkkkhgkhgkk.khgk......',
      '.......khgk..khgkhgk...kk.......',
      '........kk....kk.kk.............',
    ] },
    rat1: { p: {'k': '#14141c', 'G': '#7a6a62', 'h': '#a89688', 'g': '#4e423c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#d88a9a', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#000', 'c': '#000', 'y': '#ffffff'}, r: [
      '....................kk..........',
      '...................khhk.........',
      '..................khGGhk........',
      '.................khGppGhkkk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      '......khhGGGGGGGGGGGGGGGGGGGgk..',
      '.....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '....khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '....khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '....khtGGGGGGGGGGGGGGGGGGGGGggkk',
      '....ttGGGGGGGGGGGGGGGGGGggggkk..',
      '...t.khGGGGGGGGGGGGGGGGgkkkk....',
      '.tt...khgGGGGGGGGGGGGggkk.......',
      't......kkhggggGGgGGggkkhhk......',
      't......khgkkkkhgkhgkk.khgk......',
      '.......khgk..khgkhgk...kk.......',
      '........kk....kk.kk.............',
    ] },
    rat0: { p: {'k': '#14141c', 'G': '#7a6a62', 'h': '#a89688', 'g': '#4e423c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#d88a9a', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#000', 'c': '#000', 'y': '#ffffff'}, r: [
      '....................kk..........',
      '...................khhk.........',
      '..................khGGhk........',
      '.................khGppGhkkk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      't.....khhGGGGGGGGGGGGGGGGGGGgk..',
      't....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '..t.kttGGGGGGGGGGGGGGGGGGGGGggkk',
      '...tthGGGGGGGGGGGGGGGGGGggggkk..',
      '.....khGGGGGGGGGGGGGGGGgkkkk....',
      '......khgGGGGGGGGGGGGggk........',
      '.......kkhGggGGgggGGgkhhk.......',
      '........khgkkhgkkkhgkkhgk.......',
      '........khgkkhgk.khgk.kk........',
      '.........kk..kk...kk............',
    ] },
    tpWad: { p: {'k': '#5d6670', 'W': '#f4f6f8', 'h': '#ffffff', 'g': '#c9d0d8', 'c': '#a9b3bd', 'd': '#9aa5b0'}, r: [
      '............kkkkkk.........',
      '..........kkhhhhhhkk.......',
      '.....kkkkkhhWWWWWWhhk......',
      '....khhhhhWWWcWWWWWgkkk....',
      '...khWWWWWWWWWcWWWWWhhhkk..',
      '..khWWWWWWWWWWcWWWWWWWWhhk.',
      '.khWWWcWWWWWWWWcWWWWWWWWWhk',
      '.khWWWWcWWWWWWWcWWWWWWWWWgk',
      '.khWWWWWccWWWWWcWWWWWWWWWgk',
      '.khWWWWWWWcWWWcWWWWWWccWWgk',
      'khWWWWWWWWWWWWcWWWWccWWWWgk',
      'khWWWWWWWWWWWWWWWWcWWWWWWgk',
      'khWWWWWWWWWWWWWWWWWWWWWWgk.',
      'khWWWWWWcWWWWWWWWWWWWWWWgk.',
      '.khWWWWWWccWWWWWWWWWWWWWgk.',
      '..khgggggggccggggggggggggk.',
      '...kkkhgggggggggggggggggk..',
      '......kkhdddddkhdddddddk...',
      '........kkkkkk.kkkkkkkk....',
    ] },
    tpSheet: { p: {'k': '#6d7680', 'W': '#f4f6f8', 'h': '#ffffff', 'g': '#c9d0d8', 'q': '#d8dee5', 'p': '#9aa5b0'}, r: [
      '...................kkkk..',
      '...........kkkkkkkkhhhhk.',
      '.kkkkkkkkkkhhhhhhhhWhghk.',
      'khhhhhhhhhhWWWWWWWWWWhhk.',
      'kqWWWWqWWWWqWWWWqWWWWqhk.',
      'khWWWWWWWWWWWWWWWWWWWWgk.',
      'khWWWWWWWWWWpppppppppppk.',
      'khppppppppppWWWqWWWWqWgk.',
      'khWWWWWWWWWWWWWWWWWWWWgk.',
      '.khWWWWWWWWWWWWWWWWWWWgk.',
      '.khWqWWWWqWWWWqWWWWqWWWhk',
      '.khWWWWWWWWWWWWWWWWWWWWgk',
      '.khWWWWWWWWWWgggggggggggk',
      '.khqggggqggggkkkkkkkkkkk.',
      '.khkkkkkkkkkk............',
      '..k......................',
    ] },
    flossPick: { p: {'k': '#0f3a40', 'T': '#2fc9b8', 't': '#9ff3ea', 'D': '#1a8a80', 's': '#ffffff'}, r: [
      '...................kk.....kk..',
      '..................kttkkkkkttk.',
      '..................ktsssssssDk.',
      '.................ktTDkkkkktTtk',
      '.................ktTDk...ktTDk',
      '......kkkkkkkkkkkktTDk...ktTDk',
      '...kkkttttttttttttTTDk...ktTDk',
      '.kktttTTTTTTTTTTTTTTDkkkkktTDk',
      'ktttDDTTTTTTTTTTTTTTTtttttTTDk',
      '.kkkkktDDDDDDDDDDDTTTTTTTTTTDk',
      '......kkkkkkkkkkkktDDDDDDDDDDk',
      '..................kkkkkkkkkkk.',
    ] },
    qtip: { p: {'k': '#7a8290', 'W': '#f6f8fa', 'h': '#ffffff', 'g': '#d3d9e0', 'S': '#cfe6ff', 's': '#9fbad6'}, r: [
      '..kkkk..............kkkk..',
      '.khhhhk............khhhhk.',
      'khWWWWhkkkkkkkkkkkkhWWWWhk',
      'hWWWWWWhhhhhhhhhhhhWWWWWWh',
      'hWWWWWWgssssssssssgWWWWWWg',
      'khWWWWgkkkkkkkkkkkkhWWWWgk',
      '.khgggk............khgggk.',
      '..kkkk..............kkkk..',
    ] },
    gum: { p: {'k': '#8e2a5a', 'P': '#ff8fc6', 'p': '#ffd0e8', 'D': '#d85a98'}, r: [
      '....kkkkkk....',
      '..kkppppppkk..',
      '.kppPPPPPPppk.',
      'kpPPPPPPPPPPpk',
      'kpPPPDPPPPPPDk',
      'kpPPPPPPPPPPDk',
      'kpPPPPPPPDPPDk',
      '.kpDPPPPPPDDk.',
      '..kkpDDDDDkk..',
      '....kkkkkk....',
    ] },
    bandaid: { p: {'k': '#8a5a34', 'B': '#e8b07a', 'b': '#f6cfa0', 'd': '#c98a54', 'P': '#fff3e6'}, r: [
      '..kkkkkkkkkkkkkkkkkkk...',
      '.kbbbbbbbbbbbbbbbbbbbk..',
      'kbBBBBBBBPPPPPPBBBBBBbk.',
      'bBBBBdBBBPPPPPPBBdBBBBbk',
      'bBBBBBBBBPPPPPPBBBBBBBdk',
      'bBBdBBBBBPPPPPPBBBBBdBdk',
      'bBBBBdBBBPPPPPPBBdBBBBdk',
      'kbBBBBBBBPPPPPPBBBBBBdk.',
      '.kbddddddddddddddddddk..',
      '..kkkkkkkkkkkkkkkkkkk...',
    ] },
    soapBar: { p: {'k': '#3a6a8a', 'S': '#9fe0ff', 's': '#dff6ff', 'h': '#ffffff', 'D': '#5fb0e0', 'b': '#e8fbff'}, r: [
      '.............kbbk...',
      '...kk.......kbbbbk..',
      '..kbbk......kbbbbkk.',
      '..kbbkkkkkkkkkbbkbbk',
      '...kkksssssssskkkbbk',
      '..ksssSSSSSSSSssskk.',
      '.ksShhhhhhhhhhSSSsk.',
      'ksShhhhhhhhhhhhSSSsk',
      'ksSShhhhhhhhhhSSSSDk',
      'ksSSSSSSSSSSSSSSSSDk',
      'ksSSSSSSSSSSSSSSSSDk',
      'ksSSSSSSSSSSSSSSSSDk',
      '.ksDSSSSSSSSSSSSDDk.',
      '..kksDSSSSSSSSDDkk..',
      '....kksDDDDDDDkk....',
      '......kkkkkkkk......',
    ] },
    ring: { p: {'k': '#5a3a08', 'Y': '#ffd23f', 'y': '#fff3b0', 'D': '#c99a20', 'G': '#7ae8ff', 'x': '#ffffff'}, r: [
      '.....kkkkkkk....',
      '....kGGGGGGGk...',
      '...kGGxxGGGGGk..',
      '..kGGGGGGGxGGGk.',
      '...kGGGGGGGGGk..',
      '..kyyYGGGGGyyk..',
      '.kyYDDkGGGyDYyk.',
      'kyYDkk.kGkkkyYyk',
      'kyYDk...k..kyYDk',
      'kyYDk......kyYDk',
      'kyYDkk....kkyYDk',
      '.kyYyykkkkyyYDk.',
      '..kyDYyyyyYDDk..',
      '...kkyDDDDDkk...',
      '.....kkkkkk.....',
    ] },
    lego: { p: {'k': '#4a0808', 'R': '#ff3a3a', 'r': '#ff9a9a', 'D': '#b81a1a'}, r: [
      '..kkk.kkk..kkk.kkk..',
      '.krrrkrrrkkrrrkrrrk.',
      '.krrDkrrDkkrrDkrrDk.',
      '.krRDkrRDkkrRDkrRDk.',
      'krRRRrRRRrrRRRrRRRrk',
      'krRRRRRRRRRRRRRRRRDk',
      'krRRRRRRRRRRRRRRRRDk',
      'krRRRRRRRRRRRRRRRRDk',
      'krRRRRRRRRRRRRRRRRDk',
      'krRRRRRRRRRRRRRRRRDk',
      'krRRRRRRRRRRRRRRRRDk',
      'krRRRRRRRRRRRRRRRRDk',
      'krDDDDDDDDDDDDDDDDDk',
      '.kkkkkkkkkkkkkkkkkk.',
    ] },
    keys: { p: {'k': '#2a2a34', 'Y': '#e0b040', 'y': '#fff0a0', 'D': '#a07a20', 'S': '#c8ccd6', 's': '#ffffff', 'd': '#8a8ea0', 'B': '#ff5a5a'}, r: [
      '....kkkk.................',
      '..kkyyyykkkkkk...........',
      '.kyyDDDDyyssssk..........',
      '.kyDkkkkySSSSSskkkkkkkkk.',
      'kyDk....ksSSSSSsssssssssk',
      'kyDk....ksSSSSSSSSSSSSSdk',
      'kyDk....ksSSSSdddddSSdSdk',
      'kyDk...kBBBBSdkkkkksdksdk',
      '.kyykkkkBBBBBBBBBBBSdksdk',
      '.kyDyyyyBBBBBBBBBBBddkkk.',
      '..kkyDDDBBBBkkkkkkkkk....',
      '....kkkkkkkk.............',
    ] },
    phone: { p: {'k': '#0a0a0e', 'B': '#2a2a34', 'b': '#4a4a58', 's': '#2a8ad0', 'a': '#ffffff', 'c': '#ff5a8a', 'w': '#9fe8ff'}, r: [
      '.kkkkkkkkkkkkkk.',
      'kbbbbbbbbbbbbbbk',
      'kbBBBBkkkkBBBBk.',
      'kbBBBBBBBBBBBBk.',
      'kbBssssssssssBk.',
      'kbBssssssssssBk.',
      'kbBsaasccsaasBk.',
      'kbBsaasccsaasBk.',
      'kbBssssssssssBk.',
      'kbBssssssssssBk.',
      'kbBsccsaasccsBk.',
      'kbBsccsaasccsBk.',
      'kbBssssssssssBk.',
      'kbBssssssssssBk.',
      'kbBsaasaassssBk.',
      'kbBsaasaassssBk.',
      'kbBssssssssssBk.',
      'kbBssssssssssBk.',
      'kbBswwwwwwwwsBk.',
      'kbBssssssssssBk.',
      'kbBssssssssssBk.',
      'kbBBBBBBBBBBBBk.',
      'kbBBBBbbbbBBBBk.',
      'kbBBBBBBBBBBBBk.',
      'kbkkkkkkkkkkkkk.',
      '.k..............',
    ] },
    coin: { p: {'k': '#6a4a08', 'Y': '#f3cd66', 'y': '#fff3b0', 'D': '#c99a35'}, r: [
      '....kkkk....',
      '..kkyyyykk..',
      '.kyyYYYYyyk.',
      '.kyYYYYYYDk.',
      'kyYYDDDDYYyk',
      'kyYYDyDDYYDk',
      'kyYYDDDDYYDk',
      'kyYYDDDDYYDk',
      '.kyYYYYYYDk.',
      '.kyDYYYYDDk.',
      '..kkyDDDkk..',
      '....kkkk....',
    ] },
    duckling: { p: {'k': '#3a2a04', 'y': '#ffd23f', 'h': '#fff2a6', 'd': '#d99a10', 'o': '#ff8a1f', 'e': '#141414'}, r: [
      '..........kkkk....',
      '.........khhhhk...',
      '........khyyyyhk..',
      '....kkkkkhyyeydk..',
      '..kkhhhhhyyyyyyokk',
      '.khhyyyyyyyyyydooo',
      'khyyyyyyyyyyydkokk',
      'khyyyyyyyyyydk.k..',
      'khyyyyyyyyyydk....',
      'khyyyyyyyyyydk....',
      '.khdyyyyyyddk.....',
      '..kkhdddddkk......',
      '....kkkkkk........',
    ] },
    mouse0: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#000', 'c': '#000', 'y': '#ffffff'}, r: [
      '....................kk..........',
      '...................khhk.........',
      '..................khGGhk........',
      '.................khGppGhkkk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      't.....khhGGGGGGGGGGGGGGGGGGGgk..',
      't....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '..t.kttGGGGGGGGGGGGGGGGGGGGGggkk',
      '...tthGGGGGGGGGGGGGGGGGGggggkk..',
      '.....khGGGGGGGGGGGGGGGGgkkkk....',
      '......khgGGGGGGGGGGGGggk........',
      '.......kkhGggGGgggGGgkhhk.......',
      '........khgkkhgkkkhgkkhgk.......',
      '........khgkkhgk.khgk.kk........',
      '.........kk..kk...kk............',
    ] },
    mouse1: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#000', 'c': '#000', 'y': '#ffffff'}, r: [
      '....................kk..........',
      '...................khhk.........',
      '..................khGGhk........',
      '.................khGppGhkkk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      '......khhGGGGGGGGGGGGGGGGGGGgk..',
      '.....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '....khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '....khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '....khtGGGGGGGGGGGGGGGGGGGGGggkk',
      '....ttGGGGGGGGGGGGGGGGGGggggkk..',
      '...t.khGGGGGGGGGGGGGGGGgkkkk....',
      '.tt...khgGGGGGGGGGGGGggkk.......',
      't......kkhggggGGgGGggkkhhk......',
      't......khgkkkkhgkhgkk.khgk......',
      '.......khgk..khgkhgk...kk.......',
      '........kk....kk.kk.............',
    ] },
    roach: { p: {'k': '#140802', 'B': '#7a3a14', 'h': '#c0703a', 'D': '#4a2008', 'b': '#3a1a08', 'l': '#3a1a08'}, r: [
      '.k....klk.....k......',
      'klk...klk....klk....k',
      '.klk..kklkkkklk....kl',
      '..klkkhhlbhhklk....kl',
      '..khlhBBBbBBlhhkkkkkl',
      '.khBBBBBBbBBBBBhhhhlk',
      'khBBBBBBBbBBBBBBBBBlk',
      'khBBBBBBBbBBBBBBBBBDk',
      'khBBBBBBBbBBBBBBBBBDk',
      'khBBBBBBBbBBBBBBBBBDk',
      '.khBBBBBBbBBBBBDDDDlk',
      '..khDDBBBbBBDDDkkkklk',
      '...klkhDDbDDlkk....kl',
      '..klk.kklbkkklk....kl',
      '.klk..klkk..klk....kl',
      'klk...klk....klk....k',
    ] },
    pizza: { p: {'k': '#5a3010', 'C': '#e8a84a', 'c': '#ffd07a', 'D': '#b07020', 'Y': '#ffe08a', 'R': '#d8382a', 'g': '#5a9a30'}, r: [
      '.kkkkkkkkkkkkkkkkkkkk.',
      'kcccccccccccccccccccck',
      'kcCCCCCCCCCCCCCCCCCCDk',
      'kcCCCCCCCCCCCCRRCCCCDk',
      '.kYYYggYYYYYYRRRRYYYk.',
      '..kYRRRRYYYYRRRRRYYk..',
      '..kYRRRRYYYRRRRRYYYk..',
      '...kYRRYYYYRRRRYYYk...',
      '...kYYYYYggYRRYYYYk...',
      '....kYYYYYYYYYYYYk....',
      '....kYYYYRRYYYYYYk....',
      '.....kYYRRRRYYYYk.....',
      '......kYRRRRYYYYk.....',
      '......kYYRRYYYYk......',
      '.......kYYYYggYk......',
      '.......kYYYYYYk.......',
      '........kYYYYYk.......',
      '........kYYYYk........',
      '.........kYYYk........',
      '.........kYYk.........',
      '..........kYk.........',
      '...........k..........',
    ] },
    gatorEyes: { p: {'k': '#0a1a08', 'G': '#3a6a2a', 'g': '#6a9a4a', 'D': '#1e3a14', 'Y': '#f0ff4a', 'p': '#000000'}, r: [
      '....kkkk..........kkkk....',
      '..kkggggkk......kkggggkk..',
      '.kggYYYYggk....kggYYYYggk.',
      'kgGYYYpYYGgk..kgGYYYpYYGgk',
      'kgGYYYpYYGDk..kgGYYYpYYGDk',
      'kgGGYYpYGGDkkkkgGGYYpYGGDk',
      'kgGGGGGGGGGggggGGGGGGGGGDk',
      '.kgDGGGGGGGGGGGGGGGGGGDDk.',
      '..kkgDDDDDDDDDDDDDDDDDkk..',
      '....kkkkkkkkkkkkkkkkkk....',
    ] },
    crownMouse: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#000', 'c': '#000', 'y': '#ffffff'}, r: [
      '...................Y..Y..Y......',
      '...................YYYYYYY......',
      '...................YYYrYYY......',
      '...................YYYYYYY......',
      '...................khhk.........',
      '..................khGGhk........',
      '.................khGppGhkkk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      't.....khhGGGGGGGGGGGGGGGGGGGgk..',
      't....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '..t.kttGGGGGGGGGGGGGGGGGGGGGggkk',
      '...tthGGGGGGGGGGGGGGGGGGggggkk..',
      '.....khGGGGGGGGGGGGGGGGgkkkk....',
      '......khgGGGGGGGGGGGGggk........',
      '.......kkhGggGGgggGGgkhhk.......',
      '........khgkkhgkkkhgkkhgk.......',
      '........khgkkhgk.khgk.kk........',
      '.........kk..kk...kk............',
    ] },
    cheese: { p: {'k': '#7a5410', 'Y': '#ffd23f', 'y': '#fff0a0', 'D': '#e0a820', 'h': '#c08a10'}, r: [
      '................k.......',
      '..............kkyk......',
      '...........kkkyyyyk.....',
      '.........kkyyyyyyyykk...',
      '......kkkyyyyyyyyyyyyk..',
      '....kkyyyhhyyyyyyyyyyyk.',
      '.kkkyyyyyhhyyyyyyyyyyyyk',
      'kyyyyyyyyyyyyyyYYYYYYYYk',
      'kYYYYYYyYYYYYYYYYYYYYYYk',
      'kYYYYYYYYYYYYYYYYYYYYYYk',
      'kYYYYhhYYYYYhhYYYYYYYYYk',
      'kYYYhhhhYYYYhhYYYYYYYYYk',
      'kYYYhhhhYYYYYYYYYhhYYYYk',
      'kYYYYhhYYYYYYYYYYhhYYYYk',
      'kYYYYYYYYYYYYYYYYYYYYYYk',
      'kDDDDDDDDDDDDDDDDDDDDDDk',
      'kDDDDDDDDDDDDDDDDDDDDDDk',
      '.kkkkkkkkkkkkkkkkkkkkkk.',
    ] },
    chain: { p: {'k': '#5a3a08', 'Y': '#ffd23f', 'y': '#fff3b0', 'D': '#c99a20'}, r: [
      '..kk........kk........kk...',
      '.kyyk.kkkk.kyyk.kkkk.kyyk..',
      'kyDDykyyyykyDDykyyyykyDDyk.',
      'yDkkyyDkkyyDkkyyDkkyyDkkyyk',
      'yDkkyDDkkyDDkkyDDkkyDDkkyDk',
      'kyyyDkyyyDkyyyDkyyyDkyyyDk.',
      '.kyDk.kkkk.kyDk.kkkk.kyDk..',
      '..kk........kk........kk...',
    ] },
    partyMouse: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#ff3fb4', 'c': '#7dff6a', 'y': '#ffffff'}, r: [
      '......................y.........',
      '......................H.........',
      '.....................HHH........',
      '....................kHccc.......',
      '...................kccHHH.......',
      '..................khHHHHH.......',
      '.................khHHHHHHHk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      't.....khhGGGGGGGGGGGGGGGGGGGgk..',
      't....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '..t.kttGGGGGGGGGGGGGGGGGGGGGggkk',
      '...tthGGGGGGGGGGGGGGGGGGggggkk..',
      '.....khGGGGGGGGGGGGGGGGgkkkk....',
      '......khgGGGGGGGGGGGGggk........',
      '.......kkhGggGGgggGGgkhhk.......',
      '........khgkkhgkkkhgkkhgk.......',
      '........khgkkhgk.khgk.kk........',
      '.........kk..kk...kk............',
    ] },
    disco: { p: {'k': '#2a2a3a', 'a': '#ffffff', 'b': '#c8d4e8', 'c': '#8a9ab8', 'd': '#4a5a78', 'm': '#ff9fe8', 'n': '#9fe8ff'}, r: [
      '........kkkkkk........',
      '......kkcdaadbkk......',
      '....kkdccdaadbbdkk....',
      '...kddddddddddddddk...',
      '..kdccdaadbbdccdaadk..',
      '..kdcaaaadbbdccdaadk..',
      '.kddaaaaaadddddmddddk.',
      '.kcdaaaaaaccdaadbbdck.',
      'kccdaaaaadccdaadbbdcck',
      'kddddddddddddddddddddk',
      'kaadbbdccdaadbbdccdaak',
      'kaadbbdccdaadbbdccdaak',
      'kddddddddddddddddddddk',
      'kbbdccdaadbbdccdaadbbk',
      '.kbdccnaadbbdccdaadbk.',
      '.kddddddddddddmdddddk.',
      '..kdaadbbdccdaadbbdk..',
      '..kdaadbbdccdaadbbdk..',
      '...kddddddddddddddk...',
      '....kkdccdaadbbdkk....',
      '......kkcdaadbkk......',
      '........kkkkkk........',
    ] },
    boombox: { p: {'k': '#08080e', 'B': '#2a2a3a', 'b': '#4a4a5e', 'S': '#9a9ab4', 'n': '#7dff6a', 'm': '#0a2a08'}, r: [
      '.......kkkkkkkkkkkkkk.......',
      '......kSSSSSSSSSSSSSSk......',
      '......kSSSSSSSSSSSSSSk......',
      '.....kSSkkkkkkkkkkkkSSk.....',
      '.kkkkkSkkkkkkkkkkkkkkSkkkkk.',
      'kbbbbSSbbbbbbbbbbbbbbSSbbbbk',
      'kbBBBBBBBBBBBBBBBBBBBBBBBBk.',
      'kbBBkkkkkkBnnnnnnkkkkkkBBBk.',
      'kbBkkkkkkkknmnmnnkkkkkkkBBk.',
      'kbBkkkSSkkknnnnnnkkSSkkkBBk.',
      'kbBkkSSSSkkBBBBBkkSSSSkkBBk.',
      'kbBkkSSSSkkBBBBBkkSSSSkkBBk.',
      'kbBkkkSSkkkbbbbbbkkSSkkkBBk.',
      'kbBkkkkkkkkbbbbbbkkkkkkkBBk.',
      'kbBBkkkkkkBBBBBBBkkkkkkBBBk.',
      'kbBBBBBBBBBBBBBBBBBBBBBBBBk.',
      'kbkkkkkkkkkkkkkkkkkkkkkkkkk.',
      '.k..........................',
    ] },
    glowstick: { p: {'k': '#0a2a08', 'G': '#7dff6a', 'g': '#e0ffd8'}, r: [
      '.kkkk.',
      'kGGGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGgGGk',
      'kGGGGk',
      'kGGGGk',
      '.kkkk.',
    ] },
    partyMouseB: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#4ad0ff', 'c': '#ffe14a', 'y': '#ffffff'}, r: [
      '......................y.........',
      '......................H.........',
      '.....................HHH........',
      '....................kHccc.......',
      '...................kccHHH.......',
      '..................khHHHHH.......',
      '.................khHHHHHHHk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      't.....khhGGGGGGGGGGGGGGGGGGGgk..',
      't....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '..t.kttGGGGGGGGGGGGGGGGGGGGGggkk',
      '...tthGGGGGGGGGGGGGGGGGGggggkk..',
      '.....khGGGGGGGGGGGGGGGGgkkkk....',
      '......khgGGGGGGGGGGGGggk........',
      '.......kkhGggGGgggGGgkhhk.......',
      '........khgkkhgkkkhgkkhgk.......',
      '........khgkkhgk.khgk.kk........',
      '.........kk..kk...kk............',
    ] },
    partyMouseC: { p: {'k': '#14141c', 'G': '#a3a3b2', 'h': '#d0d0dc', 'g': '#6e6e7c', 'p': '#ffa3b8', 'e': '#000000', 'n': '#ff7f9c', 't': '#ffa3b8', 'Y': '#ffd23f', 'r': '#ff3f6a', 'H': '#7dff6a', 'c': '#ff3fb4', 'y': '#ffffff'}, r: [
      '......................y.........',
      '......................H.........',
      '.....................HHH........',
      '....................kHccc.......',
      '...................kccHHH.......',
      '..................khHHHHH.......',
      '.................khHHHHHHHk.....',
      '.........kkkkkkkkkhGppGGhhhkk...',
      '.......kkhhhhhhhhhGGppGGGGGhhk..',
      't.....khhGGGGGGGGGGGGGGGGGGGgk..',
      't....khGGGGGGGGGGGGGGGGGGGeGgkk.',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGhhk',
      '.t..khGGGGGGGGGGGGGGGGGGGGGGGGgn',
      '..t.kttGGGGGGGGGGGGGGGGGGGGGggkk',
      '...tthGGGGGGGGGGGGGGGGGGggggkk..',
      '.....khGGGGGGGGGGGGGGGGgkkkk....',
      '......khgGGGGGGGGGGGGggk........',
      '.......kkhGggGGgggGGgkhhk.......',
      '........khgkkhgkkkhgkkhgk.......',
      '........khgkkhgk.khgk.kk........',
      '.........kk..kk...kk............',
    ] },
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
      '.......kccdbbaacaadaaaacbk......',
      '.......kcccbbaacaaaaabdcck......',
      '........kabbbaadaaaabbgbek......',
      '.........kcabaacaaaaabebk.......',
      '..........kkbaaccaaaaabbk.......',
      '............kcaaddbbabcek.......',
      '............kdcaabbababck.......',
      '.............kkcaaaaaabck.......',
      '...............kkkkkkkkk........',
      '................................',
      '................................',
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
    sock: { p: {'k': '#3a3a44', 'W': '#f0f0f4', 'h': '#ffffff', 'g': '#c0c4cc', 'R': '#ff5a5a', 'G': '#c8ccd6'}, r: [
      '.kkkkkkkkk.......',
      'kGGGGGGGGGk......',
      'kGGGGGGGGGk......',
      'khWWWWWWWgk......',
      'kRRRRRRRRRk......',
      'kRRRRRRRRRk......',
      'khWWWWWWWgk......',
      'khWWWWWWWgk......',
      'khWWWWWWWgk......',
      'kRRRRRRRRRk......',
      'kRRRRRRRRRk......',
      'khWWWWWWWgk......',
      'khWWWWWWWgk......',
      'khWWWWWWWgkkk....',
      'khWWWWWWWWhhhkkk.',
      'khWWWWWWWWWWWhhhk',
      'khWWWWWWWWWWWWWgk',
      '.khWWWWWWWWWWWWgk',
      '..khWWWWWWWWWWWgk',
      '...khWWWWWWWWWWgk',
      '....khggggggggggk',
      '.....kkkkkkkkkkk.',
    ] },
    airpod: { p: {'k': '#5d6670', 'W': '#f4f6f8', 'h': '#ffffff', 'g': '#c0c8d0', 'm': '#3a3a44'}, r: [
      '..kkkkkk..',
      '.khhhhhhk.',
      'khWmmWWWhk',
      'khWmmWWWgk',
      'khWWWWWWgk',
      'khWWWWWWgk',
      '.khgWWWgk.',
      '..kkhWgk..',
      '...khWgk..',
      '...khWgk..',
      '...khWgk..',
      '...khWgk..',
      '...khWgk..',
      '...khWgk..',
      '...khggk..',
      '....kkk...',
    ] },
    toothbrush: { p: {'k': '#2a1a4a', 'H': '#8a6aff', 'h': '#c8b8ff', 'D': '#5a3ad0', 'b': '#ffffff'}, r: [
      '...................k.k.k.k..',
      '..................kbkbkbkbk.',
      '....kkkkkkkkkkkkkkkbkbkbkbk.',
      '...khhhhhhhhhhhhhhhbkbkbkbk.',
      '.kkhHHHHHHHHHHHHHHHHhHhHhHhk',
      'khhHHHHHHHHHHHHHHHHHHHHHHHDk',
      '.kkhHDDDDDDDDDDDDDDDDDDDDDDk',
      '...khkkkkkkkkkkkkkkkkkkkkkk.',
      '....k.......................',
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
  const midX = () => (O.W / 2 - 8) / O.W; // the duck's home: dead center of the drain
  const shrimpX = () => Math.round(O.W * (O.sxf !== undefined ? O.sxf : midX()));

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

  // The duck sits in the bowl on the title screen. Starting a game flushes it, gently:
  // the water starts to swirl and the duck rocks, then it goes "whoops" (a little hop and one backflip),
  // then it drifts to the middle and gets pulled down out of sight behind the bowl.
  const FLUSH_SWIRL = 2300, FLUSH_DROP = 750;
  function flushP() { return O.flushT0 ? (performance.now() - O.flushT0) / FLUSH_SWIRL : -1; }
  const easeIO = x => x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;
  function drawDuckInBowl(ctx, bs, bx, ty, k) {
    const p = O.view === 'intro' ? (O.reduced ? 1 : flushP()) : -1;
    const cx = bx + Math.round(bs.w * k / 2), rimY = ty + 6 * k, bowlR = 6.5 * k;
    const ds = sprite('duck0');
    const ds0 = k * 0.42;
    if (p >= 0 && p < 1.05) { // calm swirl of foam that slowly tightens
      const sw = clamp(p / 0.9, 0, 1), n = 16;
      for (let i = 0; i < n; i++) {
        const a = O.t * (2.5 + sw * 5) + i * (Math.PI * 2 / n);
        const r = bowlR * (0.85 - sw * 0.45) * (0.7 + 0.3 * ((i * 7) % 5) / 4);
        ctx.fillStyle = i % 4 ? 'rgba(159,214,224,0.9)' : '#ffffff';
        ctx.fillRect(Math.round(cx + Math.cos(a) * r), Math.round(rimY + 2 + Math.sin(a) * r * 0.22), 2, 1);
      }
    }
    if (p >= 1) { ctx.drawImage(bs.c, 0, 7, bs.w, bs.h - 7, bx, ty + 7 * k, bs.w * k, (bs.h - 7) * k); return; }
    let dx = 0, dy = 0, rot = 0, s = ds0;
    if (p < 0) { dy = Math.sin(O.t * 1.8) * 1.5; rot = Math.sin(O.t * 1.3) * 0.08; }
    else if (p < 0.3) { // rocking on the swirl
      const q = p / 0.3; dx = Math.sin(O.t * 3) * bowlR * 0.18 * q; rot = Math.sin(O.t * 5) * 0.22 * q; dy = Math.sin(O.t * 4) * 0.8;
    } else if (p < 0.58) { // whoops: a little hop and one clean backflip
      const q = (p - 0.3) / 0.28; dy = -Math.sin(Math.PI * q) * k * 3.2; rot = -easeIO(q) * Math.PI * 2;
    } else { // pulled to the middle and down out of sight
      const q = (p - 0.58) / 0.42, e = easeIO(q);
      rot = Math.sin(O.t * 6) * 0.15 * (1 - q); dy = e * ds.h * ds0 * 1.15; s = ds0 * (1 - e * 0.25);
    }
    const cy = rimY + 2 - ds.h * ds0 / 2 + dy;
    ctx.save(); ctx.translate(Math.round(cx + dx), Math.round(cy)); ctx.rotate(rot);
    ctx.drawImage(ds.c, Math.round(-ds.w * s / 2), Math.round(-ds.h * s / 2), Math.round(ds.w * s), Math.round(ds.h * s)); ctx.restore();
    ctx.drawImage(bs.c, 0, 7, bs.w, bs.h - 7, bx, ty + 7 * k, bs.w * k, (bs.h - 7) * k); // bowl front hides the duck as it goes down
  }

  function zoneCreatures(z, rnd) {
    // what floats past in each zone: bathroom junk → lost stuff in the pipes → sewer critters → rat royalty → the rave
    const pick = arr => arr[Math.floor(rnd * arr.length) % arr.length];
    if (z === 0) return pick(['tpWad', 'tpWad', 'tpSheet', 'flossPick', 'qtip', 'gum', 'bandaid', 'soapBar', 'toothbrush', 'tpWad', 'duckling']);
    if (z === 1) return pick(['tpWad', 'ring', 'lego', 'keys', 'phone', 'coin', 'sock', 'airpod', 'goldfish', 'flossPick', 'duckling', 'tpSheet']);
    if (z === 2) return pick(['mouse', 'mouse', 'rat', 'rat', 'pizza', 'gatorEyes', 'sludge', 'tpWad', 'coin', 'mouse']);
    if (z === 3) return pick(['crownMouse', 'ratking', 'cheese', 'chain', 'crownMouse', 'coin', 'coin', 'rat', 'cheese', 'ratking']);
    return pick(['partyMouse', 'partyMouse', 'disco', 'boombox', 'partyMouse', 'cheese', 'disco', 'auraBlob']);
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
        const dd = dz(realM); if (dd < SEWER_TOP + 100) continue; // nothing murky floating in the bowl or the pipe
        const name = big ? 'fatberg' : dd < 1000 ? 'tpWad' : (hash(s + 7) > 0.5 ? 'mouse0' : 'rat0');
        const w = big ? 24 : 32; const span = O.W + w * 2;
        let x = ((hash(s + 2) * span + O.t * sp) % span + span) % span - w;
        ctx.globalAlpha = 0.35; drawSprite(ctx, name, x, y, dir < 0, tint); ctx.globalAlpha = 1;
      }
    }
  }

  function drawCreatures(ctx) {
    const ppm = O.ppm; const CH = 55;
    const c0 = Math.floor(O.topM / CH) - 1, c1 = Math.floor((O.topM + O.H / ppm) / CH) + 1;
    for (let c = c0; c <= c1; c++) {
      if (c < 0) continue;
      const midM = c * CH + CH / 2; const z = zoneIndex(dz(midM));
      const n = dz(c * CH) > Z_MAD ? 2 + (hash(c * 13) > 0.5 ? 1 : 0) : hash(c * 7) > 0.45 ? 1 : (hash(c * 11) > 0.75 ? 2 : 0); // the insane zone is packed
      for (let k = 0; k < n; k++) {
        const s = c * 97 + k * 31 + 5;
        const mad = dz(midM) > Z_MAD;
        const type = mad ? ['partyMouse', 'goldtoilet', 'duckling', 'disco', 'partyMouseB', 'ratking', 'partyMouseC', 'cheese'][Math.floor(hash(s) * 8)] : zoneCreatures(z, hash(s));
        const m = c * CH + 6 + hash(s + 1) * (CH - 12);
        let y = (m - O.topM) * ppm;
        if (y < -30 || y > O.H + 30) continue;
        const dir = hash(s + 2) > 0.5 ? 1 : -1;
        const swims = mad || ['mouse', 'rat', 'goldfish', 'crownMouse', 'partyMouse'].includes(type);
        const sp = mad ? 14 + hash(s + 3) * 20 : swims ? 4 + hash(s + 3) * 7 : 1.2 + hash(s + 3) * 2.2;
        const span = O.W + 40;
        const x = ((hash(s + 4) * span + O.t * sp * dir) % span + span) % span - 20;
        const ph = hash(s + 5) * 6.28;
        const bob = Math.round(Math.sin(O.t * (swims ? 3 : 1.4) + ph) * (swims ? 1 : 2));
        const yy = y + bob;
        const dd = dz(m), wl = dd < SEWER_TOP ? pipeW(dd) : wallAt(dd, 0) + 2, wr = dd < SEWER_TOP ? pipeW(dd) : wallAt(dd, 1) + 2;
        ctx.save(); ctx.beginPath(); ctx.rect(Math.round(wl), yy - 40, Math.round(O.W - wl - wr), 80); ctx.clip();
        if (mad) { // a rainbow trail streaming behind
          const RB = ['#ff3f6a', '#ff9a2a', '#ffe14a', '#7dff6a', '#4ad0ff', '#c58bff'], len = 26;
          for (let k = 0; k < len; k += 2) for (let b = 0; b < 6; b++) {
            ctx.fillStyle = RB[b]; ctx.globalAlpha = 0.75 * (1 - k / len);
            ctx.fillRect(Math.round(dir > 0 ? x - k : x + 22 + k), Math.round(yy + 3 + b + Math.sin(O.t * 8 + k * 0.4) * 1.5), 2, 1);
          }
          ctx.globalAlpha = 1;
        }
        drawOne(ctx, type, x, y, yy, dir, ph, s, z, swims);
        ctx.restore();
      }
    }
  }
  function drawOne(ctx, type, x, y, yy, dir, ph, s, z, swims) {
    {
      {
        if (type === 'goldfish') { drawSprite(ctx, 'fish', x, yy, dir < 0, '~#ff8a3d'); return; }
        if (type === 'mouse' || type === 'rat') { drawSprite(ctx, type + (Math.floor(O.t * 6 + ph) % 2), x, yy, dir < 0); return; }
        if (type === 'partyMouse') {
          const v = ['partyMouse', 'partyMouseB', 'partyMouseC'][Math.floor(hash(s + 8) * 3)];
          drawSprite(ctx, v, x, y - Math.round(beatPulse() * 3), dir < 0); return;
        }
        if (type === 'tpWad' && z >= 2) { drawSprite(ctx, 'tpWad', x, yy, false, '~#c8c09a'); return; } // soggy sewer wad
        const G = { phone: [80, 200, 255, 0.22], glowstick: [125, 255, 106, 0.35], disco: [255, 255, 255, 0.2], sludge: [125, 255, 106, 0.2],
                    auraBlob: [197, 139, 255, 0.2], ratking: [255, 213, 74, 0.2], cheese: [255, 213, 74, 0.12], gatorEyes: [240, 255, 74, 0.18] }[type];
        if (type === 'gatorEyes' && (Math.floor(O.t * 1.3 + ph) % 5 === 0)) return; // blink
        if (G) glow(ctx, x + 6, yy + 4, 9, G.slice(0, 3), G[3] + 0.06 * Math.sin(O.t * 2 + ph));
        drawSprite(ctx, type, x, yy, swims ? dir < 0 : hash(s + 6) > 0.5);
        if ((type === 'ring' || type === 'coin' || type === 'disco') && Math.sin(O.t * 4 + ph) > 0.85) { // sparkle
          ctx.fillStyle = '#ffffff'; const sx = Math.round(x + 2 + hash(s + 9) * 5), sy = Math.round(yy + 1);
          ctx.fillRect(sx, sy - 1, 1, 3); ctx.fillRect(sx - 1, sy, 3, 1);
        }
      }
    }
  }

  // the beat of the Brainrot Core (~126 bpm): 1 on the kick, decaying to 0
  const beatPulse = () => Math.pow(1 - ((O.t * 2.1) % 1), 3);

  function drawSnow(ctx) {
    // marine snow / particles drifting; slightly faster parallax than camera
    const n = O.reduced ? 25 : 70;
    const camPx = O.topM * O.ppm * 1.15;
    for (let i = 0; i < n; i++) {
      const x = (hash(i * 3 + 1) * O.W + Math.sin(O.t * 0.3 + i) * 3) % O.W;
      const sp = 3 + hash(i * 5) * 5;
      const y = ((hash(i * 7) * O.H - camPx + O.t * sp) % O.H + O.H) % O.H;
      const m = O.topM + y / O.ppm; if (m < 4) continue;
      const d = dz(m), deep = d > 1000;
      if (d > Z_MAD && i % 3 === 0) { // flashing rainbow stars
        const on = Math.sin(O.t * 6 + i * 1.7) > 0.2; if (!on) continue;
        ctx.fillStyle = ['#ff3f6a', '#ffe14a', '#7dff6a', '#4ad0ff', '#c58bff', '#ffffff'][(i + Math.floor(O.t * 4)) % 6];
        const sx = Math.round(x), sy = Math.round(y); ctx.fillRect(sx, sy - 1, 1, 3); ctx.fillRect(sx - 1, sy, 3, 1); continue;
      }
      if (d > Z_CORE && i % 2 === 0) { // confetti
        ctx.fillStyle = ['#ff3fb4', '#7dff6a', '#4ad0ff', '#ffe14a', '#c58bff'][i % 5];
        ctx.fillRect(Math.round(x), Math.round(y), (i + Math.floor(O.t * 3)) % 2 ? 2 : 1, (i + Math.floor(O.t * 3)) % 2 ? 1 : 2); continue;
      }
      ctx.fillStyle = deep ? (i % 9 === 0 ? (d > Z_RAT ? 'rgba(255,110,200,0.6)' : 'rgba(125,255,106,0.55)') : 'rgba(170,210,170,0.28)') : 'rgba(230,250,255,0.35)';
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
  // One continuous shaft from the bowl down: open bowl water, then the metal drain pipe (its walls grow in
  // as the bowl narrows into the pipe), a heavy collar where the pipe meets the sewer, then brick tunnel
  // walls that keep closing in the deeper you go. Nothing fades in; it's all terrain.
  const PIPE_TOP = 110, SEWER_TOP = 1000;
  const smooth = (a, b, x) => { const q = clamp((x - a) / (b - a), 0, 1); return q * q * (3 - 2 * q); };
  // vertical drain pipes along both edges: [x as a fraction of the width, thickness, where it comes out of the wall (m), where it ends (m)]
  const PIPES = [[0.018, 10, 120, 988], [0.07, 6, 170, 988], [0.93, 7, 145, 988], [0.978, 10, 120, 988]]; // all run down into the sewer archway
  function pipeW(d) { return d < PIPE_TOP ? 0 : O.W * 0.07 + 8; } // how much of each edge the pipes take (for clipping floaters)
  function sewerW(d, side) {
    const n = Math.sin(d * (side ? 0.027 : 0.031) + side * 2) * 6 + Math.sin(d * (side ? 0.09 : 0.11)) * 3;
    const w = O.W * (0.2 + 0.1 * clamp((d - SEWER_TOP) / 5000, 0, 1)) + n;
    return w;
  }
  const BH = 10, BW = 20; // brick size in screen pixels
  const rowDepth = r => (r * BH + BH / 2) / O.ppm - OFF;                          // depth at the middle of brick row r
  const wallAt = (d, side) => Math.round(sewerW(rowDepth(Math.floor(((d + OFF) * O.ppm) / BH)), side)); // wall width, constant per brick row
  function drawTrench(ctx) {
    const ppm = O.ppm;
    const yStart = (PIPE_TOP - 40 + OFF - O.topM) * ppm; if (yStart > O.H) return; // eslint-disable-line
    const floorM = 7120 + OFF; const yFloor = (floorM - O.topM) * ppm;
    const W = O.W;
    drawPipes(ctx);
    // Sewer walls, built one brick row at a time so every edge is crisp and steady while scrolling:
    // one wall width per row (a natural stair-step edge), mortar behind, bricks cut off exactly at the wall,
    // and a soft shadow where the wall meets the tunnel.
    const r0 = Math.floor((O.topM * ppm) / BH) - 1, r1 = Math.ceil(((O.topM * ppm) + O.H) / BH) + 1;
    for (let r = r0; r <= r1; r++) {
      const yb = Math.round(r * BH - O.topM * ppm), d = rowDepth(r);
      if (d < SEWER_TOP) continue;
      const row = wallColors(d);
      for (const side of [0, 1]) {
        const wall = wallAt(d, side); if (wall < 2) continue;
        ctx.fillStyle = row[3]; ctx.fillRect(side ? W - wall : 0, yb, wall, BH);
        const off = (r % 2) * (BW / 2);
        for (let c = 0; c * BW - off < wall; c++) {
          const s = r * 131 + c * 17 + side * 7919;
          const bx0 = Math.max(0, c * BW - off), bx1 = Math.min(c * BW - off + BW - 2, wall - 1);
          if (bx1 - bx0 < 3) continue;
          const w = bx1 - bx0, h = BH - 2, x = side ? W - bx1 : bx0;
          const zc = wallColors(d, (hash(s + 99) - 0.5) * 320); // per-brick jitter = soft, brick-by-brick blend between zones
          ctx.fillStyle = zc[0]; ctx.fillRect(x, yb, w, h);
          ctx.fillStyle = zc[1]; ctx.fillRect(x, yb, w, 1); ctx.fillRect(side ? x + w - 1 : x, yb, 1, h);
          ctx.fillStyle = zc[2]; ctx.fillRect(x, yb + h - 1, w, 1);
          if (hash(s + 4) > 0.84 && w > 8) { ctx.fillStyle = zc[4]; ctx.fillRect(x + 2 + Math.floor(hash(s + 6) * (w - 5)), yb + h - 1, 2, 2 + Math.floor(hash(s + 7) * 3)); } // drips
        }
        ctx.fillStyle = 'rgba(0,0,0,0.32)'; ctx.fillRect(side ? W - wall - 2 : wall, yb, 2, BH); // shadow onto the tunnel
        ctx.fillStyle = row[1]; ctx.fillRect(side ? W - wall : wall - 1, yb, 1, BH - 2);           // lit inner edge
        if (d >= Z_RAT - 150 && d < Z_CORE + 300 && hash(r * 11 + side * 5) > 0.9) { // rat-kingdom torches on the walls
          const tx = side ? W - wall + 3 : wall - 7, ty = yb - 4, fl = Math.sin(O.t * 13 + r) * 0.5 + Math.sin(O.t * 7.3 + r * 2) * 0.5;
          glow(ctx, tx + 2, ty - 3, 14, [255, 170, 60], 0.22 + 0.08 * fl);
          ctx.fillStyle = '#3a2a1a'; ctx.fillRect(tx + 1, ty, 3, 7); ctx.fillStyle = '#7a5a3a'; ctx.fillRect(tx, ty, 5, 2); // bracket
          ctx.fillStyle = '#ff6a1f'; ctx.fillRect(tx + 1, ty - 4, 3, 4); ctx.fillStyle = '#ffd23f'; ctx.fillRect(tx + 2, ty - 5 - Math.round(fl), 1, 4);
          ctx.fillStyle = '#fff3b0'; ctx.fillRect(tx + 2, ty - 2, 1, 1);
        }
        if (hash(r * 7 + side * 13) > 0.94) { // a glowing speck stuck in the mortar
          const gx = side ? W - wall * (0.3 + hash(r + 3) * 0.5) : wall * (0.3 + hash(r + 3) * 0.5);
          const col = d < Z_RAT ? [125, 255, 106] : d < Z_CORE ? [255, 213, 74] : [255, 143, 209];
          glow(ctx, gx, yb + BH - 1, 4, col, 0.3 + 0.2 * Math.sin(O.t * 2 + r)); ctx.fillStyle = rgb(col); ctx.fillRect(Math.round(gx), yb + BH - 1, 1, 1);
        }
      }
    }
    // the sewer starts at a brick archway: a thick lintel across each wall with a keystone, pipes pour out below it
    const ya = Math.round((SEWER_TOP + OFF - O.topM) * ppm);
    if (ya > -20 && ya < O.H + 20) for (const side of [0, 1]) {
      const w = wallAt(SEWER_TOP + 20, side) + 10, x0 = side ? W - w : 0, zc = wallColors(SEWER_TOP + 50);
      ctx.fillStyle = zc[3]; ctx.fillRect(x0, ya - 12, w, 14);
      for (let bx = 0; bx < w; bx += 12) { ctx.fillStyle = zc[0]; ctx.fillRect(side ? W - bx - 11 : bx, ya - 11, 11, 5); ctx.fillRect(side ? W - bx - 5 - 11 : bx + 5, ya - 5, 11, 5); }
      ctx.fillStyle = zc[1]; ctx.fillRect(x0, ya - 12, w, 1);
      ctx.fillStyle = zc[2]; ctx.fillRect(side ? x0 : w - 7, ya - 14, 7, 16); // keystone at the inner corner
    }
    drawLedges(ctx);
  }
  function drawPipes(ctx) {
    const ppm = O.ppm, W = O.W;
    const Y = m => Math.round((m + OFF - O.topM) * ppm);
    PIPES.forEach(([fx, w, top, bot], i) => {
      const x = Math.round(W * fx - w / 2), right = fx > 0.5;
      const y0 = Y(top), y1 = Y(bot); if (y1 < -10 || y0 > O.H + 10) return;
      const ya = Math.max(-2, y0), yb = Math.min(O.H + 2, y1);
      // the pipe body with a round highlight
      ctx.fillStyle = '#4c5660'; ctx.fillRect(x, ya, w, yb - ya);
      ctx.fillStyle = '#6e7b86'; ctx.fillRect(x + 1, ya, 2, yb - ya);
      ctx.fillStyle = '#323a41'; ctx.fillRect(x + w - 2, ya, 2, yb - ya);
      // flanged joints with rivets, fixed to the world so they scroll with it
      for (let m = top + 40 + i * 9; m < bot - 10; m += 60) {
        const y = Y(m); if (y < -6 || y > O.H + 6) continue;
        ctx.fillStyle = '#5d6872'; ctx.fillRect(x - 2, y, w + 4, 4);
        ctx.fillStyle = '#88949f'; ctx.fillRect(x - 2, y, w + 4, 1);
        ctx.fillStyle = '#2a3036'; ctx.fillRect(x - 1, y + 2, 1, 1); ctx.fillRect(x + w, y + 2, 1, 1);
      }
      // top: an elbow that bends back into the wall it comes out of
      if (y0 > -20 && y0 < O.H + 20) {
        const ex0 = right ? x : 0, ew = right ? W - x : x + w;
        ctx.fillStyle = '#4c5660'; ctx.fillRect(ex0, y0 - w, ew, w);
        ctx.fillStyle = '#6e7b86'; ctx.fillRect(ex0, y0 - w + 1, ew, 2);
        ctx.fillStyle = '#323a41'; ctx.fillRect(ex0, y0 - 2, ew, 2);
        ctx.fillStyle = '#5d6872'; ctx.fillRect(right ? x : x + w - 1, y0 - w - 1, 2, w + 2); // bend seam
      }
      // bottom: a collar where the pipe goes into the archway's bricks
      if (y1 > -20 && y1 < O.H + 20) {
        ctx.fillStyle = '#5d6872'; ctx.fillRect(x - 2, y1 - 5, w + 4, 5); ctx.fillStyle = '#88949f'; ctx.fillRect(x - 2, y1 - 5, w + 4, 1);
        ctx.fillStyle = '#2a3036'; ctx.fillRect(x - 1, y1 - 3, 1, 1); ctx.fillRect(x + w, y1 - 3, 1, 1);
      }
    });
  }

  // Ledges: bricks jutting out of the tunnel walls with things sitting on them. Sparse in the sewer,
  // busier in the Rat Kingdom, and in the Brainrot Core it turns into a rave stuck to the walls:
  // party mice dancing on ledges, disco balls hanging underneath, boomboxes, neon brainrot words.
  const WORDS = ['SKIBIDI', 'OHIO', 'RIZZ', 'SIGMA', 'AURA', 'MEWING', 'NPC', 'GOATED', 'COOKED', 'W', 'FANUM TAX', 'GYM', 'SUS', 'LOCK IN'];
  function drawLedges(ctx) {
    const ppm = O.ppm, W = O.W, STEP = 70, kick = beatPulse();
    const top = dz(O.topM) - 60, bot = dz(O.topM + O.H / ppm) + 60;
    for (let L = Math.max(SEWER_TOP + 150, Math.floor(top / STEP) * STEP); L < bot; L += STEP) {
      const s = L * 7 + 13, deepness = clamp((L - Z_CORE) / 2600, 0, 1.4); // keeps climbing past 1 = more insane
      const chance = L < Z_RAT ? 0.16 : L < Z_CORE ? 0.55 : Math.min(0.95, 0.42 + 0.38 * deepness); // gets busier the deeper you go
      if (hash(s) > chance) continue;
      const side = hash(s + 1) > 0.5 ? 1 : 0, y = Math.round(Math.round(((L + OFF) * ppm) / BH) * BH - O.topM * ppm); // sits on a brick course
      const edge = wallAt(L, side), len = 30 + Math.floor(hash(s + 2) * 3) * 6, zc = wallColors(L);
      const x0 = side ? Math.round(W - edge - len) : Math.round(edge - 2);
      // the shelf: two rows of bricks sticking out of the wall
      ctx.fillStyle = zc[2]; ctx.fillRect(x0, y, len + 2, 7);
      ctx.fillStyle = zc[0]; ctx.fillRect(x0 + 1, y, len, 3); ctx.fillRect(x0 + 1, y + 4, len, 2);
      ctx.fillStyle = zc[1]; ctx.fillRect(x0 + 1, y, len, 1);
      ctx.fillStyle = zc[3]; for (let bx = x0 + 6 + (side ? 0 : 3); bx < x0 + len; bx += 9) ctx.fillRect(bx, y + 1, 1, 2);
      const mid = side ? x0 + Math.round(len * 0.4) : x0 + Math.round(len * 0.6), face = side === 0; // things face the middle of the tunnel
      const kind = hash(s + 3);
      if (L < Z_RAT) { // sewer: a mouse peeking out, or a roach
        if (kind < 0.6) drawSprite(ctx, 'mouse0', mid - 15, y - sprite('mouse0').h + 1, side === 1);
        else drawSprite(ctx, 'rat0', mid - 15, y - sprite('rat0').h + 1, side === 1);
      } else if (L < Z_CORE) { // rat kingdom: royalty and riches
        if (kind < 0.45) drawSprite(ctx, 'crownMouse', mid - 15, y - sprite('crownMouse').h + 1, side === 1);
        else if (kind < 0.75) { glow(ctx, mid, y - 6, 10, [255, 213, 74], 0.14); drawSprite(ctx, 'cheese', mid - 11, y - sprite('cheese').h + 1, side === 1); }
        else { drawSprite(ctx, 'coin', mid - 8, y - 11); drawSprite(ctx, 'coin', mid - 2, y - 11); drawSprite(ctx, 'coin', mid - 5, y - 19); }
        if (hash(s + 4) > 0.6) drawSprite(ctx, 'chain', x0 + 2, y + 6); // chain draped off the edge
      } else { // the Brainrot Core: the rave lives on the walls
        const v = ['partyMouse', 'partyMouseB', 'partyMouseC'][Math.floor(hash(s + 5) * 3)], ms = sprite(v);
        const jump = Math.round((Math.floor(L / STEP) % 2 ? kick : Math.pow(1 - ((O.t * 2.1 + 0.5) % 1), 3)) * 3);
        if (kind < 0.5) {
          drawSprite(ctx, v, mid - 15, y - ms.h + 1 - jump, side === 1);
        } else if (kind < 0.75) { // boombox with notes popping out
          drawSprite(ctx, 'boombox', mid - 14, y - sprite('boombox').h + 1);
          ctx.fillStyle = ['#ff3fb4', '#7dff6a', '#4ad0ff'][Math.floor(O.t * 2) % 3];
          const ny = y - 22 - Math.round(((O.t * 12) % 14)); ctx.fillRect(mid + 2, ny, 2, 2); ctx.fillRect(mid + 3, ny - 4, 1, 4);
        } else { // a mouse throwing it down next to a cheese
          drawSprite(ctx, v, mid - 15, y - ms.h + 1 - jump, side === 1);
          drawSprite(ctx, 'cheese', side ? mid + 12 : mid - 34, y - sprite('cheese').h + 1, side === 1);
        }
        // a disco ball hanging under the ledge, throwing beams across the tunnel
        if (hash(s + 7) > 0.45) {
          const bx = side ? x0 + 4 : x0 + len - 4, by = y + 14;
          ctx.fillStyle = '#5a5a6a'; ctx.fillRect(bx, y + 6, 1, 8);
          for (let i = 0; i < 4; i++) {
            const a = O.t * 0.9 + i * 1.57 + hash(s + 8) * 6;
            ctx.fillStyle = rgb(hex(['#ff3fb4', '#7dff6a', '#4ad0ff', '#ffe14a'][i]), (0.06 + 0.05 * kick).toFixed(3));
            ctx.beginPath(); ctx.moveTo(bx, by + 11); ctx.lineTo(bx + Math.cos(a - 0.08) * 90, by + 11 + Math.sin(a - 0.08) * 90); ctx.lineTo(bx + Math.cos(a + 0.08) * 90, by + 11 + Math.sin(a + 0.08) * 90); ctx.fill();
          }
          glow(ctx, bx, by + 11, 14, [255, 255, 255], 0.14 + 0.1 * kick);
          drawSprite(ctx, 'disco', bx - 11, by, Math.floor(O.t * 4) % 2 === 1);
        }
      }
    }
  }

  // 3x5 pixel font for the neon sign
  const GLYPH = { C: '111100100100111', D: '110101101101110', G: '111100101101111', H: '101101111101101', K: '101110100110101',
                  M: '101111111101101', P: '110101110100100', S: '111100111001111', W: '101101111111101', Z: '111001010100111', U: '101101101101111',
                  L: '100100100100111', F: '111100110100100', Y: '101101010010010', X: '101101010101101', '!': '010010010000010',
                  A: '010101111101101', B: '110101110101110', E: '111100110100111', I: '111010010010111', N: '101111111111101', O: '111101101101111',
                  R: '110101110101101', T: '111010010010010', V: '101101101101010', ' ': '000000000000000' };
  function pixText(ctx, str, x, y, col) {
    ctx.fillStyle = col;
    [...str].forEach((ch, i) => { const g = GLYPH[ch] || GLYPH[' ']; for (let p = 0; p < 15; p++) if (g[p] === '1') ctx.fillRect(x + i * 4 + (p % 3), y + Math.floor(p / 3), 1, 1); });
  }
  // The very bottom of the Brainrot Core: a mouse rave. DJ mouse, speaker stacks, a disco ball, a dancing crowd.
  function drawParty(ctx, yF) {
    const W = O.W, cx = Math.round(W / 2), yb = Math.round(yF), kick = beatPulse(), beat = O.t * 2.1;
    const NEON = ['#ff3fb4', '#7dff6a', '#4ad0ff', '#ffe14a', '#c58bff'];
    const ballY = yb - 92;
    // light beams from the disco ball
    for (let i = 0; i < 7; i++) {
      const a = O.t * 0.7 + i * (Math.PI * 2 / 7), len = 120, wdt = 0.09;
      if (Math.sin(a) < -0.2) continue; // only beams pointing down-ish
      ctx.fillStyle = rgb(hex(NEON[i % 5]), (0.07 + 0.05 * kick).toFixed(3));
      ctx.beginPath(); ctx.moveTo(cx, ballY + 11);
      ctx.lineTo(cx + Math.cos(a - wdt) * len, ballY + 11 + Math.sin(a - wdt) * len); ctx.lineTo(cx + Math.cos(a + wdt) * len, ballY + 11 + Math.sin(a + wdt) * len); ctx.fill();
    }
    // neon sign
    const sign = W > 260 ? 'BRAINROT RAVE' : 'RAVE', sw = sign.length * 4 - 1;
    const flick = Math.sin(O.t * 13) > -0.92;
    glow(ctx, cx, yb - 118, 20, [255, 63, 180], flick ? 0.14 + 0.08 * kick : 0.04);
    pixText(ctx, sign, cx - Math.round(sw / 2), yb - 120, flick ? '#ff8fd6' : '#5a1a40');
    // disco ball on its string
    ctx.fillStyle = '#5a5a6a'; ctx.fillRect(cx, yb - 140, 1, 48);
    glow(ctx, cx, ballY + 11, 18, [255, 255, 255], 0.16 + 0.1 * kick);
    drawSprite(ctx, 'disco', cx - 11, ballY, Math.floor(O.t * 4) % 2 === 1);
    // floor + flashing dance tiles
    ctx.fillStyle = '#12030f'; ctx.fillRect(0, yb, W, O.H);
    for (let x = 0, i = 0; x < W; x += 8, i++) {
      ctx.fillStyle = NEON[(i + Math.floor(beat)) % 5]; ctx.globalAlpha = 0.35 + 0.5 * (((i + Math.floor(beat)) % 3 === 0) ? kick : 0.2);
      ctx.fillRect(x, yb, 7, 3); ctx.globalAlpha = 1;
    }
    // stage, decks and the DJ
    ctx.fillStyle = '#2a0a2a'; ctx.fillRect(cx - 40, yb - 8, 80, 8); ctx.fillStyle = '#ff3fb4'; ctx.fillRect(cx - 40, yb - 8, 80, 1);
    const djs = sprite('partyMouseB'); const djY = yb - 15 - djs.h + 7 - Math.round(kick * 2);
    drawSprite(ctx, 'partyMouseB', cx - Math.round(djs.w / 2), djY, true);
    ctx.fillStyle = '#111'; ctx.fillRect(cx - 9, djY + 6, 2, 4); ctx.fillRect(cx - 9, djY + 5, 9, 1); // headphones
    ctx.fillStyle = '#1a1a26'; ctx.fillRect(cx - 18, yb - 16, 36, 8); ctx.fillStyle = '#3a3a4e'; ctx.fillRect(cx - 18, yb - 16, 36, 1);
    for (const tx of [cx - 10, cx + 9]) { // spinning records
      ctx.fillStyle = '#05050a'; disc(ctx, tx, yb - 12, 3);
      const a = O.t * 9; ctx.fillStyle = '#ff3fb4'; ctx.fillRect(Math.round(tx + Math.cos(a) * 2), Math.round(yb - 12 + Math.sin(a) * 1), 1, 1);
    }
    // speaker stacks, cones thump on the kick
    for (const sx of [cx - 62, cx + 48]) {
      ctx.fillStyle = '#0c0c14'; ctx.fillRect(sx, yb - 30, 14, 30); ctx.fillStyle = '#2a2a3a'; ctx.fillRect(sx + 1, yb - 29, 12, 28);
      for (const cy of [yb - 22, yb - 9]) { ctx.fillStyle = '#05050a'; disc(ctx, sx + 7, cy, 4 + Math.round(kick)); ctx.fillStyle = '#4a4a5e'; disc(ctx, sx + 7, cy, 1); }
    }
    // the crowd
    for (let x = 2, i = 0; x < W - 28; x += 30, i++) {
      if (Math.abs(x + 16 - cx) < 84) continue;
      const jump = Math.round(((i % 2) ? kick : Math.pow(1 - ((beat + 0.5) % 1), 3)) * 4);
      const v = ['partyMouse', 'partyMouseB', 'partyMouseC'][i % 3];
      drawSprite(ctx, v, x, yb - sprite(v).h - jump, x > cx);
      if (i % 3 === 1) { const gx = x > cx ? x + 4 : x + 24; glow(ctx, gx + 3, yb - 26 - jump, 6, [125, 255, 106], 0.3); drawSprite(ctx, 'glowstick', gx, yb - 34 - jump); }
    }
  }

  // wall colours by depth: [face, highlight, shadow, mortar, drip]
  // Brick colors blend from zone to zone. Each brick passes a little random jitter, so the switch from
  // sewer green to rat-kingdom purple to core magenta happens brick by brick over a stretch, not on a line.
  // Past Z_MAD the bricks cycle the rainbow on the beat, faster and brighter the deeper you go.
  const WALL = {
    sewer: [[46, 61, 45], [67, 87, 63], [27, 36, 26], [21, 29, 21], [125, 255, 106]],
    rat:   [[47, 34, 68], [67, 50, 95], [27, 18, 41], [20, 13, 31], [255, 213, 74]],
    core:  [[58, 18, 54], [86, 32, 79], [30, 8, 28], [22, 6, 26], [255, 63, 180]],
  };
  function hsl2rgb(h, s, l) {
    s /= 100; l /= 100; const k = n => (n + h / 30) % 12, a = s * Math.min(l, 1 - l);
    const f = n => l - a * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1));
    return [f(0) * 255, f(8) * 255, f(4) * 255];
  }
  function madWall(m) {
    const ins = clamp((m - Z_MAD) / 1500, 0, 2.5); // 0 at ~600 pts, climbing as you go deeper
    const h = (m / 6 + O.t * (40 + ins * 70)) % 360, l = 18 + beatPulse() * (8 + ins * 6);
    return [hsl2rgb(h, 55, l), hsl2rgb(h, 70, l + 14), hsl2rgb(h, 50, Math.max(4, l - 8)), hsl2rgb(h, 40, Math.max(4, l - 12)), hsl2rgb((h + 180) % 360, 100, 65)];
  }
  function wallColors(m, jitter = 0) {
    m += jitter;
    const band = 260, mixP = (A, B, q) => A.map((c, i) => mix(c, B[i], q));
    let P;
    if (m < Z_RAT) P = mixP(WALL.sewer, WALL.rat, smooth(Z_RAT - band, Z_RAT + band, m));
    else if (m < Z_CORE) P = mixP(WALL.rat, WALL.core, smooth(Z_CORE - band, Z_CORE + band, m));
    else P = WALL.core;
    if (m < Z_RAT + band && m >= Z_RAT) P = mixP(WALL.sewer, WALL.rat, smooth(Z_RAT - band, Z_RAT + band, m));
    if (m > Z_MAD - band) P = mixP(P, madWall(m), smooth(Z_MAD - band, Z_MAD + band, m));
    return [rgb(P[0]), rgb(P[1]), rgb(P[2]), rgb(P[3]), rgb(P[4], 0.6)];
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
    const sxTarget = O.sxTarget !== null && O.sxTarget !== undefined ? O.sxTarget : midX();
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

    drawSky(ctx, 0, ySurf);
    // dusk over the sky on the results screen
    O.dusk = (O.dusk || 0) + ((O.view === 'results' ? 1 : 0) - (O.dusk || 0)) * (O.reduced ? 1 : 1 - Math.exp(-dt * 2));
    if (O.dusk > 0.01 && ySurf > 0) { ctx.fillStyle = `rgba(22,30,46,${(0.78 * O.dusk).toFixed(3)})`; ctx.fillRect(0, 0, O.W, Math.ceil(ySurf) + 3); }
    drawWater(ctx, ySurf);
    drawRays(ctx, ySurf);
    drawFar(ctx);
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
    setShrimpX(f) { O.sxTarget = f === 0.5 ? midX() : f; },
    // CSS-pixel screen position helpers for DOM overlays
    depthToScreenY(d) { return ((OFF + d) - O.topM) * O.ppm * O.scale; },
    screenYToDepth(y) { return y / (O.ppm * O.scale) + O.topM - OFF; },
    shrimpScreen() { return { x: (shrimpX() + 8) * O.scale, y: ((shrimpWorld() - O.topM) * O.ppm + 5) * O.scale }; },
  };
  window.Ocean = Ocean;
})();
