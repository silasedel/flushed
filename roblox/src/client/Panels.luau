-- The website's overlays and sheets (index.html #menu, #modal, #screen-packs; css .overlay/.drawer/.modal/.sheet,
-- .stat-grid/.bars, .shop-grid, .packs, .set-row, .tier-table, .pa). Each builder takes the parent ScreenGui layer,
-- the data to show and callbacks, and returns its root (destroy it to close) plus rects for layout checks.
local Kit = require(script and script.Parent and script.Parent:FindFirstChild("Kit") or "./Kit")
local Game = require(script and script.Parent and script.Parent:FindFirstChild("GameScreen") or "./GameScreen")
local Css = Kit.Css
local rgb, hex = Kit.rgb, Kit.hex

local Panels = {}
local MONO = "plex"
local TIERS = Game.TIERS
local fmt = Game.fmt
local C = {
	panel = hex("#121d17"), line = hex("#9dff7a"), lineDim = rgb(157, 255, 122), cyan = hex("#c8ff9e"), cyan2 = hex("#7dff6a"),
	white = hex("#f2f8fc"), muted = hex("#a7bba3"), pink = hex("#ff5c8a"), pink2 = hex("#ff8fae"), gold = hex("#ffd23f"),
	goldText = hex("#ffe27a"), shopMuted = hex("#9fb39a"), rule = rgb(167, 187, 163),
}
Panels.C = C
local function U() return Css.W <= 760 and 14.72 or Css.cr(0.82, 0.55, 0.55, 1.12) end
Panels.U = U
local function round(x) return math.floor(x + 0.5) end

local function hit(parent, x, y, w, h, fn, z)
	local b = Kit.new("TextButton"); b.Text = ""; b.BackgroundTransparency = 1; b.AutoButtonColor = false
	b.Position = Kit.UDim2.fromOffset(round(x), round(y)); b.Size = Kit.UDim2.fromOffset(round(w), round(h)); b.ZIndex = z or 5
	b.Parent = parent
	if fn then b.Activated:Connect(fn) end
	return b
end
Panels.hit = hit

-- a coin / Robux tag: icon 1.05em, gap .25em, bold number (css .coin)
function Panels.coinW(n, size, spacing)
	return 1.05 * size + 0.25 * size + Kit.measure(fmt(n), { family = MONO, weight = 700, size = size, spacing = spacing or 0 })
end
function Panels.coinTag(parent, x, y, n, size, color, spacing, robux, lineH)
	local lh = lineH or Kit.lh(size)
	local ic = 1.05 * size
	Kit.sprite(parent, robux and "robux" or "coin", x, y + (lh - ic) / 2, ic, ic)
	Kit.text(parent, x + ic + 0.25 * size, y + (lh - Kit.lh(size)) / 2, fmt(n), { family = MONO, weight = 700, size = size, spacing = spacing or 0, color = color or C.gold })
	return Panels.coinW(n, size, spacing)
end

---------------------------------------------------------------- overlay (dim backdrop, click outside to close)
local function overlay(parent, onClose)
	local o = Kit.new("Frame")
	o.Name = "Overlay"
	o.BackgroundColor3 = rgb(3, 8, 4); o.BackgroundTransparency = 1 - 0.62; o.BorderSizePixel = 0
	o.Size = Kit.UDim2.fromScale(1, 1); o.ZIndex = 40
	o.Parent = parent
	hit(o, 0, 0, Css.W, Css.H, onClose, 1)
	return o
end

-- the sheet head: title (+ optional icon) and the close X; returns its height (44 + .4em + 2px border)
local function sheetHead(parent, x, y, w, U0, title, icon, onClose)
	local tF = 1.4 * U0
	local tSt = { family = MONO, weight = 600, size = tF, spacing = 0.2 * tF, color = C.cyan }
	local tx = x
	if icon then
		local isz = 1.15 * tF
		Kit.icon(parent, icon, x, y + 22 - isz / 2 + 0.5, round(isz), C.cyan, 1)
		tx += isz + Kit.measure(" ", tSt)
	end
	Kit.text(parent, tx, y + (44 - Kit.lh(tF)) / 2, title, tSt)
	Kit.icon(parent, "close", x + w - 44 + 9, y + 9, 26, C.white, 1)
	hit(parent, x + w - 44, y, 44, 44, onClose, 6)
	local pb = 0.4 * U0
	Kit.frame(parent, x, y + 44 + pb, w, 2, C.lineDim, 0.45)
	return 44 + pb + 2
end
Panels.sheetHead = sheetHead

