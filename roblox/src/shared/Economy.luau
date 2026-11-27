-- Ranked economy and "how you stack up", ported from js/game.js. Pure Luau (testable with the luau CLI).
-- Price is the same for everyone: par (median score from the player model) ÷ 5, rounded up. Payout: 1 coin per 5
-- points up to par, then 1 per 25 above par, times any visible boost, rounded down. ~50% of runs win, house +~6%.
local Config = require(script and script.Parent and script.Parent:FindFirstChild("Config") or "./Config")
local Economy = {}

-- How each kind of player scores on one prompt (share of answers per point value). On Roblox this can later be
-- replaced by real score counts from all players.
local PTS = { 0, 10, 30, 60, 85, 100 }
local PLAYER_TYPES = {
	{ w = 0.30, p = { 0.16, 0.50, 0.21, 0.08, 0.035, 0.015 } }, -- casual
	{ w = 0.35, p = { 0.10, 0.42, 0.26, 0.13, 0.06, 0.03 } }, -- average
	{ w = 0.22, p = { 0.05, 0.28, 0.29, 0.21, 0.11, 0.06 } }, -- good
	{ w = 0.13, p = { 0.02, 0.13, 0.23, 0.28, 0.19, 0.15 } }, -- elite
}
local curveCache = {}
-- curve[k] (0-based k) = chance of scoring exactly 5*k over n prompts
function Economy.scoreCurve(n)
	if curveCache[n] then return curveCache[n] end
	local out = {}
	for _, t in PLAYER_TYPES do
		local dist = { [0] = 1 }
		local size = 0
		for _ = 1, n do
			local nxt = {}
			for k = 0, size + 20 do nxt[k] = 0 end
			for k = 0, size do
				local v = dist[k]
				if v and v > 0 then
					for i, pt in PTS do
						local st = pt // 5
						nxt[k + st] += v * t.p[i]
					end
				end
			end
			dist = nxt
			size += 20
		end
		for k = 0, size do out[k] = (out[k] or 0) + dist[k] * t.w end
	end
	curveCache[n] = out
	return out
end

local parCache = {}
function Economy.par(len)
	if parCache[len] then return parCache[len] end
	local d, c, k = Economy.scoreCurve(len), 0, 0
	while d[k] do
		c += d[k]
		if c >= 0.5 then break end
		k += 1
	end
	parCache[len] = k * 5
	return k * 5
end

-- "Better than X% of players"
function Economy.percentile(n, score)
	local d = Economy.scoreCurve(math.clamp(n, 1, 120))
	local k = math.floor(score / 5 + 0.5)
	local below = 0
	for i = 0, k - 1 do below += d[i] or 0 end
	return math.floor(100 * (below + 0.5 * (d[k] or 0)) + 0.5)
end

function Economy.rankedLen(len)
	return (len and len > 0) and len or Config.ENDLESS_RANKED_LENGTH
end

function Economy.price(len)
	return math.max(1, math.ceil(Economy.par(Economy.rankedLen(len)) / Config.RANKED_RATE))
end

-- rk = profile.rk = {runs = ranked runs played, lose = losses in a row}
function Economy.boost(rk)
	rk = rk or {}
	local runs, lose = rk.runs or 0, rk.lose or 0
	if runs < #Config.WELCOME then return { x = Config.WELCOME[runs + 1], why = "NEW PLAYER" } end
	if lose >= Config.COMEBACK_AFTER then return { x = Config.COMEBACK, why = "COMEBACK" } end
	return { x = 1, why = "" }
end

function Economy.payout(score, len, boost)
	local P = Economy.par(Economy.rankedLen(len))
	local base = math.min(score, P) / Config.RANKED_RATE + math.max(0, score - P) / Config.RANKED_RATE * Config.UPPER_RATE
	return math.floor(base * (boost or 1))
end

-- smallest score that makes a profit, for the button tooltip
function Economy.profitAt(len, boost)
	local L = Economy.rankedLen(len)
	local price, s = Economy.price(L), 0
	while s < L * 100 and Economy.payout(s, L, boost) <= price do s += 5 end
	return s
end

function Economy.freeCoins(score)
	return math.floor(score / Config.FREE_RATE)
end

return Economy
