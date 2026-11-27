#!/usr/bin/env node
// Lists every existing prompt (pack · id · text) so writers can avoid duplicates.
//   node tools/prompts.js | grep -i fruit
global.window = globalThis; global.KRILLION = { qs: [], add(a) { this.qs.push(...a); } };
const fs = require('fs'), path = require('path');
const dir = path.join(__dirname, '..', 'data', 'questions');
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.js')).sort()) eval(fs.readFileSync(path.join(dir, f), 'utf8'));
for (const q of KRILLION.qs) console.log(`${q.pack} · ${q.id} · ${q.q}`);
