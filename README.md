# FLUSHED — The Daily Flush

A retro pixel-art brainrot trivia game. A rubber duck gets flushed: seven open-ended prompts, 25 seconds each, and rarer answers flush it deeper — through the Bowl, the Pipes, the Sewer and the Rat Kingdom down to the Brainrot Core (max 700 pts / 7,000 m).

Tiers: **NPC** (10) · **Mid** (30) · **Rizz** (60) · **Skibidi** (85) · **Sigma** (100, exactly one per prompt).

Roblox port and crowd-sourced rarity plan: [ROBLOX.md](ROBLOX.md).

## Run
Static files only — no build server or API needed.

```bash
python3 -m http.server 8765
```
then open http://localhost:8765 (opening `index.html` directly also works).

## Layout
- `index.html`, `css/style.css` — UI
- `js/game.js` — modes (Daily, Unlimited, Themed Packs, Archive), timers, scoring, persistence (localStorage), results, stats
- `js/ocean.js` — pixel-art canvas: bathroom, pipes, sewer, rats, the duck, descent camera
- `js/crowd.js` — crowd rarity: re-tiers answers from real player counts (for the Roblox server; `node tools/crowd-sim.js`)
- `js/match.js` — answer normalisation + fuzzy matching (shared with Node tools)
- `js/sound.js` — synthesized WebAudio sound effects
- `data/questions/*.js` — question sources; `data/questions.bundle.js` is generated

## Question format
```js
{id:"geo-0001", q:"Name a country beginning with S.", cat:"Geography", diff:"easy", pack:"geography",
 a:["Spain|10", "Suriname|85", "São Tomé and Príncipe|100|Sao Tome|STP"]}
```
Each answer is `Canonical|score|alias|alias…`, score ∈ {10, 15, 30, 60, 85, 100}. Rarity starts as a curated estimate; `js/crowd.js` is how it will follow real player statistics once there's a server.

## Tools
```bash
node tools/validate.js   # schema, duplicate questions/answers/aliases, score values
node tools/build.js      # regenerate data/questions.bundle.js after editing data
node tools/test.js       # every answer + alias matches itself; normalisation probes
```
