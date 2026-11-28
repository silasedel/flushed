--!native
-- The results page, rebuilt from the website (index.html #screen-results, css/style.css .res-*, js/game.js
-- showResults / drawDiveChart / drawStack). One scrolling column, 600px wide (minus 16px gutters on phones):
-- mini logo + mode, the big score, depth, zone, payout line, FLUSH LOG chart, HOW YOU STACK UP curve,
-- THE VIBE CHECK bands, COPY RESULT / SHARE, THE CLOG (every round, tap to open all answers), LOGBOOK,
-- PLAY AGAIN and the bottom tabs. Every size is the stylesheet's formula; checked against Chrome's layout.
local Kit = require(script and script.Parent and script.Parent:FindFirstChild("Kit") or "./Kit")
local Canvas = require(script and script.Parent and script.Parent:FindFirstChild("Canvas") or "./Canvas")
local TextRaster = require(script and script.Parent and script.Parent:FindFirstChild("TextRaster") or "./TextRaster")
local Game = require(script and script.Parent and script.Parent:FindFirstChild("GameScreen") or "./GameScreen")
local Css = Kit.Css
local rgb, hex = Kit.rgb, Kit.hex

local Results = {}

local MONO = "plex"
local TIERS = Game.TIERS
local ICON_SPR = { million = "icoSigma", deep = "icoSkibidi", rare = "icoRizz", schooler = "icoMid", plankton = "icoNPC" }
local C = {
	white = rgb(255, 255, 255), logo = hex("#f4fbff"), mode = hex("#9fb39a"), lime = hex("#7dff6a"), zone = hex("#879f81"),
	coins = hex("#c9d5c4"), secH = hex("#b6c6da"), secSub = hex("#5f7a5c"), rule = rgb(167, 187, 163), muted = hex("#9fb39a"),
	cq = hex("#71896c"), miss = hex("#5f7a5c"), nocatch = hex("#4f6079"),
}
-- score bands for a whole dive (written for 7 prompts, scaled to the game length)
local BEARING = {
	{ min = 0, tier = 10, text = "NPC. Still in the bowl, basically." },
	{ min = 151, tier = 30, text = "Mid. Made it into the pipes." },
	{ min = 251, tier = 60, text = "Rizz. Deep in the sewer. Respect." },
	{ min = 351, tier = 85, text = "Skibidi. Rat royalty bows to you." },
	{ min = 450, tier = 100, text = "Sigma. You reached the Brainrot Core." },
}
local function jsRound(x) return math.floor(x + 0.5) end
local fmt = Game.fmt

---------------------------------------------------------------- the score curve (js/game.js scoreCurve)
-- How players score per prompt (a mix of casual / average / good / elite); a game's curve is that convolved n times.
local PLAYER_TYPES = {
	{ w = 0.30, p = { { 0, 0.16 }, { 10, 0.50 }, { 30, 0.21 }, { 60, 0.08 }, { 85, 0.035 }, { 100, 0.015 } } },
	{ w = 0.35, p = { { 0, 0.10 }, { 10, 0.42 }, { 30, 0.26 }, { 60, 0.13 }, { 85, 0.06 }, { 100, 0.03 } } },
	{ w = 0.22, p = { { 0, 0.05 }, { 10, 0.28 }, { 30, 0.29 }, { 60, 0.21 }, { 85, 0.11 }, { 100, 0.06 } } },
	{ w = 0.13, p = { { 0, 0.02 }, { 10, 0.13 }, { 30, 0.23 }, { 60, 0.28 }, { 85, 0.19 }, { 100, 0.15 } } },
}
local curveCache = {}
-- returns dist (0-based: dist[k] = chance of scoring exactly 5k) and its length
local function scoreCurve(n)
	if curveCache[n] then return curveCache[n][1], curveCache[n][2] end
	local out, outN = {}, 0
	for _, t in PLAYER_TYPES do
		local dist, len = { [0] = 1 }, 1
		for _ = 1, n do
			local nlen = len + 20
			local nxt = {}
			for i = 0, nlen - 1 do nxt[i] = 0 end
			for k = 0, len - 1 do
				local v = dist[k]
				if v ~= 0 then for _, st in t.p do nxt[k + st[1] / 5] += v * st[2] end end
			end
			dist, len = nxt, nlen
		end
		for i = 0, len - 1 do out[i] = (out[i] or 0) + dist[i] * t.w end
		outN = math.max(outN, len)
	end
	curveCache[n] = { out, outN }
	return out, outN
end
local function percentile(dist, len, score)
	local k = jsRound(score / 5)
	local below = 0
	for i = 0, math.min(k, len) - 1 do below += dist[i] end
	return jsRound(100 * (below + 0.5 * (dist[k] or 0)))
end
Results.scoreCurve, Results.percentile = scoreCurve, percentile

