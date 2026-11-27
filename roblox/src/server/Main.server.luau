-- FLUSHED server: runs every game. The server picks prompts, keeps the clock, judges answers and pays coins,
-- so nothing a player does on their own device can change their score or balance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Match = require(Shared.Match)
local Economy = require(Shared.Economy)
local Bank = require(script.Parent.QuestionBank)
local Picker = require(script.Parent.Picker)
local Profiles = require(script.Parent.Profiles)

local remote = Instance.new("RemoteFunction")
remote.Name = "Flushed"
remote.Parent = ReplicatedStorage

local games = {} -- [Player] = current game
local lastCall = {} -- [Player] = os.clock() of the last request (simple spam guard)

---------------------------------------------------------------- helpers
local function shopItem(id)
	for _, s in Config.SHOP do if s.id == id then return s end end
	for _, s in Config.ROBUX_PASSES do if s.id == id then return s end end
	return nil
end

local function leaderstats(player, p)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = player
		local c = Instance.new("IntValue"); c.Name = "Coins"; c.Parent = ls
		local b = Instance.new("IntValue"); b.Name = "Best"; b.Parent = ls
	end
	ls.Coins.Value = p.coins
	ls.Best.Value = p.stats.best
end

local function profileView(player)
	local p = Profiles.get(player)
	if not p then return nil end
	local prices = {}
	for _, L in Config.LENGTHS do prices[tostring(L)] = Economy.price(L) end
	local b = Economy.boost(p.rk)
	local st = p.stats
	return {
		coins = p.coins, prices = prices, boost = b,
		profitAt = { ["5"] = Economy.profitAt(5, b.x), ["7"] = Economy.profitAt(7, b.x), ["10"] = Economy.profitAt(10, b.x), ["0"] = Economy.profitAt(0, b.x) },
		owned = p.owned, equip = p.equip, boosts = p.boosts,
		stats = { games = st.games, best = st.best, avg = st.prompts > 0 and math.floor(st.total / st.prompts * 10 + 0.5) / 10 or 0, tiers = st.tiers },
		inGame = games[player] ~= nil,
	}
end

local function promptView(g)
	local q = Bank.byId[g.ids[g.idx]]
	return {
		idx = g.idx, total = g.len > 0 and g.len or nil, prompt = q.q, pack = q.pack,
		seconds = g.answerSeconds, score = g.score, ranked = g.ranked,
	}
end

-- what to show after a prompt: the most common answers and the one Sigma answer
local function revealOf(q)
	local p = Match.parseAnswers(q)
	local common, sigma = {}, nil
	for _, a in p.list do
		if not a.hidden then
			if a.score == 100 then sigma = a.name
			elseif a.score == 10 and #common < 4 then table.insert(common, a.name) end
		end
	end
	return { common = common, sigma = sigma }
end

local function startPrompt(g)
	g.phase = "answering"
	g.deadline = os.clock() + g.answerSeconds
	Picker.markSeen(g.profile, g.ids[g.idx])
end

local function record(g, result)
	g.results[g.idx] = result
	g.score += result.score
	g.phase = "reveal"
	local st = g.profile.stats
	local key = tostring(result.score)
	st.tiers[key] = (st.tiers[key] or 0) + 1
end

local function finish(player, g)
	local p = g.profile
	local played = 0
	for i = 1, #g.ids do if g.results[i] then played += 1 end end
	local paid = 0
	if g.cheated then
		paid = 0
	elseif g.ranked then
		paid = Economy.payout(g.score, g.len, g.boost)
		p.rk.runs += 1
		p.rk.lose = paid > g.price and 0 or p.rk.lose + 1
	else
		paid = Economy.freeCoins(g.score)
	end
	p.coins += paid
	if not g.cheated then
		local st = p.stats
		st.games += 1
		st.total += g.score
		st.prompts += played
		st.best = math.max(st.best, g.score)
	end
	games[player] = nil
	leaderstats(player, p)
	task.spawn(Profiles.save, player)
	local rows = {}
	for i = 1, played do
		local r = g.results[i]
		local q = Bank.byId[g.ids[i]]
		table.insert(rows, { prompt = q.q, answer = r.display or "—", score = r.score })
	end
	return {
		done = true, score = g.score, prompts = played, ranked = g.ranked, price = g.price, boost = g.boost,
		paid = paid, cheated = g.cheated, percentile = Economy.percentile(math.max(1, played), g.score), rows = rows,
		profile = profileView(player),
	}
end

---------------------------------------------------------------- actions
local actions = {}

function actions.profile(player)
	return profileView(player)
end

function actions.start(player, args)
	local p = Profiles.get(player)
	if not p then return { error = "Still loading your profile, try again in a second." } end
	if games[player] then return { error = "You're already in a game." } end
	local len = tonumber(args.len) or 10
	if not table.find(Config.LENGTHS, len) then len = 10 end
	local ranked = args.mode == "ranked"
	local g = { ranked = ranked, len = len, results = {}, score = 0, idx = 1, profile = p, answerSeconds = Config.ANSWER_SECONDS }
	if ranked then
		g.len = Economy.rankedLen(len)
		g.price = Economy.price(g.len)
		if p.coins < g.price then return { error = string.format("Ranked costs %d coins. Play free games to earn more.", g.price) } end
		p.coins -= g.price
		g.boost = Economy.boost(p.rk).x
		if (p.boosts.time or 0) > 0 then
			p.boosts.time -= 1
			g.answerSeconds += Config.EXTRA_TIME_SECONDS
			g.extraTime = true
		end
	end
	g.ids = Picker.pick(p, g.len > 0 and g.len or 10)
	games[player] = g
	leaderstats(player, p)
	startPrompt(g)
	return { prompt = promptView(g), coins = p.coins, price = g.price, boost = g.boost, extraTime = g.extraTime }
