#!/usr/bin/env node
// Renders the website's synthesized sound effects (js/sound.js) into ONE audio file for Roblox (a "sound sprite"):
// every effect sits in its own 4-second slot, and the game plays a slot with Sound.PlaybackRegion. One upload
// instead of ~18. Rendering uses Chrome's OfflineAudioContext with the same oscillators / filters as the website.
// Usage: NODE_PATH=<node_modules with puppeteer-core> node tools/roblox-sounds.js <out.ogg>
// Prints the slot table for roblox/src/shared/Config.luau (Config.SOUND_SLOTS).
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const puppeteer = require('puppeteer-core');
const out = process.argv[2] || 'flushed-sfx.ogg';
const SLOT = 4;
const EFFECTS = ['click', 'start', 'tick', 'tickUrgent', 'go', 'wrong', 'dup', 'correct10', 'correct30', 'correct60', 'correct85', 'correct100',
  'miss', 'descend10', 'descend30', 'descend60', 'descend85', 'descend100', 'flush', 'finish', 'buy'];
const DEPTH = { 10: 30, 30: 200, 60: 450, 85: 750, 100: 1000 };

(async () => {
  const browser = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: 'new' });
  const page = await browser.newPage();
  const samples = await page.evaluate(async (EFFECTS, SLOT, DEPTH) => {
    const rate = 44100;
    const a = new OfflineAudioContext(1, rate * SLOT * EFFECTS.length, rate);
    const master = a.createGain(); master.gain.value = 0.5 * 0.5 * 2.2; master.connect(a.destination); // website volume .5, a bit louder for phones
    let seed = 7; const rnd = () => (seed = seed * 48271 % 2147483647) / 2147483647;
    let base = 0;
    function tone(freq, dur, { type = 'square', vol = 0.25, at = 0, slide = 0, attack = 0.005 } = {}) {
      const t = base + at;
      const o = a.createOscillator(), g = a.createGain();
      o.type = type; o.frequency.setValueAtTime(freq, t);
      if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq + slide), t + dur);
      g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + attack);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.connect(g); g.connect(master); o.start(t); o.stop(t + dur + 0.02);
    }
    function noise(dur, { vol = 0.15, at = 0, freq = 800, q = 1, sweep = 0 } = {}) {
      const t = base + at;
      const buf = a.createBuffer(1, Math.ceil(rate * dur), rate);
      const d = buf.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = rnd() * 2 - 1;
      const src = a.createBufferSource(); src.buffer = buf;
      const f = a.createBiquadFilter(); f.type = 'bandpass'; f.frequency.setValueAtTime(freq, t); f.Q.value = q;
      if (sweep) f.frequency.exponentialRampToValueAtTime(Math.max(40, freq + sweep), t + dur);
      const g = a.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      src.connect(f); f.connect(g); g.connect(master); src.start(t);
    }
    function murk(dur, { vol = 0.2, at = 0, freq = 520, wobble = 260, rate: lr = 3.2 } = {}) {
      const t = base + at;
      const buf = a.createBuffer(1, Math.ceil(rate * dur), rate);
      const d = buf.getChannelData(0); let last = 0;
      for (let i = 0; i < d.length; i++) { last = last * 0.82 + (rnd() * 2 - 1) * 0.18; d[i] = last * 3; }
      const src = a.createBufferSource(); src.buffer = buf;
      const f = a.createBiquadFilter(); f.type = 'lowpass'; f.frequency.setValueAtTime(freq, t); f.Q.value = 4;
      const lfo = a.createOscillator(), lg = a.createGain(); lfo.frequency.value = lr; lg.gain.value = wobble; lfo.connect(lg); lg.connect(f.frequency);
      f.frequency.exponentialRampToValueAtTime(Math.max(120, freq * 0.45), t + dur);
      const g = a.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + Math.min(0.35, dur * 0.3)); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      src.connect(f); f.connect(g); g.connect(master); src.start(t); lfo.start(t); lfo.stop(t + dur + 0.05);
    }
    const NOTES = { 10: [523], 30: [523, 659, 784], 60: [523, 659, 784, 1047], 85: [587, 740, 880, 1175, 1480], 100: [523, 659, 784, 1047, 1319, 1568, 2093] };
    const S = {
      click() { tone(880, 0.05, { vol: 0.12 }); tone(1320, 0.05, { vol: 0.08, at: 0.04 }); },
      start() { [392, 523, 659, 784].forEach((f, i) => tone(f, 0.12, { at: i * 0.07, vol: 0.14 })); noise(0.6, { at: 0.25, vol: 0.12, freq: 600, sweep: -450 }); },
      tick() { tone(660, 0.04, { vol: 0.06, type: 'triangle' }); },
      tickUrgent() { tone(990, 0.04, { vol: 0.12, type: 'triangle' }); },
      go() { tone(880, 0.12, { vol: 0.14, type: 'triangle' }); },
      wrong() { tone(196, 0.16, { vol: 0.16, type: 'sawtooth', slide: -60 }); tone(147, 0.18, { at: 0.09, vol: 0.14, type: 'sawtooth', slide: -40 }); },
      dup() { tone(330, 0.07, { vol: 0.1 }); tone(330, 0.07, { at: 0.1, vol: 0.1 }); },
      correct(score) { NOTES[score].forEach((f, i) => tone(f, 0.14, { at: i * 0.075, vol: 0.15, type: i % 2 ? 'square' : 'triangle' })); },
      miss() { [392, 330, 262].forEach((f, i) => tone(f, 0.16, { at: i * 0.1, vol: 0.12, type: 'triangle' })); },
      descend(ms) {
        const s = Math.max(0.6, ms / 1000);
        murk(s + 0.3, { vol: 0.32, freq: 700, wobble: 320, rate: 2.6 });
        tone(70, s, { type: 'sine', vol: 0.16, slide: -30, attack: 0.15 });
        const n = Math.round(6 + s * 5);
        for (let i = 0; i < n; i++) tone(180 + rnd() * 380, 0.07 + rnd() * 0.05, { at: rnd() * s, vol: 0.07, type: 'sine', slide: 220 + rnd() * 300, attack: 0.01 });
      },
      flush() {
        noise(2.3, { vol: 0.13, freq: 1300, sweep: -1000, q: 0.8 });
        for (let i = 0; i < 9; i++) tone(260 + rnd() * 380, 0.06, { at: 0.35 + i * 0.11, vol: 0.06, type: 'sine', slide: -160 });
        tone(180, 0.35, { at: 2.2, vol: 0.12, type: 'triangle', slide: -120 });
      },
      finish() { [523, 659, 784, 1047, 784, 1047].forEach((f, i) => tone(f, 0.18, { at: i * 0.11, vol: 0.14 })); },
    };
    EFFECTS.forEach((name, i) => {
      base = i * SLOT;
      let m;
      if ((m = name.match(/^correct(\d+)$/))) S.correct(+m[1]);
      else if ((m = name.match(/^descend(\d+)$/))) S.descend(1500 + DEPTH[m[1]] * 1.9);
      else if (name === 'buy') S.correct(60); // the website's purchase sound
      else S[name]();
    });
    const buf = await a.startRendering();
    return Array.from(buf.getChannelData(0));
  }, EFFECTS, SLOT, DEPTH);
  await browser.close();
  // 16-bit WAV, then encode to OGG
  { let pk = 0; for (const v of samples) pk = Math.max(pk, Math.abs(v)); const k = 0.9 / Math.max(1e-6, pk); for (let i = 0; i < samples.length; i++) samples[i] *= k; } // normalize
  const n = samples.length, wav = Buffer.alloc(44 + n * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(36 + n * 2, 4); wav.write('WAVEfmt ', 8); wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(44100, 24); wav.writeUInt32LE(88200, 28); wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34); wav.write('data', 36); wav.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) wav.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), 44 + i * 2);
  const tmp = out.replace(/\.\w+$/, '') + '.wav';
  fs.writeFileSync(tmp, wav);
  execFileSync('oggenc', ['-Q', '-q', '6', '-o', out, tmp]);
  fs.rmSync(tmp);
  let peak = 0; for (const v of samples) peak = Math.max(peak, Math.abs(v));
  console.log(`wrote ${out} (${EFFECTS.length} slots x ${SLOT}s, peak ${peak.toFixed(2)})`);
  console.log('Config.SOUND_SLOTS = { ' + EFFECTS.map((e, i) => `${e} = ${i}`).join(', ') + ' }');
})();
