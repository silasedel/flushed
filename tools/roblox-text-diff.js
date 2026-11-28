#!/usr/bin/env node
// Calibrates the Roblox text rasterizer against Chrome: renders the same strings (same font files, sizes, weights,
// letter-spacing, -webkit-font-smoothing:none) in headless Chrome and in roblox/src/client/TextRaster.luau,
// and reports mismatched pixels per sample. Needs puppeteer-core + canvas (NODE_PATH). Usage: node tools/roblox-text-diff.js <outdir>
const path = require('path'), fs = require('fs'), { execFileSync } = require('child_process');
const puppeteer = require('puppeteer-core'); const { createCanvas, loadImage } = require('canvas');
const root = path.join(__dirname, '..'); const out = process.argv[2] || '.';
const S = [ // text, family, weight, size, spacing
  ['25 seconds a prompt · rarer answers flush you deeper', 'plex', 600, 17.12, 2.7392],
  ['RANKED · 10 PROMPTS · 58', 'plex', 700, 16.8, 3.024],
  ['PROMPTS', 'plex', 400, 12.48, 2.496],
  ['THEMED PACKS  SHOP  STATS', 'plex', 400, 13.6, 1.904],
  ['Name something you might spot', 'plex', 500, 30.7, 0.92],
  ['GET FLUSHED', 'plex', 700, 28.32, 8.496],
  ['FLUSH', 'plex', 600, 32.96, 9.888],
  ['FLUSHED', 'vt323', 400, 144, 11.52],
  ['Ranked: entry is spent when the run starts', 'plex', 400, 8.8, 0.264],
  ['PROMPT 1 OF 5', 'plex', 400, 13.6, 4.08],
  ['0m 200m SCORE 100', 'plex', 600, 33.6, 1.0],
];
const W = 1400, ROWH = 190;
(async () => {
  const { pathToFileURL } = require('url'); const fontUrl = f => pathToFileURL(path.join(root, 'roblox/fonts', f + '.ttf')).href;
  const html = `<html><head><style>
  @font-face { font-family: P; src: url(${fontUrl('IBMPlexMono-Regular')}); font-weight: 400; }
  @font-face { font-family: P; src: url(${fontUrl('IBMPlexMono-Medium')}); font-weight: 500; }
  @font-face { font-family: P; src: url(${fontUrl('IBMPlexMono-SemiBold')}); font-weight: 600; }
  @font-face { font-family: P; src: url(${fontUrl('IBMPlexMono-Bold')}); font-weight: 700; }
  @font-face { font-family: V; src: url(${fontUrl('VT323-Regular')}); }
  body { margin: 0; background: #fff; -webkit-font-smoothing: none; }
  div { position: absolute; left: 10px; white-space: nowrap; color: #000; line-height: normal; }
  </style></head><body>${S.map(([t, f, w, sz, sp], i) => `<div style="top:${10 + i * ROWH}px;font-family:${f === 'vt323' ? 'V' : 'P'};font-weight:${w};font-size:${sz}px;letter-spacing:${sp}px">${t}</div>`).join('')}</body></html>`;
  fs.writeFileSync(path.join(out, 'textcal.html'), html);
  const b = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: 'new', args: ['--allow-file-access-from-files'] });
  const p = await b.newPage(); await p.setViewport({ width: W, height: S.length * ROWH + 20, deviceScaleFactor: 1 });
  await p.goto(pathToFileURL(path.join(out, 'textcal.html')).href); await p.evaluate(() => document.fonts.ready); await new Promise(r => setTimeout(r, 300));
  await p.screenshot({ path: path.join(out, 'textcal-chrome.png') }); await b.close();
  const img = await loadImage(path.join(out, 'textcal-chrome.png')); const H = S.length * ROWH + 20;
  const cv = createCanvas(W, H); const cx = cv.getContext('2d'); cx.drawImage(img, 0, 0); const ref = cx.getImageData(0, 0, W, H).data;
  // Luau
  const lua = `local TR = require("../src/client/TextRaster")
TR.originMode = "${process.env.OM || "frac4"}"; TR.baselineMode = "${process.env.BM || "round"}"; TR.advMode = "${process.env.AM || "exact"}"
local W, H = ${W}, ${H}
local px = {}
local samples = { ${S.map(([t, f, w, sz, sp]) => `{ ${JSON.stringify(t)}, "${f}", ${w}, ${sz}, ${sp} }`).join(', ')} }
for i, s in samples do
  local opts = { family = s[2], weight = s[3], size = s[4], spacing = s[5] }
  local L = TR.layout(s[1], opts)
  TR.draw(s[1], opts, L, 10, 10 + (i - 1) * ${ROWH}, L.w, function(x0, x1, y) for x = x0, x1 do px[y * W + x] = true end end)
end
local rows = {}
for y = 0, H - 1 do local r = {} for x = 0, W - 1 do r[#r + 1] = px[y * W + x] and "1" or "0" end rows[#rows + 1] = table.concat(r) end
print(table.concat(rows, "\\n"))`;
  const tmp = path.join(root, 'roblox/tests/.textcal.luau'); fs.writeFileSync(tmp, lua);
  let txt; try { txt = execFileSync('luau', [tmp], { cwd: path.join(root, 'roblox'), maxBuffer: 1 << 28 }).toString(); } finally { fs.rmSync(tmp, { force: true }); }
  const rows = txt.trim().split('\n');
  const outImg = cx.createImageData(W, H);
  const stats = S.map(() => ({ miss: 0, extra: 0, ink: 0 }));
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const o = (y * W + x) * 4; const chrome = ref[o] < 128; const mine = rows[y][x] === '1';
    const si = Math.min(S.length - 1, Math.floor((y - 10) / ROWH)); if (si < 0) continue;
    if (chrome) stats[si].ink++; if (chrome && !mine) stats[si].miss++; if (mine && !chrome) stats[si].extra++;
    const col = chrome && mine ? [0, 0, 0] : chrome ? [220, 0, 0] : mine ? [0, 120, 255] : [255, 255, 255];
    outImg.data[o] = col[0]; outImg.data[o + 1] = col[1]; outImg.data[o + 2] = col[2]; outImg.data[o + 3] = 255;
  }
  cx.putImageData(outImg, 0, 0); fs.writeFileSync(path.join(out, 'textcal-diff.png'), cv.toBuffer('image/png'));
  // best whole-pixel shift per sample (diagnostic)
  const best = S.map((_, si) => { let bb = null; for (let dy = -3; dy <= 3; dy++) for (let dx = -3; dx <= 3; dx++) { let bad = 0;
    for (let y = 10 + si * ROWH; y < 10 + si * ROWH + ROWH - 10; y++) for (let x = 3; x < W - 3; x++) { const c = ref[(y * W + x) * 4] < 128; const m = (rows[y - dy] || '')[x - dx] === '1'; if (c !== m) bad++; }
    if (!bb || bad < bb.bad) bb = { dx, dy, bad }; } return bb; });
  S.forEach((s, i) => { const st = stats[i]; process.stdout.write(`best shift dx=${best[i].dx} dy=${best[i].dy} bad=${best[i].bad} | `); console.log(`${(s[0].slice(0, 28)).padEnd(30)} ${s[1]} ${s[2]} ${s[3]}px  ink ${st.ink}  match ${(100 * (1 - (st.miss + st.extra) / Math.max(1, st.ink))).toFixed(1)}%  (missing ${st.miss}, extra ${st.extra})`); });
})();