---------------------------------------------------------------- chart drawing helpers (into a Canvas)
local function setColor(cv, c, a) cv:setRGBA(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), a or 1) end
-- SVG <text>: x, baseline y, text-anchor. Rasterized at 2x and averaged down (anti-aliased, so small axis labels
-- stay readable instead of losing strokes)
local function ctext(cv, s, size, weight, spacing, x, by, anchor, c, a)
	local opts = { family = MONO, weight = weight, size = size, spacing = spacing }
	local L = TextRaster.layout(s, opts)
	local ox = anchor == "middle" and x - L.w / 2 or anchor == "end" and x - L.w or x
	local o2 = { family = MONO, weight = weight, size = size * 2, spacing = spacing * 2 }
	local L2 = TextRaster.layout(s, o2)
	local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
	local buf, W, H = cv.buf, cv.W, cv.H
	local cov = {}
	TextRaster.draw(s, o2, L2, ox * 2, (by - L.ascent) * 2 + (L.ascent * 2 - L2.ascent), L2.w, function(x0, x1, yy)
		local py = yy // 2
		if py >= 0 and py < H then
			for xx = math.max(0, x0), math.min(W * 2 - 1, x1) do
				local k = py * W + xx // 2
				cov[k] = (cov[k] or 0) + 0.25
			end
		end
	end)
	for k, v in cov do Canvas.blend(buf, k * 4, r, g, b, (a or 1) * math.min(1, v)) end
end
-- a stroked segment (butt caps) as a filled quad
local function seg(cv, x0, y0, x1, y1, w)
	local dx, dy = x1 - x0, y1 - y0
	local l = math.sqrt(dx * dx + dy * dy)
	if l < 1e-6 then return end
	local nx, ny = -dy / l * w / 2, dx / l * w / 2
	cv:beginPath(); cv:moveTo(x0 + nx, y0 + ny); cv:lineTo(x1 + nx, y1 + ny); cv:lineTo(x1 - nx, y1 - ny); cv:lineTo(x0 - nx, y0 - ny); cv:fill()
end
local function disc(cv, cx, cy, r)
	cv:beginPath()
	for i = 0, 15 do local a = i / 16 * math.pi * 2; cv:lineTo(cx + math.cos(a) * r, cy + math.sin(a) * r) end
	cv:fill()
end
local function ring(cv, cx, cy, r, w)
	cv:beginPath()
	local N = 24
	for i = 0, N do local a = i / N * math.pi * 2; cv:lineTo(cx + math.cos(a) * (r + w / 2), cy + math.sin(a) * (r + w / 2)) end
	for i = N, 0, -1 do local a = i / N * math.pi * 2; cv:lineTo(cx + math.cos(a) * (r - w / 2), cy + math.sin(a) * (r - w / 2)) end
	cv:fill()
end
-- pixel sprite into the canvas, nearest neighbour, dest box snapped to whole pixels
local function csprite(cv, name, x, y, w, h)
	local g = Kit.spriteGrid(name)
	local X0, Y0 = jsRound(x), jsRound(y)
	local PW, PH = jsRound(x + w) - X0, jsRound(y + h) - Y0
	for py = 0, PH - 1 do
		local sy = math.min(g.h - 1, math.floor((py + 0.5) * g.h / PH))
		for px = 0, PW - 1 do
			local c = g.px[sy * g.w + math.min(g.w - 1, math.floor((px + 0.5) * g.w / PW)) + 1]
			local X, Y = X0 + px, Y0 + py
			if c and X >= 0 and Y >= 0 and X < cv.W and Y < cv.H then
				Canvas.blend(cv.buf, (Y * cv.W + X) * 4, math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), 1)
			end
		end
	end
