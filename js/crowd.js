// Flushed — crowd rarity. Turns real player answer counts into tiers.
// Not wired into the web game yet (GitHub Pages has no server to count answers).
// It's the reference implementation for the Roblox port: see ROBLOX.md, "Crowd rarity".
(function (root) {
  'use strict';

  // How often a player gives each curated tier (share of all accepted answers to a prompt).
  // These are the starting guesses; real counts take over as players arrive.
  // Each value sits in the middle of its band below, so with zero players every answer keeps its curated tier.
  const PRIOR_SHARE = { 10: 0.20, 30: 0.04, 60: 0.01, 85: 0.002, 100: 0.0005 };

  // Share of players needed to sit in a tier (checked from the top).
  const CUTS = [[0.08, 10], [0.02, 30], [0.005, 60], [0, 85]];

  const PRIOR_WEIGHT = 300;  // the curated guess counts as this many pretend players
  const HYSTERESIS = 0.25;   // a tier only moves once the share is 25% past the cut line

  // answers: [{ name, score }] with the curated scores.
  // counts:  { name: number of players whose accepted answer was this }.
  // prev:    { name: score } last published scores, for hysteresis (optional).
  // Returns  { name: score } with exactly one 100 (Sigma).
  function crowdScores(answers, counts, prev) {
    const N = answers.reduce((s, a) => s + (counts[a.name] || 0), 0);
    const rows = answers.map(a => {
      const prior = PRIOR_SHARE[a.score] || PRIOR_SHARE[10];
      const share = ((counts[a.name] || 0) + PRIOR_WEIGHT * prior) / (N + PRIOR_WEIGHT);
      return { name: a.name, share, curated: a.score };
    });
    const out = {};
    for (const r of rows) {
      let s = CUTS.find(([cut]) => r.share >= cut)[1];
      const old = prev && prev[r.name];
      if (old && old !== 100 && old !== s && near(r.share, old)) s = old; // don't flicker on a line
      out[r.name] = s;
    }
    // Sigma: the single rarest answer. Ties go to whoever was curated rarer, then to the previous Sigma.
    let best = null;
    for (const r of rows) {
      if (!best || r.share < best.share - 1e-12 ||
          (Math.abs(r.share - best.share) <= 1e-12 && (r.curated > best.curated || (prev && prev[r.name] === 100)))) best = r;
    }
    out[best.name] = 100;
    return out;
  }

  // Is the share still inside the hysteresis band of the tier it used to be in?
  function near(share, score) {
    const i = CUTS.findIndex(([, s]) => s === score); if (i < 0) return false;
    const lo = CUTS[i][0], hi = i > 0 ? CUTS[i - 1][0] : Infinity;
    return share >= lo * (1 - HYSTERESIS) && share < hi * (1 + HYSTERESIS);
  }

  const api = { crowdScores, PRIOR_SHARE, CUTS, PRIOR_WEIGHT };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.Crowd = api;
})(typeof window !== 'undefined' ? window : globalThis);
