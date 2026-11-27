# FLUSHED on Roblox

This folder is the Roblox version of FLUSHED, written in Luau and synced into Roblox Studio with
[Rojo](https://rojo.space). It plays like the website:
- the same 3,776 prompts
- the same answer judging (checked against the website on 49,161 typed answers, with zero differences)
- the same ranked prices, payouts and visible boosts

The money rules for Roblox are in `../ROBLOX.md`, section 5.

## Try it in 2 minutes

1. Install **Roblox Studio** (free): https://create.roblox.com
2. Build the place file. From this folder, run:
   ```bash
   rojo build -o Flushed.rbxl
   ```
   (Install Rojo once with `brew install rojo`.)
3. Double-click `Flushed.rbxl` to open it in Studio, then press **Play** (F5).

You'll see the title screen with FLUSH, RANKED, SHOP and STATS. Type answers and press Enter.

## Working on it (live sync)

1. In Studio, install the **Rojo** plugin from the Toolbox (Plugins tab), by user "Rojo".
2. From this folder, start the sync server:
   ```bash
   rojo serve
   ```
3. In Studio, open the Plugins tab, click **Rojo**, then **Connect**.

From then on, every time a `.luau` file here is saved, Studio updates instantly.

## Publishing

1. In Studio: **File → Publish to Roblox**, and give it a name.
2. **Game Settings → Security → Enable Studio Access to API Services**. This makes saving (coins, stats, skins)
   work in Studio tests. Published games always save.
3. Fill in the **Maturity & Compliance questionnaire** on the Creator Dashboard. FLUSHED has hidden crude answers
   (marked `!` in the data). They're accepted but never shown, and you may want them removed for an all-ages rating.
4. On the Creator Dashboard, set the experience to **Public**, and add an icon and thumbnails. The Sigma and toilet
   sprites work well.

## How it's built

| File | What it does |
|---|---|
| `src/shared/Config.luau` | All the numbers: timer, coins, ranked rates, boosts, topic weights, shop, art and sound ids |
| `src/shared/Match.luau` | Answer judging, a line-for-line port of `js/match.js` |
| `src/shared/Economy.luau` | Ranked prices (29/41/58), payouts, boosts, "better than X%" |
| `src/server/QuestionBank.luau` | Loads the prompts from `src/server/Questions/` |
| `src/server/Picker.luau` | Picks a game's prompts: no repeats, no look-alikes, brainy topics first, one brainrot max |
| `src/server/Profiles.luau` | Saves coins, stats, skins and seen prompts (DataStore) |
| `src/server/Main.server.luau` | Runs every game. The server keeps the clock, judges answers and pays coins, so players can't cheat |
| `src/client/Main.client.luau` | Every screen: title, prompt, reveal, results, shop, stats |
| `src/client/Scene.luau` | The pixel-art world: duck in the toilet, the flush, then the sewer dive with pipes, brick walls, ledges and floating junk |
| `src/client/Sprites.luau` | All the website's pixel sprites, drawn as Frames, so there's nothing to upload (made by `tools/roblox-sprites.js`) |

### Money (Roblox rules)
- **Flush Coins are earn-only.** Everyone starts with 1,000. Free games pay 1 coin per 20 points, and ranked
  pays by score. Coins can never be bought with Robux, because staking anything bought with Robux on a result
  counts as gambling, and Roblox bans it.
- **Robux only buys cosmetics.** These are Game Passes listed in `Config.ROBUX_PASSES`. Create the pass on the
  Creator Dashboard, paste its id, and it appears in the shop.
- **The test code 6969** gives an instant Sigma. It only works for you (the game's creator) and in unpublished
  Studio tests. That run pays nothing and doesn't count toward stats.

### Art and sound
All the art is the website's pixel sprites, rebuilt from Frames in code, so there's nothing to upload:
- **The title:** the duck bobbing in the toilet.
- **The flush:** a foam swirl, a "whoops" backflip, then the duck gets pulled down.
- **The dive** (down the middle):
  - Pipes, then brick sewer walls.
  - The Rat Kingdom from about 400 points, with torches, crowned mice and cheese.
  - The disco core from about 500 points, with party mice, disco balls and boomboxes.
  - Rainbow insanity from about 600 points, with hue-cycling bricks and rainbow trails.
- **Skins:** shop skins tint the pixel art. The Golden Throne uses the gold toilet sprite, the expensive ducks get a
  glow, sparkles and a crown, and trails stream behind the duck.

Sounds are optional. Upload them in Studio (**View → Asset Manager**), then paste the ids into `Config.SOUNDS`.

If you change sprites in `js/ocean.js`, run `node tools/roblox-sprites.js`.
To preview the scene without Roblox, run `node tools/roblox-render.js <folder>`. It writes PNG snapshots of the
title, the flush and every zone.

## Updating the questions

After editing anything in `data/questions/` (or `difficulty.js`, `wording.js` or `removed.js`), run these from the
repo root:
```bash
node tools/roblox-export.js
```
Then rebuild (or let `rojo serve` pick it up).

## Tests (run before publishing changes)

```bash
node tools/roblox-fixture.js && (cd roblox && luau tests/run.luau)
```
```bash
cd roblox && luau tests/economy.luau
```
```bash
node tools/roblox-sim.js
```
- The first test replays about 49,000 typed answers through the Luau matcher and fails on any difference from
  the website.
- The second checks prices, payouts, boosts and percentiles.
- The third plays full games against the real server scripts in a mock Roblox: free, ranked, endless, the shop,
  timeouts, and saving across a rejoin.

## Not ported yet
- Themed packs. Random games only, like the website's main mode.
- Crowd rarity, where scores come from what real players answer. See `../ROBLOX.md`, section 1.
- A global leaderboard. The in-game player list already shows Coins and Best.
