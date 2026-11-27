-- Saves each player's coins, stats, skins and which prompts they've seen (DataStore).
-- In Studio, turn on Game Settings > Security > "Enable Studio Access to API Services" to test saving;
-- without it the game still runs and just keeps data in memory for the session.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Profiles = {}
local loaded = {} -- [Player] = profile
local store
do
	local ok, res = pcall(function() return DataStoreService:GetDataStore("FlushedProfiles_v1") end)
	if ok then store = res else warn("[FLUSHED] DataStore unavailable, progress won't save:", res) end
end

local function defaults()
	return {
		v = 1, coins = Config.START_COINS, seen = {}, seenN = 0, recentGroups = {},
		rk = { runs = 0, lose = 0 }, owned = {}, equip = {}, boosts = { time = 0 },
		stats = { games = 0, total = 0, prompts = 0, best = 0, tiers = {} },
	}
end

local function keyOf(player) return "p_" .. player.UserId end

function Profiles.load(player)
	local data
	if store then
		for attempt = 1, 3 do
			local ok, res = pcall(function() return store:GetAsync(keyOf(player)) end)
			if ok then data = res; break end
			warn("[FLUSHED] load failed, retrying:", res)
			task.wait(attempt)
		end
	end
	local p = defaults()
	if type(data) == "table" then
		for k, v in data do p[k] = v end
	end
	loaded[player] = p
	return p
end

function Profiles.get(player) return loaded[player] end

function Profiles.save(player)
	local p = loaded[player]
	if not p or not store then return end
	local ok, err = pcall(function()
		store:UpdateAsync(keyOf(player), function() return p end)
	end)
	if not ok then warn("[FLUSHED] save failed:", err) end
end

function Profiles.release(player)
	Profiles.save(player)
	loaded[player] = nil
end

-- autosave every 2 minutes, and on shutdown
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in Players:GetPlayers() do Profiles.save(player) end
	end
end)
game:BindToClose(function()
	for _, player in Players:GetPlayers() do Profiles.save(player) end
end)

return Profiles