end
local function showCanvas(parent, cv, x, y)
	if Kit.makeImage then
		local img = Kit.makeImage(cv.W, cv.H)
		img:write(cv.buf)
		local lbl = img:label()
		lbl.Position = Kit.UDim2.fromOffset(jsRound(x), jsRound(y))
		lbl.Size = Kit.UDim2.fromOffset(cv.W, cv.H)
		lbl.Parent = parent
		return lbl
	end
	-- Frames fallback: one Frame per run of equal opaque-ish pixels
	local holder = Kit.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = Kit.UDim2.fromOffset(jsRound(x), jsRound(y))
	holder.Size = Kit.UDim2.fromOffset(cv.W, cv.H)
	holder.Parent = parent
	local buf = cv.buf
	for yy = 0, cv.H - 1 do
		local x0, key = nil, nil
		for xx = 0, cv.W do
			local k = nil
			if xx < cv.W then
				local v = buffer.readu32(buf, (yy * cv.W + xx) * 4)
				if v >= 0x10000000 then k = v end
			end
			if k ~= key then
				if key then
					local r, g, b, a = key % 256, (key // 256) % 256, (key // 65536) % 256, key // 16777216
					Kit.frame(holder, x0, yy, xx - x0, 1, rgb(r, g, b), a / 255)
				end
				x0, key = xx, k
			end
		end
	end
	return holder
end

---------------------------------------------------------------- FLUSH LOG (js drawDiveChart), viewBox 480x270
local function diveChart(parent, x, y, w, results)
	local k = w / 480
	local cv = Canvas.new(math.ceil(w), math.ceil(270 * k))
	local Wv, Hv, L, R, T, B = 480, 270, 34, 14, 14, 30
	local n = math.max(1, #results)
	local slot = (Wv - L - R) / n
	local function X(i) return L + (i + 0.5) * slot end
	local function Y(p) return T + (p / 100) * (Hv - T - B) end
	for _, p in { 0, 25, 50, 75, 100 } do
		setColor(cv, C.rule, p == 0 and 0.35 or 0.12)
		cv:fillRect(L * k, Y(p) * k - k / 2, (Wv - R - L) * k, k)
		ctext(cv, p ~= 0 and ("-" .. p) or "0m", 9.62 * k, 400, 0, (L - 6) * k, (Y(p) + 3) * k, "end", C.secSub)
	end
	for i, r in results do
		local t = (r.score or 0) > 0 and TIERS[r.score] or nil
		local cx = X(i - 1)
		if n <= 12 or i % 5 == 0 or i == 1 then ctext(cv, tostring(i), 9.62 * k, 400, 0, cx * k, (Hv - 8) * k, "middle", C.secSub) end
		if not t then
			setColor(cv, hex("#56684f"), 1)
			ring(cv, cx * k, Y(0) * k, 4 * k, 1.5 * k)
		else
			local cy = Y(r.score)
			setColor(cv, t.color, 0.85)
			cv:fillRect(cx * k - 0.75 * k, Y(0) * k, 1.5 * k, (cy - Y(0)) * k)
			local sz = math.min(32, math.max(10, slot - 2))
			csprite(cv, ICON_SPR[t.key], (cx - sz / 2) * k, (cy - sz / 2) * k, sz * k, sz * k)
		end
	end
	return showCanvas(parent, cv, x, y), 270 * k
end

---------------------------------------------------------------- HOW YOU STACK UP (js drawStack), viewBox 480x230
local function tierForPer(per)
	return TIERS[per >= 70 and 100 or per >= 50 and 85 or per >= 35 and 60 or per >= 20 and 30 or 10]
end
function Results.stackInfo(score, n)
	n = math.max(1, n)
	local dist, len = scoreCurve(math.min(n, 120))
	local pct = percentile(dist, len, score)
	local t = tierForPer(score / n)
	local word = pct >= 99 and "Top 1%. Certified Sigma." or pct >= 90 and "Built different." or pct >= 70 and "Above the crowd."
		or pct >= 45 and "Right in the pack." or pct >= 20 and "Kinda NPC behavior." or "Still in the bowl."
	return math.min(99, math.max(1, pct)), word, t
end
local function stackChart(parent, x, y, w, score, n)
	n = math.max(1, n)
	local dist, len = scoreCurve(math.min(n, 120))
	local k = w / 480
	local cv = Canvas.new(math.ceil(w), math.ceil(230 * k))
	local Wv, Hv, L, R, T, B = 480, 230, 10, 10, 74, 26
	local lo, hi, c = 0, len - 1, 0
	for i = 0, len - 1 do
		c += dist[i]
		if c < 0.002 then lo = i end
		if c < 0.998 then hi = i + 1 end
	end
	local you = jsRound(score / 5)
	lo = math.max(0, math.min(lo, you - 2)); hi = math.min(len - 1, math.max(hi, you + 2))
	local sm = {}
	for i = 0, len - 1 do
		local s, ww = 0, 0
		for j = -3, 3 do
			local v = dist[i + j]
			if v ~= nil then local q = 4 - math.abs(j); s += v * q; ww += q end
		end
		sm[i] = s / ww
	end
	local peak = 0
	for i = lo, hi do peak = math.max(peak, sm[i]) end
	local function X(i) return L + ((i - lo) / math.max(1, hi - lo)) * (Wv - L - R) end
	local function Y(v) return Hv - B - (v / peak) * (Hv - T - B) end
	local per = score / n
	local t = tierForPer(per)
	local avg = 0
	for i = 0, len - 1 do avg += dist[i] * i * 5 end
	local function pt(i) return X(i) * k, Y(sm[i]) * k end
	-- area under the whole curve
	setColor(cv, C.rule, 0.12)
	cv:beginPath()
	for i = lo, hi do local px, py = pt(i); cv:lineTo(px, py) end
	cv:lineTo(X(hi) * k, (Hv - B) * k); cv:lineTo(X(lo) * k, (Hv - B) * k); cv:fill()
	-- your part of it
	local ci = math.min(math.max(you, lo), hi)
	local yx, yy = X(ci), Y(sm[ci])
	setColor(cv, t.color, 0.38)
	cv:beginPath()
	for i = lo, math.min(you, hi) do local px, py = pt(i); cv:lineTo(px, py) end
	cv:lineTo(yx * k, (Hv - B) * k); cv:lineTo(X(lo) * k, (Hv - B) * k); cv:fill()
	-- the curve (2px, round joins)
	setColor(cv, C.coins, 1)
	for i = lo, hi - 1 do
		local ax, ay = pt(i); local bx, by = pt(i + 1)
		seg(cv, ax, ay, bx, by, 2 * k)
		if i > lo then disc(cv, ax, ay, k) end
	end
	-- average marker (dashed 3 3) and its label, kept clear of your marker
	local ax = X(jsRound(avg / 5))
	local near = math.abs(ax - yx) < 70
	local aLabelX = near and (ax < yx and ax - 6 or ax + 6) or ax
	local aAnchor = near and (ax < yx and "end" or "start") or "middle"
	setColor(cv, C.rule, 0.5)
	local d = T - 6
	while d < Hv - B do
		cv:fillRect(ax * k - k / 2, d * k, k, (math.min(d + 3, Hv - B) - d) * k)
		d += 6
	end
	ctext(cv, "AVG " .. jsRound(avg), 10 * k, 400, k, aLabelX * k, (T - 9) * k, aAnchor, hex("#7a9276"))
	-- you: line, icon, label
	local iy = math.max(18, yy - 44)
	local lx = math.min(Wv - 40, math.max(40, yx))
	setColor(cv, t.color, 1)
	cv:fillRect(yx * k - k, (iy + 28) * k, 2 * k, (Hv - B - iy - 28) * k)
	csprite(cv, ICON_SPR[t.key], (yx - 14) * k, iy * k, 28 * k, 28 * k)
	ctext(cv, "YOU " .. score, 12 * k, 700, 1.2 * k, lx * k, (iy - 5) * k, "middle", t.color)
	-- base line and axis
	setColor(cv, C.rule, 0.4)
	cv:fillRect(L * k, (Hv - B) * k - k / 2, (Wv - R - L) * k, k)
	for _, f in { 0, 0.25, 0.5, 0.75, 1 } do
		local i = jsRound(lo + f * (hi - lo))
		ctext(cv, tostring(i * 5), 10 * k, 400, k, X(i) * k, (Hv - 8) * k, "middle", hex("#7a9276"))
	end
	return showCanvas(parent, cv, x, y), 230 * k
end

---------------------------------------------------------------- the page
-- data: modeLabel, score, depth, zone, coinsLine = segments {text, bold?, coin?} , results = { {score, q, answer,
--       input, reason, tries} }, n (prompt count), stats = {played, avg, best}, againLabel, expanded = { [i] = answers }
-- cb: onCopy, onShare, onAgain, onPacks, onStats, onHome, onToggle(i)
-- Returns a ScrollingFrame and rects (name -> {x, y, w, h}, page coordinates) for layout checks.
function Results.build(parent, data, cb)
	cb = cb or {}
	local W, H = Css.W, Css.H
	local narrow, xs = W <= 760, W <= 700
	local U = narrow and 14.72 or Css.cr(0.82, 0.55, 0.55, 1.12)
	local colW = math.min(W - 32, 600)
	local X0 = (W - colW) / 2
	local rects = {}
	local function Rr(name, x, y, w, h) rects[name] = { x, y, w, h } end

	local root = Kit.new("ScrollingFrame")
	root.Name = "Results"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = Kit.UDim2.fromScale(1, 1)
	root.ScrollBarThickness = 0
	root.ScrollingDirection = Enum and Enum.ScrollingDirection.Y or nil
	root.ElasticBehavior = Enum and Enum.ElasticBehavior.Never or nil
	root.Parent = parent
	local page = Kit.new("Frame")
	page.Name = "Page"
	page.BackgroundTransparency = 1
	page.Parent = root
	local function hit(x, y, w, h, fn)
		local b = Kit.new("TextButton"); b.Text = ""; b.BackgroundTransparency = 1; b.AutoButtonColor = false
		b.Position = Kit.UDim2.fromOffset(jsRound(x), jsRound(y)); b.Size = Kit.UDim2.fromOffset(jsRound(w), jsRound(h)); b.ZIndex = 5
		b.Parent = page
		if fn then b.Activated:Connect(fn) end
		return b
	end

	local y = Css.clamp(18, Css.vh(4), 40)
	------------------------------------------------ res-top: mini logo + mode
	local logoF = 35.2
	local logoSt = { family = "vt323", size = logoF, spacing = 0.08 * logoF, color = C.logo,
		shadows = { { -2, 0, 0, rgb(255, 92, 138), 0.95 }, { 2, 0, 0, rgb(125, 255, 106), 0.95 } } }
	local logoW, logoH = Kit.measure("FLUSHED", logoSt)
	Kit.text(page, X0, y, "FLUSHED", logoSt)
	Rr("mini-logo", X0, y, logoW, logoH)
	local modeF = 12.432
	local modeSt = { family = MONO, size = modeF, spacing = 0.28 * modeF, color = C.mode }
	local modeW = Kit.measure(data.modeLabel, modeSt)
	local avail = colW - logoW
	local boxW = math.min(modeW, avail)
	local mSt = table.clone(modeSt); mSt.width = boxW
	local _, modeH = Kit.measure(data.modeLabel, mSt)
	local modeY = y + 28 - math.floor(1.025 * modeF + 0.5) -- baselines line up (VT323 ascent 0.8em)
	Kit.text(page, X0 + colW - boxW, modeY, data.modeLabel, mSt, boxW)
	Rr("res-mode", X0 + colW - boxW, modeY, boxW, modeH)
	y += math.max(logoH, modeY + modeH - y)

	------------------------------------------------ score + depth
	y += 0.35 * U
	local S = Css.cr(4, 3, 3, 6)
	local scoreSt = { family = MONO, weight = 700, size = S, spacing = 0.02 * S, color = C.white, lineHeight = 0.85 * S }
	local scoreW = Kit.measure(tostring(data.score), scoreSt)
	local scoreH = 0.85 * S
	local scoreY = y
	local scoreHolder = Kit.text(page, X0, y, tostring(data.score), scoreSt)
	Rr("res-score", X0, y, scoreW, scoreH)
	local dF = 15.984
	local dSt = { family = MONO, size = dF, color = C.lime, lineHeight = 0.85 * dF }
	local dStr = "-" .. fmt(data.depth or 0) .. "m"
	local dW = Kit.measure(dStr, dSt)
	local dH = 0.85 * dF + 0.5 * dF
	Kit.text(page, X0 + scoreW + 0.7 * U, y + scoreH - dH, dStr, dSt)
	Rr("res-depth", X0 + scoreW + 0.7 * U, y + scoreH - dH, dW, dH)
	y += scoreH
	-- count the score up like the website (900ms, ease-out cubic)
	if data.countUp and task then
		task.spawn(function()
			local t0 = os.clock()
			local last = -1
			while true do
				local p = math.min(1, (os.clock() - t0) / 0.9)
				local v = jsRound(data.score * (1 - (1 - p) ^ 3))
				if v ~= last and scoreHolder.Parent then
					last = v
					local old = scoreHolder
					scoreHolder = Kit.text(page, X0, scoreY, tostring(v), scoreSt)
					old:Destroy()
				end
				if p >= 1 or not root.Parent then break end
				task.wait(1 / 30)
			end
		end)
	end

	------------------------------------------------ zone, coins
	local zF = 13.616
	y += 0.5 * zF
	Kit.text(page, X0, y, data.zone or "", { family = MONO, size = zF, spacing = 0.12 * zF, color = C.zone })
	Rr("res-zone", X0, y, colW, Kit.lh(zF))
	y += Kit.lh(zF)
	y += 0.4 * U
	local cSt = { family = MONO, size = U, spacing = 0.08 * U, color = C.coins }
	local bSt = table.clone(cSt); bSt.weight = 700
	local segs = {}
	for _, s in data.coinsLine or { { "Free game · play " }, { "Ranked", bold = true }, { " to win coins" } } do
		table.insert(segs, { s[1], style = s.bold and bSt or cSt })
	end
	local cH = Kit.rich(page, X0, y, colW, segs, cSt)
	Rr("res-coins", X0, y, colW, cH)
	y += cH
	local mb = 0 -- margin-bottom of the previous block (CSS margins collapse: the larger wins)

	------------------------------------------------ section heading: "TITLE ---- sub ------"
	local hF = 15.392
	local function secH(title, sub, name)
		y += math.max(mb, 2.4 * hF)
		local tSt = { family = MONO, size = hF, spacing = 0.3 * hF, color = C.secH }
		local tw = Kit.measure(title, tSt)
		Kit.text(page, X0, y, title, tSt)
		Rr(name or title, X0, y, colW, Kit.lh(hF))
		local x = X0 + tw + 1.2 * hF
		if sub then
			local sF = 0.9 * hF
			local sSt = { family = MONO, size = sF, spacing = 0.2 * sF, color = C.secSub }
			local sw = Kit.measure(sub, sSt)
			Kit.text(page, x, y + (Kit.lh(hF) - Kit.lh(sF)) / 2, sub, sSt)
			Rr((name or title) .. "-sub", x, y + (Kit.lh(hF) - Kit.lh(sF)) / 2, sw, Kit.lh(sF))
			x += sw + 1.2 * hF
		end
		if X0 + colW - x > 0 then Kit.dashH(page, x, y + (Kit.lh(hF) - 1) / 2, X0 + colW - x, C.rule, 0.35) end
		y += Kit.lh(hF)
		mb = 0.8 * hF
	end

	------------------------------------------------ FLUSH LOG
	secH("FLUSH LOG", "DEEPER ↓ RARER", "sec-log")
	y += mb; mb = 0
	local _, dh = diveChart(page, X0, y, colW, data.results)
	Rr("dive-chart", X0, y, colW, dh)
	y += dh

	------------------------------------------------ HOW YOU STACK UP
	local n = math.max(1, data.n or #data.results)
	secH("HOW YOU STACK UP", string.format("VS. THE AVERAGE %d-PROMPT FLUSH", n), "sec-stack")
	local slF = Css.cr(0.95, 0.8, 0.4, 1.2)
	y += math.max(mb, 0.2 * slF); mb = 0
	local pct, word, st = Results.stackInfo(data.score, n)
	local lSt = { family = MONO, size = slF, spacing = 0.08 * slF, color = C.coins }
	local lbSt = { family = MONO, size = 1.35 * slF, weight = 700, spacing = 0.08 * slF, color = st.color }
	local lsSt = { family = MONO, size = slF, spacing = 0.08 * slF, color = C.mode }
	local slH = Kit.rich(page, X0, y, colW, {
		{ "Better than ", style = lSt }, { pct .. "%", style = lbSt }, { " of flushers. ", style = lSt }, { word, style = lsSt, ml = 0.4 * slF },
	}, lSt)
	Rr("stack-line", X0, y, colW, slH)
	y += slH
	y += math.max(0.2 * slF, 0.4 * U)
	local _, sh = stackChart(page, X0, y, colW, data.score, n)
	Rr("stack-chart", X0, y, colW, sh)
	y += sh
	mb = 0.6 * U

	------------------------------------------------ THE VIBE CHECK
	secH("THE VIBE CHECK", nil, "sec-vibe")
	y += mb; mb = 0
	do
		local bF = narrow and 16.8 or 14.208
		local padY, padX = 0.75 * bF, 0.2 * bF
		local icoCol, rangeCol, gap = narrow and 24 or 28, (narrow and 5.2 or 6.5) * bF, 0.8 * bF
		local textX = padX + icoCol + gap + rangeCol + gap
		local textW = colW - textX - padX
		local sc = n / 7
		local norm = data.score / sc
		local y0 = y
		for i, b in BEARING do
			local nextMin = BEARING[i + 1] and BEARING[i + 1].min
			local on = norm >= b.min and (i == #BEARING or norm < nextMin)
			local label = i == #BEARING and (jsRound(b.min * sc) .. "+") or (jsRound(b.min * sc) .. "–" .. (jsRound(nextMin * sc) - 1))
			local tSt = { family = MONO, size = bF, weight = on and 700 or 400, color = on and C.white or C.zone, width = textW }
			local _, th = Kit.measure(b.text, tSt)
			local ch = math.max(24, th)
			local rowH = 2 * padY + ch + 1
			if on then
				-- linear-gradient(90deg, rgba(157,255,122,.08), transparent)
				local bands = 16
				for k2 = 0, bands - 1 do
					Kit.frame(page, X0 + colW * k2 / bands, y, colW / bands, rowH, rgb(157, 255, 122), 0.08 * (1 - (k2 + 0.5) / bands))
				end
			end
			local t = TIERS[b.tier]
			Kit.sprite(page, ICON_SPR[t.key], X0 + padX, y + padY + (ch - 24) / 2, 24, 24)
			Kit.text(page, X0 + padX + icoCol + gap, y + padY + (ch - Kit.lh(bF)) / 2, label, { family = MONO, size = bF, color = t.color })
			Kit.text(page, X0 + textX, y + padY + (ch - th) / 2, b.text, tSt, textW)
			Rr("bearing-" .. i, X0, y, colW, rowH)
			Kit.frame(page, X0, y + rowH - 1, colW, 1, C.rule, 0.18)
			y += rowH
		end
		Rr("bearing", X0, y0, colW, y - y0)
	end

	------------------------------------------------ COPY RESULT / SHARE
	y += 2 * U
	do
		local shareW = 108
		local copyW = colW - 10 - shareW
		local box = Kit.box(page, X0, y, copyW, 64, { bg = hex("#ff7a9f"), border = 2, bc = hex("#ff86a6"), glow = { 22, rgb(255, 92, 138), 0.35 } })
		local fF = narrow and 19.2 or 17.76
		local fSt = { family = MONO, size = fF, spacing = (narrow and 0.18 or 0.3) * fF, color = hex("#2b0c1a") }
		local tw = Kit.measure("COPY RESULT", fSt)
		Kit.text(box, (copyW - tw) / 2, (64 - Kit.lh(fF)) / 2, "COPY RESULT", fSt)
		Rr("btn-copy", X0, y, copyW, 64)
		hit(X0, y, copyW, 64, cb.onCopy)
		local sx = X0 + copyW + 10
		local sbox = Kit.box(page, sx, y, shareW, 64, { bg = rgb(14, 22, 16), bgA = 0.9, border = 2, bc = C.rule, bcA = 0.45 })
		local sF = 16.576
		local sSt = { family = MONO, size = sF, spacing = 0.2 * sF, color = hex("#e8f0f8") }
		local sw = Kit.measure("SHARE_", sSt)
		local sw5 = Kit.measure("SHARE", sSt)
		Kit.text(sbox, (shareW - sw) / 2, (64 - Kit.lh(sF)) / 2, "SHARE", sSt)
		local caret = Kit.text(sbox, (shareW - sw) / 2 + sw5, (64 - Kit.lh(sF)) / 2, "_", sSt)
		Rr("btn-share2", sx, y, shareW, 64)
		hit(sx, y, shareW, 64, cb.onShare)
		if task then
			task.spawn(function()
				while root.Parent do
					task.wait(0.5)
					caret.Visible = not caret.Visible
				end
			end)
		end
		y += 64
	end
	mb = 0

	------------------------------------------------ THE CLOG
	secH("THE CLOG", "TAP A ROUND FOR EVERY ANSWER", "sec-clog")
	y += mb; mb = 0
	do
		local padY, padX = U, 0.2 * U
		local nW, icoW, gap = (narrow and 1.2 or 1.6) * U, narrow and 26 or 32, (narrow and 0.6 or 0.9) * U
		local plusW = narrow and 0 or 1.2 * U
		local pF = 16.576
		local qF = 12.432
		local aF = 23.2
		local g = 0.3 * U
		local y0 = y
		for i, r in data.results do
			local t = (r.score or 0) > 0 and TIERS[r.score] or nil
			local col = t and t.color or C.nocatch
			local pSt = { family = MONO, size = pF, color = col }
			local pW = Kit.measure(tostring(r.score or 0), pSt)
			local bodyX = padX + nW + gap + icoW + gap
			local bodyW = colW - bodyX - padX - gap - pW - (narrow and 0 or (gap + plusW))
			local inp = (r.input and r.input ~= "") and r.input or nil
			local ans = (r.answer and r.answer ~= "") and r.answer or (inp and ('"' .. inp .. '"')) or (r.reason == "skip" and "skipped" or "—")
			local aSt = { family = MONO, weight = 600, size = aF, color = r.answer and C.white or C.miss, width = bodyW }
			local _, aH = Kit.measure(ans, aSt)
			local bodyH = Kit.lh(qF) + g + aH + g + Kit.lh(qF)
			local headH = 2 * padY + bodyH
			local cy = y + padY
			-- number
			Kit.text(page, X0 + padX, cy + (bodyH - Kit.lh(13.024)) / 2, tostring(i), { family = MONO, size = 13.024, color = C.secSub })
			-- icon (24px wide, centred in its column)
			if t then
				Kit.sprite(page, ICON_SPR[t.key], X0 + padX + nW + gap + (icoW - 24) / 2, cy + (bodyH - 24) / 2, 24, 24)
			else
				local sh2 = 24 * 7 / 11
				Kit.sprite(page, "silhouette", X0 + padX + nW + gap + (icoW - 24) / 2, cy + (bodyH - sh2) / 2, 24, sh2, 1, hex("#4a5b72"))
			end
			-- prompt (one line, ellipsis)
			local qSt = { family = MONO, size = qF, spacing = 0.14 * qF, color = C.cq, upper = true }
			local q = (r.q or ""):gsub("%.$", ""):upper()
			if Kit.measure(q, qSt) > bodyW then
				local cut = q
				while #cut > 0 and Kit.measure(cut .. "…", qSt) > bodyW do cut = cut:sub(1, utf8.offset(cut, -1) - 1) end
				q = cut .. "…"
			end
			Kit.text(page, X0 + bodyX, cy, q, qSt)
			Kit.text(page, X0 + bodyX, cy + Kit.lh(qF) + g, ans, aSt, bodyW)
			local subSt = { family = MONO, size = qF, color = C.zone }
			local subSegs
			if t then
				subSegs = { { t.name, style = { family = MONO, size = qF, color = t.color } }, { " · flushed " .. fmt(t.depth) .. "m", style = subSt } }
			else
				subSegs = { { (r.reason == "skip" and "Skipped" or r.reason == "surfaced" and "Pulled out early" or "Time's up") .. " · nothing flushed", style = subSt } }
			end
			Kit.rich(page, X0 + bodyX, cy + Kit.lh(qF) + g + aH + g, bodyW, subSegs, subSt)
			-- points (+ the open/close mark on wide screens)
			local pX = X0 + bodyX + bodyW + gap
			Kit.text(page, pX, cy + (bodyH - Kit.lh(pF)) / 2, tostring(r.score or 0), pSt)
			Rr("c-p-" .. i, pX, cy + (bodyH - Kit.lh(pF)) / 2, pW, Kit.lh(pF))
			if not narrow then
				local open = data.expanded and data.expanded[i]
				local plusSt = { family = MONO, size = U, color = C.secSub }
				Kit.text(page, pX + pW + gap, cy + (bodyH - Kit.lh(U)) / 2, open and "×" or "+", plusSt)
			end
			Rr("catch-" .. i, X0, y, colW, headH)
			hit(X0, y, colW, headH, cb.onToggle and function() cb.onToggle(i) end)
			y += headH
			-- opened round: every accepted answer
			local list = data.expanded and data.expanded[i]
			if list then y = Results.answerList(page, X0, y, colW, U, narrow, r, list, rects) end
			Kit.frame(page, X0, y, colW, 1, C.rule, 0.16)
			y += 1
		end
		Rr("catch", X0, y0, colW, y - y0)
	end

	------------------------------------------------ LOGBOOK
	secH("LOGBOOK", nil, "sec-logbook")
	y += mb; mb = 0
	do
		local lF = narrow and 18.4 or 17.168
		local base = { family = MONO, size = lF, spacing = (narrow and 0.12 or 0.2) * lF, color = C.secH }
		local bold = table.clone(base); bold.color = C.white
		local s = data.stats or { played = 0, avg = 0, best = 0 }
		local lh = Kit.rich(page, X0, y, colW, {
			{ "PLAYED ", style = base }, { tostring(s.played), style = bold }, { " · AVG ", style = base }, { tostring(s.avg), style = bold },
			{ " · BEST ", style = base }, { tostring(s.best), style = bold },
		}, base)
		Rr("logbook", X0, y, colW, lh)
		y += lh
	end

	------------------------------------------------ PLAY AGAIN (the big green FLUSH button style)
	y += 2.2 * U
	do
		local bh = H <= 760 and 50 or Css.clamp(52, Css.vh(8), 78)
		local fbF = Css.cr(1.2, 0.8, 1.4, 2.3)
		local box = Kit.box(page, X0, y, colW, bh, { bg = rgb(14, 24, 16), bgA = 0.94, border = 3, bc = C.lime, inset = { 2, rgb(14, 22, 16), 0.9 }, glow = { 22, C.lime, 0.35 } })
		local label = data.againLabel or "PLAY AGAIN"
		local triF = 0.85 * fbF
		local labStyle = { family = MONO, weight = 600, size = fbF, spacing = 0.3 * fbF, color = hex("#f2f8fc") }
		local triStyle = { family = MONO, weight = 600, size = triF, color = hex("#f2f8fc") }
		local lw = Kit.measure(label, labStyle)
		local trW = Kit.measure("▼", triStyle)
		local gp = 1.1 * fbF
		local x0 = (colW - (trW * 2 + lw + gp * 2)) / 2
		Kit.text(box, x0, bh / 2 - Kit.lh(triF) / 2, "▼", triStyle)
		Kit.text(box, x0 + trW + gp, bh / 2 - Kit.lh(fbF) / 2, label, labStyle)
		Kit.text(box, x0 + trW + gp + lw + gp, bh / 2 - Kit.lh(triF) / 2, "▼", triStyle)
		Rr("btn-again", X0, y, colW, bh)
		hit(X0, y, colW, bh, cb.onAgain)
		y += bh
	end

	------------------------------------------------ bottom tabs
	y += 14
	do
		local tF = xs and 12.48 or 14.4
		local padY, padX = (xs and 0.85 or 0.9) * tF, (xs and 0.3 or 0.6) * tF
		local tSt = { family = MONO, size = tF, spacing = (xs and 0.1 or 0.2) * tF, color = C.muted }
		local tabs = { { "THEMED PACKS", cb.onPacks }, { "STATS", cb.onStats }, { "HOME", cb.onHome } }
		-- flex: 1 1 0 with min-width: auto (a tab never gets narrower than its text)
		local mins, ws, free, frozen = {}, {}, colW - 20, {}
		for i, t in tabs do mins[i] = Kit.measure(t[1], tSt) + 2 * padX + 4 end
		local left = #tabs
		local changed = true
		while changed do
			changed = false
			local share = free / left
			for i = 1, #tabs do
				if not frozen[i] and mins[i] > share then frozen[i] = true; ws[i] = mins[i]; free -= mins[i]; left -= 1; changed = true end
			end
		end
		for i = 1, #tabs do if not frozen[i] then ws[i] = free / left end end
		local th = Kit.lh(tF) + 2 * padY + 4
		local x = X0
		for i, t in tabs do
			local b = Kit.box(page, x, y, ws[i], th, { bg = rgb(14, 22, 16), bgA = 0.7, border = 2, bc = C.rule, bcA = 0.45 })
			local tw = Kit.measure(t[1], tSt)
			Kit.text(b, (ws[i] - tw) / 2, 2 + padY, t[1], tSt)
			Rr("tab-" .. i, x, y, ws[i], th)
			hit(x, y, ws[i], th, t[2])
			x += ws[i] + 10
		end
		y += th
	end
	y += 60
	page.Size = Kit.UDim2.fromOffset(W, math.ceil(y))
	root.CanvasSize = Kit.UDim2.fromOffset(0, math.ceil(y))
	Rr("res-col", X0, 0, colW, y)
	return root, rects, y
end

---------------------------------------------------------------- an opened round (css .log-more / .ab-*)
-- list = { {name, score, mine?}, ... } sorted rarest first. Chips filter by rarity; long lists show the first 100.
function Results.answerList(page, X0, y, colW, U, narrow, r, list, rects)
	local padL = narrow and 0.4 * U or 3.4 * U
	local x = X0 + padL
	local w = colW - padL
	y += 0.2 * U
	if r.tries and #r.tries > 0 then
		local f = 0.8 * U
		local base = { family = MONO, size = f, spacing = 0.08 * f, color = hex("#a7bba3") }
		local miss = table.clone(base); miss.color = hex("#ff8fae")
		local segs = { { "Your misses: ", style = base } }
		for i, t in r.tries do table.insert(segs, { t .. (i < #r.tries and ", " or ""), style = miss }) end
		y += 0.2 * f
		y += Kit.rich(page, x, y, w, segs, base)
		y += 0.5 * f
	end
	-- rarity chips
	local SHORT = { million = "Sigma", deep = "Skibidi", rare = "Rizz", schooler = "Mid", plankton = "NPC" }
	local cF = narrow and 12.48 or 14.4
	local cpY, cpX = (narrow and 0.45 or 0.55) * cF, (narrow and 0.7 or 1) * cF
	local counts = {}
	for _, a in list do counts[a.score] = (counts[a.score] or 0) + 1 end
	local chips = { { "All", #list, rgb(201, 213, 227), true } }
	for _, sc in { 100, 85, 60, 30, 10 } do local t = TIERS[sc]; table.insert(chips, { SHORT[t.key], counts[sc] or 0, t.color }) end
	local cx, cy = x, y + 0.2 * U
	local chH = Kit.lh(cF) + 2 * cpY + 2
	for _, c in chips do
		local st = { family = MONO, size = cF, spacing = 0.02 * cF, color = c[4] and rgb(255, 255, 255) or c[3] }
		local nst = table.clone(st); nst.weight = 500
		local label = c[1] .. " "
		local cw = Kit.measure(label, st) + Kit.measure(fmt(c[2]), nst) + 2 * cpX + 2
		if cx + cw > x + w and cx > x then cx = x; cy += chH + 8 end
		Kit.box(page, cx, cy, cw, chH, { bg = rgb(16, 22, 17), bgA = 0.75, border = c[4] and 2 or 1, bc = c[4] and hex("#e8eef5") or C.rule, bcA = c[4] and 1 or 0.3 })
		Kit.text(page, cx + cpX + 1, cy + cpY + 1, label, st)
		Kit.text(page, cx + cpX + 1 + Kit.measure(label, st), cy + cpY + 1, fmt(c[2]), nst)
		cx += cw + 8
	end
	y = cy + chH + 0.9 * U
	-- the list (first 100)
	local rowF = 1.02 * 16
	for i = 1, math.min(#list, 100) do
		local a = list[i]
		local t = TIERS[a.score] or TIERS[10]
		local nSt = { family = MONO, size = rowF, spacing = 0.03 * rowF, color = hex("#eef3f9"), width = w - 30 - 2 * U - 60 }
		local _, nh = Kit.measure(a.name, nSt)
		local rh = math.max(20, nh) + 2 * 0.85 * U
		if a.mine then
			Kit.frame(page, x, y, w, rh, rgb(157, 255, 122), 0.1)
			Kit.frame(page, x, y, 3, rh, hex("#8dff6e"), 1)
		end
		Kit.sprite(page, ICON_SPR[t.key], x + 0.3 * U + 5, y + (rh - 20) / 2, 20, 20)
		Kit.text(page, x + 0.3 * U + 30 + U, y + (rh - nh) / 2, a.name, nSt, nSt.width)
		local pSt = { family = MONO, size = 0.9 * 16, weight = 600, color = t.color }
		local ps = "+" .. a.score
		Kit.text(page, x + w - 0.3 * U - Kit.measure(ps, pSt), y + (rh - Kit.lh(14.4)) / 2, ps, pSt)
		Kit.frame(page, x, y + rh - 1, w, 1, C.rule, 0.1)
		y += rh
	end
	local fSt = { family = MONO, size = 14.4, spacing = 0.04 * 14.4, color = hex("#8aa384") }
	y += 0.8 * U
	Kit.text(page, x, y, string.format("%s of %s answers", fmt(math.min(#list, 100)), fmt(#list)), fSt)
	y += Kit.lh(14.4) + 1.2 * U
	return y
end

return Results
