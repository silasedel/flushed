-- FLUSHED settings shared by server and client. Tweak numbers here; everything else reads from this.
local Config = {}

Config.ANSWER_SECONDS = 25 -- time to answer each prompt
Config.EXTRA_TIME_SECONDS = 5 -- the Extra Time boost adds this to every prompt of one ranked run
Config.GRACE_SECONDS = 1.5 -- network slack the server allows past the deadline
Config.LENGTHS = { 5, 7, 10, 0 } -- prompts per game; 0 = endless
Config.ENDLESS_RANKED_LENGTH = 10 -- ranked can't be endless; picking ∞ prices a 10-prompt run

-- Flush Coins: the game's EARN-ONLY currency. Roblox rules: you can't pay Robux out to players, and staking
-- anything bought with Robux on a result counts as gambling. So coins can never be bought with Robux.
Config.START_COINS = 1000
Config.FREE_RATE = 20 -- free games pay 1 coin per 20 points (so free play keeps you topped up)
Config.RANKED_RATE = 5 -- ranked pays 1 coin per 5 points up to par...
Config.UPPER_RATE = 0.2 -- ...then 1 per 25 points above par
Config.WELCOME = { 1.3, 1.2, 1.1 } -- NEW PLAYER payout boosts on the first 3 ranked runs (shown on the button)
Config.COMEBACK = 1.3 -- COMEBACK payout boost after...
Config.COMEBACK_AFTER = 3 -- ...this many ranked losses in a row

-- Topic weights for random games: thinking topics lead, entertainment is a sprinkle (same as the website)
Config.WEIGHTS = { science = 4, geography = 3.2, general = 2.6, language = 1.3, fun = 0.8, sports = 0.6, gaming = 0.55, pop = 0.45, music = 0.35, movies = 0.3 }
Config.ENTERTAINMENT = { pop = true, movies = true, music = true } -- at most 2 per game

-- Shop: cosmetics and boosts bought with Flush Coins. `color` tints the duck/toilet on screen.
-- Robux items go in ROBUX_PASSES below (cosmetic only).
Config.SHOP = {
	{ id = "duck-mint", type = "duck", name = "Mint Duck", price = 50, color = "#9fffd0" },
	{ id = "duck-peach", type = "duck", name = "Peach Duck", price = 100, color = "#ffb88a" },
	{ id = "duck-ice", type = "duck", name = "Ice Duck", price = 250, color = "#9fe8ff" },
	{ id = "duck-bubblegum", type = "duck", name = "Bubblegum Duck", price = 400, color = "#ff7ac8" },
	{ id = "duck-toxic", type = "duck", name = "Toxic Duck", price = 600, color = "#7dff6a" },
	{ id = "duck-void", type = "duck", name = "Void Duck", price = 1500, color = "#8a5cff" },
	{ id = "duck-gold", type = "duck", name = "Golden Duck", price = 5000, color = "#ffcc33" },
	{ id = "duck-diamond", type = "duck", name = "Diamond Duck", price = 100000, color = "#dff8ff" },
	{ id = "duck-million", type = "duck", name = "One-in-a-Million Duck", price = 1000000, color = "#ffd23f" },
	{ id = "toilet-sky", type = "toilet", name = "Sky Blue Toilet", price = 100, color = "#bfe6ff" },
	{ id = "toilet-pink", type = "toilet", name = "Pink Porcelain", price = 500, color = "#ffb3d9" },
	{ id = "toilet-obsidian", type = "toilet", name = "Obsidian Throne", price = 2500, color = "#4a4458" },
	{ id = "toilet-gold", type = "toilet", name = "Golden Throne", price = 20000, color = "#ffcc33" },
	{ id = "toilet-diamond", type = "toilet", name = "Diamond Throne", price = 500000, color = "#e6fbff" },
	{ id = "boost-time", type = "boost", name = "Extra Time", note = "+5s every prompt, next ranked run", price = 25 },
}

-- Robux game passes (cosmetic only). Create the pass on the Creator Dashboard, paste its id here, and it shows up
-- in the shop. 0 = hidden.
Config.ROBUX_PASSES = {
	{ id = "pass-neon", passId = 0, type = "duck", name = "Neon Duck (Game Pass)", color = "#39ff14" },
}

-- Art and sound. Upload the sprites/sounds in Studio (Asset Manager), paste the "rbxassetid://..." ids here.
-- Empty = the game uses emoji/colored text instead.
Config.IMAGES = { duck = "", toilet = "", sigma = "", skibidi = "", rizz = "", mid = "", npc = "" }
Config.SOUNDS = { correct = "", miss = "", flush = "", tick = "" }

return Config