end

function actions.submit(player, args)
	local g = games[player]
	if not g or g.phase ~= "answering" then return { error = "No prompt to answer." } end
	local text = tostring(args.text or ""):sub(1, 80)
	if text:match("^%s*$") then return { result = "empty" } end
	if os.clock() > g.deadline + Config.GRACE_SECONDS then return actions.timeout(player) end
	local q = Bank.byId[g.ids[g.idx]]
	-- creator-only test code: 6969 = instant Sigma (the run then pays nothing and doesn't count toward stats)
	if text:gsub("%s", "") == "6969" and (player.UserId == game.CreatorId or game.CreatorId == 0) then
		for _, a in Match.parseAnswers(q).list do
			if a.score == 100 then
				g.cheated = true
				record(g, { score = 100, display = a.name })
				return { result = "hit", answer = a.name, score = 100, total = g.score, reveal = revealOf(q), last = g.len > 0 and g.idx >= g.len }
			end
		end
	end
	local j = Match.judge(q, text)
	if j and j.answer then
		local display = j.contained and text or (j.label and j.label ~= j.answer.name and j.label or j.answer.name)
		record(g, { score = j.score, display = display })
		return { result = "hit", answer = display, official = j.answer.name, score = j.score, total = g.score, reveal = revealOf(q), last = g.len > 0 and g.idx >= g.len }
	elseif j and j.suggest then
		return { result = "suggest", label = j.suggest.label }
	end
	g.tries = (g.tries or 0) + 1
	return { result = "miss" }
end

function actions.timeout(player)
	local g = games[player]
	if not g or g.phase ~= "answering" then return { error = "No prompt running." } end
	if os.clock() < g.deadline - 1 then return { error = "Time isn't up yet." } end
	local q = Bank.byId[g.ids[g.idx]]
	record(g, { score = 0, display = nil })
	return { result = "timeout", score = 0, total = g.score, reveal = revealOf(q), last = g.len > 0 and g.idx >= g.len }
end

function actions.next(player)
	local g = games[player]
	if not g or g.phase ~= "reveal" then return { error = "Nothing to continue." } end
	if g.len > 0 and g.idx >= g.len then return finish(player, g) end
	g.idx += 1
	if g.len == 0 and g.idx > #g.ids then -- endless: draw 10 more, avoiding everything already played
		for _, id in Picker.pick(g.profile, 10, g.ids) do table.insert(g.ids, id) end
	end
	startPrompt(g)
	return { prompt = promptView(g) }
end

function actions.endRun(player)
	local g = games[player]
	if not g then return { error = "No game running." } end
	if g.phase == "answering" then
		g.ids = table.move(g.ids, 1, g.idx - 1, 1, {}) -- the unanswered prompt doesn't count
	else
		g.ids = table.move(g.ids, 1, g.idx, 1, {})
	end
	return finish(player, g)
end

function actions.buy(player, args)
	local p = Profiles.get(player)
	local item = shopItem(tostring(args.id))
	if not p or not item or item.passId then return { error = "Can't buy that." } end
	if item.type ~= "boost" and p.owned[item.id] then return { error = "You already own it." } end
	if p.coins < item.price then return { error = "Not enough coins." } end
	p.coins -= item.price
	if item.type == "boost" then p.boosts.time = (p.boosts.time or 0) + 1 else p.owned[item.id] = true; p.equip[item.type] = item.id end
	leaderstats(player, p)
	task.spawn(Profiles.save, player)
	return profileView(player)
end

function actions.equip(player, args)
	local p = Profiles.get(player)
	local item = shopItem(tostring(args.id))
	if not p or not item or not p.owned[item.id] then return { error = "You don't own that." } end
	p.equip[item.type] = if p.equip[item.type] == item.id then nil else item.id -- tap again to unequip
	return profileView(player)
end

function actions.buyPass(player, args)
	local item = shopItem(tostring(args.id))
	if item and item.passId and item.passId > 0 then MarketplaceService:PromptGamePassPurchase(player, item.passId) end
	return { ok = true }
end

remote.OnServerInvoke = function(player, action, args)
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.15 then return { error = "Slow down." } end
	lastCall[player] = now
	local f = actions[action]
	if type(f) ~= "function" then return { error = "Unknown action." } end
	local ok, res = pcall(f, player, type(args) == "table" and args or {})
	if not ok then
		warn("[FLUSHED]", action, res)
		return { error = "Something went wrong." }
	end
	return res
end

---------------------------------------------------------------- players
local function grantPasses(player, p)
	for _, item in Config.ROBUX_PASSES do
		if item.passId > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, item.passId)
			if ok and owns then p.owned[item.id] = true end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	local p = Profiles.load(player)
	grantPasses(player, p)
	leaderstats(player, p)
end)
for _, player in Players:GetPlayers() do
	task.spawn(function()
		local p = Profiles.load(player)
		grantPasses(player, p)
		leaderstats(player, p)
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
	if not bought then return end
	local p = Profiles.get(player)
	if not p then return end
	for _, item in Config.ROBUX_PASSES do
		if item.passId == passId then p.owned[item.id] = true; p.equip[item.type] = item.id end
	end
	task.spawn(Profiles.save, player)
end)

Players.PlayerRemoving:Connect(function(player)
	local g = games[player]
	-- leaving mid-ranked-run: get paid for what you answered (the entry is already spent)
	if g and g.ranked then pcall(actions.endRun, player) end
	games[player] = nil
	lastCall[player] = nil
	Profiles.release(player)
end)
