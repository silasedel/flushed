-- Picks prompts for a game, same rules as the website's randomIds():
--  * never repeats a prompt until you've seen the whole pool (oldest-seen come back first)
--  * no two look-alike prompts in one game, and none from groups you played in your last ~3 games
--  * topics drawn by weight (science/geography/history lead), at most 2 entertainment prompts
--  * at most one brainrot (in ~40% of games), "Name something..." (~1/3) and "famous X" (~35%) prompt
--  * the same topic never twice in a row when there's a way around it
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Bank = require(script.Parent.QuestionBank)

local Picker = {}
local rng = Random.new()

local function shuffle(list)
	local a = table.clone(list)
	for i = #a, 2, -1 do
		local j = rng:NextInteger(1, i)
		a[i], a[j] = a[j], a[i]
	end
	return a
end

local function pickPack(exclude)
	local opts, total = {}, 0
	for p, w in Config.WEIGHTS do
		if not exclude[p] then table.insert(opts, { p, w }); total += w end
	end
	table.sort(opts, function(a, b) return a[1] < b[1] end)
	local x = rng:NextNumber() * total
	for _, o in opts do
		x -= o[2]
		if x <= 0 then return o[1] end
	end
	return opts[#opts][1]
end

local FALLBACK = { easy = { "easy", "medium", "hard" }, medium = { "medium", "easy", "hard" }, hard = { "hard", "medium", "easy" } }

-- profile.seen[id] = counter when served; profile.recentGroups = last 30 groups served
-- pack = a Config.PACKS key for a themed pack (all difficulties, ramped), or nil for a random game
function Picker.pick(profile, n, exclude, pack)
	exclude = exclude or {}
	local seen = profile.seen or {}
	local ex = {}
	for _, id in exclude do ex[id] = true end
	local pool = {}
	local source = pack and (Bank.byPack[pack] or {}) or Bank.casual
	for _, q in source do if not ex[q.id] then table.insert(pool, q) end end
	if #pool < n then pool = source end
	local fresh, old = {}, {}
	for _, q in pool do
		if seen[q.id] == nil then table.insert(fresh, q) else table.insert(old, q) end
	end
	if #fresh < n * 3 then -- nearly everything seen: top up with the ones seen longest ago
		table.sort(old, function(a, b) return seen[a.id] < seen[b.id] end)
		for i = 1, math.min(#old, math.max(n * 6, 40)) do table.insert(fresh, old[i]) end
	end
	local sh = shuffle(fresh)
	local picks, picked = {}, {}
	local recentG = {}
	for _, g in profile.recentGroups or {} do recentG[g] = true end
	local inGame = {}
	for i = math.max(1, #exclude - 11), #exclude do
		local q = Bank.byId[exclude[i]]
		if q then inGame[q.group] = true end
	end
	local allowVague, allowBrainrot, allowFamous = rng:NextNumber() < 1 / 3, rng:NextNumber() < 0.4, rng:NextNumber() < 0.35
	local function count(pred)
		local c = 0
		for _, p in picks do if pred(p) then c += 1 end end
		return c
	end
	local function ok(x, strict)
		if picked[x] then return false end
		if strict >= 1 then
			if inGame[x.group] then return false end
			for _, p in picks do if p.group == x.group then return false end end
		end
		if strict >= 2 and recentG[x.group] then return false end
		if pack then return true end -- packs: any prompt in the topic, no brainrot/vague/famous limits
		if x.vague and (not allowVague or count(function(p) return p.vague end) > 0) then return false end
		if x.famous and (not allowFamous or count(function(p) return p.famous end) > 0) then return false end
		if x.brainrot and (not allowBrainrot or count(function(p) return p.brainrot end) > 0) then return false end
		return true
	end
	local function add(q) table.insert(picks, q); picked[q] = true end
	for _, strict in { 2, 1, 0 } do
		if pack then -- difficulty ramp: 3 easy, 3 medium, 1 hard
			for _, want in Config.PACK_MIX do
				if #picks >= n then break end
				for _, w in FALLBACK[want] do
					local found = nil
					for _, q in sh do
						if q.diff == w and ok(q, strict) then found = q; break end
					end
					if found then add(found); break end
				end
			end
		end
		local tries = pack and 60 or 0
		while #picks < n and tries < 60 do
			tries += 1
			local ent = count(function(p) return Config.ENTERTAINMENT[p.pack] == true end)
			local p = pickPack(ent >= 2 and Config.ENTERTAINMENT or {})
			for _, q in sh do
				if q.pack == p and ok(q, strict) then add(q); break end
			end
		end
		for _, q in sh do
			if #picks >= n then break end
			if ok(q, strict) then add(q) end
		end
		if #picks >= n then break end
	end
	if not pack and allowBrainrot and #picks > 0 and count(function(p) return p.brainrot end) == 0 then
		for _, q in sh do
			if q.brainrot and not picked[q] then picks[#picks] = q; break end
		end
	end
	if pack then
		local ids = {}
		for _, q in picks do table.insert(ids, q.id) end
		return ids
	end
	-- order so the same topic never comes twice in a row when possible
	local byPack, packOrder = {}, {}
	for _, q in shuffle(picks) do
		if not byPack[q.pack] then byPack[q.pack] = {}; table.insert(packOrder, q.pack) end
		table.insert(byPack[q.pack], q)
	end
	local order = {}
	local prevQ = Bank.byId[exclude[#exclude] or ""]
	local prev = prevQ and prevQ.pack or nil
	while #order < #picks do
		local best, bestN = nil, -1
		for _, p in shuffle(packOrder) do
			local l = byPack[p]
			if #l > 0 and p ~= prev and #l > bestN then best, bestN = p, #l end
		end
		if not best then
			for _, p in packOrder do if #byPack[p] > 0 then best = p; break end end
		end
		table.insert(order, table.remove(byPack[best]).id)
		prev = best
	end
	return order
end

function Picker.markSeen(profile, id)
	profile.seen = profile.seen or {}
	profile.seenN = (profile.seenN or 0) + 1
	profile.seen[id] = profile.seenN
	local q = Bank.byId[id]
	if not q then return end
	local groups = {}
	for _, g in profile.recentGroups or {} do if g ~= q.group then table.insert(groups, g) end end
	table.insert(groups, q.group)
	while #groups > 30 do table.remove(groups, 1) end
	profile.recentGroups = groups
end

return Picker
