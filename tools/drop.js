#!/usr/bin/env node
// Removes prompts by id from a question file:  node tools/drop.js data/questions/x.js id1 id2 ...
const fs = require('fs');
const [file, ...ids] = process.argv.slice(2);
let t = fs.readFileSync(file, 'utf8'); let n = 0;
for (const id of ids) {
  const re = new RegExp(`\\n\\s*\\{\\s*id:\\s*"${id}"[\\s\\S]*?(?=\\n\\s*\\{\\s*id:|\\n\\]\\);)`);
  if (re.test(t)) { t = t.replace(re, ''); n++; }
}
fs.writeFileSync(file, t); console.log(`${file}: dropped ${n}`);
