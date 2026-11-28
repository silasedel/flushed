#!/usr/bin/env node
// Renders the same scenario with the website's js/ocean.js (node-canvas) and the Roblox Luau port
// (roblox/src/client/Ocean.luau via the luau CLI), then writes side-by-side PNGs and reports pixel differences.
// Needs: npm i canvas (in NODE_PATH or a sibling node_modules). Usage: node tools/roblox-scene-diff.js <outdir> [W H]
const path = require('path'), fs = require('fs'), vm = require('vm'), { execFileSync } = require('child_process');
const { createCanvas } = require('canvas');
const root = path.join(__dirname, '..');
const out = process.argv[2] || '.'; const W = +(process.argv[3] || 1440), H = +(process.argv[4] || 900);
// ---- website reference
let now = 1000; const rafQ = []; let seed = 12345;
const rnd = () => { seed = (seed * 48271) % 2147483647; return seed / 2147483647; };
const M = Object.create(Math); M.random = rnd;
const ctx = { window: { innerWidth: W, innerHeight: H, addEventListener() {} }, document: { createElement: () => createCanvas(1, 1) },
  performance: { now: () => now }, requestAnimationFrame: cb => rafQ.push(cb), Math: M, console };
vm.createContext(ctx); vm.runInContext(fs.readFileSync(path.join(root, 'js/ocean.js'), 'utf8'), ctx);
const Ocean = ctx.window.Ocean; const canvas = createCanvas(1, 1); Ocean.init(canvas);
const step = ms => { const n = Math.round(ms / 16.67); for (let i = 0; i < n; i++) { now += 16.67; rafQ.splice(0).forEach(cb => cb(now)); } };
const web = {};
const snap = n => { web[n] = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height); };
Ocean.setView('title', true); step(1500); snap('title');
Ocean.setView('intro'); Ocean.flush(); step(900); snap('flush-mid');
step(1700); snap('flush-drop');
Ocean.setView('game'); step(1500); snap('game-start');
for (const d of [1200, 2700, 3900, 4900, 6200]) { Ocean.setDepth(d); step(4000); snap('game-depth-' + d); }
Ocean.setView('results'); step(2500); snap('results');
// ---- Luau port
const src = fs.readFileSync(path.join(root, 'roblox/tests/ocean_scene.luau'), 'utf8').replace('tonumber(SCENE_W or 1440)', W).replace('tonumber(SCENE_H or 900)', H);
const tmp = path.join(root, 'roblox/tests/.scene_tmp.luau'); fs.writeFileSync(tmp, src);
let txt; try { txt = execFileSync('luau', [tmp], { cwd: path.join(root, 'roblox'), maxBuffer: 1 << 30 }).toString(); } finally { fs.rmSync(tmp, { force: true }); }
const lines = txt.split('\n'); let total = 0;
for (let i = 0; i < lines.length; i++) {
  if (!lines[i].startsWith('SNAP ')) continue;
  const [, name, w, h] = lines[i].split(' '); const hex = lines[i + 1]; const lu = Buffer.from(hex, 'hex');
  const ref = web[name]; let diff = 0, big = 0;
  const cv = createCanvas(+w * 2 + 4, +h); const c2 = cv.getContext('2d'); const id = c2.createImageData(+w * 2 + 4, +h);
  for (let y = 0; y < +h; y++) for (let x = 0; x < +w; x++) {
    const o = (y * +w + x) * 4, d = (y * (+w * 2 + 4) + x) * 4, d2 = (y * (+w * 2 + 4) + x + +w + 4) * 4;
    let dd = 0; for (let k = 0; k < 3; k++) { dd = Math.max(dd, Math.abs(ref.data[o + k] - lu[o + k])); }
    if (dd > 3) diff++; if (dd > 40) big++;
    for (let k = 0; k < 4; k++) { id.data[d + k] = ref.data[o + k]; id.data[d2 + k] = lu[o + k]; }
  }
  c2.putImageData(id, 0, 0);
  fs.writeFileSync(path.join(out, `cmp-${name}.png`), cv.toBuffer('image/png'));
  const pct = (100 * diff / (+w * +h)).toFixed(2); total += diff;
  console.log(`${name.padEnd(18)} ${w}x${h}  differing pixels: ${pct}%  (big: ${(100 * big / (+w * +h)).toFixed(2)}%)`);
}
