#!/usr/bin/env node
// Checks new prompts against EVERY other prompt for look-alikes (prompts that would feel like a repeat).
//   node tools/similar.js data/questions/zout-1.js [more files]
// Flags: answer overlap >= 45% (of the smaller list, 6+ shared answers), or nearly the same wording.
const fs = require('fs'), path = require('path');
global.window = globalThis; global.KRILLION = { qs: [], add(a) { this.qs.push(...a.map(q => ({ ...q, _file: global.__file }))); } };
const dir = path.join(__dirname, '..', 'data', 'questions');
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.js')).sort()) { global.__file = f; eval(fs.readFileSync(path.join(dir, f), 'utf8')); }
const M = require('../js/match.js');
const mine = new Set(process.argv.slice(2).map(p => path.basename(p)));
if (!mine.size) { console.log('usage: node tools/similar.js data/questions/<file>.js'); process.exit(1); }
const qs = KRILLION.qs;
const words = s => M.norm(s).split(' ').filter(w => !['name', 'a', 'an', 'any', 'the', 'one', 'of', 'that', 'is', 'in', 'or', 'you', 'can', 'something'].includes(w));
const sets = qs.map(q => new Set(q.a.map(a => M.norm(a.split('|')[0].replace(/^!/, '')))));
let bad = 0;
qs.forEach((q, i) => {
  if (!mine.has(q._file)) return;
  const wi = new Set(words(q.q));
  let worst = null;
  qs.forEach((o, j) => {
    if (i === j) return;
    let inter = 0; for (const x of sets[i]) if (sets[j].has(x)) inter++;
    const ov = inter / Math.min(sets[i].size, sets[j].size);
    const wj = words(o.q); const ww = wj.filter(w => wi.has(w)).length / Math.max(wi.size, wj.length, 1);
    const score = Math.max(inter >= 6 ? ov : 0, ww >= 0.8 ? ww : 0);
    if (!worst || score > worst.score) worst = { score, ov, ww, o };
  });
  if (worst && worst.score >= 0.45) { bad++; console.log(`TOO SIMILAR ${q.id} "${q.q}"  ~  ${worst.o.id} "${worst.o.q}"  (answers ${Math.round(worst.ov * 100)}%, wording ${Math.round(worst.ww * 100)}%)`); }
});
console.log(bad ? `${bad} prompt(s) too similar to existing ones: change the angle or drop them.` : 'OK: nothing too similar.');
process.exit(bad ? 1 : 0);
