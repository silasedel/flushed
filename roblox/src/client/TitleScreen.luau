-- The title screen, rebuilt from the website's CSS cascade (css/style.css) as maths on the viewport size.
-- Every number below comes from a rule in the stylesheet; checked against Chrome's computed layout at
-- 1440x900, 1280x720, 1024x768 and 390x844 (tools/roblox-ui-check.js).
local Kit = require(script and script.Parent and script.Parent:FindFirstChild("Kit") or "./Kit")
local Css = Kit.Css
local rgb = Kit.rgb

local Title = {}

local MONO = "plex"
local C = {
	white = rgb(242, 248, 252), muted = rgb(159, 179, 154), gold = Kit.hex("#ffd23f"), lime = Kit.hex("#7dff6a"),
}

-- state: coins, len (5/7/10/0), price, boost = {x, why}, rules (fine print text)
-- cb: onFlush, onRanked, onLen(n), onPacks, onShop, onStats, onMenu, onHowTo
-- returns the root Frame and rects (name -> {x, y, w, h}) for layout checks
function Title.build(parent, state, cb)
	local W, H = Css.W, Css.H
	local root = Kit.new("Frame")
	root.Name = "Title"
	root.BackgroundTransparency = 1
	root.Size = Kit.UDim2.fromScale(1, 1)
	root.Parent = parent
	local rects = {}
	local function R(name, x, y, w, h) rects[name] = { x, y, w, h } end
	local short = H <= 760
	local narrow = W <= 760
	local xs = W <= 700

	------------------------------------------------ title-top
	local topY = short and Css.vh(6) or Css.vh(11)
	local Lf = short and Css.clamp(51.2, 16 + Css.vh(11), 128) or Css.cr(4.4, 1.8, 8, 10)
	local logoStyle = { family = "vt323", size = Lf, spacing = 0.08 * Lf, padLeft = 0.1 * Lf, color = Kit.hex("#f4fbff"),
		lineHeight = 0.9 * Lf, stroke = { 0.05 * Lf, Kit.hex("#1a0f24") },
		shadows = { { -0.06 * Lf, 0, 0, Kit.hex("#ff3fb4"), 1 }, { 0.06 * Lf, 0, 0, Kit.hex("#5fe04a"), 1 },
			{ 0, 0.07 * Lf, 0, Kit.hex("#1a0f24"), 1 }, { 0, 0, 0.35 * Lf, rgb(20, 10, 30), 0.35 } } }
	local lw, lh = Kit.measure("FLUSHED", logoStyle)
	local lx = (W - lw) / 2
	R("logo", lx, topY, lw, lh)
	local logo = Kit.text(root, lx, topY, "FLUSHED", logoStyle)
	-- transform: scaleX(1.32) about the centre
	for _, ch in logo:GetChildren() do
		if ch:IsA("ImageLabel") then
			local p, s = ch.Position, ch.Size
			local cx = lw / 2
			ch.Size = Kit.UDim2.fromOffset(math.floor(s.X.Offset * 1.32 + 0.5), s.Y.Offset)
			ch.Position = Kit.UDim2.fromOffset(math.floor(cx + (p.X.Offset - cx) * 1.32 + 0.5), p.Y.Offset)
		elseif ch:IsA("Frame") then
			local p, s = ch.Position, ch.Size
			local cx = lw / 2
			ch.Size = Kit.UDim2.fromOffset(math.floor(s.X.Offset * 1.32 + 0.5), s.Y.Offset)
			ch.Position = Kit.UDim2.fromOffset(math.floor(cx + (p.X.Offset - cx) * 1.32 + 0.5), p.Y.Offset)
		end
	end
	logo.Name = "Logo"

	local T = Css.cr(1, 0.6, 1.3, 1.9)
	local tagY = topY + 0.9 * Lf + 0.55 * T
	local tagStyle = { family = MONO, weight = 700, size = T, spacing = 0.3 * T, color = C.gold, stroke = { 1.5, Kit.hex("#2a1a04") },
		shadows = { { 0, 3, 0, Kit.hex("#2a1a04"), 1 }, { 0, 0, 14, rgb(20, 10, 30), 0.35 } } }
	local tw, th = Kit.measure("GET FLUSHED", tagStyle)
	local contentW = W - 32 - 0.6 * T
	local tx = 16 + 0.6 * T + (contentW - tw) / 2
	R("tagline", 16, tagY, W - 32, th)
	Kit.text(root, tx, tagY, "GET FLUSHED", tagStyle)

	local S = Css.cr(0.8, 0.62, 0.5, 1.15)
	if not (H <= 560) then
		local subY = tagY + Kit.lh(T) + (short and 0.8 * S or 1.4 * S)
		local padX, padY = 0.9 * S, 0.35 * S
		local maxTextW = W - 32 - 2 * padX - 4
		local subStyle = { family = MONO, weight = 600, size = S, spacing = 0.16 * S, color = Kit.hex("#f4f8f2"), width = maxTextW, align = "center" }
		local _, sh = Kit.measure("25 seconds a prompt · rarer answers flush you deeper", subStyle)
		-- inline-block shrink-to-fit: min(max-content, available) -> full width once the text wraps
		local oneLine = Kit.measure("25 seconds a prompt · rarer answers flush you deeper", { family = MONO, weight = 600, size = S, spacing = 0.16 * S })
		local boxW = math.min(oneLine, maxTextW) + 2 * padX + 4
		local bx = (W - boxW) / 2
		local bh = sh + 2 * padY + 4
		R("subline", bx, subY, boxW, bh)
		Kit.box(root, bx, subY, boxW, bh, { bg = rgb(20, 26, 22), bgA = 0.72, border = 2, bc = rgb(20, 26, 22), bcA = 0.9 })
		subStyle.width = boxW - 2 * padX - 4
		Kit.text(root, bx + 2 + padX, subY + 2 + padY, "25 seconds a prompt · rarer answers flush you deeper", subStyle, boxW - 2 * padX - 4)
	end

	------------------------------------------------ title-bottom (stacked from the bottom edge)
	local bw = math.min(W - 32, 860)
	local bx = (W - bw) / 2
	local u = narrow and 14.72 or Css.clamp(13.12, 8.8 + Css.vw(0.55), 17.92)
	-- measure every block first (flex column), then place from the bottom
	local blocks = {}
	-- how to play toggle
	local howF = 11.52
	local howPadTop = short and 0 or 0.3 * howF
	if not (H <= 560) then
		table.insert(blocks, { name = "howto", h = Kit.lh(howF) + howPadTop + 0.3 * howF, mt = 0 })
	end
	-- FLUSH button
	local fbH = short and 50 or Css.clamp(52, Css.vh(8), 78)
	local fbF = Css.cr(1.2, 0.8, 1.4, 2.3)
	table.insert(blocks, { name = "flush", h = math.max(fbH, Kit.lh(fbF)), mt = short and 8 or Css.vh(1.2) })
	-- ranked button: content wraps inside (inline-flex, gap .6em)
	local rkF = short and 13.6 or Css.cr(0.85, 0.7, 0.4, 1.05)
	local rkPadY, rkPadX = (short and 0.4 or 0.55) * rkF, rkF
	local L = state.len == 0 and 10 or state.len
	local rkText = string.format("RANKED · %d PROMPTS ·", L) -- flex trims the trailing space before the coin
	local rkStyle = { family = MONO, weight = 700, size = rkF, spacing = 0.18 * rkF, color = Kit.hex("#ffe27a") }
	local rkTW = Kit.measure(rkText, rkStyle)
	local coinStyle = { family = MONO, weight = 700, size = rkF, spacing = 0.18 * rkF, color = C.gold }
	local priceStr = tostring(state.price or 0)
	local coinTW = 1.05 * rkF + 0.25 * rkF + Kit.measure(priceStr, coinStyle)
	local boostOn = state.boost and state.boost.x and state.boost.x > 1
	local bF = 0.72 * rkF
	local boostStyle = { family = MONO, weight = 800, size = bF, spacing = 0.08 * bF, color = Kit.hex("#0b1a08") }
	local boostText = boostOn and string.format("%s ×%s", state.boost.why, tostring(state.boost.x)) or ""
	local boostTW = boostOn and (Kit.measure(boostText, boostStyle) + 2 * 0.5 * bF) or 0
	local innerW = bw - 4 - 2 * rkPadX
	local line1 = rkTW + coinTW
	local items = { { "text", rkTW }, { "coin", coinTW } }
	if boostOn then table.insert(items, { "boost", boostTW }) end
	-- wrap items into lines (gap .6em)
	local lines, curLine, curW = {}, {}, 0
	for _, it in items do
		local add = (#curLine > 0 and 0.6 * rkF or 0) + it[2]
		if #curLine > 0 and curW + add > innerW then table.insert(lines, { items = curLine, w = curW }); curLine, curW = {}, 0; add = it[2] end
		table.insert(curLine, it); curW += add
	end
	table.insert(lines, { items = curLine, w = curW })
	local lineHs = {}
	for i, ln in lines do
		local h = 0
		for _, it in ln.items do
			h = math.max(h, it[1] == "boost" and (Kit.lh(bF) + 2 * 0.15 * bF) or Kit.lh(rkF))
		end
		lineHs[i] = h
	end
	local rkContentH = 0
	for i, h in lineHs do rkContentH += h + (i > 1 and 0.6 * rkF or 0) end -- flex gap .6em between wrapped rows
	local rkH = rkContentH + 2 * rkPadY + 4
	table.insert(blocks, { name = "ranked", h = rkH, mt = short and 8 or 10 })
	-- fine print
	local fpF = H <= 640 and 8 or 8.8
	local fpW = math.min(bw, 680)
	local fpStyle = { family = MONO, size = fpF, spacing = 0.03 * fpF, lineHeight = 1.35 * fpF, color = rgb(201, 213, 196), alpha = 0.72, width = fpW, align = "center" }
	local _, fpH = Kit.measure(state.rules or "", fpStyle)
	table.insert(blocks, { name = "fine", h = fpH, mt = H <= 640 and 4 or 6 })
	-- title bar: len-pick + tabs (flex wrap, centred, gap 10)
	local tabF = xs and 12.48 or 13.6
	local tabPadY, tabPadX = 0.7 * tabF, tabF
	local tabStyle = { family = MONO, size = tabF, spacing = 0.14 * tabF, color = C.muted }
	local tabs = {
		{ "THEMED PACKS", "cube", cb.onPacks, "packs" }, { "SHOP", nil, cb.onShop, "shop" }, { "STATS", "chart", cb.onStats, "stats" },
	}
	local tabWs = {}
	for i, t in tabs do
		local w = Kit.measure(t[1], tabStyle) + 2 * tabPadX + 4
		if t[2] and not narrow then w += 0.7 * tabF + 1.15 * tabF end -- icons are hidden at <=760px
		tabWs[i] = w
	end
	local tabH = Kit.lh(tabF) + 2 * tabPadY + 4
	local lpLabelF = xs and 11.2 or 12.48
	local lpLabelPad = xs and 0.6 * lpLabelF or 0.9 * lpLabelF
	local lpLabelStyle = { family = MONO, size = lpLabelF, spacing = 0.2 * lpLabelF, color = C.muted }
	local lpLabelW = Kit.measure("PROMPTS", lpLabelStyle) + 2 * lpLabelPad + 2
	local lpBtnF, lpInfF = 15.2, 18.4
	local lpBtnStyle = { family = MONO, weight = 600, size = lpBtnF, spacing = 0.05 * lpBtnF }
	local lpInfStyle = { family = MONO, weight = 600, size = lpInfF, spacing = 0.05 * lpInfF }
	local lpH = Kit.lh(lpInfF) + 2 * 0.6 * lpInfF + 4
	local lens = { 5, 7, 10, 0 }
	local lpBtnWs = {}
	for i, n in lens do
		local st = n == 0 and lpInfStyle or lpBtnStyle
		local f = n == 0 and lpInfF or lpBtnF
		lpBtnWs[i] = math.max(2.6 * f, Kit.measure(n == 0 and "∞" or tostring(n), st) + 2 * 0.5 * f)
	end
	local lpW = 4 + lpLabelW
	for _, w in lpBtnWs do lpW += w end
	if xs then lpW = bw end
	-- flex-wrap rows
	local rowItems = { { "len", lpW, lpH } }
	for i = 1, #tabs do table.insert(rowItems, { "tab" .. i, tabWs[i], tabH }) end
	local rows, cur, cw = {}, {}, 0
	for _, it in rowItems do
		local add = (#cur > 0 and 8 or 0) + it[2]
		if #cur > 0 and cw + add > bw + 0.01 then table.insert(rows, { items = cur, w = cw }); cur, cw = {}, 0; add = it[2] end
		table.insert(cur, it); cw += add
	end
	table.insert(rows, { items = cur, w = cw })
	if xs then
		-- phone: tabs share a row equally (flex: 1)
		for _, row in rows do
			if row.items[1][1] ~= "len" then
				-- flex: 1 with min-width: auto -> equal shares, but nothing shrinks below its content
				local free = bw - 8 * (#row.items - 1)
				local fixed = {}
				for _ = 1, #row.items do
					local open, used = 0, 0
					for i2, it in row.items do if fixed[i2] then used += it.content else open += 1 end end
					local share = open > 0 and (free - used) / open or 0
					local changed = false
					for i2, it in row.items do
						it.content = it.content or it[2]
						if not fixed[i2] and it.content > share then fixed[i2] = true; changed = true end
					end
					if not changed then
						for i2, it in row.items do it[2] = fixed[i2] and it.content or share end
						break
					end
				end
				row.w = bw
			end
		end
	end
	local barH = 0
	for i, row in rows do
		local h = 0
		for _, it in row.items do h = math.max(h, it[3]) end
		row.h = h
		barH += h + (i > 1 and 8 or 0)
	end
	table.insert(blocks, { name = "bar", h = barH, mt = short and 8 or 14 })
	-- the (empty) daily note under the bar still takes its margin + padding: 8px + 2 x .5em of .78rem
	table.insert(blocks, { name = "daily", h = 12.48, mt = 8 })

	local total = 0
	for i, b in blocks do total += b.h + (i > 1 and b.mt or 0) end
	local bottom = H - math.max(14, Css.vh(3.5))
	local y = bottom - total
	R("title-bottom", bx, y, bw, total)
	for i, b in blocks do
		if i > 1 then y += b.mt end
		b.y = y
		y += b.h
	end
	local byName = {}
	for _, b in blocks do byName[b.name] = b end

	-- how to play
	if byName.howto then
		local b = byName.howto
		R("howto", bx, b.y, 0, b.h)
		local hs = { family = MONO, size = howF, spacing = 0.3 * howF, color = C.muted }
		Kit.text(root, bx, b.y + howPadTop, "▸", { family = MONO, size = howF, spacing = 0.3 * howF, color = C.muted })
		local caretW = Kit.measure("▸", hs)
		Kit.text(root, bx + caretW + 0.6 * howF, b.y + howPadTop, "HOW TO PLAY", hs)
		local hit = Kit.new("TextButton"); hit.Text = ""; hit.BackgroundTransparency = 1
		hit.Position = Kit.UDim2.fromOffset(bx, b.y); hit.Size = Kit.UDim2.fromOffset(150, b.h); hit.Parent = root
		if cb.onHowTo then hit.Activated:Connect(cb.onHowTo) end
	end
	-- FLUSH
	do
		local b = byName.flush
		R("btn-begin", bx, b.y, bw, b.h)
		local box = Kit.box(root, bx, b.y, bw, b.h, { bg = rgb(14, 24, 16), bgA = 0.94, border = 3, bc = C.lime, inset = { 2, rgb(14, 22, 16), 0.9 }, glow = { 22, C.lime, 0.35 } })
		box.Name = "FlushButton"
		local triF = 0.85 * fbF
		local labStyle = { family = MONO, weight = 600, size = fbF, spacing = 0.3 * fbF, color = C.white }
		local triStyle = { family = MONO, weight = 600, size = triF, color = C.white }
		local lw2 = Kit.measure("FLUSH", labStyle)
		local trW = Kit.measure("▼", triStyle)
		local gap = 1.1 * fbF
		local totalW = trW * 2 + lw2 + gap * 2
		local x0 = (bw - totalW) / 2
		local cy = b.h / 2
		Kit.text(box, x0, cy - Kit.lh(triF) / 2, "▼", triStyle)
		Kit.text(box, x0 + trW + gap, cy - Kit.lh(fbF) / 2, "FLUSH", labStyle)
		Kit.text(box, x0 + trW + gap + lw2 + gap, cy - Kit.lh(triF) / 2, "▼", triStyle)
		local hit = Kit.new("TextButton"); hit.Text = ""; hit.BackgroundTransparency = 1; hit.Size = Kit.UDim2.fromScale(1, 1); hit.Parent = box
		if cb.onFlush then hit.Activated:Connect(cb.onFlush) end
	end
	-- RANKED
	do
		local b = byName.ranked
		R("btn-ranked", bx, b.y, bw, b.h)
		local box = Kit.box(root, bx, b.y, bw, b.h, { bg = rgb(40, 30, 6), bgA = 0.85, border = 2, bc = C.gold })
		box.Name = "RankedButton"
		if state.poor then box.Body.BackgroundTransparency = 1 - 0.85 * 0.55 end
		local yy = 2 + rkPadY
		for li, ln in lines do
			local x = (bw - ln.w) / 2
			for _, it in ln.items do
				local lh = lineHs[li]
				if it[1] == "text" then
					Kit.text(box, x, yy + (lh - Kit.lh(rkF)) / 2, rkText, rkStyle)
				elseif it[1] == "coin" then
					local ico = 1.05 * rkF
					Title.coinIcon(box, x, yy + (lh - ico) / 2, ico)
					Kit.text(box, x + ico + 0.25 * rkF, yy + (lh - Kit.lh(rkF)) / 2, priceStr, coinStyle)
				elseif it[1] == "boost" then
					local bh = Kit.lh(bF) + 2 * 0.15 * bF
					local chip = Kit.box(box, x, yy + (lh - bh) / 2, it[2], bh, { bg = C.lime })
					Kit.text(chip, 0.5 * bF, 0.15 * bF, boostText, boostStyle)
				end
				x += it[2] + 0.6 * rkF
			end
			yy += lineHs[li] + 0.6 * rkF
		end
		local hit = Kit.new("TextButton"); hit.Text = ""; hit.BackgroundTransparency = 1; hit.Size = Kit.UDim2.fromScale(1, 1); hit.Parent = box
		if cb.onRanked then hit.Activated:Connect(cb.onRanked) end
	end
	-- fine print
	do
		local b = byName.fine
		local fx = bx + (bw - fpW) / 2
		R("fine-print", fx, b.y, fpW, b.h)
		Kit.text(root, fx, b.y, state.rules or "", fpStyle, fpW)
	end
	-- title bar
	do
		local b = byName.bar
		local yy = b.y
		for _, row in rows do
			local x = bx + (bw - row.w) / 2
			for _, it in row.items do
				local iy = yy + (row.h - it[3]) / 2
				if it[1] == "len" then
					R("len-pick", x, yy, it[2], row.h)
					local lp = Kit.box(root, x, yy, it[2], row.h, { bg = rgb(14, 22, 16), bgA = 0.75, border = 2, bc = rgb(167, 187, 163), bcA = 0.45 })
					local ih = row.h - 4
					-- label
					local labW = lpLabelW
					local bws = table.clone(lpBtnWs)
					if xs then
						local rest = it[2] - 4 - labW
						for i = 1, #bws do bws[i] = rest / #bws end
					end
					Kit.text(lp, 2 + lpLabelPad, 2 + (ih - Kit.lh(lpLabelF)) / 2, "PROMPTS", lpLabelStyle)
					Kit.frame(lp, 2 + labW - 2, 2, 2, ih, rgb(167, 187, 163), 0.3)
					local bxx = 2 + labW
					for i, n in lens do
						local on = (state.len == n)
						local st = table.clone(n == 0 and lpInfStyle or lpBtnStyle)
						st.color = on and Kit.hex("#0b140e") or rgb(201, 213, 196)
						if on then Kit.frame(lp, bxx, 2, bws[i], ih, C.lime, 1) end
						local lbl = n == 0 and "∞" or tostring(n)
						local f = n == 0 and lpInfF or lpBtnF
						local tw2 = Kit.measure(lbl, st)
						Kit.text(lp, bxx + (bws[i] - tw2) / 2, 2 + (ih - Kit.lh(f)) / 2, lbl, st)
						if i < #lens then Kit.frame(lp, bxx + bws[i] - 2, 2, 2, ih, rgb(167, 187, 163), 0.2) end
						local hit = Kit.new("TextButton"); hit.Text = ""; hit.BackgroundTransparency = 1
						hit.Position = Kit.UDim2.fromOffset(bxx, 2); hit.Size = Kit.UDim2.fromOffset(bws[i], ih); hit.Parent = lp
						if cb.onLen then hit.Activated:Connect(function() cb.onLen(n) end) end
						bxx += bws[i]
					end
				else
					local i = tonumber(it[1]:sub(4))
					local t = tabs[i]
					R("tab-" .. t[4], x, iy, it[2], it[3])
					local tb = Kit.box(root, x, iy, it[2], it[3], { bg = rgb(14, 22, 16), bgA = 0.7, border = 2, bc = rgb(167, 187, 163), bcA = 0.45 })
					local lw3 = Kit.measure(t[1], tabStyle)
					local cw2 = lw3 + ((t[2] and not narrow) and (0.7 * tabF + 1.15 * tabF) or 0)
					local tx2 = (it[2] - cw2) / 2
					Kit.text(tb, tx2, 2 + tabPadY, t[1], tabStyle)
					if t[2] and not narrow then Kit.icon(tb, t[2], tx2 + lw3 + 0.7 * tabF, (it[3] - 1.15 * tabF) / 2, math.floor(1.15 * tabF + 0.5), C.muted, 0.7) end
					local hit = Kit.new("TextButton"); hit.Text = ""; hit.BackgroundTransparency = 1; hit.Size = Kit.UDim2.fromScale(1, 1); hit.Parent = tb
					if t[3] then hit.Activated:Connect(t[3]) end
				end
				x += it[2] + 8
			end
			yy += row.h + 8
		end
	end
	return root, rects
end

-- the website's pixel coin/robux icon (sprite "robux"), drawn as frames
function Title.coinIcon(parent, x, y, size)
	local Sprites = require(script and script.Parent and script.Parent:FindFirstChild("Sprites") or "./Sprites")
	local s = Sprites.robux
	local u = size / s.w
	local holder = Kit.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = Kit.UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	holder.Size = Kit.UDim2.fromOffset(math.floor(size + 0.5), math.floor(size + 0.5))
	holder.Parent = parent
	local r = s.runs
	for i = 1, #r, 4 do
		Kit.frame(holder, r[i] * u, r[i + 1] * u, r[i + 2] * u, u, Kit.hex(s.pal[r[i + 3]]), 1)
	end
	return holder
end

return Title
