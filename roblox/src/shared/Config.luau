-- FLUSHED settings shared by server and client. Tweak numbers here; everything else reads from this.
local Config = {}

Config.ANSWER_SECONDS = 25 -- time to answer each prompt
Config.EXTRA_TIME_SECONDS = 5 -- the Extra Time boost adds this to every prompt of one ranked run
Config.GRACE_SECONDS = 1.5 -- network slack the server allows past the deadline
Config.LENGTHS = { 5, 7, 10, 0 } -- prompts per game; 0 = endless
Config.ENDLESS_RANKED_LENGTH = 10 -- ranked can't be endless; picking ∞ prices a 10-prompt run

-- Flush Coins: the game's EARN-ONLY currency. Roblox rules: you can't pay Robux out to players, and staking
-- anything bought with Robux on a result counts as gambling. So coins can never be bought with Robux.
Config.START_COINS = 0 -- everyone starts broke; free games pay coins, ranked pays more
Config.FREE_RATE = 20 -- free games pay 1 coin per 20 points (so free play keeps you topped up)
Config.RANKED_RATE = 5 -- ranked pays 1 coin per 5 points up to par...
Config.UPPER_RATE = 0.2 -- ...then 1 per 25 points above par
Config.WELCOME = { 1.3, 1.2, 1.1 } -- NEW PLAYER payout boosts on the first 3 ranked runs (shown on the button)
Config.COMEBACK = 1.3 -- COMEBACK payout boost after...
Config.COMEBACK_AFTER = 3 -- ...this many ranked losses in a row

-- Topic weights for random games: thinking topics lead, entertainment is a sprinkle (same as the website)
Config.WEIGHTS = { science = 4, geography = 3.2, general = 2.6, language = 1.3, fun = 0.8, sports = 0.6, gaming = 0.55, pop = 0.45, music = 0.35, movies = 0.3 }
Config.ENTERTAINMENT = { pop = true, movies = true, music = true } -- at most 2 per game

-- Themed packs: one topic, a difficulty ramp (3 easy, 3 medium, 1 hard, then easy/medium for longer games).
-- Free to play (pays like a free game); ranked stays random-topic only.
Config.PACKS = {
	{ key = "geography", name = "Geography", blurb = "Countries, capitals, rivers, peaks and every corner of the map." },
	{ key = "science", name = "Science & Nature", blurb = "Elements, planets, the human body and the animal kingdom." },
	{ key = "general", name = "History & General", blurb = "Wars, inventions, presidents, food and everyday knowledge." },
	{ key = "language", name = "Language & Lit", blurb = "Words, alphabets, languages and literature." },
	{ key = "movies", name = "Movies & TV", blurb = "Directors, franchises, characters and the small screen." },
	{ key = "music", name = "Music", blurb = "Instruments, bands, albums, composers and musicals." },
	{ key = "sports", name = "Sports", blurb = "Teams, tournaments, legends and the rules of the game." },
	{ key = "gaming", name = "Gaming", blurb = "Pokémon, Minecraft, Nintendo, consoles and classics." },
	{ key = "pop", name = "Pop Culture", blurb = "Celebrities, internet, apps, snacks and everything trending." },
	{ key = "fun", name = "Fun & Random", blurb = "Things that use suction, junk-drawer finds, Minecraft blocks and more." },
}
Config.PACK_MIX = { "easy", "easy", "easy", "medium", "medium", "medium", "hard" }

