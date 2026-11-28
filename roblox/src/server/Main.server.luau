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
local push = Instance.new("RemoteEvent") -- server -> client updates (a Robux purchase went through, etc.)
push.Name = "FlushedPush"
push.Parent = ReplicatedStorage

local games = {} -- [Player] = current game
local lastCall = {} -- [Player] = os.clock() of the last request (simple spam guard)
local lastGame = {} -- [Player] = the finished game (for "show every answer" on the results page)
local pendingBuy = {} -- [UserId] = shop item id the player is buying with Robux
local TIER_DEPTH = { [100] = 1000, [85] = 750, [60] = 450, [30] = 200, [10] = 30 }

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

local bankAnswers = 0
for _, q in Bank.all do bankAnswers += #(q.a or {}) end
local function packList(p)
	local out = {}
	for _, pk in Config.PACKS do
		table.insert(out, { key = pk.key, name = pk.name, blurb = pk.blurb, count = #(Bank.byPack[pk.key] or {}), best = (p.packBest or {})[pk.key] })
	end
	return out
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
		owned = p.owned, equip = p.equip, boosts = p.boosts, packs = packList(p), bankPrompts = #Bank.all, bankAnswers = bankAnswers,
		stats = {
			games = st.games, best = st.best, avg = st.games > 0 and math.floor(st.total / st.games + 0.5) or 0,
			avgPer = st.games > 0 and math.floor((st.perSum or 0) / st.games + 0.5) or 0, deepest = st.deepest or 0,
			answeredPct = st.prompts > 0 and math.floor((st.answered or 0) / st.prompts * 100 + 0.5) or 0, bins = st.bins or {}, tiers = st.tiers,
		},
		robuxReady = (function() local r = {} for price, id in Config.ROBUX_PRODUCTS do if id > 0 then r[tostring(price)] = true end end return r end)(),
		inGame = games[player] ~= nil,
	}
end

local function promptView(g)
	local q = Bank.byId[g.ids[g.idx]]
	return {
		idx = g.idx, total = g.len > 0 and g.len or nil, prompt = q.q, pack = q.pack, packName = g.pack and g.pack.name,
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

local function startPrompt(g, lead)
	g.phase = "answering"
	g.deadline = os.clock() + g.answerSeconds + (lead or 0) -- lead: the flush animation before the first prompt
	g.tries = {}
	Picker.markSeen(g.profile, g.ids[g.idx])
end

local function record(g, result)
	result.tries = g.tries or {}
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
	local depth = 0
	for i = 1, played do depth += TIER_DEPTH[g.results[i].score] or 0 end
	if not g.cheated then
		local st = p.stats
		st.games += 1
		st.total += g.score
		st.prompts += played
		local hits = 0
		for i = 1, played do if g.results[i].score > 0 then hits += 1 end end
		st.answered = (st.answered or 0) + hits
		local per = g.score / math.max(1, played)
		st.perSum = (st.perSum or 0) + per
		st.bins = st.bins or {}
		local bin = tostring(math.min(9, math.floor(per / 10)) + 1)
		st.bins[bin] = (st.bins[bin] or 0) + 1
		st.deepest = math.max(st.deepest or 0, depth)
		st.best = math.max(st.best, g.score)
		if g.pack then
			p.packBest = p.packBest or {}
			p.packBest[g.pack.key] = math.max(p.packBest[g.pack.key] or 0, g.score)
		end
	end
	games[player] = nil
	leaderstats(player, p)
	task.spawn(Profiles.save, player)
	local rows = {}
	for i = 1, played do
		local r = g.results[i]
		local q = Bank.byId[g.ids[i]]
		table.insert(rows, { q = q.q, answer = r.display, input = r.input, score = r.score, reason = r.reason, tries = r.tries })
	end
	lastGame[player] = { ids = table.move(g.ids, 1, played, 1, {}), results = g.results }
	local st = p.stats
	return {
		done = true, score = g.score, prompts = played, ranked = g.ranked, pack = g.pack and g.pack.key, packName = g.pack and g.pack.name, price = g.price, boost = g.boost,
		paid = paid, cheated = g.cheated, percentile = Economy.percentile(math.max(1, played), g.score), rows = rows, depth = depth, len = g.len,
		logbook = { played = st.games, avg = st.games > 0 and math.floor(st.total / st.games + 0.5) or 0, best = st.best },
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
	local pack = nil
	if args.mode == "pack" then
		for _, pk in Config.PACKS do if pk.key == args.pack then pack = pk end end
		if not pack then return { error = "Unknown pack." } end
	end
	local ranked = args.mode == "ranked"
	local g = { ranked = ranked, pack = pack, len = len, results = {}, score = 0, idx = 1, profile = p, answerSeconds = Config.ANSWER_SECONDS }
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
	g.ids = Picker.pick(p, g.len > 0 and g.len or 10, nil, pack and pack.key)
	games[player] = g
	leaderstats(player, p)
	startPrompt(g, Config.INTRO_SECONDS)
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
		record(g, { score = j.score, display = display, input = text })
		return { result = "hit", answer = display, official = j.answer.name, score = j.score, total = g.score, reveal = revealOf(q), last = g.len > 0 and g.idx >= g.len }
	elseif j and j.suggest then
		return { result = "suggest", label = j.suggest.label }
	end
	g.tries = g.tries or {}
	local norm = Match.norm(text)
	for _, t in g.tries do if Match.norm(t) == norm then return { result = "dup" } end end
	table.insert(g.tries, text)
	return { result = "miss" }
end

function actions.timeout(player, args)
	local g = games[player]
	if not g or g.phase ~= "answering" then return { error = "No prompt running." } end
	local skip = args and args.skip
	if not skip and os.clock() < g.deadline - 1 then return { error = "Time isn't up yet." } end
	local q = Bank.byId[g.ids[g.idx]]
	-- whatever is in the box when time runs out still counts (like the website)
	local text = tostring(args and args.text or ""):sub(1, 80)
	if not skip and not text:match("^%s*$") then
		local j = Match.judge(q, text)
		if j and j.answer then
			local display = j.contained and text or (j.label and j.label ~= j.answer.name and j.label or j.answer.name)
			record(g, { score = j.score, display = display, input = text })
			return { result = "hit", answer = display, official = j.answer.name, score = j.score, total = g.score, reveal = revealOf(q), last = g.len > 0 and g.idx >= g.len }
		end
		g.tries = g.tries or {}
		if not table.find(g.tries, text) then table.insert(g.tries, text) end
	end
	local tries = g.tries or {}
	record(g, { score = 0, display = nil, input = tries[#tries] or "", reason = skip and "skip" or "time" })
	return { result = "timeout", score = 0, total = g.score, reveal = revealOf(q), last = g.len > 0 and g.idx >= g.len }
end

function actions.next(player)
	local g = games[player]
	if not g or g.phase ~= "reveal" then return { error = "Nothing to continue." } end
	if g.len > 0 and g.idx >= g.len then return finish(player, g) end
	g.idx += 1
	if g.len == 0 and g.idx > #g.ids then -- endless: draw 10 more, avoiding everything already played
		for _, id in Picker.pick(g.profile, 10, g.ids, g.pack and g.pack.key) do table.insert(g.ids, id) end
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
	if not p or not item or item.type ~= "boost" then return { error = "Looks are bought with Robux." } end
	if item.type ~= "boost" and p.owned[item.id] then return { error = "You already own it." } end
	if p.coins < item.price then return { error = "Not enough coins." } end
	p.coins -= item.price
	if item.type == "boost" then p.boosts.time = (p.boosts.time or 0) + 1 else p.owned[item.id] = true; p.equip[item.type] = item.id end
	leaderstats(player, p)
	task.spawn(Profiles.save, player)
	return profileView(player)
end

-- every accepted answer for round i of the last finished game (the results page's "tap a round")
function actions.answers(player, args)
	local lg = lastGame[player]
	local i = tonumber(args.i)
	if not lg or not i or not lg.ids[i] then return { error = "No such round." } end
	local q = Bank.byId[lg.ids[i]]
	local r = lg.results[i] or {}
	local out = {}
	for _, a in Match.parseAnswers(q).list do
		if not a.hidden or a.name == r.display then table.insert(out, { name = a.name, score = a.score, mine = (a.name == r.display) or nil }) end
	end
	table.sort(out, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.name < b.name end)
	return { list = out }
end

-- looks cost real Robux: one Developer Product per price (Config.ROBUX_PRODUCTS)
function actions.buyRobux(player, args)
	local p = Profiles.get(player)
	local item = shopItem(tostring(args.id))
	if not p or not item or item.type == "boost" then return { error = "Can't buy that." } end
	if p.owned[item.id] then return { error = "You already own it." } end
	local productId = Config.ROBUX_PRODUCTS[item.price] or 0
	if productId <= 0 then return { error = "This item isn't on sale yet." } end
	pendingBuy[player.UserId] = item.id
	MarketplaceService:PromptProductPurchase(player, productId)
	return { ok = true }
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

-- Robux purchases: grant the look the player picked (falls back to any unowned look at that price)
local PRICE_OF = {}
for price, id in Config.ROBUX_PRODUCTS do if id > 0 then PRICE_OF[id] = price end end
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local p = player and Profiles.get(player)
	if not p then return Enum.ProductPurchaseDecision.NotProcessedYet end
	p.receipts = p.receipts or {}
	if p.receipts[info.PurchaseId] then return Enum.ProductPurchaseDecision.PurchaseGranted end
	local price = PRICE_OF[info.ProductId]
	local item = shopItem(pendingBuy[info.PlayerId] or "")
	if not item or item.price ~= price or p.owned[item.id] then
		item = nil
		for _, s in Config.SHOP do if s.type ~= "boost" and s.price == price and not p.owned[s.id] then item = s; break end end
	end
	if item then p.owned[item.id] = true; p.equip[item.type] = item.id end
	pendingBuy[info.PlayerId] = nil
	p.receipts[info.PurchaseId] = true
	local ok = pcall(Profiles.save, player)
	if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
	push:FireClient(player, { kind = "profile", profile = profileView(player), bought = item and item.name })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

Players.PlayerRemoving:Connect(function(player)
	local g = games[player]
	-- leaving mid-ranked-run: get paid for what you answered (the entry is already spent)
	if g and g.ranked then pcall(actions.endRun, player) end
	games[player] = nil
	lastCall[player] = nil
	lastGame[player] = nil
	Profiles.release(player)
end)
