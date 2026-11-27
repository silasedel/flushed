#!/usr/bin/env node
// Adds answers to a prompt, skipping any that already match:  node tools/addmany.js <id> "Name|score|alias" ...
const fs = require('fs'), path = require('path');
global.window = globalThis; const M = require('../js/match.js');
const [id, ...adds] = process.argv.slice(2);
const dir = path.join(__dirname, '..', 'data', 'questions');
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.js'))) {
  const p = path.join(dir, f); let t = fs.readFileSync(p, 'utf8');
  const i = t.indexOf(`id:"${id}"`); if (i < 0) continue;
  global.KRILLION = { qs: [], add(a) { this.qs.push(...a); } }; eval(t);
  const q = KRILLION.qs.find(x => x.id === id);
  const fresh = adds.filter(a => !M.matchExact(q, a.split('|')[0].replace(/^!/, '')));
  if (!fresh.length) { console.log(`${id}: nothing new`); process.exit(0); }
  const aStart = t.indexOf('a:[', i), aEnd = t.indexOf(']', aStart);
  t = t.slice(0, aEnd) + ',' + fresh.map(a => JSON.stringify(a)).join(',') + t.slice(aEnd);
  fs.writeFileSync(p, t); console.log(`${id}: added ${fresh.length} (${fresh.map(a => a.split('|')[0]).join(', ')})`); process.exit(0);
}
console.log('id not found'); process.exit(1);
