-- FLUSHED answer matching: a line-for-line port of js/match.js so Roblox judges answers exactly like the website.
-- Pure Luau (no Roblox APIs), so it also runs in the plain `luau` CLI for tests (roblox/tests/).
local Match = {}

Match.TIERS = {
	{ score = 100, key = "million", name = "Sigma", color = Color3 and Color3.fromHex("#f3cd66") or "#f3cd66", blurb = "One in a million. Absolute sigma." },
	{ score = 85, key = "deep", name = "Skibidi", color = Color3 and Color3.fromHex("#b77dff") or "#b77dff", blurb = "Certified skibidi. Few think like this." },
	{ score = 60, key = "rare", name = "Rizz", color = Color3 and Color3.fromHex("#ff4d4d") or "#ff4d4d", blurb = "Okay, you've got something." },
	{ score = 30, key = "schooler", name = "Mid", color = Color3 and Color3.fromHex("#6fc8ff") or "#6fc8ff", blurb = "Respectable. Kinda." },
	{ score = 10, key = "plankton", name = "NPC", color = Color3 and Color3.fromHex("#a8b3c4") or "#a8b3c4", blurb = "Everyone said that." },
}
function Match.tierOf(score)
	for _, t in Match.TIERS do
		if t.score == score then return t end
	end
	return Match.TIERS[#Match.TIERS]
end

---------------------------------------------------------------- text helpers
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function split(s)
	local out = {}
	for w in s:gmatch("[^ ]+") do table.insert(out, w) end
	return out
end
local function endsWith(s, suf) return #s >= #suf and s:sub(-#suf) == suf end
local function startsWith(s, pre) return s:sub(1, #pre) == pre end
local function has(s, sub) return s:find(sub, 1, true) ~= nil end

-- Accent folding (the JS version uses Unicode NFD + strips combining marks)
local ACCENTS = {}
local function addFold(chars, rep)
	for _, c in utf8.codes(chars) do ACCENTS[c] = rep end
end
addFold("àáâãäåāăąÀÁÂÃÄÅĀĂĄ", "a"); addFold("çćĉċčÇĆĈĊČ", "c"); addFold("ďĎ", "d")
addFold("èéêëēĕėęěÈÉÊËĒĔĖĘĚ", "e"); addFold("ĝğġģĜĞĠĢ", "g"); addFold("ĥĤ", "h")
addFold("ìíîïĩīĭįıÌÍÎÏĨĪĬĮİ", "i"); addFold("ĵĴ", "j"); addFold("ķĶ", "k"); addFold("ĺļľłĹĻĽŁ", "l")
addFold("ñńņňÑŃŅŇ", "n"); addFold("òóôõöōŏőøÒÓÔÕÖŌŎŐØ", "o"); addFold("ŕŗřŔŖŘ", "r")
addFold("śŝşšșŚŜŞŠȘ", "s"); addFold("ţťțŢŤȚ", "t"); addFold("ùúûüũūŭůűųÙÚÛÜŨŪŬŮŰŲ", "u")
addFold("ŵŴ", "w"); addFold("ýÿŷÝŸŶ", "y"); addFold("źżžŹŻŽ", "z")
addFold("ß", "ss"); addFold("æÆ", "ae"); addFold("œŒ", "oe"); addFold("µμ", "u")
addFold("’‘´", "'"); addFold("“”", '"')
local function fold(s)
	local ok, res = pcall(function()
		local parts = {}
		for _, c in utf8.codes(s) do
			if c >= 0x300 and c <= 0x36F then
				-- combining accent: drop
			elseif ACCENTS[c] then
				table.insert(parts, ACCENTS[c])
			else
				table.insert(parts, utf8.char(c))
			end
		end
		return table.concat(parts)
	end)
	return ok and res or s
end

local WORD_SUBS = { st = "saint", ste = "sainte", mt = "mount", ft = "fort", dr = "doctor", no = "number", ["&"] = "and", vs = "versus" }
local PUNCT = "[%'%`%\"%.%,%!%?%:%;%(%)%[%]%{%}%-%/%\\%_%*%#%@%+%~%|]"

function Match.norm(s)
	s = trim(fold(tostring(s)):lower())
	for _ = 1, 2 do -- up to two leading articles ("the", "a", "an")
		local rest = s:match("^the%s+(%S.*)$") or s:match("^an%s+(%S.*)$") or s:match("^a%s+(%S.*)$")
		if rest then s = rest else break end
	end
	s = s:gsub("%+%+", " plus plus ")
	s = s:gsub("(%l)#", "%1 sharp")
	s = s:gsub("&", " and ")
	s = s:gsub(PUNCT, " ")
	s = trim(s:gsub("%s+", " "))
	local words = split(s)
	for i, w in words do words[i] = WORD_SUBS[w] or w end
	return table.concat(words, " ")
end

local IRREG = { mice = "mouse", geese = "goose", teeth = "tooth", feet = "foot", men = "man", women = "woman", children = "child", people = "person", oxen = "ox", lice = "louse", dice = "die", cacti = "cactus", fungi = "fungus", octopi = "octopus", wolves = "wolf", knives = "knife", wives = "wife", lives = "life", leaves = "leaf", loaves = "loaf", halves = "half", shelves = "shelf", calves = "calf", elves = "elf", thieves = "thief", hooves = "hoof", scarves = "scarf", slushies = "slushie", smoothies = "smoothie", cookies = "cookie", movies = "movie", zombies = "zombie", brownies = "brownie", selfies = "selfie", hippies = "hippie", rookies = "rookie", goalies = "goalie", aunties = "auntie", oreos = "oreo", tacos = "taco", photos = "photo", pianos = "piano", radios = "radio", videos = "video", kangaroos = "kangaroo", tattoos = "tattoo" }
local function singular(w)
	if IRREG[w] then return IRREG[w] end
	if #w > 4 and endsWith(w, "ies") then return w:sub(1, -4) .. "y" end
	if #w > 4 and (endsWith(w, "ches") or endsWith(w, "shes") or endsWith(w, "xes") or endsWith(w, "sses") or endsWith(w, "zes") or endsWith(w, "oes")) then return w:sub(1, -3) end
	if #w > 3 and endsWith(w, "s") and not endsWith(w, "ss") and not endsWith(w, "us") and not endsWith(w, "is") then return w:sub(1, -2) end
	return w
end
Match.singular = singular
local function mapWords(s, f)
	local ws = split(s)
	for i, w in ws do ws[i] = f(w) end
	return table.concat(ws, " ")
end

local FILL = { the = true, their = true, your = true, my = true, his = true, her = true, our = true, its = true, a = true, an = true, of = true, some = true }
function Match.variants(n)
	local out, seen = {}, {}
	local function add(v)
		if v ~= "" and not seen[v] then seen[v] = true; table.insert(out, v) end
	end
	add(n)
	add(mapWords(n, singular))
	do
		local ws = {}
		for _, w in split(n) do if w ~= "and" then table.insert(ws, w) end end
		add(table.concat(ws, " "))
	end
	for _, v in table.clone(out) do
		local ws = {}
		for _, w in split(v) do if not FILL[w] then table.insert(ws, w) end end
		local f = table.concat(ws, " ")
		if f ~= "" and has(f, " ") and f ~= v then add(f) end
	end
	for _, v in table.clone(out) do add(mapWords(v, singular)) end
	for _, v in table.clone(out) do add((v:gsub(" ", ""))) end
	return out
end

-- optimal string alignment distance (adjacent swaps count as 1); returns max+1 once it's clearly over max
local function lev(a, b, max)
	if math.abs(#a - #b) > max then return max + 1 end
	local A, B = { a:byte(1, -1) }, { b:byte(1, -1) }
	local pp = nil
	local prev = {}
	for j = 0, #B do prev[j] = j end
	for i = 1, #A do
		local cur = { [0] = i }
		local best = i
		for j = 1, #B do
			local c = (A[i] == B[j]) and 0 or 1
			cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + c)
			if pp and j > 1 and i > 1 and A[i] == B[j - 1] and A[i - 1] == B[j] then cur[j] = math.min(cur[j], pp[j - 2] + 1) end
			if cur[j] < best then best = cur[j] end
		end
		if best > max then return max + 1 end
		pp = prev; prev = cur
	end
	return prev[#B]
end
Match.lev = lev

---------------------------------------------------------------- answers
-- q.a entries look like "Name|score|alias|alias"; a leading "!" means accepted but never shown in answer lists
function Match.parseAnswers(q)
	if q._parsed then return q._parsed end
	local list = {}
	for i, raw in q.a do
		local parts = {}
		for part in (tostring(raw) .. "|"):gmatch("(.-)|") do table.insert(parts, trim(part)) end
		local name = parts[1] or ""
		local hidden = startsWith(name, "!")
		if hidden then name = name:sub(2) end
		local sc = tonumber(parts[2]) or 10
		if sc == 15 then sc = 10 end -- the retired 15 tier counts as NPC
		local aliases = {}
		for k = 3, #parts do if parts[k] ~= "" then table.insert(aliases, parts[k]) end end
		table.insert(list, { i = i, name = name, score = sc, aliases = aliases, hidden = hidden })
	end
	local index, keys, label = {}, {}, {}
	-- exact normalised names/aliases win over derived variants
	for _, ans in list do
		for _, k in { ans.name, table.unpack(ans.aliases) } do
			local n = Match.norm(k)
			if n ~= "" and index[n] == nil then index[n] = ans; label[n] = k; table.insert(keys, { n, ans }) end
		end
	end
	for _, ans in list do
		for _, k in { ans.name, table.unpack(ans.aliases) } do
			local n = Match.norm(k)
			if n ~= "" then
				for _, v in Match.variants(n) do
					if index[v] == nil then index[v] = ans; label[v] = k; table.insert(keys, { v, ans }) end
				end
			end
		end
	end
	q._parsed = { list = list, index = index, keys = keys, label = label }
	return q._parsed
end

-- "Name a word that goes after 'side'": accept "flip", "side flip" and "sideflip" alike. q.anchor = {"after"|"before", normalised word}
local function anchorAlts(q, n)
	local an = q.anchor
	if not an then return {} end
	local dir, a = an[1], an[2]
	if not a or a == "" then return {} end
	local flat, af, out = n:gsub(" ", ""), a:gsub(" ", ""), {}
	if dir == "after" then
		if startsWith(flat, af) and #flat > #af then table.insert(out, startsWith(n, a .. " ") and n:sub(#a + 2) or flat:sub(#af + 1)) end
		table.insert(out, a .. " " .. n)
	else
		if endsWith(flat, af) and #flat > #af then table.insert(out, endsWith(n, " " .. a) and n:sub(1, #n - #a - 1) or flat:sub(1, #flat - #af)) end
		table.insert(out, n .. " " .. a)
	end
	local res = {}
	for _, x in out do if x ~= "" and x ~= n then table.insert(res, x) end end
	return res
end

-- Typed answer -> {answer, exact, label} or nil. Allows small typos on long inputs (7+ letters).
function Match.match(q, input, alt)
	local n = Match.norm(input)
	if n == "" then return nil end
	if not alt then
		local direct = Match.match(q, input, true)
		if direct then return direct end
		for _, a in anchorAlts(q, n) do
			local r = Match.match(q, a, true)
			if r then return r end
		end
		return nil
	end
	local p = Match.parseAnswers(q)
	for _, v in Match.variants(n) do
		local a = p.index[v]
		if a then return { answer = a, exact = true, label = p.label[v] } end
	end
	local flat = n:gsub(" ", "")
	local flatLen = utf8.len(flat) or #flat -- count letters, not bytes ("ʻ" is one letter)
	if flatLen < 7 then return nil end -- short words: a 1-letter change is often a different real word (horse/house)
	local maxD = flatLen >= 11 and 2 or 1
	local best, bestD, tie = nil, maxD + 1, false
	for _, kv in p.keys do
		local k, ans = kv[1], kv[2]
		if not has(k, " ") and #k >= 5 and k:sub(1, 1) == flat:sub(1, 1) then
			local d = lev(flat, k, maxD)
			if d < bestD then best = ans; bestD = d; tie = false
			elseif d == bestD and best and ans ~= best then tie = true end
		end
	end
	if best and not tie and bestD <= maxD then return { answer = best, exact = false } end
	return nil
end

function Match.matchExact(q, input)
	local n = Match.norm(input)
	if n == "" then return nil end
	local p = Match.parseAnswers(q)
	local cands = { n }
	for _, a in anchorAlts(q, n) do table.insert(cands, a) end
	for _, cand in cands do
		for _, v in Match.variants(cand) do
			local a = p.index[v]
			if a then return { answer = a, exact = true, label = p.label[v] } end
		end
	end
	return nil
end

-- "Did you mean" for near misses: typos, missing words, partial names. Returns {answer, label} or nil if unclear.
function Match.suggest(q, input)
	local n = Match.norm(input)
	if n == "" or #n < 3 then return nil end
	local p = Match.parseAnswers(q)
	local flat = n:gsub(" ", "")
	local maxD = #flat >= 12 and 3 or #flat >= 6 and 2 or #flat >= 4 and 1 or 0
	local scored, order = {}, {}
	local function consider(ans, cost, key)
		local cur = scored[ans]
		if not cur then table.insert(order, ans) end
		if not cur or cost < cur[1] then scored[ans] = { cost, key } end
	end
	for _, kv in p.keys do
		local k, ans = kv[1], kv[2]
		local kf = k:gsub(" ", "")
		if maxD > 0 and math.abs(#kf - #flat) <= maxD then
			local d = lev(flat, kf, maxD)
			if d <= maxD then consider(ans, d + (kf:sub(1, 1) == flat:sub(1, 1) and 0 or 0.6), k) end
		end
		if #flat >= 4 and #kf > #flat and startsWith(kf, flat) then consider(ans, 1.2 + (#kf - #flat) / 20, k) end
		if has(k, " ") and #n >= 4 then
			for _, w in split(k) do
				if #w >= 4 then
					local d = (w == n) and 0 or (#n >= 5 and lev(n, w, 1) or 9)
					if d <= 1 then consider(ans, 1.4 + d, k) end
				end
			end
		end
	end
	if #order == 0 then return nil end
	local pos = {}
	for i, a in order do pos[a] = i end
	table.sort(order, function(x, y)
		if scored[x][1] ~= scored[y][1] then return scored[x][1] < scored[y][1] end
		return pos[x] < pos[y]
	end)
	if #order > 1 and scored[order[2]][1] - scored[order[1]][1] < 0.35 then return nil end -- ambiguous
	local top = order[1]
	return { answer = top, label = p.label[scored[top][2]] or top.name }
end

-- A phrase that CONTAINS one valid answer counts as that answer ("lemon gatorade" -> Lemon), with guardrails.
local NAMING_WORDS = {}
for _, w in { "state", "city", "county", "island", "islands", "river", "lake", "mountain", "mountains", "street", "avenue", "park", "records", "studios", "games", "entertainment", "inc", "corp", "company", "co", "fc", "united", "jr", "sr", "ii", "iii", "iv", "tech", "district", "province", "territory", "bay", "beach", "airport", "station", "stadium", "arena", "museum", "hospital", "church", "cathedral", "bridge", "tower", "mall" } do NAMING_WORDS[w] = true end
-- names that contain an answer but are NOT that thing ("horseshoe crab" isn't a crab)
local MISNOMERS = {}
for _, w in { "horseshoe crab", "guinea pig", "koala bear", "sea cucumber", "sea lion", "sea horse", "prairie dog", "flying fox", "electric eel", "killer whale", "sea anemone", "mud puppy", "flying lemur", "red panda", "bearcat", "king cobra", "velvet ant", "firefly", "dragonfly", "jelly fish", "star fish", "cray fish", "silver fish", "shell fish", "cuttle fish", "peanut", "coconut", "strawberry", "pineapple" } do MISNOMERS[w] = true end

function Match.matchContained(q, input)
	if q.noContain then return nil end -- geography ('New Mexico' isn't Mexico) and letter prompts ('polar bear' for B)
	local n0 = Match.norm(input)
	if n0 == "" or not has(n0, " ") then return nil end
	if MISNOMERS[n0] or MISNOMERS[mapWords(n0, singular)] then return nil end
	local words = split(n0)
	local forms = { n0, mapWords(n0, singular) }
	local p = Match.parseAnswers(q)
	local hits, hitOrder = {}, {}
	for _, kv in p.keys do
		local k, ans = kv[1], kv[2]
		if #k >= 3 and k ~= n0 then
			local f, s, e
			for _, form in forms do
				s, e = (" " .. form .. " "):find(" " .. k .. " ", 1, true)
				if s then f = form; break end
			end
			if f then
				local kWords = split(k)
				local extra = #words - #kWords
				local padded = " " .. f .. " "
				local before, after = trim(padded:sub(1, s)), trim(padded:sub(e))
				local ok = true
				-- "Penn State", "Kansas City": a naming word after the answer makes it a different thing
				for _, w in split(after) do
					if NAMING_WORDS[w] or NAMING_WORDS[w .. "s"] then ok = false end
				end
				-- short alias of a longer name ("Golem" for Iron Golem): extra words must come from that name
				if ok then
					local nameWords = split(mapWords(Match.norm(ans.name), singular))
					local nameSet = {}
					for _, w in nameWords do nameSet[w] = true end
					if #nameWords > #kWords then
						local sub = true
						for _, w in kWords do if not nameSet[singular(w)] then sub = false end end
						if sub then
							for _, w in split(before .. " " .. after) do
								if not nameSet[singular(w)] then ok = false end
							end
						end
					end
				end
				if ok and (extra < 1 or extra > 4 or (#k < 4 and extra > 2)) then ok = false end
				if ok then
					local cur = hits[ans]
					if not cur then table.insert(hitOrder, ans) end
					if not cur or #k > #cur then hits[ans] = k end
				end
			end
		end
	end
	if #hitOrder == 0 then return nil end
	-- several answers inside one phrase: the head noun usually comes last ("lemon gatorade" -> Gatorade)
	local function ends(k)
		for _, f in forms do
			if endsWith(f, " " .. k) or f == k then return 1 end
		end
		return 0
	end
	local pos = {}
	for i, a in hitOrder do pos[a] = i end
	table.sort(hitOrder, function(x, y)
		local ex, ey = ends(hits[x]), ends(hits[y])
		if ex ~= ey then return ex > ey end
		if #hits[x] ~= #hits[y] then return #hits[x] > #hits[y] end
		return pos[x] < pos[y]
	end)
	return { answer = hitOrder[1], contained = true }
end

-- A more specific phrase than a listed answer is something few people say: score it at least Rizz,
-- one tier above the answer it contains, never Sigma.
local LADDER = { 10, 30, 60, 85 }
function Match.containedScore(score)
	local i = table.find(LADDER, score)
	local bumped = i and LADDER[math.min(#LADDER, i + 1)] or 85
	return math.min(85, math.max(60, bumped))
end

-- The order the game judges a submitted answer in (same as the website's submit()):
-- exact name/alias -> a phrase containing one answer -> otherwise maybe a "did you mean".
-- Returns {answer, score, display} on a hit, {suggest = {...}} on a near miss, or nil.
function Match.judge(q, input)
	local m = Match.matchExact(q, input)
	if m then return { answer = m.answer, score = m.answer.score, label = m.label } end
	local mc = Match.matchContained(q, input)
	if mc then return { answer = mc.answer, score = Match.containedScore(mc.answer.score), contained = true } end
	local sg = Match.suggest(q, input)
	if sg then return { suggest = sg } end
	return nil
end

return Match
