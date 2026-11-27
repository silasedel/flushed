-- Replays tests/fixture.luau (answers judged by the website's JS matcher) through the Luau port.
-- Run from the roblox/ folder:  luau tests/run.luau
local Match = require("../src/shared/Match")
local fixture = require("./fixture")
local cases, fails = 0, 0
for _, item in fixture do
	local q = item.q
	for _, t in item.t do
		local inp, want, wantFuzzy, wantNorm = t[1], t[2], t[3], t[4]
		cases += 1
		local ex = Match.matchExact(q, inp)
		local mc = not ex and Match.matchContained(q, inp)
		local sg = not ex and not mc and Match.suggest(q, inp)
		local got = ex and ("E:" .. ex.answer.name) or mc and ("C:" .. mc.answer.name .. ":" .. Match.containedScore(mc.answer.score)) or sg and ("S:" .. sg.answer.name) or "-"
		local fz = Match.match(q, inp)
		local gotFuzzy = fz and fz.answer.name or "-"
		local gotNorm = Match.norm(inp)
		if got ~= want or gotFuzzy ~= wantFuzzy or gotNorm ~= wantNorm then
			fails += 1
			if fails <= 25 then
				print(string.format("DIFF %s %q: web=%s/%s/%q luau=%s/%s/%q", q.id, inp, want, wantFuzzy, wantNorm, got, gotFuzzy, gotNorm))
			end
		end
	end
end
print(string.format("%d cases, %d differences", cases, fails))
if fails > 0 then error("Luau matcher differs from the website") end