-- A centred modal (css .modal): width min(100%, 560px) inside 14px padding, max-height 88vh (scrolls inside).
-- body(frame, innerW, U) draws the content at (0, 0) and returns its height.
function Panels.modal(parent, title, body, onClose, rects)
	local W, H = Css.W, Css.H
	local U0 = U()
	local o = overlay(parent, onClose)
	local mw = math.min(W - 28, 560)
	local padT, padX = U0, 1.3 * U0
	local innerW = mw - 4 - 2 * padX
	local box = Kit.new("ScrollingFrame")
	box.Name = "Modal"
	box.BackgroundColor3 = C.panel; box.BorderSizePixel = 0; box.ZIndex = 41
	box.ScrollBarThickness = 6; box.ScrollBarImageColor3 = C.lineDim
	box.ScrollingDirection = Enum and Enum.ScrollingDirection.Y or nil
	box.Parent = o
	local content = Kit.new("Frame"); content.Name = "Content"; content.BackgroundTransparency = 1; content.Parent = box
	local headH = sheetHead(content, 2 + padX, 2 + padT, innerW, U0, title, nil, onClose)
	local by = 2 + padT + headH + 0.6 * U0
	local bodyF = Kit.new("Frame"); bodyF.Name = "Body"; bodyF.BackgroundTransparency = 1
	bodyF.Position = Kit.UDim2.fromOffset(round(2 + padX), round(by)); bodyF.Parent = content
	local bh = body(bodyF, innerW, U0)
	bodyF.Size = Kit.UDim2.fromOffset(round(innerW), round(bh))
	local total = by + bh + 1.3 * U0 + 2
	local mh = math.min(total, 0.88 * H)
	local mx, my = (W - mw) / 2, math.max(14, (H - mh) / 2)
	box.Position = Kit.UDim2.fromOffset(round(mx), round(my)); box.Size = Kit.UDim2.fromOffset(round(mw), round(mh))
	box.CanvasSize = Kit.UDim2.fromOffset(0, round(total))
	content.Size = Kit.UDim2.fromOffset(round(mw), round(total))
	-- 2px border (drawn on the box so it stays put while the content scrolls) and the 0 8px 0 shadow
	local deco = Kit.new("Frame"); deco.BackgroundTransparency = 1; deco.ZIndex = 42
	deco.Position = box.Position; deco.Size = box.Size; deco.Parent = o
	Kit.frame(o, mx, my + mh, mw, 8, rgb(0, 0, 0), 0.45)
	for _, r in { { 0, 0, mw, 2 }, { 0, mh - 2, mw, 2 }, { 0, 0, 2, mh }, { mw - 2, 0, 2, mh } } do Kit.frame(deco, r[1], r[2], r[3], r[4], C.line, 1) end
	if rects then rects.modal = { mx, my, mw, mh }; rects["modal-body"] = { mx + 2 + padX, my + by, innerW, bh } end
	return o, box
end

-- small section heading inside modals (css .mh): .95em, 600, ls .2em, margin 1.2em 0 .4em
local function mh(parent, y, text, U0, first)
	local f = 0.95 * U0
	if not first then y += 1.2 * f end
	Kit.text(parent, 0, y, text, { family = MONO, weight = 600, size = f, spacing = 0.2 * f, color = C.cyan })
	return y + Kit.lh(f) + 0.4 * f
end

-- a .btn (optionally .btn-ghost / .small / .btn-pink); returns width, height
local function btn(parent, x, y, label, U0, opts)
	opts = opts or {}
	local f = (opts.small and 0.85 or 1) * (opts.size or U0)
	local st = { family = MONO, weight = 600, size = f, spacing = 0.14 * f, color = opts.ghost and C.muted or opts.pink and C.pink or C.cyan }
	local tw = Kit.measure(label, st)
	local padX = (opts.small and 1 or 1.6) * f
	local h = math.max((opts.small and 2.2 or 2.9) * f, Kit.lh(f) + 2 * (opts.small and 0.2 or 0.25) * f + 4)
	local w = math.max(tw + 2 * padX + 4, opts.minW or 0)
	if opts.right then x -= w end
	Kit.frame(parent, x, y + 3, w, h, rgb(0, 0, 0), 0.35)
	Kit.box(parent, x, y, w, h, { bg = opts.ghost and rgb(16, 26, 20) or rgb(16, 26, 20), bgA = opts.ghost and 0.6 or 0.88, border = 2,
		bc = opts.pink and C.pink or opts.ghost and C.lineDim or C.line, bcA = opts.ghost and 0.45 or 1, inset = { 2, C.lineDim, 0.08 } })
	Kit.text(parent, x + (w - tw) / 2, y + (h - Kit.lh(f)) / 2, label, st)
	hit(parent, x, y, w, h, opts.onClick)
	return w, h
end
Panels.btn = btn

---------------------------------------------------------------- MENU drawer
-- items: { {label, icon, act, danger?} }, active = act of the current screen, foot = footer text
function Panels.menu(parent, items, active, foot, onAct, onClose)
	local W, H = Css.W, Css.H
	local U0 = U()
	local rects = {}
	local o = overlay(parent, onClose)
	local dw = math.min(0.86 * W, 330)
	local d = Kit.new("Frame"); d.Name = "Drawer"; d.BackgroundColor3 = C.panel; d.BorderSizePixel = 0; d.ZIndex = 41
	d.Size = Kit.UDim2.fromOffset(round(dw), H); d.Parent = o
	Kit.frame(d, dw - 2, 0, 2, H, C.line, 1)
	local padY, padX = U0, 1.1 * U0
	local iw = dw - 2 - 2 * padX
	local y = padY
	y += sheetHead(d, padX, y, iw, U0, "MENU", nil, onClose)
	y += 0.6 * U0
	local f = 0.85 * U0
	local st = { family = MONO, size = f, spacing = 0.14 * f }
	for _, it in items do
		y += 2
		if it.danger then y += 0.6 * f end
		local h = 2 * 0.65 * f + Kit.lh(f) + 4
		local on = it.act == active
		local bc = it.danger and rgb(255, 120, 120) or C.lineDim
		if on or it.danger then Kit.box(d, padX, y, iw, h, { border = 2, bc = bc, bcA = it.danger and 0.3 or 0.45 }) end
		local col = on and C.cyan or C.white
		local isz = 1.15 * f
		local tx = padX + 2 + 0.6 * f
		Kit.icon(d, it.icon, tx, y + (h - isz) / 2, round(isz), col, 1)
		local s2 = table.clone(st); s2.color = col
		Kit.text(d, tx + isz + 0.8 * f, y + (h - Kit.lh(f)) / 2, it.label, s2)
		rects["menu-" .. it.act] = { padX, y, iw, h }
		hit(d, padX, y, iw, h, function() onAct(it.act) end)
		y += h
	end
	if foot and foot ~= "" then
		local ff = 0.75 * U0
		local fs = { family = MONO, size = ff, spacing = 0.08 * ff, color = C.muted, width = iw }
		local _, fh = Kit.measure(foot, fs)
		Kit.text(d, padX, H - padY - fh, foot, fs, iw)
		rects["menu-foot"] = { padX, H - padY - fh - ff, iw, fh + ff }
	end
	rects.drawer = { 0, 0, dw, H }
	return o, rects
