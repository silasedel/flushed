// Simulates players answering one prompt and shows how the tiers settle.
//   node tools/crowd-sim.js
const { crowdScores } = require('../js/crowd.js');
const answers = [
  { name: 'Refrigerator', score: 10 }, { name: 'Microwave', score: 10 }, { name: 'Toaster', score: 30 },
  { name: 'Air fryer', score: 60 }, { name: 'Dishwasher', score: 30 }, { name: 'Rice cooker', score: 85 },
  { name: 'Sous vide', score: 100 },
];
// What real players "actually" say: the curated guess was wrong about air fryers.
const truth = { Refrigerator: 0.3, Microwave: 0.25, 'Air fryer': 0.2, Toaster: 0.12, Dishwasher: 0.1, 'Rice cooker': 0.025, 'Sous vide': 0.005 };
const counts = {}; let prev = null; let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
let ok = true;
for (const n of [0, 50, 500, 5000, 50000]) {
  while (Object.values(counts).reduce((s, x) => s + x, 0) < n) {
    let r = rnd(), pick = answers[0].name;
    for (const [k, p] of Object.entries(truth)) { if ((r -= p) <= 0) { pick = k; break; } }
    counts[pick] = (counts[pick] || 0) + 1;
  }
  prev = crowdScores(answers, counts, prev);
  if (n === 0 && answers.some(a => prev[a.name] !== a.score)) ok = false; // no players yet: curated tiers unchanged
  const sig = Object.values(prev).filter(s => s === 100).length;
  if (sig !== 1) ok = false;
  console.log(String(n).padStart(6), 'players ', answers.map(a => `${a.name} ${prev[a.name]}`).join(' · '));
}
if (prev['Air fryer'] !== 10) ok = false;
console.log(ok ? 'OK: one Sigma each round; Air fryer settled to NPC' : 'FAIL'); process.exit(ok ? 0 : 1);
