// Krillion — game logic, modes, persistence and UI.
(function () {
  'use strict';
  const $ = s => document.querySelector(s);
  const $$ = s => [...document.querySelectorAll(s)];
  const fmt = n => Math.round(n).toLocaleString('en-US');
  const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const { TIERS, tierOf, match, parseAnswers } = window.Match;

  // tier icons in their natural colors (Too Clever borrows the fish, tinted green)
  const ICON_SPR = { plankton: ['icoNPC'], clever: ['icoMid'], schooler: ['icoMid'], rare: ['icoRizz'], deep: ['icoSkibidi'], million: ['icoSigma'] };
  ICON_SPR.none = ['silhouette', '#4a5b72'];
  const READ_MS = 3000, ANSWER_MS = 25000, PER_GAME = 7, MAX_SCORE = 700;
  // Game length: 5, 7, 10 prompts, or 0 = endless (keeps going until you end the run).
  const LENGTHS = [5, 7, 10, 0];
  const lenOf = g => (g && g.len !== undefined ? g.len : PER_GAME);
  const countOf = e => e.results.length;
  // Depth per answer scales so any length spans the same 0–7,000 m world (endless paces like a 10).
  const depthScale = () => 1; // depth follows points in every game length: ~400 pts = Rat Kingdom, ~500 = disco core, 600+ = insanity
  const lenName = l => (l ? `${l} PROMPTS` : 'ENDLESS');
  // ---------- Pretend Robux (web prototype of the Roblox money loop) ----------
  // You start with R$1,000. Normal games are free and pay nothing. Ranked: buy in at the "market price" for the
  // number of prompts, get paid R$1 per 5 points. The price sits ~10% above what an average player wins back, so
  // beating the average = profit and the house keeps a small edge. See ROBLOX.md, "Money" for the real-Roblox rules.
  const START_COINS = 1000, NORMAL_RATE = Infinity, RANKED_RATE = 10, AVG_PER_PROMPT = 25.45; // payout = score ÷ 10, rounded down
  const rankedLen = () => (LENGTHS.includes(store.settings.len) && store.settings.len ? store.settings.len : 10);
  // The buy-in follows how players ACTUALLY score (recent prompts), not a fixed guess: if people get better the price
  // rises, if they get worse it falls. Price = average payout for that length + the house cut, so on average the house
  // always takes in more than it pays out. Web: this device's recent prompts blended with the model. Roblox: every
  // player's recent ranked prompts (DataStore), same formula.
  const HOUSE_CUT = 1.05, PRIOR_PROMPTS = 40; // entry = average payout + 5%, rounded up
  function avgPerPrompt() {
    const recent = cleanGames().slice(-40).flatMap(e => e.results.map(r => r.score || 0)).slice(-300);
    return (AVG_PER_PROMPT * PRIOR_PROMPTS + recent.reduce((a, b) => a + b, 0)) / (PRIOR_PROMPTS + recent.length);
  }
  const marketPrice = len => Math.max(1, Math.ceil((avgPerPrompt() * len / RANKED_RATE) * HOUSE_CUT));
  const coinsFor = (score, ranked) => (ranked ? Math.floor(score / RANKED_RATE) : 0);
  let coinImg = '';
  const coinTag = n => `<span class="coin">${coinImg ? `<img class="pix coin-ico" src="${coinImg}" alt="">` : ''}${Number(n).toLocaleString('en-US')}</span>`;
  const EPOCH = '2026-09-01'; // Daily Dive #1
  const PACKS = [
    { key: 'geography', name: 'Geography', blurb: 'Countries, capitals, rivers, peaks and every corner of the map.' },
    { key: 'movies', name: 'Movies & TV', blurb: 'Directors, franchises, characters and the small screen.' },
    { key: 'sports', name: 'Sports', blurb: 'Teams, tournaments, legends and the rules of the game.' },
    { key: 'gaming', name: 'Gaming', blurb: 'Pokémon, Minecraft, Nintendo, consoles and classics.' },
    { key: 'science', name: 'Science & Nature', blurb: 'Elements, planets, the human body and the animal kingdom.' },
    { key: 'music', name: 'Music', blurb: 'Instruments, bands, albums, composers and musicals.' },
    { key: 'language', name: 'Language & Lit', blurb: 'Words, alphabets, languages and literature.' },
    { key: 'pop', name: 'Pop Culture', blurb: 'Celebrities, internet, apps, snacks and everything trending.' },
    { key: 'fun', name: 'Fun & Random', blurb: 'Things that use suction, junk-drawer finds, Minecraft blocks and more.' },
  ];
  const ALL_PACKS = [...PACKS.map(p => p.key), 'general'];
  const FUN_PACKS = ['pop', 'fun'];                              // every dive gets one of each
  const DIFF_RANK = { easy: 0, medium: 1, hard: 2 };

  // ---------- question pool ----------
  const QS = (window.KRILLION.questions || []).slice().sort((a, b) => a.id < b.id ? -1 : 1);
  // difficulty re-rated for a casual teen / young-adult audience (data/difficulty.js)
  const DIFF_OVERRIDE = window.KRILLION.difficulty || {};
  QS.forEach(q => { if (DIFF_OVERRIDE[q.id]) q.diff = DIFF_OVERRIDE[q.id]; });
  // plain-language rewrites of confusing prompts (data/wording.js)
  const WORDING = window.KRILLION.wording || {};
  QS.forEach(q => { if (WORDING[q.id]) q.q = WORDING[q.id]; });
  // Daily & Unlimited: easy only. Themed packs: 3 easy, 3 medium, 1 hard.
  const MIX = ['easy', 'easy', 'easy', 'easy', 'easy', 'easy', 'easy']; // Daily & Unlimited: only questions ~90% of players can answer
  const PACK_MIX = ['easy', 'easy', 'easy', 'medium', 'medium', 'medium', 'hard'];
  // abstract "Name something that…" prompts: fun in small doses, at most one per dive
  // Brainrot prompts (memes, slang, skibidi energy): a surprise, not the main course.
  const isBrainrot = q => q.cat === 'Brainrot' || /\b(brain ?rot|gen alpha|meme|skibidi|rizz|sigma|aura|npc|ohio|gyatt|fanum)\b/i.test(q.q);
  const isVague = q => /^(name|give) (something|anything|a thing|an object|an item)\b/i.test(q.q);
  const FALLBACK = { easy: ['easy', 'medium', 'hard'], medium: ['medium', 'easy', 'hard'], hard: ['hard', 'medium', 'easy'] };
  const BY_ID = new Map(QS.map(q => [q.id, q]));

  // ---------- RNG ----------
  function strHash(s) { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  function shuffle(arr, r = Math.random) { const a = arr.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }

  // ---------- dates ----------
  const pad = n => String(n).padStart(2, '0');
  const dateKey = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  const parseKey = k => { const [y, m, d] = k.split('-').map(Number); return new Date(y, m - 1, d); };
  const todayKey = () => dateKey(new Date());
  const dayIndex = k => Math.round((parseKey(k) - parseKey(EPOCH)) / 86400000);
  const addDays = (k, n) => { const d = parseKey(k); d.setDate(d.getDate() + n); return dateKey(d); };
  const prettyDate = k => parseKey(k).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  function msToMidnight() { const n = new Date(); const m = new Date(n.getFullYear(), n.getMonth(), n.getDate() + 1); return m - n; }
  function hms(ms) { const s = Math.max(0, Math.floor(ms / 1000)); return `${pad(Math.floor(s / 3600))}:${pad(Math.floor(s / 60) % 60)}:${pad(s % 60)}`; }

  // ---------- daily selection (deterministic, same for everyone) ----------
  const packOrderCache = {};
  function packOrder(p) {
    if (!packOrderCache[p]) packOrderCache[p] = shuffle(QS.filter(q => q.pack === p), rng(strHash('flushed-pack-v1-' + p)));
    return packOrderCache[p];
  }
  // Daily & Unlimited draw each prompt's topic at random with these weights: thinking topics lead,
  // entertainment trails, and any dive can come out science-heavy, geography-heavy or mixed.
  // Mostly brainy: science, geography and history lead; entertainment is a sprinkle.
  const WEIGHTS = { science: 4, geography: 3.2, general: 2.6, language: 1.3, fun: 0.8, sports: 0.6, gaming: 0.55, pop: 0.45, music: 0.35, movies: 0.3 };
  function pickPack(rand, exclude) {
    const opts = Object.entries(WEIGHTS).filter(([p]) => !exclude.has(p));
    let x = rand() * opts.reduce((n, [, w]) => n + w, 0);
    for (const [p, w] of opts) { if ((x -= w) <= 0) return p; }
    return opts[opts.length - 1][0];
  }
  // "Name a character from <show>" style prompts need you to have watched that thing: Themed Packs only
  const isFandom = q => /\b(character|villain|cast member|episode)\b/i.test(q.q);
  const casualOK = q => q.diff === 'easy' && !isFandom(q);
  const ENTERTAINMENT = ['pop', 'movies', 'music'];

  function dailyIds(key) {
    const d = Math.max(0, dayIndex(key));
    const r = rng(strHash('flushed-daily-v1-' + key));
    const allowVague = d % 3 === 0; // "Name something that…" at most one, on some days only
    const picks = [], used = new Map();
    for (let slot = 0, tries = 0; picks.length < PER_GAME && tries < 60; tries++) {
      const ent = picks.filter(q => ENTERTAINMENT.includes(q.pack)).length;
      const p = pickPack(r, new Set(ent >= 2 ? ENTERTAINMENT : []));
      const ord = packOrder(p); if (!ord.length) continue;
      const n = used.get(p) || 0; const start = (d * 5 + n * 17) % ord.length;
      const vagueBlocked = !allowVague || picks.some(isVague);
      for (let k = 0; k < ord.length; k++) {
        const c = ord[(start + k) % ord.length];
        if (casualOK(c) && !picks.includes(c) && !(vagueBlocked && isVague(c))) { picks.push(c); used.set(p, n + 1); break; }
      }
    }
    let k = 0; while (picks.length < PER_GAME && k < QS.length) { const q = QS[(d * 7 + k++) % QS.length]; if (!picks.includes(q) && casualOK(q)) picks.push(q); }
    return picks.map(q => q.id);
  }
  // No-repeat picking. Every prompt you're served gets stamped in store.seen with a running counter.
  // Games only draw from prompts you've never seen; once those run low, the ones seen LONGEST ago come back first.
  // Within a game, two prompts of the same kind ("Name a fruit" / "Name a fruit that's red") never appear together.
  const kindOf = q => q.q.toLowerCase().replace(/^(name|give|list)\s+(a|an|any|one of the|one of|the|some)?\s*/, '').split(/[^a-z]+/)[0];
  function markSeen(id) {
    store.seen = store.seen || {}; store.seenN = (store.seenN || 0) + 1; store.seen[id] = store.seenN;
    const q = BY_ID.get(id); if (!q) return;
    store.recentGroups = [...(store.recentGroups || []).filter(g => g !== groupOf(q)), groupOf(q)].slice(-30); // ~3 games of memory
  }
  // Look-alike groups: prompts whose answers mostly overlap share a family (data/families.js);
  // otherwise group by the thing being named ("fruit", "country"...).
  const FAMILY = window.KRILLION.family || {};
  const isFamous = q => /\b(famous|popular|well[- ]known|notable|celebrit\w*|iconic|legendary)\b/i.test(q.q);
  const TEMPLATE = /\b(model|emoji|rhymes?|synonym|in spanish|in french|compound|starts? with|beginning with|starting with|song by|team based in|in its title|in the title|in the title of|movie with|movie about|show about|movie or show|shows? with|starring|movie by|cartoon|part of|parts of|piece of)s?\b/i; // repeated templates ("Name a Nissan model", "Name a weather emoji"): one per game
  const groupOf = q => (FAMILY[q.id] ? 'f' + FAMILY[q.id] : TEMPLATE.test(q.q) ? 't:' + TEMPLATE.exec(q.q)[1].toLowerCase().replace(/s$/, '').replace(/^(start|beginning|starting) with$|^starts with$/, 'letter') : 'k:' + kindOf(q));
  function randomIds(pack, n = PER_GAME, exclude = []) {
    const seen = store.seen || {}; const ex = new Set(exclude);
    const fits = q => (pack ? q.pack === pack : casualOK(q));
    let pool = QS.filter(q => fits(q) && !ex.has(q.id));
    if (pool.length < n) pool = QS.filter(fits);
    const unseen = pool.filter(q => seen[q.id] === undefined);
    let fresh = unseen;
    if (fresh.length < n * 3) { // nearly everything seen: top up with the ones seen longest ago
      const old = pool.filter(q => seen[q.id] !== undefined).sort((a, b) => seen[a.id] - seen[b.id]);
      fresh = unseen.concat(old.slice(0, Math.max(n * 6, 40)));
    }
    const sh = shuffle(fresh); const picks = [];
    const recentG = new Set(store.recentGroups || []); // groups served in your last few games
    const inGame = new Set(exclude.map(id => BY_ID.get(id)).filter(Boolean).map(groupOf).slice(-12));
    const allowVague = Math.random() < 1 / 3; // "Name something that…" only in about a third of games
    const allowBrainrot = Math.random() < 0.4; // about 40% of games get one brainrot prompt
    const allowFamous = Math.random() < 0.35; // "Name a famous…" prompts are fuzzy (what counts as famous?), so keep them rare
    // strictness 2: new group in this game AND not played recently; 1: new group in this game; 0: anything
    const ok = (x, strict) => !picks.includes(x) && (pack || casualOK(x))
      && (strict < 1 || (!picks.some(p => groupOf(p) === groupOf(x)) && !inGame.has(groupOf(x))))
      && (strict < 2 || !recentG.has(groupOf(x)))
      && (pack || !(isVague(x) && (!allowVague || picks.some(isVague))))
      && (pack || !(isFamous(x) && (!allowFamous || picks.some(isFamous))))
      && (pack || !(isBrainrot(x) && (!allowBrainrot || picks.some(isBrainrot))));
    for (const strict of [2, 1, 0]) {
      if (pack) {
        for (const want of PACK_MIX) { if (picks.length >= n) break; for (const w of FALLBACK[want]) { const q = sh.find(x => x.diff === w && ok(x, strict)); if (q) { picks.push(q); break; } } }
      } else {
        for (let tries = 0; picks.length < n && tries < 60; tries++) {
          const ent = picks.filter(q => ENTERTAINMENT.includes(q.pack)).length;
          const p = pickPack(Math.random, new Set(ent >= 2 ? ENTERTAINMENT : []));
          const q = sh.find(x => x.pack === p && ok(x, strict)); if (q) picks.push(q);
        }
      }
      for (const q of sh) { if (picks.length >= n) break; if (ok(q, strict)) picks.push(q); }
      if (picks.length >= n) break;
    }
    if (!pack && allowBrainrot && !picks.some(isBrainrot) && picks.length) {
      const br = sh.find(x => isBrainrot(x) && casualOK(x) && !picks.includes(x));
      if (br) picks[picks.length - 1] = br;
    }
    // order them so the same topic never comes twice in a row (when there's any way around it)
    // (always take next from the topic with the most left that isn't the one just played)
    const byPack = new Map(); for (const q of shuffle(picks)) { if (!byPack.has(q.pack)) byPack.set(q.pack, []); byPack.get(q.pack).push(q); }
    const order = []; let prev = exclude.length ? (BY_ID.get(exclude[exclude.length - 1]) || {}).pack : null;
    while (order.length < picks.length) {
      const packs = [...byPack.entries()].filter(([, l]) => l.length).sort((x, y) => y[1].length - x[1].length || Math.random() - 0.5);
      const pick = packs.find(([p]) => p !== prev) || packs[0];
      order.push(pick[1].pop()); prev = pick[0];
    }
    return order.map(q => q.id);
  }

  // ---------- persistence ----------
  const SKEY = 'flushed.v1';
  const DEFAULTS = () => ({ v: 1, settings: { sound: true, volume: 0.5, ambience: true, motion: 'full', showMeta: true, len: 10 }, daily: {}, archive: {}, history: [], recent: [], seen: {}, seenN: 0, coins: START_COINS, active: null, tiers: {}, seenHelp: false });
  let store = DEFAULTS();
  function load() {
    try { const raw = localStorage.getItem(SKEY); if (raw) { const s = JSON.parse(raw); store = Object.assign(DEFAULTS(), s); store.settings = Object.assign(DEFAULTS().settings, s.settings || {}); }
      if (!store.seenN) { // first run with no-repeat tracking: count everything already played as seen, oldest first
        [...store.history.flatMap(h => h.ids || []), ...store.recent].forEach(id => { store.seenN++; store.seen[id] = store.seenN; });
      } } catch (e) { /* private mode */ }
  }
  function save() { try { localStorage.setItem(SKEY, JSON.stringify(store)); } catch (e) {} }

  // ---------- game state ----------
  let G = null; // active game
  let tickTimer = null, lastTickSec = -1;

  function newGame(mode, key) {
    const len = mode === 'ranked' ? rankedLen() : mode === 'daily' || mode === 'archive' ? PER_GAME : (LENGTHS.includes(store.settings.len) ? store.settings.len : 10);
    const ids = mode === 'daily' || mode === 'archive' ? dailyIds(key) : randomIds(mode === 'pack' ? key : null, len || 10);
    return { mode, key, ids, len, ranked: mode === 'ranked' || undefined, price: mode === 'ranked' ? marketPrice(len) : undefined, idx: 0, results: [], score: 0, depth: 0, phase: 'answering', phaseEnd: Date.now() + ANSWER_MS, input: '', tries: [], startedAt: Date.now() };
  }
  const curQ = () => BY_ID.get(G.ids[G.idx]);

  function startGame(mode, key) {
    Sound.unlock();
    if (G) { if (G.mode === mode && G.key === key && mode !== 'unlimited') return showGame(); return leaveThen(() => startGame(mode, key)); }
    if (mode === 'daily') {
      key = todayKey();
      if (store.daily[key]) { return showResults(store.daily[key]); }
    }
    if (mode === 'ranked') {
      const price = marketPrice(rankedLen());
      if ((store.coins ?? START_COINS) < price) { toast(`Ranked costs R$${price}. You're out of pretend Robux. Reset it in Settings.`); return; }
      store.coins = (store.coins ?? START_COINS) - price; Sound.click();
    }
    G = newGame(mode, key);
    if (mode === 'ranked' && (store.boosts || {}).time > 0) { store.boosts.time--; G.extraMs = 5000; toast('Extra Time boost: +5s every prompt'); }
    store.active = G; save(); renderCoins();
    Sound.start();
    Ocean.setDepth(0, { instant: true });
    showGame(true);
    beginQuestion(0, true);
  }

  const INTRO_MS = 3200;
  function beginQuestion(i, fresh) {
    G.idx = i; G.input = ''; G.tries = []; markSeen(G.ids[i]);
    if (fresh) { // first prompt: the duck gets flushed down the toilet before the clock starts
      G.phase = 'intro'; G.phaseEnd = Date.now() + INTRO_MS;
      Ocean.setView('intro', true); Ocean.flush(); Sound.flush();
    } else { G.phase = 'answering'; G.phaseEnd = Date.now() + answerMs(); Sound.go(); }
    save(); renderQuestion();
  }

  function setPhase(p, ms) { G.phase = p; G.phaseEnd = ms ? Date.now() + ms : 0; save(); }

  function tick() {
    if (!G || G.pausedLeft !== undefined) return;
    const now = Date.now();
    if (G.phase === 'reading') { setPhase('answering', answerMs()); renderPhase(); // legacy saved state
    } else if (G.phase === 'intro') {
      const left = G.phaseEnd - now; $('#intro-n').textContent = Math.max(1, Math.ceil(left / 1000));
      if (left <= 0) { setPhase('answering', answerMs()); Sound.go(); Ocean.setView('game'); Ocean.setShrimpX(null); Ocean.setDepth(0, { duration: 900 }); renderPhase(); }
    } else if (G.phase === 'answering') {
      const left = Math.max(0, G.phaseEnd - now);
      const frac = left / answerMs(); const sec = Math.ceil(left / 1000);
      $('#timer-num').textContent = sec;
      $('#timer-ring').style.strokeDashoffset = String(157.08 * (1 - frac));
      $('#timer-hand').setAttribute('transform', `rotate(${(-360 * (1 - frac)).toFixed(1)} 32 32)`);
      $('#time-fill').style.width = `${frac * 100}%`;
      const urgent = left <= 5000;
      $('#timer').classList.toggle('urgent', urgent); $('#time-fill').classList.toggle('urgent', urgent);
      if (sec !== lastTickSec && urgent && sec > 0) { lastTickSec = sec; Sound.tick(true); }
      if (left <= 0) timeUp();
    }
  }

  function submit() {
    if (!G || G.phase !== 'answering') return;
    const inp = $('#answer'); const val = inp.value.trim();
    if (!val) { shake(); return; }
    const n = window.Match.norm(val);
    // secret cheat: 6969 = instant Sigma (the prompt's one-in-a-million answer)
    if (val.replace(/\s/g, '') === '6969') { const sig = parseAnswers(curQ()).list.find(x => x.score === 100); if (sig) { clearSuggest(); return accept(sig, val, sig.name, undefined, true); } }
    // second Enter on a suggestion accepts it
    if (pendingSuggest && pendingSuggest.n === n) { const a = pendingSuggest.answer, typed = pendingSuggest.typed, lb = pendingSuggest.label; clearSuggest(); return accept(a, typed, lb !== a.name ? lb : undefined); }
    const m = window.Match.matchExact(curQ(), val);
    if (m) return accept(m.answer, val, m.label && m.label !== m.answer.name ? m.label : undefined); // show the name they used
    const mc = window.Match.matchContained(curQ(), val);
    if (mc) return accept(mc.answer, val, titleCase(val), window.Match.containedScore(mc.answer.score));
    const sg = window.Match.suggest(curQ(), val);
    if (sg) {
      // fill the correction into the box; submitting again confirms it, editing cancels it
      // show the closest name the player was aiming at ("quen" -> "Qwen"), not necessarily the official one
      const fix = sg.label || sg.answer.name;
      pendingSuggest = { n: window.Match.norm(fix), answer: sg.answer, typed: val, label: fix };
      $('#sg-typed').textContent = `“${val}”`; $('#sg-fix').textContent = `“${fix}”`;
      $('#suggest-box').hidden = false; $('#feedback').textContent = '';
      inp.value = fix; G.input = inp.value; save();
      inp.focus(); inp.setSelectionRange(inp.value.length, inp.value.length); Sound.dup();
      return;
    }
    if (G.tries.some(t => window.Match.norm(t) === n)) { feedback(`Already tried "${val}".`, 'warn'); Sound.dup(); }
    else { G.tries.push(val); feedback(`"${val}" isn't on our list. Try again!`, 'bad'); Sound.wrong(); renderTries(); }
    shake(); inp.select(); G.input = inp.value; save(); // keep the wrong answer in the box (selected, so typing replaces it)
  }

  let pendingSuggest = null;
  function clearSuggest() { pendingSuggest = null; $('#suggest-box').hidden = true; }
  const titleCase = s => s.trim().replace(/\s+/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
  function accept(ans, input, display, scoreOverride, cheat) {
    clearSuggest();
    if (scoreOverride) ans = Object.assign({}, ans, { score: scoreOverride });
    const t = tierOf(ans.score);
    // display: what the player typed when it was a longer phrase containing a valid answer
    G.results[G.idx] = { id: G.ids[G.idx], answer: display || ans.name, matched: ans.name, input, score: ans.score, tries: G.tries.slice() };
    if (cheat) G.results[G.idx].cheat = true; // 6969 test cheat: the game plays out, but it stays out of your stats
    G.sinkFrom = G.depth; G.score += ans.score; G.depth += Math.round(t.depth * depthScale(lenOf(G)));
    if (!cheat) store.tiers[ans.score] = (store.tiers[ans.score] || 0) + 1;
    Sound.correct(ans.score);
    sink();
  }

  function miss(reason) {
    G.results[G.idx] = { id: G.ids[G.idx], answer: null, input: G.tries[G.tries.length - 1] || '', score: 0, tries: G.tries.slice(), reason };
    setPhase('reveal'); save();
    Sound.miss();
    renderReveal(true);
  }

  function timeUp() {
    if (!G || G.phase !== 'answering') return;
    const val = ($('#answer').value || G.input || '').trim();
    if (pendingSuggest && val && window.Match.norm(val) === pendingSuggest.n) { const sa = pendingSuggest.answer; clearSuggest(); return accept(sa, val); }
    if (val) { const m = match(curQ(), val); if (m) return accept(m.answer, val); const mc = window.Match.matchContained(curQ(), val); if (mc) return accept(mc.answer, val, titleCase(val), window.Match.containedScore(mc.answer.score)); if (!G.tries.includes(val)) G.tries.push(val); }
    miss('time');
  }
  function skip() { if (G && G.phase === 'answering') miss('skip'); else if (G && G.phase === 'reading') { setPhase('answering', answerMs()); renderPhase(); } }
  const answerMs = () => ANSWER_MS + ((G && G.extraMs) || 0);

  function next() {
    if (!G || G.phase !== 'reveal') return;
    Sound.click();
    const L = lenOf(G);
    if (!L) { // endless: top up the queue so it never runs out
      if (G.idx >= G.ids.length - 2) G.ids.push(...randomIds(G.mode === 'pack' ? G.key : null, 10, G.ids));
      return beginQuestion(G.idx + 1);
    }
    if (G.idx < L - 1) beginQuestion(G.idx + 1); else finish();
  }

  function finish(silent) {
    if (!lenOf(G)) G.ids = G.ids.slice(0, Math.max(1, G.results.length)); // endless: only the prompts actually played
    const cheated = G.results.some(r => r && r.cheat);
    const earned = cheated ? 0 : coinsFor(G.score, G.ranked);
    store.coins = (store.coins ?? START_COINS) + earned;
    const entry = { coins: earned, ranked: G.ranked, price: G.price, cheated: cheated || undefined, mode: G.mode, key: G.key, len: lenOf(G), ids: G.ids, results: G.ids.map((id, i) => G.results[i] || { id, answer: null, input: '', score: 0, tries: [], reason: 'surfaced' }), score: G.score, depth: G.depth, at: Date.now() };
    if (G.mode === 'daily') { entry.dayNo = dayIndex(G.key) + 1; store.daily[G.key] = entry; }
    if (G.mode === 'archive') { const a = store.archive[G.key] || { best: 0, plays: 0 }; a.plays++; a.best = Math.max(a.best, entry.score); store.archive[G.key] = a; entry.dayNo = dayIndex(G.key) + 1; }
    store.history.push(entry); if (store.history.length > 400) store.history.splice(0, store.history.length - 400);
    store.recent = [...store.recent.filter(id => !G.ids.includes(id)), ...G.ids].slice(-600);
    store.active = null; G = null; save();
    if (silent) return;
    Sound.finish();
    showResults(entry, true);
  }

  function abandon(silent) {
    if (!G) return;
    if (G.phase !== 'reveal') { G.results[G.idx] = G.results[G.idx] || { id: G.ids[G.idx], answer: null, input: '', score: 0, tries: G.tries.slice(), reason: 'surfaced' }; }
    finish(silent);
  }
  // Throw away a practice dive (Unlimited / Pack / Archive) without recording it.
  function discardDive() { store.active = null; G = null; save(); Ocean.setDepth(0, { instant: true }); }
  const DAILY_LEAVE = "Leave today's Daily Flush? You only get one attempt a day, so it ends now and scores what you have so far.";
  // Leave the current dive (confirming when needed), then run fn.
  function leaveThen(fn) {
    if (!G) return fn();
    if (G.mode === 'daily') return confirmBox(DAILY_LEAVE, () => { abandon(true); fn(); });
    const answered = G.results.filter(Boolean).length;
    if (!answered) { discardDive(); return fn(); }
    if (!lenOf(G)) return confirmBox('End this endless run? Your score so far is saved.', () => abandon());
    if (G.ranked) return confirmBox('End this ranked run now? You get paid for the points you have so far.', () => abandon());
    confirmBox('Quit this flush? Its progress will be thrown away.', () => { discardDive(); fn(); });
  }
  function quitDive() { Sound.click(); leaveThen(showTitle); }
  function restartDive() {
    if (!G) return;
    Sound.click();
    if (G.mode === 'daily') return toast("The Daily Flush can't be restarted. It's one attempt per day.");
    if (G.ranked) return toast("Ranked runs can't be restarted. Finish it to get paid.");
    const { mode, key } = G;
    const go = () => { discardDive(); startGame(mode, key); };
    if (!G.results.filter(Boolean).length) return go();
    confirmBox(`Restart with fresh prompts (${lenName(lenOf(G)).toLowerCase()})? This flush will be thrown away.`, go);
  }

  // ---------- rendering: screens ----------
  function show(id) {
    $$('.screen').forEach(s => s.classList.toggle('active', s.id === 'screen-' + id));
    document.body.dataset.screen = id;
    $('#gauge').classList.toggle('active', id === 'game');
  }

  function showTitle() {
    if (G) return showGame();
    show('title'); Ocean.setView('title'); updateTitle();
    setTimeout(() => $('#btn-begin').focus({ preventScroll: true }), 50);
  }
  function updateTitle() {
    const k = todayKey(); const done = store.daily[k];
    $('#begin-label').textContent = G ? 'KEEP FLUSHING' : 'FLUSH';
    renderLenPick();
    const all = cleanGames(); const best = Math.max(0, ...all.map(h => h.score));
    $('#daily-note').innerHTML = all.length ? `PLAYED <b>${all.length}</b> · BEST <b>${best}</b>` : '';
    return;
    const streak = streaks().current;
    $('#daily-note').innerHTML = done
      ? `FLUSH #${dayIndex(k) + 1} · <b>${done.score}</b> PTS · NEXT <b class="cd">${hms(msToMidnight())}</b>`
        : `FLUSH #${dayIndex(k) + 1}${streak ? ` · STREAK <b>${streak}</b>` : ''}`;
  }

  function showGame(fromTitle) {
    show('game'); Ocean.setView('game'); Ocean.setEndless(!lenOf(G));
    Ocean.setDepth(G.depth, { instant: true });
    buildGauge(); renderHud(); renderQuestion(true);
  }

  function renderHud(depthOverride) {
    if (!G) return;
    const d = depthOverride ?? G.depth;
    $('#depth-val').textContent = fmt(Math.max(0, d));
    $('#score-val').textContent = G.score;
    const L = lenOf(G);
    const pips = $('#pips'); pips.innerHTML = ''; pips.dataset.label = promptLabel();
    const from = L ? 0 : Math.max(0, G.idx - 8), to = L ? L : from + 10; // endless: a rolling window of 10
    for (let i = from; i < to; i++) {
      const r = G.results[i]; const el = document.createElement('span'); el.className = 'pip';
      if (r) { if (r.score) { el.classList.add('done'); el.style.setProperty('--c', tierOf(r.score).color); } else el.classList.add('miss'); }
      else if (i === G.idx) el.classList.add('cur');
      pips.appendChild(el);
    }
  }

  function promptLabel() { const L = lenOf(G), r = G.ranked ? 'RANKED · ' : ''; return L ? `${r}PROMPT ${G.idx + 1} OF ${L}` : `PROMPT ${G.idx + 1} · ENDLESS`; }
  function renderQuestion(restoring) {
    const q = curQ(); if (!q) return;
    $('#prompt-no').textContent = promptLabel();
    $('#q-meta').textContent = store.settings.showMeta ? `${q.cat} · ${q.diff}`.toUpperCase() : '';
    $('#q-text').textContent = q.q;
    $('#answer').value = G.phase === 'answering' ? (G.input || '') : '';
    clearSuggest(); $('#feedback').textContent = ''; $('#feedback').className = 'feedback';
    renderTries(); renderHud(); lastTickSec = -1;
    if (G.phase === 'sinking') { Ocean.setDepth(G.depth, { instant: true }); setPhase('reveal'); }
    if (G.phase === 'reveal') renderReveal(false); else renderPhase();
  }
  function renderTries() {
    const ul = $('#tried'); ul.innerHTML = '';
    (G?.tries || []).slice(-6).forEach(t => { const li = document.createElement('li'); li.textContent = t; ul.appendChild(li); });
  }

  function renderPhase() {
    const ask = $('#phase-ask'), rev = $('#phase-reveal');
    ask.hidden = false; rev.hidden = true;
    const reading = G.phase === 'reading' || G.phase === 'intro';
    document.body.classList.toggle('intro', G.phase === 'intro');
    $('#answer').disabled = reading; $('#btn-dive').disabled = reading;
    $('#btn-skip').textContent = 'SKIP ▸▸';
    if (!reading) { const inp = $('#answer'); setTimeout(() => inp.focus({ preventScroll: true }), 30); }
    tick();
  }

  function renderReveal(animate) {
    const q = curQ(); const r = G.results[G.idx];
    $('#phase-ask').hidden = true; const rev = $('#phase-reveal'); rev.hidden = false;
    rev.classList.remove('pop'); void rev.offsetWidth; rev.classList.add('pop');
    const { list } = parseAnswers(q);
    const t = r.score ? tierOf(r.score) : null;
    if (t) {
      rev.style.setProperty('--tc', t.color);
      $('#tier-name').textContent = t.name.toUpperCase();
      $('#reveal-answer').textContent = `“${r.answer}”`;
      $('#reveal-pts').innerHTML = `<span class="pts">+${r.score} PTS</span> <span class="dot">·</span> flush ${fmt(Math.round(t.depth * depthScale(lenOf(G))))}m`;
      $('#reveal-blurb').textContent = t.blurb;
    } else {
      rev.style.setProperty('--tc', '#8aa0b8');
      $('#tier-name').textContent = r.reason === 'skip' ? 'SKIPPED' : r.reason === 'surfaced' ? 'SURFACED' : "TIME'S UP";
      $('#reveal-answer').textContent = r.input ? `“${r.input}”` : '—';
      $('#reveal-pts').innerHTML = `<span class="pts">+0 PTS</span> <span class="dot">·</span> stuck in the bowl`;
      $('#reveal-blurb').textContent = r.reason === 'skip' ? 'Skipped. Every answer is in the flush log at the end.' : 'Nothing went down this time.';
    }
    const L = lenOf(G), last = L && G.idx >= L - 1;
    $('#btn-descend').innerHTML = !last ? 'KEEP FLUSHING <span class="tri">▼</span>' : 'RESURFACE <span class="tri">▲</span>';
    $('#btn-endrun').hidden = !!L;
    drawTierIcon(t ? t.key : null);
    document.body.classList.remove('intro');
    renderHud(); if (last) $('#pips').dataset.label = 'FLUSH COMPLETE';
    $('#btn-descend').disabled = false;
    setTimeout(() => $('#btn-descend').focus({ preventScroll: true }), 30);
  }

  // DESCEND: the answer, in its rarity color, is dragged down with the shrimp.
  let sinkTimer = null;
  function sink() {
    const r = G.results[G.idx]; const t = tierOf(r.score);
    setPhase('sinking');
    $('#phase-reveal').hidden = true; $('#phase-ask').hidden = false;
    $('#answer').disabled = true;
    const box = $('#sink'); box.style.setProperty('--tc', t.color);
    $('#sink-text').textContent = `“${r.answer}”`;
    $('#sink-tag').innerHTML = `${iconImg(t.key, 'pix tag-ico')}<span>${t.name.toUpperCase()} · ${r.score}</span>`;
    box.hidden = false; box.classList.remove('go'); void box.offsetWidth; box.classList.add('go');
    document.body.classList.add('sinking');
    Ocean.setShrimpX(0.5);
    const reduced = store.settings.motion === 'reduced';
    const dur = reduced ? 0 : 1500 + t.depth * 1.9;
    setTimeout(() => {
      Ocean.setDepth(G.depth, { duration: dur });
      Sound.descend(dur || 300);
    }, reduced ? 0 : 450);
    clearTimeout(sinkTimer);
    sinkTimer = setTimeout(afterSink, (reduced ? 300 : 450 + dur + 450));
  }
  function afterSink() {
    clearTimeout(sinkTimer);
    $('#sink').hidden = true; document.body.classList.remove('sinking');
    Ocean.setShrimpX(null);
    if (!G || G.phase !== 'sinking') return;
    setPhase('reveal'); renderReveal(true);
  }

  // Depth labels drifting past on either side (zone names left, sea-life notes right).
  const DEPTH_LABELS = [
    [0, 'l', 'the bowl'], [200, 'l', 'the pipes'], [1000, 'l', 'the sewer'], [3600, 'l', 'the rat kingdom'], [4600, 'l', 'the brainrot core'], [5600, 'l', 'it gets unhinged'],
    [60, 'r', 'last chance to unflush'], [150, 'l', 'lost AirPod spotted'], [260, 'r', 'someone flushed a goldfish'], [420, 'l', 'the smell intensifies'],
    [600, 'r', 'a sock. just one sock.'], [850, 'l', 'toothbrush graveyard'], [1150, 'r', 'gator sighting (unconfirmed)'], [1500, 'l', 'you can hear Ohio from here'],
    [2000, 'r', 'fatberg the size of a bus'], [2600, 'l', 'rats doing a TikTok dance'], [3200, 'r', 'the wifi is surprisingly good'], [3300, 'l', 'abandoned rubber duck colony'],
    [3900, 'r', 'rat with a crown'], [4300, 'r', 'the rat king is watching'], [5000, 'r', 'skill issue detected'], [6200, 'l', 'skibidi levels critical'], [6800, 'r', 'peak brainrot ahead'],
    [7400, 'l', 'the rats have a DJ now'], [8000, 'r', 'it only gets worse from here'], [8800, 'l', 'ohio sends its regards'], [9600, 'r', 'the bass is load-bearing'],
    [10500, 'l', 'no one has ever come back'], [11500, 'r', 'certified brainrot bedrock'], [13000, 'l', 'you are the brainrot now'],
  ];
  function buildDepthLabels() {
    $('#tier-lines').innerHTML = TIERS.slice().reverse().map(t => `<div class="tl" data-d="${t.depth}" style="--tc:${t.color}"><span>${iconImg(t.key, 'pix tag-ico')} ${t.name.toUpperCase()} · ${t.score}</span></div>`).join('');
    const box = $('#depth-labels'); if (box.childElementCount) return;
    box.innerHTML = DEPTH_LABELS.map(([m, side, text]) => `<span class="dl dl-${side}${side === 'l' && /zone|trench/.test(text) ? ' zone' : ''}" data-m="${m}">${side === 'l' ? '—— ' : ''}${esc(text)}${side === 'r' ? ' ——' : ''}</span>`).join('');
  }
  function labelLoop() {
    if (document.body.dataset.screen === 'game') {
      const H = window.innerHeight;
      for (const el of document.querySelectorAll('#depth-labels .dl')) {
        const y = Ocean.depthToScreenY(Number(el.dataset.m));
        if (y < -30 || y > H + 30) { el.style.display = 'none'; continue; }
        el.style.display = ''; el.style.transform = `translateY(${Math.round(y)}px)`;
      }
      // rarity threshold lines below where this answer started sinking
      if (G && document.body.classList.contains('sinking')) {
        for (const el of document.querySelectorAll('#tier-lines .tl')) {
          const y = Ocean.depthToScreenY((G.sinkFrom || 0) + Number(el.dataset.d) * depthScale(lenOf(G))); // same scale the duck sinks by
          el.style.display = y < -20 || y > H + 20 ? 'none' : ''; el.style.transform = `translateY(${Math.round(y)}px)`;
        }
      }
      // local depth ruler: a tick every 25m, labels every 100m
      const top = Ocean.screenYToDepth(0), bot = Ocean.screenYToDepth(H);
      const ticks = []; for (let d = Math.ceil(Math.max(0, top) / 25) * 25; d <= bot; d += 25) ticks.push(d);
      const ruler = $('#ruler');
      while (ruler.childElementCount < ticks.length) ruler.appendChild(document.createElement('span'));
      [...ruler.children].forEach((el, i) => {
        const d = ticks[i]; if (d === undefined) { el.style.display = 'none'; return; }
        el.style.display = ''; el.className = d % 100 === 0 ? 'rt major' : 'rt';
        el.textContent = d % 100 === 0 ? (d ? `-${fmt(d)}m` : '0m') : '';
        el.style.transform = `translateY(${Math.round(Ocean.depthToScreenY(d))}px)`;
      });
      $('#gauge-you').style.transform = `translateY(${Math.round(Ocean.shrimpScreen().y)}px)`;
      const sk = $('#sink'); if (!sk.hidden) { const p = Ocean.shrimpScreen(); sk.style.top = `${Math.round(p.y - 46)}px`; /* the shrimp hangs just below, dragging it down */ }
    }
    requestAnimationFrame(labelLoop);
  }

  function drawTierIcon(key) {
    const c = $('#tier-icon'); const ctx = c.getContext('2d');
    const [name, tint, flip] = ICON_SPR[key || 'none'];
    const s = Ocean.sprite(name, tint || undefined); c.width = s.w; c.height = s.h; ctx.clearRect(0, 0, s.w, s.h); ctx.drawImage(flip ? s.f : s.c, 0, 0);
    $('#phase-reveal').dataset.tier = key || 'none';
    const k = Math.max(2, Math.round(64 / s.w)); c.style.width = `${s.w * k}px`; c.style.height = `${s.h * k}px`;
  }

  // depth -> zone banner + gauge during animation
  let lastZone = -1;
  Ocean.onDepth = (d) => {
    if (!G || document.body.dataset.screen !== 'game') return;
    $('#depth-val').textContent = fmt(Math.max(0, d));
    const z = Ocean.zoneIndex(d);
    lastZone = z;
  };
  function zoneBanner(z) {
    const b = $('#zone-banner'); b.innerHTML = `ENTERING<br><b>${z.name.toUpperCase()}</b><span>${fmt(z.from)}m${z.to < 9999 ? '–' + fmt(z.to) + 'm' : '+'}</span>`;
    b.classList.remove('show'); void b.offsetWidth; b.classList.add('show');
  }

  function buildGauge() {
    const t = $('#gauge-ticks'); if (!t || t.childElementCount) return;
    for (let m = 0; m <= 7000; m += 1000) { const s = document.createElement('span'); s.style.top = `${(m / 7000) * 100}%`; s.textContent = m === 0 ? '0m' : `${fmt(m)}m`; t.appendChild(s); }
  }

  function feedback(msg, cls) { const f = $('#feedback'); f.textContent = msg; f.className = 'feedback ' + (cls || ''); }
  function shake() { const r = $('#answer-form'); r.classList.remove('shake'); void r.offsetWidth; r.classList.add('shake'); }

  // ---------- results ----------
  let resultsEntry = null;
  const iconCache = {};
  function iconURL(key) {
    if (!iconCache[key]) { const [n, tint, flip] = ICON_SPR[key]; const sp = Ocean.sprite(n, tint || undefined); iconCache[key] = (flip ? sp.f : sp.c).toDataURL(); }
    return iconCache[key];
  }
  const iconImg = (key, cls = 'pix') => `<img class="${cls}" src="${iconURL(key)}" alt="">`;
  // Score bands for a whole dive (out of 700).
  const BEARING = [
    { min: 0, max: 150, tier: 'plankton', label: '0–150', text: 'NPC. Still in the bowl, basically.' },
    { min: 151, max: 250, tier: 'schooler', label: '151–250', text: 'Mid. Made it into the pipes.' },
    { min: 251, max: 350, tier: 'rare', label: '251–350', text: 'Rizz. Deep in the sewer. Respect.' },
    { min: 351, max: 449, tier: 'deep', label: '351–449', text: 'Skibidi. Rat royalty bows to you.' },
    { min: 450, max: 700, tier: 'million', label: '450+', text: 'Sigma. You reached the Brainrot Core.' },
  ];
  const TIER_COLOR = Object.fromEntries(TIERS.map(t => [t.key, t.color]));

  function showResults(entry, fresh) {
    resultsEntry = entry;
    show('results'); Ocean.setView('results');
    $('#screen-results').scrollTop = 0;
    const modeLabel = entry.mode === 'daily' ? `FLUSH #${entry.dayNo} COMPLETE`
      : entry.mode === 'archive' ? `ARCHIVE FLUSH #${entry.dayNo} COMPLETE`
      : entry.mode === 'pack' ? `${(PACKS.find(p => p.key === entry.key) || {}).name || entry.key} PACK COMPLETE`.toUpperCase() : entry.ranked ? `RANKED ${countOf(entry)}-PROMPT FLUSH` : entry.len === 0 ? `ENDLESS RUN · ${countOf(entry)} PROMPTS` : `${countOf(entry)}-PROMPT FLUSH COMPLETE`;
    $('#res-mode').textContent = modeLabel;
    countUp($('#res-score'), entry.score, fresh ? 900 : 0);
    $('#res-depth').textContent = `-${fmt(entry.depth)}m`;
    $('#res-zone').textContent = entry.depth ? `Reached the ${Ocean.ZONES[Ocean.zoneIndex(entry.depth)].name}` : 'Never left the bowl';
    drawDiveChart(entry);
    drawStack(entry);
    const cl = $('#res-coins');
    if (entry.cheated) cl.innerHTML = 'Cheat code used · no Robux this time';
    else if (entry.ranked) { const net = (entry.coins || 0) - (entry.price || 0); cl.innerHTML = `Bought in ${coinTag(entry.price)} · paid out ${coinTag(entry.coins || 0)} · <b class="${net >= 0 ? 'up' : 'down'}">${net >= 0 ? '+' : ''}${net} ${net >= 0 ? 'profit' : 'loss'}</b>`; }
    else cl.innerHTML = `Free game · play <b>Ranked</b> to win Robux`;
    renderCoins();
    // bearing
    const n = countOf(entry), sc = n / 7, norm = entry.score / sc; // bands are written for 7 prompts
    $('#bearing').innerHTML = BEARING.map((b, i) => {
      const on = norm >= b.min && (norm <= b.max || i === BEARING.length - 1) && (i === BEARING.length - 1 || norm < BEARING[i + 1].min);
      const label = i === BEARING.length - 1 ? `${Math.round(b.min * sc)}+` : `${Math.round(b.min * sc)}–${Math.round((BEARING[i + 1].min) * sc) - 1}`;
      return `<li class="${on ? 'on' : ''}">${iconImg(b.tier)}<span class="b-range" style="color:${TIER_COLOR[b.tier]}">${label}</span><span class="b-text">${b.text}</span></li>`;
    }).join('');
    // logbook
    const st = streaks(); const all = store.history;
    $('#st-streak').textContent = st.current; $('#st-played').textContent = all.length;
    const clean = cleanGames();
    $('#st-avg').textContent = clean.length ? Math.round(clean.reduce((n, h) => n + h.score, 0) / clean.length) : 0;
    $('#st-best').textContent = Math.max(0, ...clean.map(h => h.score));
    // the catch
    const list = $('#log-list'); list.innerHTML = '';
    entry.results.forEach((r, i) => {
      const q = BY_ID.get(r.id); if (!q) return;
      const t = r.score ? tierOf(r.score) : null;
      const col = t ? t.color : '#4f6079';
      const ans = r.answer ? esc(r.answer) : r.input ? `"${esc(r.input)}"` : (r.reason === 'skip' ? 'skipped' : '—');
      const sub = t ? `<span style="color:${t.color}">${t.name}</span> · flushed ${fmt(Math.round(t.depth * depthScale(lenOf(entry))))}m` : (r.reason === 'skip' ? 'Skipped' : r.reason === 'surfaced' ? 'Pulled out early' : "Time's up") + ' · nothing flushed';
      const li = document.createElement('li'); li.className = 'catch-row';
      li.innerHTML = `<button class="catch-head" aria-expanded="false"><span class="c-n">${i + 1}</span><span class="c-icon">${iconImg(t ? t.key : 'none')}</span><span class="c-body"><span class="c-q">${esc(q.q.replace(/\.$/, ''))}</span><span class="c-a${r.answer ? '' : ' miss'}">${ans}</span><span class="c-sub">${sub}</span></span><span class="c-p" style="color:${col}">${r.score}</span><span class="c-plus">+</span></button><div class="log-more" hidden></div>`;
      li.querySelector('.catch-head').addEventListener('click', () => toggleLog(li, q, r));
      list.appendChild(li);
    });
    $('#btn-again').innerHTML = `<span class="tri">▼</span>${entry.mode === 'pack' ? 'PLAY PACK AGAIN' : 'PLAY AGAIN'}<span class="tri">▼</span>`;
    renderLenPick();
    updateCountdown();
    setTimeout(() => $('#btn-share').focus({ preventScroll: true }), 60);
  }
  // ---------- how you stack up ----------
  // How an average player does on one prompt (share of answers per score). It's a fixed model for now; on Roblox it
  // gets replaced by real score counts (see ROBLOX.md). A game's score curve is this convolved n times.
  const AVG_PROMPT = { 0: 0.11, 10: 0.45, 30: 0.25, 60: 0.12, 85: 0.05, 100: 0.02 };
  function scoreCurve(n) {
    let dist = [1]; // index = points / 5
    const step = Object.entries(AVG_PROMPT).map(([p, w]) => [Number(p) / 5, w]);
    for (let i = 0; i < n; i++) {
      const next = new Array(dist.length + 20).fill(0);
      dist.forEach((v, k) => { if (v) for (const [s, w] of step) next[k + s] += v * w; });
      dist = next;
    }
    return dist; // dist[k] = chance of scoring exactly 5k
  }
  function percentile(dist, score) {
    const k = Math.round(score / 5); let below = 0;
    for (let i = 0; i < Math.min(k, dist.length); i++) below += dist[i];
    return Math.round(100 * (below + 0.5 * (dist[k] || 0)));
  }
  function drawStack(entry) {
    const n = Math.max(1, countOf(entry)), dist = scoreCurve(Math.min(n, 120)), pct = percentile(dist, entry.score);
    const W = 480, H = 230, L = 10, R = 10, T = 74, B = 26; // T leaves room above the curve for your icon + label
    // show the part of the curve where players actually land (0.2%–99.8%), plus your score
    let lo = 0, hi = dist.length - 1, c = 0;
    for (let i = 0; i < dist.length; i++) { c += dist[i]; if (c < 0.002) lo = i; if (c < 0.998) hi = i + 1; }
    const you = Math.round(entry.score / 5); lo = Math.max(0, Math.min(lo, you - 2)); hi = Math.min(dist.length - 1, Math.max(hi, you + 2));
    // smooth the bumpy discrete distribution into a clean slope
    const sm = dist.map((_, i) => { let s = 0, w = 0; for (let j = -3; j <= 3; j++) { const v = dist[i + j]; if (v !== undefined) { const ww = 4 - Math.abs(j); s += v * ww; w += ww; } } return s / w; });
    const peak = Math.max(...sm.slice(lo, hi + 1));
    const x = i => L + ((i - lo) / Math.max(1, hi - lo)) * (W - L - R), y = v => H - B - (v / peak) * (H - T - B);
    let line = '', fillYou = '';
    for (let i = lo; i <= hi; i++) line += `${i === lo ? 'M' : 'L'}${x(i).toFixed(1)},${y(sm[i]).toFixed(1)} `;
    for (let i = lo; i <= Math.min(you, hi); i++) fillYou += `${i === lo ? 'M' : 'L'}${x(i).toFixed(1)},${y(sm[i]).toFixed(1)} `;
    const yx = x(Math.min(Math.max(you, lo), hi)), yy = y(sm[Math.min(Math.max(you, lo), hi)]);
    const per = entry.score / n, t = tierOf(per >= 70 ? 100 : per >= 50 ? 85 : per >= 35 ? 60 : per >= 20 ? 30 : 10); // color by your points per prompt
    const avg = dist.reduce((s, v, i) => s + v * i * 5, 0);
    let svg = `<path d="${line} L${x(hi).toFixed(1)},${H - B} L${x(lo).toFixed(1)},${H - B} Z" class="sc-all"/>`;
    svg += `<path d="${fillYou} L${yx.toFixed(1)},${H - B} L${x(lo).toFixed(1)},${H - B} Z" class="sc-you" style="fill:${t.color}"/>`;
    svg += `<path d="${line}" class="sc-line"/>`;
    const ax = x(Math.round(avg / 5)), near = Math.abs(ax - yx) < 70; // keep the AVG label clear of your marker
    const aLabelX = near ? (ax < yx ? ax - 6 : ax + 6) : ax, aAnchor = near ? (ax < yx ? 'end' : 'start') : 'middle';
    svg += `<line x1="${ax.toFixed(1)}" x2="${ax.toFixed(1)}" y1="${T - 6}" y2="${H - B}" class="sc-avg"/><text x="${aLabelX.toFixed(1)}" y="${T - 9}" class="sc-ax" text-anchor="${aAnchor}">AVG ${Math.round(avg)}</text>`;
    svg += `<line x1="${yx.toFixed(1)}" x2="${yx.toFixed(1)}" y1="${(Math.max(18, yy - 44) + 28).toFixed(1)}" y2="${H - B}" stroke="${t.color}" class="sc-you-line"/>`;
    const iy = Math.max(18, yy - 44), lx = Math.min(W - 40, Math.max(40, yx)); // never above the chart, never off its sides
    svg += `<image href="${iconURL(t.key)}" x="${(yx - 14).toFixed(1)}" y="${iy.toFixed(1)}" width="28" height="28" class="pix-svg"/>`;
    svg += `<text x="${lx.toFixed(1)}" y="${(iy - 5).toFixed(1)}" class="sc-you-t" text-anchor="middle" style="fill:${t.color}">YOU ${entry.score}</text>`;
    svg += `<line x1="${L}" x2="${W - R}" y1="${H - B}" y2="${H - B}" class="sc-base"/>`;
    for (const f of [0, 0.25, 0.5, 0.75, 1]) { const i = Math.round(lo + f * (hi - lo)); svg += `<text x="${x(i).toFixed(1)}" y="${H - 8}" class="sc-ax" text-anchor="middle">${i * 5}</text>`; }
    $('#stack-chart').innerHTML = svg;
    const word = pct >= 99 ? 'Top 1%. Certified Sigma.' : pct >= 90 ? 'Built different.' : pct >= 70 ? 'Above the crowd.' : pct >= 45 ? 'Right in the pack.' : pct >= 20 ? 'Kinda NPC behavior.' : 'Still in the bowl.';
    $('#stack-line').innerHTML = `Better than <b style="color:${t.color}">${Math.min(99, Math.max(1, pct))}%</b> of flushers. <span>${word}</span>`;
    $('#stack-sub').textContent = `VS. THE AVERAGE ${n}-PROMPT FLUSH`;
  }

  function drawDiveChart(entry) {
    const W = 480, H = 270, L = 34, R = 14, T = 14, B = 30;
    const n = Math.max(1, entry.results.length); const slot = (W - L - R) / n;
    const x = i => L + (i + 0.5) * slot;
    const y = p => T + (p / 100) * (H - T - B);
    let svg = '';
    for (const p of [0, 25, 50, 75, 100]) {
      svg += `<line x1="${L}" x2="${W - R}" y1="${y(p)}" y2="${y(p)}" class="grid${p === 0 ? ' g0' : ''}"/><text x="${L - 6}" y="${y(p) + 3}" class="ax" text-anchor="end">${p ? '-' + p : '0m'}</text>`;
    }
    entry.results.forEach((r, i) => {
      const t = r.score ? tierOf(r.score) : null; const cx = x(i);
      if (n <= 12 || (i + 1) % 5 === 0 || i === 0) svg += `<text x="${cx}" y="${H - 8}" class="ax" text-anchor="middle">${i + 1}</text>`;
      if (!t) { svg += `<circle cx="${cx}" cy="${y(0)}" r="4" class="nocatch"/>`; return; }
      const cy = y(r.score);
      svg += `<line x1="${cx}" x2="${cx}" y1="${y(0)}" y2="${cy}" stroke="${t.color}" class="drop" style="--len:${cy - y(0)}"/>`;
      const s = Ocean.sprite(ICON_SPR[t.key][0], ICON_SPR[t.key][1] || undefined); const sz = Math.min(32, Math.max(10, slot - 2));
      svg += `<image href="${iconURL(t.key)}" x="${cx - sz / 2}" y="${cy - sz / 2}" width="${sz}" height="${sz}" class="pix-svg"/>`;
    });
    $('#dive-chart').innerHTML = svg;
  }
  // Expanded round: every accepted answer, filterable by rarity, searchable, scrolls in pages of 100.
  function toggleLog(li, q, r) {
    const more = li.querySelector('.log-more'); const head = li.querySelector('button');
    const open = more.hidden; more.hidden = !open; head.setAttribute('aria-expanded', open); li.classList.toggle('open', open);
    if (!open || more.childElementCount) return;
    const mine = r.matched || r.answer;
    const all = parseAnswers(q).list.filter(a => !a.hidden || a.name === mine)
      .slice().sort((x, y) => (y.score - x.score) || x.name.localeCompare(y.name));
    const SHORT = { million: 'Sigma', deep: 'Skibidi', rare: 'Rizz', schooler: 'Mid', plankton: 'NPC' };
    const chips = [`<button class="ab-chip on" data-t="all">All <b>${fmt(all.length)}</b></button>`]
      .concat(TIERS.map(t => `<button class="ab-chip" data-t="${t.score}" style="--c:${t.color}">${SHORT[t.key]} <b>${fmt(all.filter(a => a.score === t.score).length)}</b></button>`));
    more.innerHTML = `${r.tries && r.tries.length ? `<p class="more-tries">Your misses: ${r.tries.map(t => `<s>${esc(t)}</s>`).join(', ')}</p>` : ''}
      <div class="ab-chips">${chips.join('')}</div>
      <input class="ab-search" type="search" placeholder="Search all answers…" aria-label="Search all answers" autocomplete="off" spellcheck="false">
      <div class="ab-list" tabindex="0"></div>
      <div class="ab-foot"><span class="ab-count"></span><span class="ab-more">Scroll for more</span></div>`;
    const list = more.querySelector('.ab-list'); let tier = 'all', query = '', shown = 0, rows = all;
    const row = a => { const t = tierOf(a.score); return `<div class="ab-row${a.name === mine ? ' mine' : ''}">${iconImg(t.key, 'pix ab-ico')}<span class="ab-name">${esc(a.name)}</span><span class="ab-pts" style="color:${t.color}">+${a.score}</span></div>`; };
    const page = () => { const next = rows.slice(shown, shown + 100); list.insertAdjacentHTML('beforeend', next.map(row).join('')); shown += next.length; foot(); };
    const foot = () => { more.querySelector('.ab-count').textContent = `${fmt(shown)} of ${fmt(rows.length)} answers`; more.querySelector('.ab-more').hidden = shown >= rows.length; };
    const apply = () => {
      const n = query ? window.Match.norm(query) : '';
      rows = all.filter(a => (tier === 'all' || a.score === Number(tier)) && (!n || window.Match.norm(a.name).includes(n) || a.aliases.some(al => window.Match.norm(al).includes(n))));
      list.innerHTML = rows.length ? '' : '<p class="ab-empty">No answers match.</p>'; shown = 0; list.scrollTop = 0; page();
    };
    more.querySelectorAll('.ab-chip').forEach(c => c.addEventListener('click', () => { more.querySelectorAll('.ab-chip').forEach(x => x.classList.toggle('on', x === c)); tier = c.dataset.t; apply(); }));
    more.querySelector('.ab-search').addEventListener('input', e => { query = e.target.value.trim(); apply(); });
    list.addEventListener('scroll', () => { if (list.scrollTop + list.clientHeight > list.scrollHeight - 120 && shown < rows.length) page(); });
    apply();
  }
  function countUp(el, to, ms) {
    if (!ms || store.settings.motion === 'reduced') { el.textContent = to; return; }
    const t0 = performance.now();
    const step = now => { const p = Math.min(1, (now - t0) / ms); el.textContent = Math.round(to * (1 - Math.pow(1 - p, 3))); if (p < 1) requestAnimationFrame(step); };
    requestAnimationFrame(step);
  }

  function shareText(e) {
    const sq = { 0: '⬛', 10: '⬜', 15: '⬜', 30: '🟦', 60: '🟥', 85: '🟪', 100: '🟨' };
    const head = e.mode === 'daily' || e.mode === 'archive' ? `FLUSHED #${e.dayNo}${e.mode === 'archive' ? ' (archive)' : ''}` : e.mode === 'pack' ? `FLUSHED · ${(PACKS.find(p => p.key === e.key) || {}).name} pack` : e.len === 0 ? 'FLUSHED · Endless' : `FLUSHED · ${countOf(e)} prompts`;
    const n = countOf(e); const tail = e.len === 0 ? `${e.score} pts in ${n} prompts` : `${e.score}/${n * 100}`;
    return `${head} 🦆\n${tail} · -${fmt(e.depth)}m\n${e.results.map(r => sq[r.score] || '⬛').join('')}`;
  }
  async function copyShare() {
    if (!resultsEntry) return;
    const txt = shareText(resultsEntry);
    try { await navigator.clipboard.writeText(txt); toast('Result copied to clipboard'); }
    catch (e) { const ta = document.createElement('textarea'); ta.value = txt; document.body.appendChild(ta); ta.select(); try { document.execCommand('copy'); toast('Result copied to clipboard'); } catch (x) { toast('Copy failed'); } ta.remove(); }
    Sound.click();
  }

  // ---------- stats ----------
  function streaks() {
    const days = Object.keys(store.daily).sort();
    let max = 0, run = 0, prev = null;
    for (const d of days) { run = prev && addDays(prev, 1) === d ? run + 1 : 1; max = Math.max(max, run); prev = d; }
    const t = todayKey(); let cur = 0; let k = store.daily[t] ? t : addDays(t, -1);
    while (store.daily[k]) { cur++; k = addDays(k, -1); }
    return { current: cur, max };
  }
  const cleanGames = () => store.history.filter(h => !h.cheated); // games where you used the 6996 cheat don't count
  function statsHtml() {
    const games = store.history, all = cleanGames();
    const per = e => e.score / Math.max(1, e.results.length); // points per prompt, comparable across game lengths
    const avg = all.length ? Math.round(all.reduce((n, e) => n + e.score, 0) / all.length) : 0;
    const avgPer = all.length ? Math.round(all.reduce((n, e) => n + per(e), 0) / all.length) : 0;
    const best = Math.max(0, ...all.map(e => e.score));
    const deepest = Math.max(0, ...all.map(e => e.depth));
    const answered = all.reduce((n, e) => n + e.results.filter(r => r.score).length, 0);
    const total = all.reduce((n, e) => n + e.results.length, 0);
    const bins = new Array(10).fill(0); all.forEach(e => bins[Math.min(9, Math.floor(per(e) / 10))]++);
    const bmax = Math.max(1, ...bins);
    const tmax = Math.max(1, ...TIERS.map(t => store.tiers[t.score] || 0));
    return `
      <div class="stat-grid">
        <div><b>${games.length}</b><span>FLUSHES</span></div>
        <div><b>${best}</b><span>PERSONAL BEST</span></div>
        <div><b>${avg}</b><span>AVG SCORE</span></div>
        <div><b>${avgPer}</b><span>AVG PER PROMPT</span></div>
        <div><b>${fmt(deepest)}m</b><span>DEEPEST</span></div>
        <div><b>${total ? Math.round(answered / total * 100) : 0}%</b><span>ANSWERED</span></div>
      </div>
      <h3 class="mh">POINTS PER PROMPT</h3>
      <div class="bars">${bins.map((b, i) => `<div class="bar-row"><span>${i * 10}${i === 9 ? '+' : '–' + (i * 10 + 9)}</span><i style="width:${(b / bmax) * 100}%"></i><em>${b}</em></div>`).join('')}</div>
      <h3 class="mh">RARITIES FOUND</h3>
      <div class="bars">${TIERS.map(t => `<div class="bar-row"><span style="color:${t.color}">${t.name}</span><i style="width:${((store.tiers[t.score] || 0) / tmax) * 100}%;background:${t.color}"></i><em>${store.tiers[t.score] || 0}</em></div>`).join('')}</div>
      <p class="fine">Games where you used a cheat code still count as played, but not toward your best or average.</p>
      <button class="btn btn-ghost small" id="btn-reset-stats">RESET STATISTICS</button>`;
  }
  // ---------- Shop ----------
  // Cosmetics are pure profit (no effect on score). The one boost is priced well above what it adds to an average payout.
  // Price ladder: cheap impulse buys (5-25) so everyone can get something, a solid middle (100-400), and a few
  // absurd flex items (25,000-1,000,000) for the rare player with way too much Robux.
  const SHOP = [
    { id: 'duck-mint', type: 'duck', name: 'Mint Duck', price: 5, tint: '~#9fffd0' },
    { id: 'duck-peach', type: 'duck', name: 'Peach Duck', price: 10, tint: '~#ffb88a' },
    { id: 'duck-lemon', type: 'duck', name: 'Lemonade Duck', price: 15, tint: '~#fff27a' },
    { id: 'duck-diamond', type: 'duck', name: 'Diamond Duck', price: 25000, tint: '~#dff8ff', fx: 'diamond' },
    { id: 'duck-rainbow', type: 'duck', name: 'Rainbow Duck', price: 100000, fx: 'rainbow' },
    { id: 'duck-million', type: 'duck', name: 'One-in-a-Million Duck', price: 1000000, tint: '~#ffd23f', fx: 'million' },
    { id: 'duck-gold', type: 'duck', name: 'Golden Duck', price: 250, tint: '~#ffcc33' },
    { id: 'duck-ninja', type: 'duck', name: 'Ninja Duck', price: 150, tint: '~#4a4f5e' },
    { id: 'duck-bubblegum', type: 'duck', name: 'Bubblegum Duck', price: 100, tint: '~#ff7ac8' },
    { id: 'duck-ice', type: 'duck', name: 'Ice Duck', price: 100, tint: '~#9fe8ff' },
    { id: 'duck-toxic', type: 'duck', name: 'Toxic Duck', price: 120, tint: '~#7dff6a' },
    { id: 'duck-void', type: 'duck', name: 'Void Duck', price: 300, tint: '~#8a5cff' },
    { id: 'toilet-sky', type: 'toilet', name: 'Sky Blue Toilet', price: 10, tint: '~#bfe6ff' },
    { id: 'toilet-mint', type: 'toilet', name: 'Mint Toilet', price: 20, tint: '~#c6ffe0' },
    { id: 'toilet-gold', type: 'toilet', name: 'Golden Throne', price: 400, sprite: 'goldtoilet' },
    { id: 'toilet-diamond', type: 'toilet', name: 'Diamond Throne', price: 250000, tint: '~#e6fbff', fx: 'diamond' },
    { id: 'toilet-ratking', type: 'toilet', name: "Rat King's Throne", price: 500000, sprite: 'goldtoilet', fx: 'crown' },
    { id: 'toilet-pink', type: 'toilet', name: 'Pink Porcelain', price: 150, tint: '~#ffb3d9' },
    { id: 'toilet-obsidian', type: 'toilet', name: 'Obsidian Throne', price: 250, tint: '~#4a4458' },
    { id: 'trail-bubble', type: 'trail', name: 'Bubble Trail', price: 5, trail: 'bubble' },
    { id: 'trail-confetti', type: 'trail', name: 'Confetti Trail', price: 25, trail: 'confetti' },
    { id: 'trail-rainbow', type: 'trail', name: 'Rainbow Trail', price: 200, trail: 'rainbow' },
    { id: 'trail-money', type: 'trail', name: 'Money Trail', price: 75000, trail: 'money' },
    { id: 'trail-aura', type: 'trail', name: 'Infinite Aura Trail', price: 150000, trail: 'aura' },
    { id: 'trail-sparkle', type: 'trail', name: 'Sparkle Trail', price: 120, trail: 'sparkle' },
    { id: 'trail-fire', type: 'trail', name: 'Fire Trail', price: 175, trail: 'fire' },
    { id: 'boost-time', type: 'boost', name: 'Extra Time', note: '+5s every prompt, next ranked run', price: 5 },
  ];
  function applySkin() {
    const eq = store.equip || {}, byId = id => SHOP.find(s => s.id === id) || {};
    const d = byId(eq.duck), tl = byId(eq.toilet), tr = byId(eq.trail);
    Ocean.setSkin({ duckTint: d.tint, duckFx: d.fx, toiletSprite: tl.sprite, toiletTint: tl.tint, toiletFx: tl.fx, trail: tr.trail });
  }
  function shopHtml() {
    const own = store.owned || {}, eq = store.equip || {}, c = store.coins ?? START_COINS;
    const preview = s => { const sp = Ocean.sprite(s.type === 'toilet' ? (s.sprite || 'toilet') : s.type === 'duck' ? 'duck0' : 'robux', s.fx === 'rainbow' ? '~#ff7ad9' : s.tint); return s.type === 'trail' ? `<span class="trail-sw trail-${s.trail}"></span>` : s.type === 'boost' ? '<span class="boost-sw">+5s</span>' : `<img class="pix shop-img" src="${sp.c.toDataURL()}" alt="">`; };
    const rarity = p => p >= 100000 ? ['MYTHIC', 'r-mythic'] : p >= 10000 ? ['LEGENDARY', 'r-legend'] : p >= 100 ? ['RARE', 'r-rare'] : ['COMMON', 'r-common'];
    const group = (type, title) => `<h3 class="mh">${title}</h3><div class="shop-grid">${SHOP.filter(s => s.type === type).sort((a, b) => a.price - b.price).map(s => {
      const owned = own[s.id], on = eq[s.type] === s.id;
      const btn = s.type === 'boost' ? `<button class="shop-btn" data-buy="${s.id}" ${c < s.price ? 'disabled' : ''}>BUY ${coinTag(s.price)}</button><span class="shop-have">have ${((store.boosts || {}).time) || 0}</span>`
        : owned ? `<button class="shop-btn ${on ? 'on' : ''}" data-equip="${s.id}">${on ? 'EQUIPPED' : 'EQUIP'}</button>`
        : `<button class="shop-btn" data-buy="${s.id}" ${c < s.price ? 'disabled' : ''}>BUY ${coinTag(s.price)}</button>`;
      const [rl, rc] = rarity(s.price);
      return `<div class="shop-item ${rc}"><span class="rar">${s.type === 'boost' ? 'BOOST' : rl}</span>${preview(s)}<b>${s.name}</b>${s.note ? `<small>${s.note}</small>` : ''}${btn}</div>`;
    }).join('')}</div>`;
    return `<p class="shop-bal">Balance ${coinTag(c)}</p>${group('duck', 'DUCKS')}${group('toilet', 'TOILETS')}${group('trail', 'TRAILS')}${group('boost', 'BOOSTS')}
      <p class="fine">${Object.keys(own).length ? `<button class="link-btn" data-equip="default">Use the default look</button>` : ''}</p>`;
  }
  function openShop() {
    openModal('SHOP', shopHtml());
    const wireShop = () => {
      $$('#modal [data-buy]').forEach(b => b.addEventListener('click', () => {
        const s = SHOP.find(x => x.id === b.dataset.buy); const c = store.coins ?? START_COINS; if (!s || c < s.price) return;
        store.coins = c - s.price;
        if (s.type === 'boost') { store.boosts = store.boosts || {}; store.boosts.time = (store.boosts.time || 0) + 1; }
        else { store.owned = store.owned || {}; store.owned[s.id] = true; store.equip = store.equip || {}; store.equip[s.type] = s.id; applySkin(); }
        save(); Sound.correct(60); renderCoins(); $('#modal .modal-body').innerHTML = shopHtml(); wireShop();
      }));
      $$('#modal [data-equip]').forEach(b => b.addEventListener('click', () => {
        store.equip = store.equip || {};
        if (b.dataset.equip === 'default') store.equip = {};
        else { const s = SHOP.find(x => x.id === b.dataset.equip); store.equip[s.type] = store.equip[s.type] === s.id ? undefined : s.id; }
        save(); applySkin(); Sound.click(); $('#modal .modal-body').innerHTML = shopHtml(); wireShop();
      }));
    };
    wireShop();
  }
  function resetRobux() { store.coins = START_COINS; save(); renderCoins(); toast('Pretend Robux reset to R$1,000'); }
  function openStats() {
    openModal('STATISTICS', statsHtml());
    $('#btn-reset-stats').addEventListener('click', () => {
      confirmBox('Reset all statistics, history and streaks? Settings are kept. This cannot be undone.', () => {
        const keep = store.settings; store = DEFAULTS(); store.settings = keep; store.seenHelp = true; if (G) store.active = G; save(); openStats(); toast('Statistics reset');
      });
    });
  }

  // ---------- settings / help ----------
  function openSettings() {
    const s = store.settings;
    openModal('SETTINGS', `
      <label class="set-row"><span>Sound effects</span><input type="checkbox" id="set-sound" ${s.sound ? 'checked' : ''}><i class="tog"></i></label>
      <label class="set-row"><span>Volume</span><input type="range" id="set-vol" min="0" max="1" step="0.05" value="${s.volume}"></label>
      <label class="set-row"><span>Ambient sewer hum</span><input type="checkbox" id="set-amb" ${s.ambience ? 'checked' : ''}><i class="tog"></i></label>
      <label class="set-row"><span>Reduced motion</span><input type="checkbox" id="set-motion" ${s.motion === 'reduced' ? 'checked' : ''}><i class="tog"></i></label>
      <label class="set-row"><span>Show category &amp; difficulty</span><input type="checkbox" id="set-meta" ${s.showMeta ? 'checked' : ''}><i class="tog"></i></label>
      <h3 class="mh">KEYBOARD</h3>
      <ul class="keys"><li><kbd>Enter</kbd> flush · submit · keep flushing</li><li><kbd>M</kbd> menu · <kbd>Esc</kbd> close</li><li><kbd>S</kbd> toggle sound (outside the answer box)</li></ul>
      <p class="fine">Question database: <b>${fmt(QS.length)}</b> prompts · <b>${fmt(QS.reduce((n, q) => n + q.a.length, 0))}</b> accepted answers</p>
      <button class="btn btn-ghost small danger" id="btn-wipe">ERASE ALL DATA</button><button class="btn btn-ghost small" id="btn-reset-robux">RESET PRETEND ROBUX (R$1,000)</button>`);
    $('#set-sound').onchange = e => { s.sound = e.target.checked; applySettings(); save(); };
    $('#set-vol').oninput = e => { s.volume = Number(e.target.value); applySettings(); save(); };
    $('#set-vol').onchange = () => Sound.click();
    $('#set-amb').onchange = e => { s.ambience = e.target.checked; applySettings(); save(); };
    $('#set-motion').onchange = e => { s.motion = e.target.checked ? 'reduced' : 'full'; applySettings(); save(); };
    $('#set-meta').onchange = e => { s.showMeta = e.target.checked; save(); if (G) $('#q-meta').textContent = s.showMeta ? `${curQ().cat} · ${curQ().diff}`.toUpperCase() : ''; };
    $('#btn-wipe').onclick = () => confirmBox('Erase every flush, streak, statistic and setting on this device? This cannot be undone.', () => { try { localStorage.removeItem(SKEY); } catch (e) {} location.reload(); });
    const rr = $('#btn-reset-robux'); if (rr) rr.addEventListener('click', resetRobux);
  }
  function applySettings() {
    const s = store.settings;
    Sound.setVolume(s.volume); Sound.settings.ambience = s.ambience; Sound.setEnabled(s.sound);
    Ocean.setReduced(s.motion === 'reduced'); document.body.classList.toggle('reduced', s.motion === 'reduced');
    $('#btn-sound use').setAttribute('href', s.sound ? '#i-sound' : '#i-mute');
  }
  function openHelp() {
    openModal('HOW TO PLAY', `
      <p>Every prompt has dozens of right answers. Everyone can name the obvious ones — the goal is to name the <b>rarest</b> answer you can.</p>
      <ul class="rules"><li>Pick <b>5, 7 or 10 prompts</b>, or <b>endless</b>. You have <b>25 seconds</b> each.</li>
      <li>Wrong answers cost nothing — keep guessing until the timer runs out. Whatever is in the box when time expires is submitted.</li>
      <li>Rarer answers score more and flush your duck deeper. A perfect flush reaches <b>7,000m</b>.</li></ul>
      <table class="tier-table">${TIERS.slice().reverse().map(t => `<tr><td style="color:${t.color}">${t.name}</td><td>+${t.score}</td><td>${fmt(t.depth)}m</td></tr>`).join('')}</table>
      <p class="fine">Rarity tiers are our curated estimate of how likely a typical person is to think of each answer — not live player data.</p>
      <p class="fine"><b>Endless</b> never stops: hit <b>END RUN</b> on any reveal to cash out. <b>Themed Packs</b> keep every prompt on one topic.</p>
      <button class="btn btn-wide" data-close>GOT IT</button>`);
  }

  // ---------- archive ----------
  let calMonth = null;
  function showArchive() {
    if (G) return showGame();
    show('archive'); Ocean.setView('menu');
    const t = parseKey(todayKey()); if (!calMonth) calMonth = new Date(t.getFullYear(), t.getMonth(), 1);
    renderCal();
  }
  function renderCal() {
    const first = parseKey(EPOCH); const t = parseKey(todayKey());
    const minM = new Date(first.getFullYear(), first.getMonth(), 1), maxM = new Date(t.getFullYear(), t.getMonth(), 1);
    if (calMonth < minM) calMonth = minM; if (calMonth > maxM) calMonth = maxM;
    $('#cal-prev').disabled = calMonth <= minM; $('#cal-next').disabled = calMonth >= maxM;
    $('#cal-title').textContent = calMonth.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }).toUpperCase();
    const cal = $('#cal'); cal.innerHTML = ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map(d => `<span class="dow">${d}</span>`).join('');
    const y = calMonth.getFullYear(), m = calMonth.getMonth(); const days = new Date(y, m + 1, 0).getDate();
    for (let i = 0; i < new Date(y, m, 1).getDay(); i++) cal.insertAdjacentHTML('beforeend', '<span></span>');
    const tk = todayKey();
    for (let d = 1; d <= days; d++) {
      const k = `${y}-${pad(m + 1)}-${pad(d)}`; const before = k < EPOCH, future = k > tk;
      const b = document.createElement('button'); b.className = 'day';
      const daily = store.daily[k], arc = store.archive[k];
      const sc = daily ? daily.score : arc ? arc.best : null;
      b.innerHTML = `<span class="dn">${d}</span>${!before && !future ? `<span class="dno">#${dayIndex(k) + 1}</span>` : ''}${sc !== null ? `<b>${sc}</b>` : ''}`;
      if (k === tk) b.classList.add('today'); if (daily) b.classList.add('played'); else if (arc) b.classList.add('arc');
      if (before || future) b.disabled = true;
      else b.addEventListener('click', () => { if (k === tk) startGame('daily'); else archivePrompt(k); });
      b.setAttribute('aria-label', `${prettyDate(k)}${sc !== null ? `, best ${sc}` : ''}`);
      cal.appendChild(b);
    }
  }
  function archivePrompt(k) {
    const d = store.daily[k], a = store.archive[k];
    const ids = dailyIds(k);
    openModal(`FLUSH #${dayIndex(k) + 1}`, `
      <p class="fine">${prettyDate(k)}</p>
      ${d ? `<p>Your daily score: <b>${d.score}</b> (-${fmt(d.depth)}m)</p>` : ''}
      ${a ? `<p>Archive best: <b>${a.best}</b> · ${a.plays} play${a.plays > 1 ? 's' : ''}</p>` : ''}
      <p class="fine">Categories: ${ids.map(id => BY_ID.get(id).cat).join(' · ')}</p>
      <div class="modal-actions">${d ? '<button class="btn btn-ghost" id="arc-view">VIEW LOG</button>' : ''}<button class="btn btn-wide" id="arc-play">FLUSH ▸</button></div>`);
    $('#arc-play').onclick = () => { closeModal(); startGame('archive', k); };
    if (d) $('#arc-view').onclick = () => { closeModal(); showResults(d); };
    $('#arc-play').focus();
  }

  // ---------- packs ----------
  function showPacks() {
    if (G) return showGame();
    show('packs'); Ocean.setView('menu');
    const box = $('#packs'); box.innerHTML = '';
    PACKS.forEach((p, i) => {
      const n = QS.filter(q => q.pack === p.key).length;
      const played = store.history.filter(h => h.mode === 'pack' && h.key === p.key);
      const best = played.length ? Math.max(...played.map(h => h.score)) : null;
      const b = document.createElement('button'); b.className = 'pack';
      b.innerHTML = `<span class="pk-n">0${i + 1}</span><span class="pk-name">${p.name.toUpperCase()}</span><span class="pk-blurb">${p.blurb}</span><span class="pk-meta">${n} PROMPTS${best !== null ? ` · BEST ${best}` : ''}</span>`;
      if (n < PER_GAME) b.disabled = true;
      b.addEventListener('click', () => startGame('pack', p.key));
      box.appendChild(b);
    });
    setTimeout(() => box.querySelector('.pack')?.focus({ preventScroll: true }), 50);
  }

  // ---------- overlays ----------
  let lastFocus = null;
  function openModal(title, html) {
    lastFocus = lastFocus || document.activeElement;
    $('#modal-title').textContent = title; $('#modal-body').innerHTML = html; $('#modal').hidden = false; $('#menu').hidden = true;
    $$('#modal [data-close]').forEach(b => b.onclick = closeModal);
    setTimeout(() => ($('#modal-body button, #modal-body input') || $('#modal [data-close]')).focus({ preventScroll: true }), 30);
  }
  function closeModal() { $('#modal').hidden = true; restoreFocus(); }
  function restoreFocus() {
    if (G && G.phase === 'answering' && document.body.dataset.screen === 'game') $('#answer').focus({ preventScroll: true });
    else if (lastFocus && document.contains(lastFocus)) lastFocus.focus({ preventScroll: true });
    lastFocus = null;
  }
  function confirmBox(msg, ok) {
    openModal('ARE YOU SURE?', `<p>${esc(msg)}</p><div class="modal-actions"><button class="btn btn-ghost" data-close>CANCEL</button><button class="btn btn-pink" id="confirm-ok">CONFIRM</button></div>`);
    $('#confirm-ok').onclick = () => { closeModal(); ok(); };
  }
  function openMenu() {
    lastFocus = document.activeElement;
    $('#menu').hidden = false; $('#menu-quit').hidden = !G; $('#menu-restart').hidden = !G || G.mode === 'daily';
    $('#menu-foot').textContent = `${fmt(QS.length)} prompts in the deep · Daily #${dayIndex(todayKey()) + 1}`;
    setTimeout(() => $('#menu .menu-item').focus(), 30);
  }
  function closeMenu() { $('#menu').hidden = true; restoreFocus(); }
  let toastT = null;
  function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('show'), 2200); }

  function menuAction(act) {
    closeMenu();
    if (act === 'home') return leaveThen(showTitle);
    if (act === 'daily') return leaveThen(() => startGame('unlimited'));
    if (act === 'unlimited') return leaveThen(() => startGame('unlimited'));
    if (act === 'packs') return leaveThen(showPacks);
    if (act === 'archive') return leaveThen(showArchive);
    if (act === 'quit') return quitDive();
    if (act === 'restart') return restartDive();
    if (act === 'stats') return openStats();
    if (act === 'shop') return openShop();
    if (act === 'settings') return openSettings();
    if (act === 'help') return openHelp();
  }

  function renderCoins() {
    const c = store.coins ?? START_COINS, price = marketPrice(rankedLen());
    $$('.coin-bal').forEach(el => { el.innerHTML = coinTag(c); });
    const rb = $('#btn-ranked');
    if (rb) { const L = rankedLen(); rb.innerHTML = `RANKED · ${L} PROMPTS · ${coinTag(price)}`; rb.title = `Pays R$1 per ${RANKED_RATE} points. Score ${price * RANKED_RATE}+ to profit.`; rb.classList.toggle('poor', c < price); }
  }
  function renderLenPick() {
    const cur = LENGTHS.includes(store.settings.len) ? store.settings.len : 10;
    $$('[data-len]').forEach(b => { const on = Number(b.dataset.len) === cur; b.classList.toggle('on', on); b.setAttribute('aria-checked', String(on)); });
    renderCoins();
  }
  function updateCountdown() {
    const s = hms(msToMidnight());
    $$('.cd').forEach(e => e.textContent = s); if ($('#st-next')) $('#st-next').textContent = s;
    // roll over at midnight
    if (document.body.dataset.screen === 'title') { const k = todayKey(); if (k !== updateCountdown.k) { updateCountdown.k = k; updateTitle(); } }
  }

  // ---------- wiring ----------
  function wire() {
    $('#howto-tiers').innerHTML = TIERS.slice().reverse().map(t => `<span style="color:${t.color}">${t.name} +${t.score}</span>`).join('');
    $('#howto-toggle').addEventListener('click', e => { const box = $('#howto'); box.hidden = !box.hidden; e.currentTarget.setAttribute('aria-expanded', String(!box.hidden)); Sound.click(); });
    $('#btn-begin').addEventListener('click', () => { Sound.click(); if (G) showGame(); else startGame('unlimited'); });
    $$('[data-len]').forEach(b => b.addEventListener('click', () => { Sound.click(); store.settings.len = Number(b.dataset.len); save(); renderLenPick(); }));
    $('#btn-ranked').addEventListener('click', () => { Sound.click(); if (G) return showGame(); startGame('ranked'); });
    $('#btn-endrun').addEventListener('click', () => { if (G && G.phase === 'reveal') { Sound.click(); finish(); } });
    $$('[data-go]').forEach(b => b.addEventListener('click', () => {
      Sound.click(); const g = b.dataset.go;
      if (g === 'archive') showArchive(); else if (g === 'packs') showPacks(); else if (g === 'unlimited') startGame('unlimited'); else showTitle();
    }));
    $('#answer-form').addEventListener('submit', e => { e.preventDefault(); submit(); });
    $('#answer').addEventListener('input', e => { if (pendingSuggest && window.Match.norm(e.target.value) !== pendingSuggest.n) clearSuggest(); if (G) { G.input = e.target.value; save(); } if (store.settings.sound) Sound.key(); });

    $('#btn-skip').addEventListener('click', skip);
    $('#btn-descend').addEventListener('click', next);
    $('#btn-again').addEventListener('click', () => { const e = resultsEntry; if (e && e.mode === 'pack') startGame('pack', e.key); else if (e && e.ranked) startGame('ranked'); else startGame('unlimited'); });
    $('#btn-res-archive').addEventListener('click', () => { Sound.click(); showArchive(); });
    $('#btn-stats2').addEventListener('click', openStats);
    $('#btn-stats-title').addEventListener('click', () => { Sound.click(); openStats(); });
    $('#btn-shop').addEventListener('click', () => { Sound.click(); openShop(); });
    $('#btn-res-packs').addEventListener('click', () => { Sound.click(); showPacks(); });
    $('#btn-share').addEventListener('click', copyShare);
    $('#btn-share2').addEventListener('click', async () => { if (navigator.share && resultsEntry) { try { await navigator.share({ text: shareText(resultsEntry) }); return; } catch (e) { if (e.name === 'AbortError') return; } } copyShare(); });
    $('#btn-quit').addEventListener('click', quitDive);
    $('#btn-restart').addEventListener('click', restartDive);
    $('#btn-res-home').addEventListener('click', () => { Sound.click(); showTitle(); });
    $('#btn-settings').addEventListener('click', () => { Sound.click(); openSettings(); });
    $('#btn-menu').addEventListener('click', () => { Sound.click(); openMenu(); });
    $('#btn-sound').addEventListener('click', () => { store.settings.sound = !store.settings.sound; applySettings(); save(); Sound.click(); toast(store.settings.sound ? 'Sound on' : 'Sound off'); });
    $$('#menu [data-act]').forEach(b => b.addEventListener('click', () => menuAction(b.dataset.act)));
    $('#menu').addEventListener('click', e => { if (e.target.id === 'menu' || e.target.closest('[data-close]')) closeMenu(); });
    $('#modal').addEventListener('click', e => { if (e.target.id === 'modal') closeModal(); });
    $('#cal-prev').addEventListener('click', () => { calMonth = new Date(calMonth.getFullYear(), calMonth.getMonth() - 1, 1); renderCal(); });
    $('#cal-next').addEventListener('click', () => { calMonth = new Date(calMonth.getFullYear(), calMonth.getMonth() + 1, 1); renderCal(); });

    document.addEventListener('keydown', e => {
      const typing = e.target.matches('input[type=text], textarea');
      if (e.key === 'Escape') {
        if (!$('#modal').hidden) return closeModal();
        if (!$('#menu').hidden) return closeMenu();
        if (['archive', 'packs'].includes(document.body.dataset.screen)) return showTitle();
        return;
      }
      if (!$('#modal').hidden || !$('#menu').hidden) {
        if (e.key === 'Tab') trapFocus(e, !$('#modal').hidden ? $('#modal .modal') : $('#menu .drawer'));
        return;
      }
      if (typing) return;
      if (e.key === 'm' || e.key === 'M') { e.preventDefault(); return openMenu(); }
      if (e.key === 's' || e.key === 'S') { return $('#btn-sound').click(); }
      if (e.key === 'Enter' && !e.target.matches('button, a, input')) {
        const sc = document.body.dataset.screen;
        if (sc === 'title') { e.preventDefault(); $('#btn-begin').click(); }
        else if (sc === 'game' && G && G.phase === 'reveal' && !$('#btn-descend').disabled) { e.preventDefault(); next(); }
        else if (sc === 'game' && G && G.phase === 'reading' && e.shiftKey) skip();
      }
      if (document.body.dataset.screen === 'game' && G && G.phase === 'answering' && e.key.length === 1 && !e.metaKey && !e.ctrlKey) $('#answer').focus();
    });
    document.addEventListener('pointerdown', () => { Sound.unlock(); if (store.settings.sound && store.settings.ambience) Sound.startAmbience(); }, { once: true });
    document.addEventListener('keydown', () => { Sound.unlock(); if (store.settings.sound && store.settings.ambience) Sound.startAmbience(); }, { once: true });
    window.addEventListener('storage', e => { if (e.key === SKEY && !G) { load(); if (document.body.dataset.screen === 'title') updateTitle(); } });
  }
  function trapFocus(e, root) {
    const f = [...root.querySelectorAll('button:not([disabled]):not([hidden]), input, [tabindex]:not([tabindex="-1"])')].filter(x => x.offsetParent !== null);
    if (!f.length) return; const first = f[0], last = f[f.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  }

  // ---------- boot ----------
  // GitHub Pages lets browsers reuse the page for ~10 minutes; if a newer version is live, reload once to get it.
  function checkVersion() {
    if (!window.FLUSHED_V || !window.fetch) return;
    fetch('version.json?t=' + Date.now(), { cache: 'no-store' }).then(r => r.ok ? r.json() : null).then(j => {
      if (!j || !j.v || j.v === window.FLUSHED_V) return;
      if (sessionStorage.getItem('flushed-reloaded') === j.v) return; // only try once per new version
      sessionStorage.setItem('flushed-reloaded', j.v); location.reload();
    }).catch(() => {});
  }
  function boot() {
    checkVersion();
    load();
    Ocean.init($('#ocean'));
    try { coinImg = Ocean.sprite('robux').c.toDataURL(); } catch (e) { /* no sprite yet */ }
    if (store.robuxV !== 1) { store.robuxV = 1; store.coins = START_COINS; save(); } // switch to pretend Robux: everyone starts at R$1,000
    applySettings(); wire(); buildGauge(); renderCoins(); applySkin();
    if (!QS.length) { document.body.insertAdjacentHTML('beforeend', '<p style="position:fixed;bottom:8px;left:8px;color:#f66">Question database failed to load.</p>'); }
    // Reloading mid-game ends that game and starts a fresh one (endless runs with answers are saved first).
    const A = store.active;
    Ocean.setView('title', true); showTitle();
    if (A && A.ids && A.ids.every(id => BY_ID.has(id))) {
      G = A;
      if ((!lenOf(G) || G.ranked) && G.results.filter(Boolean).length) abandon(true); else if (G.ranked) { store.coins = (store.coins ?? START_COINS) + (G.price || 0); discardDive(); } else discardDive(); // ranked with no answers yet: refund
      startGame(A.mode === 'pack' ? 'pack' : 'unlimited', A.mode === 'pack' ? A.key : undefined);
    } else store.active = null;
    buildDepthLabels(); requestAnimationFrame(labelLoop);
    tickTimer = setInterval(tick, 100);
    setInterval(updateCountdown, 1000);
    document.addEventListener('visibilitychange', () => {
      // Practice dives pause while the tab is hidden; the Daily Dive keeps running so it can't be paused to look things up.
      if (G && G.mode !== 'daily' && G.phase === 'answering') {
        if (document.hidden) { G.pausedLeft = Math.max(0, G.phaseEnd - Date.now()); save(); }
        else if (G.pausedLeft !== undefined) { G.phaseEnd = Date.now() + G.pausedLeft; delete G.pausedLeft; save(); }
      }
      if (!document.hidden) tick();
    });
  }

  // test hooks (used by automated checks; harmless in play)
  window.__krillion = { get G() { return G; }, get store() { return store; }, dailyIds, randomIds, match, QS, BY_ID, submit, next, skip, finish };
  boot();
})();