end

---------------------------------------------------------------- STATISTICS
-- s = { games, best, avg, avgPer, deepest, answeredPct, bins = {10 counts}, tiers = {[score] = count} }
function Panels.stats(parent, s, cb)
	local rects = {}
	local o = Panels.modal(parent, "STATISTICS", function(b, w, U0)
		local cells = { { tostring(s.games or 0), "FLUSHES" }, { tostring(s.best or 0), "PERSONAL BEST" }, { tostring(s.avg or 0), "AVG SCORE" },
			{ tostring(s.avgPer or 0), "AVG PER PROMPT" }, { fmt(s.deepest or 0) .. "m", "DEEPEST" }, { (s.answeredPct or 0) .. "%", "ANSWERED" } }
		local cw = (w - 12) / 3
		local bF, sF = 1.5 * U0, 0.65 * U0
		local strutA, strutD = round(1.025 * U0), round(0.275 * U0)
		local ch = 2 * 0.4 * U0 + 2 + Kit.lh(bF) + strutA + strutD
		for i, c in cells do
			local cx, cy = ((i - 1) % 3) * (cw + 6), ((i - 1) // 3) * (ch + 6)
			Kit.box(b, cx, cy, cw, ch, { bg = rgb(16, 26, 20), bgA = 0.7, border = 1, bc = C.lineDim, bcA = 0.45 })
			local bs = { family = MONO, weight = 600, size = bF, color = C.white }
			Kit.text(b, cx + (cw - Kit.measure(c[1], bs)) / 2, cy + 1 + 0.4 * U0, c[1], bs)
			local ss = { family = MONO, size = sF, spacing = 0.14 * sF, color = C.muted }
			local sy = cy + 1 + 0.4 * U0 + Kit.lh(bF) + strutA - round(1.025 * sF)
			Kit.text(b, cx + (cw - Kit.measure(c[2], ss)) / 2, sy, c[2], ss)
		end
		local y = 2 * ch + 6
		local f = 0.85 * U0
		local function bars(rows)
			local c1, c3, gap = 8.5 * f, 2.5 * f, 0.5 * f
			local c2 = w - c1 - c3 - 2 * gap
			local mx = 1
			for _, r in rows do mx = math.max(mx, r[2]) end
			for _, r in rows do
				Kit.text(b, 0, y, r[1], { family = MONO, size = f, color = r[3] or C.muted })
				Kit.frame(b, c1 + gap, y + (Kit.lh(f) - 12) / 2, math.max(2, c2 * r[2] / mx), 12, r[3] or C.cyan2, 1)
				local es = { family = MONO, size = f, color = C.white }
				local t = tostring(r[2])
				Kit.text(b, w - Kit.measure(t, es), y, t, es)
				y += Kit.lh(f) + 4
			end
			y -= 4
		end
		y = mh(b, y, "POINTS PER PROMPT", U0)
		local rows = {}
		for i = 0, 9 do table.insert(rows, { i == 9 and "90+" or (i * 10 .. "–" .. (i * 10 + 9)), (s.bins or {})[i + 1] or 0 }) end
		bars(rows)
		y = mh(b, y + 0.4 * 0.95 * U0 - 0.4 * 0.95 * U0, "RARITIES FOUND", U0)
		rows = {}
		for _, sc in { 100, 85, 60, 30, 10 } do table.insert(rows, { TIERS[sc].name, (s.tiers or {})[sc] or 0, TIERS[sc].color }) end
		bars(rows)
		y += f
		local fs = { family = MONO, size = f, spacing = 0.03 * f, color = C.muted, width = w, lineHeight = 1.45 * f }
		local note = "Games where you used a cheat code still count as played, but not toward your best or average."
		local _, nh = Kit.measure(note, fs)
		Kit.text(b, 0, y, note, fs, w)
		y += nh + f
		local _, bh2 = btn(b, 0, y, "RESET STATISTICS", U0, { ghost = true, small = true, onClick = cb.onReset })
		return y + bh2
	end, cb.onClose, rects)
	return o, rects
end

---------------------------------------------------------------- SHOP
-- items: { {id, type, name, price, robux = true (costs real Robux) | false (earned coins), owned, equipped, note,
--          preview = sprite name, solid/tint, trail = kind} }; coins = balance of earned coins
local TRAIL_SW = {
	rainbow = { "bar", { "#ff3f6a", "#ff9a2a", "#ffe14a", "#7dff6a", "#4ad0ff", "#c58bff" }, 0.4, 0.6, 0.4, 0.6 },
	fire = { "bar", { "#fff3b0", "#ffb020", "#ff4d2a" }, 0.3, 0.7, 0.45, 0.55 },
	aura = { "bar", { "#1a0b2e", "#8a5cff", "#1a0b2e" }, 0.2, 0.8, 0.45, 0.55 },
	sparkle = { "dots", { { 0.2, 0.5, 2.5, "#ffffff" }, { 0.5, 0.3, 2.5, "#ffe14a" }, { 0.8, 0.6, 2.5, "#ffffff" } } },
	bubble = { "dots", { { 0.25, 0.5, 3.5, "#cfefff" }, { 0.6, 0.35, 2.5, "#cfefff" }, { 0.8, 0.6, 2.5, "#cfefff" } } },
	confetti = { "dots", { { 0.2, 0.4, 2.5, "#ff3fb4" }, { 0.45, 0.6, 2.5, "#7dff6a" }, { 0.7, 0.35, 2.5, "#4ad0ff" }, { 0.85, 0.65, 2.5, "#ffe14a" } } },
	money = { "dots", { { 0.25, 0.5, 5.5, "#111111" }, { 0.25, 0.5, 4.5, "#ffffff" }, { 0.65, 0.45, 5.5, "#111111" }, { 0.65, 0.45, 4.5, "#ffffff" } } },
}
local function trailSwatch(parent, kind, x, y)
	local sw = TRAIL_SW[kind]
	if not sw then return end
	if sw[1] == "bar" then
		-- gradient band (clip-path polygon from y0..y1 at the left to y2..y3 at the right), drawn in 2px columns
		local cols = sw[2]
		for i = 0, 31 do
			local t = (i + 0.5) / 32
			local seg = t * (#cols - 1)
			local k = math.min(#cols - 1, math.floor(seg))
			local c = hex(cols[k + 1]):Lerp(hex(cols[k + 2]), seg - k)
			local top = (sw[3] + (sw[5] - sw[3]) * t) * 40
			local bot = (sw[4] + (sw[6] - sw[4]) * t) * 40
			Kit.frame(parent, x + i * 2, y + top, 2, bot - top, c, 1)
		end
	else
		for _, d in sw[2] do
			local r = d[3]
			for yy = -math.floor(r), math.floor(r) do
				local half = math.sqrt(math.max(0, r * r - yy * yy))
				Kit.frame(parent, x + d[1] * 64 - half, y + d[2] * 40 + yy, 2 * half, 1, hex(d[4]), 1)
			end
		end
	end
end
function Panels.shop(parent, data, cb)
	local rects = {}
	local o, box = Panels.modal(parent, "SHOP", function(b, w, U0)
		local y = 0
		local bal = { family = MONO, size = U0, spacing = 0.1 * U0, color = C.white }
		local lh = 1.621 * U0 -- the inline-flex coin makes this line taller than plain text (Chrome: 27.1px at 16.72px)
		Kit.text(b, 0, y + (lh - Kit.lh(U0)) / 2, "Coins", bal)
		Panels.coinTag(b, Kit.measure("Coins ", bal), y + (lh - Kit.lh(U0)) / 2, data.coins or 0, U0, C.gold, 0.1 * U0, false)
		y += lh
		local groups = { { "duck", "DUCKS" }, { "toilet", "TOILETS" }, { "trail", "TRAILS" }, { "boost", "BOOSTS" } }
		for gi, g in groups do
			y = mh(b, y, g[2], U0)
			local list = {}
			for _, it in data.items do if it.type == g[1] then table.insert(list, it) end end
			table.sort(list, function(a, c) return a.price < c.price end)
			local ncol = math.max(1, math.floor((w + 10) / 160))
			local cw = (w - 10 * (ncol - 1)) / ncol
			local rowY, rowH = y, 0
			local laid = {}
			-- measure each card's natural height
			for i, it in list do
				local nameSt = { family = MONO, weight = 700, size = 14.4, spacing = 0.08 * 14.4, color = C.cyan, width = cw - 24, align = "center" }
				local _, nh = Kit.measure(it.name, nameSt)
				local prevH = it.type == "trail" and 40 or it.type == "boost" and 40 or 64 * (it.ph or 13) / (it.pw or 16)
				local noteH = 0
				if it.note then local _, h2 = Kit.measure(it.note, { family = MONO, size = 11.52, width = cw - 24 }); noteH = h2 + 6 end
				local btnH = Kit.lh(U0) + 2 * 0.35 * U0 + 4
				local h = 10 + 2 + 13 + 6 + prevH + 6 + nh + noteH + 6 + btnH + (it.type == "boost" and 6 + Kit.lh(11.52) or 0) + 10 + 2
				laid[i] = { it = it, h = h, nh = nh, prevH = prevH, nameSt = nameSt, btnH = btnH, noteH = noteH }
			end
			for i, L in laid do
				local col = (i - 1) % ncol
				if col == 0 and i > 1 then rowY += rowH + 10; rowH = 0 end
				-- a row is as tall as its tallest card
				local rh = 0
				local rs = (i - 1) - col
				for j = rs + 1, math.min(#laid, rs + ncol) do rh = math.max(rh, laid[j].h) end
				rowH = rh
				local it = L.it
				local x = col * (cw + 10)
				local tier = it.price >= 100000 and "mythic" or it.price >= 10000 and "legend" or it.price >= 100 and "rare" or "common"
				if it.type == "boost" then tier = "boost" end
				local st = { bg = rgb(14, 22, 16), bgA = 0.7, border = 2, bc = C.rule, bcA = 0.35 }
				if tier == "legend" then st.bc, st.bcA, st.glow = C.gold, 1, { 14, C.gold, 0.25 }
				elseif tier == "mythic" then st.bc, st.bcA, st.glow, st.bg, st.bgA = hex("#c58bff"), 1, { 18, hex("#c58bff"), 0.35 }, rgb(40, 21, 56), 0.85 end
				Kit.box(b, x, rowY, cw, rh, st)
				local cy = rowY + 12
				local rl = tier == "boost" and "BOOST" or tier == "mythic" and "MYTHIC" or tier == "legend" and "LEGENDARY" or tier == "rare" and "RARE" or "COMMON"
				local rc = tier == "rare" and hex("#6fc8ff") or tier == "legend" and C.gold or tier == "mythic" and hex("#ffe14a") or C.shopMuted
				local rs2 = { family = MONO, weight = 700, size = 9.92, spacing = 0.2 * 9.92, color = rc }
				Kit.text(b, x + (cw - Kit.measure(rl, rs2)) / 2, cy, rl, rs2)
				cy += 13 + 6
				if it.type == "trail" then trailSwatch(b, it.trail, x + (cw - 64) / 2, cy)
				elseif it.type == "boost" then
					local bs = { family = MONO, weight = 700, size = 22.4, color = C.cyan2 }
					Kit.text(b, x + (cw - Kit.measure("+5s", bs)) / 2, cy + (40 - Kit.lh(22.4)) / 2, "+5s", bs)
				else
					Kit.sprite(b, it.preview or "duck0", x + (cw - 64) / 2, cy, 64, L.prevH, 1, it.tint)
				end
				cy += L.prevH + 6
				Kit.text(b, x + 12, cy, it.name, L.nameSt, cw - 24)
				cy += L.nh + 6
				if it.note then
					Kit.text(b, x + 12, cy - 6 + 6, it.note, { family = MONO, size = 11.52, color = C.shopMuted, width = cw - 24, align = "center" }, cw - 24)
					cy += L.noteH
				end
				-- the button: BUY <price> / EQUIP / EQUIPPED
				local f = U0
				local bst = { family = MONO, weight = 700, size = f, spacing = 0.12 * f, color = C.goldText }
				local label = it.owned and (it.equipped and "EQUIPPED" or "EQUIP") or "BUY"
				local bw = Kit.measure(label, bst) + 2 * 0.8 * f + 4
				if not it.owned then bw += 0.4 * f + Panels.coinW(it.price, f, 0.12 * f) end
				local bx = x + (cw - bw) / 2
				local on = it.owned and it.equipped
				local poor = not it.owned and not it.robux and (data.coins or 0) < it.price
				Kit.box(b, bx, cy, bw, L.btnH, { bg = on and C.cyan2 or rgb(40, 30, 6), bgA = on and 1 or 0.85, border = 2, bc = on and C.cyan2 or C.gold })
				local s3 = table.clone(bst); s3.color = on and hex("#0b140e") or C.goldText
				Kit.text(b, bx + 2 + 0.8 * f, cy + 2 + 0.35 * f, label, s3)
				if not it.owned then
					Panels.coinTag(b, bx + 2 + 0.8 * f + Kit.measure(label, bst) + 0.4 * f, cy + 2 + 0.35 * f, it.price, f, C.gold, 0.12 * f, it.robux)
				end
				if poor then Kit.frame(b, bx, cy, bw, L.btnH, rgb(18, 29, 23), 0.55) end
				hit(b, bx, cy, bw, L.btnH, function()
					if it.owned then if cb.onEquip then cb.onEquip(it.id) end elseif cb.onBuy then cb.onBuy(it.id) end
				end)
				rects["shop-" .. it.id] = { x, rowY, cw, rh }
				if it.type == "boost" then
					cy += L.btnH + 6
					local hs = { family = MONO, size = 11.52, color = C.shopMuted }
					local ht = "have " .. tostring(data.boosts or 0)
					Kit.text(b, x + (cw - Kit.measure(ht, hs)) / 2, cy, ht, hs)
				end
			end
			y = rowY + rowH + U0
		end
		local fs = { family = MONO, size = 0.85 * U0, color = C.muted, width = w, lineHeight = 1.45 * 0.85 * U0 }
		local note = "Looks are cosmetic and bought with Robux. Boosts use coins you earn by playing."
		local _, nh = Kit.measure(note, fs)
		Kit.text(b, 0, y, note, fs, w)
		y += nh
		if data.anyOwned then
			y += 0.5 * U0
			local ls = { family = MONO, size = U0, spacing = 0.12 * U0, color = C.white }
			Kit.text(b, 0.3 * U0, y + 0.5 * U0, "Use the default look", ls)
			hit(b, 0, y, Kit.measure("Use the default look", ls) + 0.6 * U0, Kit.lh(U0) + U0, cb.onDefault)
			y += Kit.lh(U0) + U0
		end
		return y
	end, cb.onClose, rects)
	return o, rects, box
end

---------------------------------------------------------------- THEMED PACKS (a full screen sheet, not a modal)
-- packs: { {key, name, blurb, count} }
function Panels.packs(parent, packs, cb)
	local W, H = Css.W, Css.H
	local U0 = U()
	local rects = {}
	local root = Kit.new("ScrollingFrame"); root.Name = "Packs"; root.BackgroundTransparency = 1; root.BorderSizePixel = 0
	root.Size = Kit.UDim2.fromScale(1, 1); root.ScrollBarThickness = 0; root.ZIndex = 30
	root.ScrollingDirection = Enum and Enum.ScrollingDirection.Y or nil
	root.Parent = parent
	local sw = math.min(W - 28, 760)
	local padT, padX = U0, 1.4 * U0
	local iw = sw - 4 - 2 * padX
	-- measure the grid first (cards grow to their row's height; extra height is shared by the 4 lines)
	local ncol = math.max(1, math.floor((iw + 10) / 220))
	local cw = (iw - 10 * (ncol - 1)) / ncol
	local cpY, cpX = 0.7 * U0, 0.9 * U0
	local tw = cw - 4 - 2 * cpX
	local nF, nmF, bF, mF = 0.8 * U0, 1.2 * U0, 0.85 * U0, 0.75 * U0
	local cards = {}
	for i, p in packs do
		local nmSt = { family = MONO, weight = 600, size = nmF, spacing = 0.12 * nmF, color = C.white, width = tw }
		local bSt = { family = MONO, size = bF, color = C.muted, width = tw, lineHeight = 1.3 * bF }
		local _, nh = Kit.measure(p.name:upper(), nmSt)
		local _, bh = Kit.measure(p.blurb, bSt)
		local parts = { Kit.lh(nF), nh, bh, 0.2 * mF + Kit.lh(mF) }
		local h = 0
		for _, v in parts do h += v end
		h += 3 * 0.25 * U0 + 2 * cpY + 4
		cards[i] = { p = p, parts = parts, h = h, nmSt = nmSt, bSt = bSt }
	end
	local rowsH = {}
	for i, c in cards do local r = (i - 1) // ncol + 1; rowsH[r] = math.max(rowsH[r] or 0, c.h) end
	local gridH = 0
	for r, h in rowsH do gridH += h + (r > 1 and 10 or 0) end
	local subF = 0.95 * U0
	local headH = 44 + 0.4 * U0 + 2
	local sh = 2 + padT + headH + 0.6 * U0 + Kit.lh(subF) + subF + gridH + 1.4 * U0 + 2
	local sx = (W - sw) / 2
	local sy = 70 + math.max(0, (H - 70 - 20 - sh) / 2)
	local page = Kit.new("Frame"); page.BackgroundTransparency = 1; page.Parent = root
	page.Size = Kit.UDim2.fromOffset(W, round(math.max(H, sy + sh + 20)))
	root.CanvasSize = Kit.UDim2.fromOffset(0, round(math.max(H, sy + sh + 20)))
	Kit.frame(page, sx, sy + sh, sw, 6, rgb(0, 0, 0), 0.4)
	Kit.box(page, sx, sy, sw, sh, { bg = rgb(12, 20, 14), bgA = 0.93, border = 2, bc = C.line })
	rects.sheet = { sx, sy, sw, sh }
	local x0, y = sx + 2 + padX, sy + 2 + padT
	y += sheetHead(page, x0, y, iw, U0, "THEMED PACKS", "cube", cb.onClose)
	y += 0.6 * U0
	Kit.text(page, x0, y, "Seven prompts from a single sea. Unlimited replays.", { family = MONO, size = subF, spacing = 0.06 * subF, color = C.muted })
	y += Kit.lh(subF) + subF
	rects.packs = { x0, y, iw, gridH }
	local ry = y
	for i, c in cards do
		local col, r = (i - 1) % ncol, (i - 1) // ncol + 1
		if col == 0 and i > 1 then ry += rowsH[r - 1] + 10 end
		local x = x0 + col * (cw + 10)
		local ch = rowsH[r]
		local sel = cb.focus == i
		Kit.box(page, x, ry, cw, ch, { bg = sel and rgb(30, 60, 28) or rgb(16, 26, 20), bgA = sel and 0.85 or 0.8, border = 2, bc = sel and C.line or C.lineDim, bcA = sel and 1 or 0.45 })
		local extra = (ch - c.h) / 4
		local yy = ry + 2 + cpY
		local tx = x + 2 + cpX
		local function line(k) local h = c.parts[k] + extra; local top = yy; yy += h + 0.25 * U0; return top, h end
		local t1, h1 = line(1)
		Kit.text(page, tx, t1 + (h1 - Kit.lh(nF)) / 2, string.format("%02d", i), { family = MONO, size = nF, spacing = 0.2 * nF, color = C.pink })
		local t2, h2 = line(2)
		Kit.text(page, tx, t2 + (h2 - c.parts[2]) / 2, c.p.name:upper(), c.nmSt, tw)
		local t3, h3 = line(3)
		Kit.text(page, tx, t3 + (h3 - c.parts[3]) / 2, c.p.blurb, c.bSt, tw)
		local t4, h4 = line(4)
		local ms = { family = MONO, size = mF, spacing = 0.14 * mF, color = C.cyan }
		Kit.text(page, tx, t4 + 0.2 * mF + (h4 - c.parts[4]) / 2, fmt(c.p.count or 0) .. " PROMPTS", ms)
		rects["pack-" .. i] = { x, ry, cw, ch }
		hit(page, x, ry, cw, ch, function() if cb.onPick then cb.onPick(c.p.key) end end)
	end
	return root, rects
end

---------------------------------------------------------------- HOW TO PLAY
function Panels.help(parent, cb)
	return Panels.modal(parent, "HOW TO PLAY", function(b, w, U0)
		local y = 0
		local p = { family = MONO, size = U0, spacing = 0.03 * U0, color = C.white }
		local hb = table.clone(p); hb.color = C.cyan
		local function para(segs, indent)
			local h = Kit.rich(b, indent or 0, y, w - (indent or 0), segs, p)
			return h
		end
		y += U0
		y += para({ { "Every prompt has dozens of right answers. Everyone can name the obvious ones — the goal is to name the ", style = p }, { "rarest", style = hb }, { " answer you can.", style = p } })
		y += U0
		local li = {
			{ { "Pick ", style = p }, { "5, 7 or 10 prompts", style = hb }, { ", or ", style = p }, { "endless", style = hb }, { ". You have ", style = p }, { "25 seconds", style = hb }, { " each.", style = p } },
			{ { "Wrong answers cost nothing — keep guessing until the timer runs out. Whatever is in the box when time expires is submitted.", style = p } },
			{ { "Rarer answers score more and flush your duck deeper. A perfect flush reaches ", style = p }, { "7,000m", style = hb }, { ".", style = p } },
		}
		for _, segs in li do
			Kit.text(b, 1.2 * U0 - 0.9 * U0, y + 0.25 * U0, "•", p)
			local _, lines = Kit.richLayout(segs, w - 1.2 * U0 - 40, p)
			local h = 0
			for _, l in lines do h += math.max(l.h, 1.5 * U0) end
			Kit.rich(b, 1.2 * U0, y + 0.25 * U0, w - 1.2 * U0 - 40, segs, p)
			y += h
		end
		y += U0 + 0.6 * U0
		local tf = 0.925 * U0
		for _, sc in { 100, 85, 60, 30, 10 } do
			local t = TIERS[sc]
			local rh = Kit.lh(tf) + 0.24 * tf
			Kit.text(b, 0.4 * tf, y + 0.12 * tf, t.name, { family = MONO, size = tf, color = t.color })
			local a, d = "+" .. sc, fmt(t.depth) .. "m"
			local ws = { family = MONO, size = tf, color = C.white }
			Kit.text(b, w * 0.66 - 0.4 * tf - Kit.measure(a, ws), y + 0.12 * tf, a, ws)
			Kit.text(b, w - 0.4 * tf - Kit.measure(d, ws), y + 0.12 * tf, d, ws)
			Kit.frame(b, 0, y + rh, w, 1, C.lineDim, 0.15)
			y += rh + 1
		end
		y += 0.6 * U0
		local f = 0.85 * U0
		local fs = { family = MONO, size = f, color = C.muted, spacing = 0.03 * f }
		local fb = table.clone(fs); fb.color = C.cyan
		y += f
		y += Kit.rich(b, 0, y, w, { { "Rarity tiers are our curated estimate of how likely a typical person is to think of each answer — not live player data.", style = fs } }, fs)
		y += f
		y += Kit.rich(b, 0, y, w, { { "Endless", style = fb }, { " never stops: hit ", style = fs }, { "END RUN", style = fb }, { " on any reveal to cash out. ", style = fs }, { "Themed Packs", style = fb }, { " keep every prompt on one topic.", style = fs } }, fs)
		y += f + U0
		local bw = math.max(11 * 1.25 * U0, Kit.measure("GOT IT", { family = MONO, weight = 600, size = 1.25 * U0, spacing = 0.14 * 1.25 * U0 }) + 2 * 1.6 * 1.25 * U0 + 4)
		local _, bh = btn(b, (w - bw) / 2, y, "GOT IT", U0, { size = 1.25 * U0, minW = bw, onClick = cb.onClose })
		return y + bh
	end, cb.onClose)
end

---------------------------------------------------------------- SETTINGS
-- s = { sound, ambience, reduced, showMeta, prompts, answers }; cb.onToggle(key, value)
function Panels.settings(parent, s, cb)
	return Panels.modal(parent, "SETTINGS", function(b, w, U0)
		local y = 0
		local rows = { { "sound", "Sound effects" }, { "ambience", "Ambient sewer hum" }, { "reduced", "Reduced motion" }, { "showMeta", "Show category & difficulty" } }
		for _, r in rows do
			local h = 2 * 0.6 * U0 + math.max(Kit.lh(U0), 22)
			Kit.text(b, 0, y + (h - Kit.lh(U0)) / 2, r[2], { family = MONO, size = U0, spacing = 0.06 * U0, color = C.white })
			local on = s[r[1]]
			local tx, ty = w - 44, y + (h - 22) / 2
			Kit.box(b, tx, ty, 44, 22, { bg = rgb(16, 26, 20), bgA = 0.9, border = 2, bc = on and C.line or C.lineDim, bcA = on and 1 or 0.45 })
			Kit.frame(b, tx + (on and 24 or 2) + 2, ty + 4, 14, 14, on and C.cyan2 or C.muted, 1)
			Kit.frame(b, 0, y + h - 1, w, 1, C.lineDim, 0.15)
			hit(b, 0, y, w, h, function() if cb.onToggle then cb.onToggle(r[1], not on) end end)
			y += h
		end
		y = mh(b, y, "KEYBOARD", U0)
		local ks = { family = MONO, size = U0, color = C.muted }
		for _, l in { "Enter  flush · submit · keep flushing", "M  menu · Esc  close" } do
			Kit.text(b, 0, y + 0.4 * U0, l, ks)
			y += 1.8 * U0
		end
		y += U0
		local f = 0.85 * U0
		local fs = { family = MONO, size = f, color = C.muted }
		local fb = table.clone(fs); fb.color = C.cyan
		y += Kit.rich(b, 0, y, w, { { "Question database: ", style = fs }, { fmt(s.prompts or 0), style = fb }, { " prompts · ", style = fs }, { fmt(s.answers or 0), style = fb }, { " accepted answers", style = fs } }, fs)
		return y + f
	end, cb.onClose)
end

---------------------------------------------------------------- ARE YOU SURE?
function Panels.confirm(parent, msg, onOk, onClose)
	return Panels.modal(parent, "ARE YOU SURE?", function(b, w, U0)
		local ps = { family = MONO, size = U0, spacing = 0.03 * U0, color = C.white, width = w, lineHeight = 1.45 * U0 }
		local _, h = Kit.measure(msg, ps)
		Kit.text(b, 0, U0, msg, ps, w)
		local y = U0 + h + U0 + U0
		local w1, bh = btn(b, w, y, "CONFIRM", U0, { pink = true, right = true, onClick = onOk })
		btn(b, w - w1 - 12, y, "CANCEL", U0, { ghost = true, right = true, onClick = onClose })
		return y + bh
	end, onClose)
end

---------------------------------------------------------------- PLAY AGAIN (length pick + FLUSH + RANKED)
-- st = { len, price, boost = {x, why}, coins }; cb.onLen(n), cb.onFlush, cb.onRanked
function Panels.playAgain(parent, st, cb)
	return Panels.modal(parent, "PLAY AGAIN", function(b, w, U0)
		local y = 0
		-- len-pick: label + 5 / 7 / 10 / ∞
		local lf = 12.48
		local lst = { family = MONO, size = lf, spacing = 0.2 * lf, color = C.shopMuted }
		local labW = Kit.measure("PROMPTS", lst) + 2 * 0.9 * lf + 2
		local bf = 15.2
		local opts = { 5, 7, 10, 0 }
		local bws = {}
		local total = labW
		for i, n in opts do
			local f = n == 0 and 18.4 or bf
			local s = { family = MONO, weight = 600, size = f, spacing = 0.05 * f }
			bws[i] = math.max(2.6 * f, Kit.measure(n == 0 and "∞" or tostring(n), s) + 2 * 0.5 * f) + (i < #opts and 2 or 0)
			total += bws[i]
		end
		local bh = 2 * 0.6 * bf + Kit.lh(bf)
		local lx = (w - total - 4) / 2
		Kit.box(b, lx, y, total + 4, bh + 4, { bg = rgb(14, 22, 16), bgA = 0.75, border = 2, bc = C.rule, bcA = 0.45 })
		Kit.text(b, lx + 2 + 0.9 * lf, y + 2 + (bh - Kit.lh(lf)) / 2, "PROMPTS", lst)
		Kit.frame(b, lx + labW, y + 2, 2, bh, C.rule, 0.3)
		local bx = lx + 2 + labW
		for i, n in opts do
			local f = n == 0 and 18.4 or bf
			local on = st.len == n
			if on then Kit.frame(b, bx, y + 2, bws[i] - (i < #opts and 2 or 0), bh, C.cyan2, 1) end
			local s = { family = MONO, weight = 600, size = f, spacing = 0.05 * f, color = on and hex("#0b140e") or hex("#c9d5c4") }
			local t = n == 0 and "∞" or tostring(n)
			local bw0 = bws[i] - (i < #opts and 2 or 0)
			Kit.text(b, bx + (bw0 - Kit.measure(t, s)) / 2, y + 2 + (bh - Kit.lh(f)) / 2, t, s)
			if i < #opts then Kit.frame(b, bx + bw0, y + 2, 2, bh, C.rule, 0.2) end
			hit(b, bx, y + 2, bw0, bh, function() if cb.onLen then cb.onLen(n) end end)
			bx += bws[i]
		end
		y += bh + 4 + 12
		-- FLUSH
		local fbF = Css.cr(1.2, 0.8, 1.4, 2.3)
		local fh = 64
		local box = Kit.box(b, 0, y, w, fh, { bg = rgb(14, 24, 16), bgA = 0.94, border = 3, bc = C.cyan2, inset = { 2, rgb(14, 22, 16), 0.9 }, glow = { 22, C.cyan2, 0.35 } })
		local triF = 0.85 * fbF
		local labStyle = { family = MONO, weight = 600, size = fbF, spacing = 0.3 * fbF, color = C.white }
		local triStyle = { family = MONO, weight = 600, size = triF, color = C.white }
		local l1, trW, gp = Kit.measure("FLUSH", labStyle), Kit.measure("▼", triStyle), 1.1 * fbF
		local x0 = (w - (trW * 2 + l1 + gp * 2)) / 2
		Kit.text(box, x0, fh / 2 - Kit.lh(triF) / 2, "▼", triStyle)
		Kit.text(box, x0 + trW + gp, fh / 2 - Kit.lh(fbF) / 2, "FLUSH", labStyle)
		Kit.text(box, x0 + trW + gp + l1 + gp, fh / 2 - Kit.lh(triF) / 2, "▼", triStyle)
		hit(b, 0, y, w, fh, cb.onFlush)
		y += fh + 12
		-- RANKED · n PROMPTS · <coin> price [boost]
		local rf = Css.cr(0.85, 0.7, 0.4, 1.05)
		local rs = { family = MONO, weight = 700, size = rf, spacing = 0.18 * rf, color = C.goldText }
		local L = st.len == 0 and 10 or st.len
		local txt = string.format("RANKED · %d PROMPTS ·", L)
		local tw = Kit.measure(txt, rs) + 0.5 * rf + Panels.coinW(st.price or 0, rf, 0.18 * rf)
		local boostOn = st.boost and st.boost.x and st.boost.x > 1
		local bst = { family = MONO, weight = 700, size = 0.7 * rf, spacing = 0.08 * 0.7 * rf, color = hex("#0b140e") }
		local btxt = boostOn and string.format("%s ×%s", st.boost.why, tostring(st.boost.x)) or ""
		local bw = boostOn and Kit.measure(btxt, bst) + 0.9 * rf or 0
		local rh = Kit.lh(rf) + 2 * 0.55 * rf + 4
		Kit.box(b, 0, y, w, rh, { bg = rgb(40, 30, 6), bgA = 0.85, border = 2, bc = C.gold })
		local rx = (w - tw - (boostOn and bw + 0.6 * rf or 0)) / 2
		Kit.text(b, rx, y + (rh - Kit.lh(rf)) / 2, txt, rs)
		Panels.coinTag(b, rx + Kit.measure(txt, rs) + 0.5 * rf, y + (rh - Kit.lh(rf)) / 2, st.price or 0, rf, C.gold, 0.18 * rf, false)
		if boostOn then
			local bx2 = rx + tw + 0.6 * rf
			local bh2 = Kit.lh(0.7 * rf) + 0.3 * rf
			Kit.frame(b, bx2, y + (rh - bh2) / 2, bw, bh2, C.cyan2, 1)
			Kit.text(b, bx2 + 0.45 * rf, y + (rh - Kit.lh(0.7 * rf)) / 2, btxt, bst)
		end
		if (st.coins or 0) < (st.price or 0) then Kit.frame(b, 0, y, w, rh, rgb(18, 29, 23), 0.45) end
		hit(b, 0, y, w, rh, cb.onRanked)
		return y + rh
	end, cb.onClose)
end

---------------------------------------------------------------- toast (bottom centre, css .toast)
function Panels.toast(parent, msg)
	local U0 = U()
	local st = { family = MONO, size = U0, spacing = 0.08 * U0, color = C.white }
	local tw = Kit.measure(msg, st)
	local w, h = tw + 2 * 1.1 * U0 + 4, Kit.lh(U0) + U0 + 4
	local holder = Kit.box(parent, (Css.W - w) / 2, Css.H - 24 - h, w, h, { bg = C.panel, border = 2, bc = C.line })
	holder.ZIndex = 60
	holder.Name = "Toast"
	Kit.text(holder, 2 + 1.1 * U0, 2 + 0.5 * U0, msg, st)
	return holder
end

return Panels