-- Shop: the website's items and prices. Looks (duck / toilet / trail) cost real Robux: each price is a Developer
-- Product (ROBUX_PRODUCTS below maps price -> product id; create them on the Creator Dashboard). Boosts cost earned
-- coins. `tint` recolours the pixel art ("~#hex" keeps the shading), `fx` adds an effect, `sprite` swaps the toilet
-- art, `trail` picks the trail.
Config.SHOP = {
	{ id = "duck-mint", type = "duck", name = "Mint Duck", price = 5, tint = "~#9fffd0" },
	{ id = "duck-peach", type = "duck", name = "Peach Duck", price = 10, tint = "~#ffb88a" },
	{ id = "duck-lemon", type = "duck", name = "Lemonade Duck", price = 15, tint = "~#fff27a" },
	{ id = "duck-diamond", type = "duck", name = "Diamond Duck", price = 25000, tint = "~#dff8ff", fx = "diamond" },
	{ id = "duck-rainbow", type = "duck", name = "Rainbow Duck", price = 100000, fx = "rainbow" },
	{ id = "duck-million", type = "duck", name = "One-in-a-Million Duck", price = 1000000, tint = "~#ffd23f", fx = "million" },
	{ id = "duck-gold", type = "duck", name = "Golden Duck", price = 250, tint = "~#ffcc33" },
	{ id = "duck-ninja", type = "duck", name = "Ninja Duck", price = 150, tint = "~#4a4f5e" },
	{ id = "duck-bubblegum", type = "duck", name = "Bubblegum Duck", price = 100, tint = "~#ff7ac8" },
	{ id = "duck-ice", type = "duck", name = "Ice Duck", price = 100, tint = "~#9fe8ff" },
	{ id = "duck-toxic", type = "duck", name = "Toxic Duck", price = 120, tint = "~#7dff6a" },
	{ id = "duck-void", type = "duck", name = "Void Duck", price = 300, tint = "~#8a5cff" },
	{ id = "toilet-sky", type = "toilet", name = "Sky Blue Toilet", price = 10, tint = "~#bfe6ff" },
	{ id = "toilet-mint", type = "toilet", name = "Mint Toilet", price = 20, tint = "~#c6ffe0" },
	{ id = "toilet-gold", type = "toilet", name = "Golden Throne", price = 400, sprite = "goldtoilet" },
	{ id = "toilet-diamond", type = "toilet", name = "Diamond Throne", price = 250000, tint = "~#e6fbff", fx = "diamond" },
	{ id = "toilet-ratking", type = "toilet", name = "Rat King's Throne", price = 500000, sprite = "goldtoilet", fx = "crown" },
	{ id = "toilet-pink", type = "toilet", name = "Pink Porcelain", price = 150, tint = "~#ffb3d9" },
	{ id = "toilet-obsidian", type = "toilet", name = "Obsidian Throne", price = 250, tint = "~#4a4458" },
	{ id = "trail-bubble", type = "trail", name = "Bubble Trail", price = 5, trail = "bubble" },
	{ id = "trail-confetti", type = "trail", name = "Confetti Trail", price = 25, trail = "confetti" },
	{ id = "trail-rainbow", type = "trail", name = "Rainbow Trail", price = 200, trail = "rainbow" },
	{ id = "trail-money", type = "trail", name = "Money Trail", price = 75000, trail = "money" },
	{ id = "trail-aura", type = "trail", name = "Infinite Aura Trail", price = 150000, trail = "aura" },
	{ id = "trail-sparkle", type = "trail", name = "Sparkle Trail", price = 120, trail = "sparkle" },
	{ id = "trail-fire", type = "trail", name = "Fire Trail", price = 175, trail = "fire" },
	{ id = "boost-time", type = "boost", name = "Extra Time", note = "+5s every prompt, next ranked run", price = 25 },
}
-- Robux price -> Developer Product id (Creator Dashboard > your game > Monetization > Developer Products, one product
-- per price, named e.g. "Look R$100"). A look whose price has no product yet shows "SOON" and can't be bought.
Config.ROBUX_PRODUCTS = {
	[5] = 0, [10] = 0, [15] = 0, [20] = 0, [25] = 0, [100] = 0, [120] = 0, [150] = 0, [175] = 0, [200] = 0, [250] = 0,
	[300] = 0, [400] = 0, [25000] = 0, [75000] = 0, [100000] = 0, [150000] = 0, [250000] = 0, [500000] = 0, [1000000] = 0,
}
Config.ROBUX_PASSES = {}

-- Sounds: the website's synthesized effects, rendered by tools/roblox-sounds.js into one file (roblox/audio/flushed-sfx.ogg),
-- each effect in its own 4-second slot. Upload that file once (Studio > Asset Manager > Import) and paste its id here.
Config.SFX_ID = "" -- e.g. "rbxassetid://1234567890"; empty = silent
Config.SOUND_SLOTS = { click = 0, start = 1, tick = 2, tickUrgent = 3, go = 4, wrong = 5, dup = 6, correct10 = 7, correct30 = 8, correct60 = 9, correct85 = 10, correct100 = 11, miss = 12, descend10 = 13, descend30 = 14, descend60 = 15, descend85 = 16, descend100 = 17, flush = 18, finish = 19, buy = 20 }

return Config
