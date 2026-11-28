-- The dive screen, rebuilt from the website's CSS (index.html #screen-game, css "v11: mockup-faithful dive screen").
-- HUD (chamfered DEPTH / SCORE boxes + progress pips), the prompt card, the answer dock (timer ring, input,
-- pink FLUSH button, feedback line, did-you-mean box), the reveal (halo + tier icon + tier name + answer + points),
-- the sinking answer card, rarity threshold lines, drifting depth labels and the depth ruler with the YOU marker.
local Kit = require(script and script.Parent and script.Parent:FindFirstChild("Kit") or "./Kit")
local Canvas = require(script and script.Parent and script.Parent:FindFirstChild("Canvas") or "./Canvas")
local Css = Kit.Css
local rgb, hex = Kit.rgb, Kit.hex

local Game = {}
Game.__index = Game

local MONO = "plex"
local C = {
	white = hex("#f2f6fb"), muted = rgb(159, 179, 154), lime = hex("#8dff6e"), pink = hex("#ff5c8a"), pink2 = hex("#ff8fae"),
	warn = hex("#ffd166"), suggest = hex("#ffd84a"), panel = rgb(14, 22, 16), card = rgb(16, 26, 20), mutedFb = hex("#a7bba3"),
}
Game.TIERS = {
	[100] = { key = "million", name = "Sigma", depth = 1000, color = hex("#f3cd66"), blurb = "One in a million. Absolute sigma." },
	[85] = { key = "deep", name = "Skibidi", depth = 750, color = hex("#b77dff"), blurb = "Certified skibidi. Few think like this." },
	[60] = { key = "rare", name = "Rizz", depth = 450, color = hex("#ff4d4d"), blurb = "Okay, you've got something." },
	[30] = { key = "schooler", name = "Mid", depth = 200, color = hex("#6fc8ff"), blurb = "Respectable. Kinda." },
	[10] = { key = "plankton", name = "NPC", depth = 30, color = hex("#a8b3c4"), blurb = "Everyone said that." },
}
local TIER_ORDER = { 100, 85, 60, 30, 10 }
local ICON_SPR = { million = "icoSigma", deep = "icoSkibidi", rare = "icoRizz", schooler = "icoMid", plankton = "icoNPC" }
Game.DEPTH_LABELS = {
	{ 0, "l", "the bowl" }, { 200, "l", "the pipes" }, { 1000, "l", "the sewer" }, { 3600, "l", "the rat kingdom" }, { 4600, "l", "the brainrot core" }, { 5600, "l", "it gets unhinged" },
	{ 60, "r", "last chance to unflush" }, { 150, "l", "lost AirPod spotted" }, { 260, "r", "someone flushed a goldfish" }, { 420, "l", "the smell intensifies" },
	{ 600, "r", "a sock. just one sock." }, { 850, "l", "toothbrush graveyard" }, { 1150, "r", "gator sighting (unconfirmed)" }, { 1500, "l", "you can hear Ohio from here" },
	{ 2000, "r", "fatberg the size of a bus" }, { 2600, "l", "rats doing a TikTok dance" }, { 3200, "r", "the wifi is surprisingly good" }, { 3300, "l", "abandoned rubber duck colony" },
	{ 3900, "r", "rat with a crown" }, { 4300, "r", "the rat king is watching" }, { 5000, "r", "skill issue detected" }, { 6200, "l", "skibidi levels critical" }, { 6800, "r", "peak brainrot ahead" },
	{ 7400, "l", "the rats have a DJ now" }, { 8000, "r", "it only gets worse from here" }, { 8800, "l", "ohio sends its regards" }, { 9600, "r", "the bass is load-bearing" },
	{ 10500, "l", "no one has ever come back" }, { 11500, "r", "certified brainrot bedrock" }, { 13000, "l", "you are the brainrot now" },
}
local function fmt(n)
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end
Game.fmt = fmt

-- pixel sprite (Sprites.luau) drawn as frames at integer scale k
function Game.sprite(parent, name, x, y, k)
	local Sprites = require(script and script.Parent and script.Parent:FindFirstChild("Sprites") or "./Sprites")
	local s = Sprites[name]
	local holder = Kit.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = Kit.UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	holder.Size = Kit.UDim2.fromOffset(s.w * k, s.h * k)
	holder.Parent = parent
	local r = s.runs
	for i = 1, #r, 4 do Kit.frame(holder, r[i] * k, r[i + 1] * k, r[i + 2] * k, k, hex(s.pal[r[i + 3]]), 1) end
	return holder, s.w * k, s.h * k
end

local function layer(parent, name, z)
	local f = Kit.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = Kit.UDim2.fromScale(1, 1)
	if z then f.ZIndex = z end
	f.Parent = parent
	return f
end
local function clear(f) for _, c in f:GetChildren() do c:Destroy() end end
local function hitButton(parent, x, y, w, h, fn)
	local b = Kit.new("TextButton")
	b.Text = ""
	b.BackgroundTransparency = 1
	b.Position = Kit.UDim2.fromOffset(x, y)
	b.Size = Kit.UDim2.fromOffset(w, h)
	b.Parent = parent
	if fn then b.Activated:Connect(fn) end
	return b
end

-- cb: onSubmit(text), onInput(text), onNext(), onEndRun(), onMenu(), onQuit(), onRestart(), onSound()
function Game.new(parent, cb)
	local self = setmetatable({ cb = cb or {}, state = {}, rects = {} }, Game)
	self.root = layer(parent, "Game", 2)
	self.labels = layer(self.root, "DepthLabels", 1)
	self.tierLines = layer(self.root, "TierLines", 2)
	self.gauge = layer(self.root, "Gauge", 3)
	self.ui = layer(self.root, "UI", 4)
	self.sinkLayer = layer(self.root, "Sink", 5)
	self:layout()
	return self
end

---------------------------------------------------------------- layout (rebuilt on resize)
function Game:metrics()
	local W, H = Css.W, Css.H
	local narrow = W <= 760
	local m = {}
	m.W, m.H, m.narrow = W, H, narrow
	m.u = narrow and 14.72 or Css.clamp(13.12, 8.8 + Css.vw(0.55), 17.92)
	m.gw = narrow and 54 or Css.clamp(84, Css.vw(9), 130)
	m.padT = narrow and 10 or 12
	m.padR = narrow and (m.gw + 4) or (m.gw + 8)
	m.padL = m.gw + 8
	m.cw = W - m.padL - m.padR
	m.boxH = Css.clamp(64, Css.vw(7.5), 86)
	m.boxW = Css.clamp(110, Css.vw(12), 170)
	return m
end

function Game:layout()
	clear(self.ui); clear(self.labels); clear(self.gauge)
	local m = self:metrics()
	self.m = m
	local W, H = m.W, m.H
	local ui = self.ui
	-- bottom fade behind the dock: linear-gradient(transparent -> rgba(12,18,13,.92) at 45%)
	local fadeH = Css.clamp(120, Css.vh(20), 190)
	local fade = Kit.frame(ui, 0, H - fadeH, W, fadeH, rgb(12, 18, 13), 1)
	local ok = pcall(function()
		local g = Kit.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.08), NumberSequenceKeypoint.new(1, 0.08) })
		g.Parent = fade
	end)
	if not ok then -- headless tests: stepped bands
		fade:Destroy()
		for i = 0, 23 do
			local t = (i + 0.5) / 24
			Kit.frame(ui, 0, H - fadeH + i * fadeH / 24, W, fadeH / 24 + 1, rgb(12, 18, 13), t < 0.45 and (t / 0.45) * 0.92 or 0.92)
		end
	end
	-- HUD boxes
	local u = m.u
	local function hudBox(x, label, right)
		local box = Kit.chamfer(ui, x, m.padT, m.boxW, m.boxH, C.panel, 0.9)
		local ls = { family = MONO, size = 10.88, spacing = 0.32 * 10.88, color = C.muted }
		local lw = Kit.measure(label, ls)
		local padL, padT = 1.1 * u, 0.55 * u
		Kit.text(box, right and (m.boxW - padL - lw) or padL, padT, label, ls)
		return box, padL, padT
	end
	self.depthBox = hudBox(m.padL, "DEPTH", false)
	self.scoreBox = hudBox(W - m.padR - m.boxW, "SCORE", true)
	self.rects["hud-depth"] = { m.padL, m.padT, m.boxW, m.boxH }
	self.rects["hud-score"] = { W - m.padR - m.boxW, m.padT, m.boxW, m.boxH }
	-- side rails: menu / home / restart on the left, sound on the right, under the HUD
	local railTop = 12 + m.boxH + 10
	local function railBtn(x, y, icon, fn)
		local b = Kit.box(ui, x, y, 40, 40, { bg = rgb(22, 32, 22), bgA = 0.78, border = 1, bc = rgb(167, 187, 163), bcA = 0.25 })
		Kit.icon(b, icon, 10, 10, 20, hex("#f2f8fc"), 1)
		hitButton(b, 0, 0, 40, 40, fn)
		return b
	end
	railBtn(14, railTop, "menu", self.cb.onMenu)
	self.soundBtn = railBtn(W - m.padR - 40, railTop, self.state.muted and "mute" or "sound", self.cb.onSound)
	-- pips + label (rebuilt by setProgress)
	self.pipsHolder = layer(ui, "Pips")
	-- stage
	local hudH = m.boxH
	if m.narrow then hudH = m.boxH + 6 + 0.9 * u + 9 end
	local stageY = m.padT + hudH
	local stagePad = Css.clamp(30, Css.vh(14), 150)
	m.stageY = stageY
	m.panelW = math.min(m.cw, 860)
	m.panelX = m.padL + (m.cw - m.panelW) / 2
	m.panelY = stageY + stagePad
	m.introPanelY = stageY + Css.vh(42) - 70
	-- prompt card (rebuilt by setPrompt)
	self.qbox = layer(ui, "QBox")
	-- dock
	local tSize = Css.clamp(64, Css.vw(7.6), 96)
	local gap = Css.clamp(10, Css.vw(1.4), 18)
	local inF = Css.cr(1.3, 0.9, 1, 2)
	local inH = Kit.lh(inF) + 6
	local btnH = Css.clamp(52, Css.vw(6.4), 70)
	local btnF = Css.clamp(16.8, 12.8 + Css.vw(0.8), 25.6)
	local btnLs = 0.14 * btnF
	local btnTextW = Kit.measure("FLUSH", { family = MONO, weight = 700, size = btnF, spacing = btnLs })
	local btnPad = m.narrow and 0.6 * btnF or 0
	local btnW = math.max(m.narrow and 76 or Css.vw(11), btnTextW + 2 * btnPad + 6)
	local fbF = 0.95 * u
	local underH = math.max(1.4 * u, Kit.lh(fbF))
	local colH = 14 + inH + 8 + 8 -- input column: padding-top 14, input, gap 8, time bar 8
	local rowH = math.max(6 + tSize, colH, 14 + btnH)
	local dockH = 8 + underH + 0.3 * u + rowH
	local dockY = H - dockH
	m.dock = { y = dockY, underY = dockY + 8, rowY = dockY + 8 + underH + 0.3 * u, tSize = tSize, gap = gap, inF = inF, inH = inH, btnH = btnH, btnW = btnW, btnF = btnF, btnLs = btnLs, fbF = fbF, underH = underH }
	local d = m.dock
	self.dock = layer(ui, "Dock")
	local dock = self.dock
	local px = m.panelX
	-- timer ring (pixel image) at the left
	d.timerX, d.timerY = px, d.rowY + 6
	self.timerHolder = layer(dock, "Timer")
	-- input column
	d.inX = px + tSize + gap
	d.inW = m.panelW - tSize - gap - btnW - gap
	d.inY = d.rowY + (rowH - colH) / 2 + 14 -- the column is centred in the row (timer and button stick to the top)
	local input = Kit.box(dock, d.inX, d.inY, d.inW, inH, { bg = hex("#0f1712"), border = 3, bc = hex("#a8ff8c") })
	self.inputBox = input
	local tb = Kit.new("TextBox")
	tb.Name = "Answer"
	tb.BackgroundTransparency = 1
	tb.TextTransparency = 1 -- the visible text is drawn in the website font (setInputText)
	tb.ClearTextOnFocus = false
	tb.Text = ""
	tb.Position = Kit.UDim2.fromOffset(0, 0)
	tb.Size = Kit.UDim2.fromOffset(d.inW, inH)
	tb.Parent = input
	self.textBox = tb
	self.inputText = layer(input, "Typed")
	if tb.GetPropertyChangedSignal then
		tb:GetPropertyChangedSignal("Text"):Connect(function()
			local t = tb.Text:sub(1, 60)
			self:setInputText(t)
			if self.cb.onInput then self.cb.onInput(t) end
		end)
		tb.FocusLost:Connect(function(enter)
			if enter and self.cb.onSubmit then self.cb.onSubmit(tb.Text) end
		end)
	end
	-- time bar
	d.barY = d.inY + inH + 8
	self.timeBar = Kit.frame(dock, d.inX, d.barY, d.inW, 8, hex("#a8ff8c"), 1)
	-- FLUSH (pink)
	d.btnX = d.inX + d.inW + gap
	d.btnY = d.rowY + 14
	local fb = Kit.box(dock, d.btnX, d.btnY, btnW, btnH, { bg = hex("#e85d86"), border = 3, bc = hex("#0e120f"), shadow = { 0, 6, hex("#6e1f3a"), 1 }, glow = { 22, hex("#e85d86"), 0.35 } })
	Kit.text(fb, (btnW - btnTextW) / 2, (btnH - Kit.lh(btnF)) / 2, "FLUSH", { family = MONO, weight = 700, size = btnF, spacing = btnLs, color = hex("#1a0a12") })
	hitButton(fb, 0, 0, btnW, btnH, function() if self.cb.onSubmit then self.cb.onSubmit(self.textBox.Text) end end)
	self.rects["answer"] = { d.inX, d.inY, d.inW, inH }
	self.rects["btn-dive"] = { d.btnX, d.btnY, btnW, btnH }
	self.rects["timer"] = { d.timerX, d.timerY, tSize, tSize }
	-- feedback line
	self.feedbackHolder = layer(dock, "Feedback")
	-- suggest box / reveal / intro pill layers
	self.suggestHolder = layer(ui, "Suggest")
	self.reveal = layer(ui, "Reveal")
	self.reveal.Visible = false
	self.intro = layer(ui, "Intro")
	-- depth labels (positioned every frame)
	self.dl = {}
	local dlF = 12.8
	for _, L in Game.DEPTH_LABELS do
		if not (m.narrow and L[2] == "r") then
			local text = L[2] == "l" and ("—— " .. L[3]) or (L[3] .. " ——")
			local st = { family = MONO, size = dlF, spacing = 0.16 * dlF, color = rgb(160, 186, 210), alpha = 0.45 }
			local w = Kit.measure(text, st)
			local x = L[2] == "l" and (m.narrow and 12 or Css.clamp(70, Css.vw(14), 300)) or (W - (m.gw + 24) - w)
			local h = Kit.text(self.labels, x, 0, text, st)
			h.Visible = false
			table.insert(self.dl, { holder = h, m = L[1], x = x })
		end
	end
	-- gauge: line + ticks + YOU marker
	self.gaugeLine = Kit.frame(self.gauge, W - 12 - 2, 0, 2, H, rgb(170, 190, 212), 0.5)
	self.ticks = {}
	self.youHolder = layer(self.gauge, "You")
	local youF = 11.52
	local ys = { family = MONO, size = youF, color = C.pink }
	local yw = Kit.measure("YOU", ys)
	self.you = Kit.new("Frame"); self.you.BackgroundTransparency = 1; self.you.Size = Kit.UDim2.fromOffset(yw + 22, 14); self.you.Parent = self.youHolder
	Kit.text(self.you, 0, -7, "YOU", ys)
	Kit.frame(self.you, yw + 22 - 9 - 10, -1, 10, 2, C.pink, 1)
	for i = 0, 5 do Kit.frame(self.you, yw + 22 - 9 + i * 1.5, -6 + i, 9 - i * 1.5, 12 - 2 * i, C.pink, 1) end
	self:refresh()
end

-- re-apply the current state after a relayout
function Game:refresh()
	local s = self.state
	if s.prompt then self:setPrompt(s.prompt, s.label) end
	self:setHud(s.depth or 0, s.score or 0)
	if s.pips then self:setProgress(s.pips, s.label) end
	self:setFeedback(s.fb, s.fbCls)
	self:setTimer(s.left or 25, s.total or 25)
	self:setInputText(self.textBox.Text)
	if s.reveal then self:showReveal(s.reveal) end
end

---------------------------------------------------------------- HUD
function Game:setHud(depth, score)
	self.state.depth, self.state.score = depth, score
	local m = self.m
	local f = Css.clamp(24, 16 + Css.vw(1.4), 40)
	local u = m.u
	local function val(box, text, right, color)
		local old = box:FindFirstChild("Val")
		if old then old:Destroy() end
		local st = { family = MONO, weight = 600, size = f, spacing = 0.02 * f, color = color, lineHeight = f }
		local w = Kit.measure(text, st)
		local padL = 1.1 * u
		local y = 0.55 * u + Kit.lh(10.88) + 0.35 * f
		local h = Kit.text(box, right and (m.boxW - padL - w) or padL, y, text, st)
		h.Name = "Val"
	end
	val(self.depthBox, fmt(math.max(0, depth)) .. "m", false, C.lime)
	val(self.scoreBox, tostring(score), true, C.pink)
end

-- pips: list of {state = "done"|"miss"|"cur"|"todo", color}; label under them
function Game:setProgress(pips, label)
	self.state.pips, self.state.label = pips, label
	clear(self.pipsHolder)
	local m = self.m
	local size = Css.clamp(9, Css.vw(0.85), 12)
	local n = #pips
	local totalW = n * size + (n - 1) * 4
	local x0, y0
	if m.narrow then
		x0 = (m.W - totalW) / 2
		y0 = m.padT + m.boxH + 6 + 0.9 * m.u
	else
		x0 = (m.W - totalW) / 2
		y0 = m.padT + 0.9 * m.u
	end
	for i, p in pips do
		local x = x0 + (i - 1) * (size + 4)
		local bc, bca = rgb(167, 187, 163), 0.35
		if p.state == "cur" then bc, bca = rgb(216, 250, 212), 0.725 end
		if p.state == "done" then
			Kit.frame(self.pipsHolder, x, y0, size, size, p.color, 1)
		elseif p.state == "miss" then
			Kit.box(self.pipsHolder, x, y0, size, size, { bg = rgb(255, 92, 138), bgA = 0.3, border = 1, bc = rgb(255, 92, 138), bcA = 0.6 })
		else
			Kit.box(self.pipsHolder, x, y0, size, size, { bg = C.panel, bgA = 0.9, border = 1, bc = bc, bcA = bca })
		end
	end
	if label then
		local lf = 9.92
		local st = { family = MONO, size = lf, spacing = 0.32 * lf, color = C.muted }
		local w = Kit.measure(label, st)
		Kit.text(self.pipsHolder, (m.W - w) / 2, y0 + size + 8, label, st)
	end
end

---------------------------------------------------------------- prompt card
function Game:setPrompt(text, label, intro)
	self.state.prompt, self.state.label = text, label
	clear(self.qbox)
	local m = self.m
	local padT, padX, padB = Css.clamp(22, Css.vw(3), 40), Css.clamp(24, Css.vw(3.4), 52), Css.clamp(22, Css.vw(2.6), 34)
	local pf = Css.cr(0.72, 0.6, 0.3, 0.95)
	local qf = Css.cr(1.5, 1, 1.8, 2.7)
	local innerW = m.panelW - 2 * padX
	local pStyle = { family = MONO, weight = 500, size = pf, spacing = 0.4 * pf, color = C.pink }
	local qStyle = { family = MONO, weight = 600, size = qf, spacing = 0.01 * qf, color = C.white, lineHeight = 1.25 * qf, width = innerW }
	local _, ph = Kit.measure(label or "", pStyle)
	local _, qh = Kit.measure(text, qStyle)
	local boxH = padT + ph + 0.7 * pf + qh + padB
	local y = (intro and m.introPanelY or m.panelY) + 0.9 * m.u
	-- box-shadow 0 10px 30px rgba(0,0,0,.35) (approximated), chamfered 10x5 corners
	for i = 3, 1, -1 do
		local g = i * 8
		Kit.frame(self.qbox, m.panelX - g + 4, y + 10 - g + 4, m.panelW + 2 * g - 8, boxH + 2 * g - 8, rgb(0, 0, 0), 0.06)
	end
	local box = Kit.new("Frame"); box.BackgroundTransparency = 1; box.Position = Kit.UDim2.fromOffset(m.panelX, y); box.Size = Kit.UDim2.fromOffset(m.panelW, boxH); box.Parent = self.qbox
	Kit.frame(box, 10, 0, m.panelW - 20, boxH, C.card, 0.94)
	Kit.frame(box, 0, 5, 10, boxH - 10, C.card, 0.94)
	Kit.frame(box, m.panelW - 10, 5, 10, boxH - 10, C.card, 0.94)
	Kit.text(box, padX, padT, label or "", pStyle)
	Kit.text(box, padX, padT + ph + 0.7 * pf, text, qStyle, innerW)
	self.rects["q-box"] = { m.panelX, y, m.panelW, boxH }
end

---------------------------------------------------------------- dock
function Game:setFeedback(msg, cls)
	self.state.fb, self.state.fbCls = msg, cls
	clear(self.feedbackHolder)
	if not msg or msg == "" then return end
	local d = self.m.dock
	local color = cls == "bad" and C.pink2 or cls == "warn" and C.warn or cls == "suggest" and C.suggest or C.mutedFb
	Kit.text(self.feedbackHolder, self.m.panelX, d.underY, msg, { family = MONO, size = d.fbF, spacing = 0.06 * d.fbF, color = color, width = self.m.panelW })
end

function Game:setInputText(t)
	clear(self.inputText)
	local d = self.m.dock
	local st = { family = MONO, weight = 500, size = d.inF, spacing = 0.04 * d.inF, color = C.white }
	local pad = 0.8 * d.inF
	if t ~= "" then
		Kit.text(self.inputText, pad, (d.inH - Kit.lh(d.inF)) / 2, t, st)
	end
	-- caret
	local w = t ~= "" and Kit.measure(t, st) or 0
	self.caret = Kit.frame(self.inputText, pad + w + 1, (d.inH - d.inF) / 2, 2, d.inF, hex("#c8ff9e"), 1)
end

-- the timer ring: an SVG in the website (viewBox 64), drawn into a pixel image here
function Game:setTimer(left, total)
	self.state.left, self.state.total = left, total
	local d = self.m.dock
	local n = math.ceil(math.max(0, left))
	local key = n .. "|" .. math.floor(left / total * 120)
	if self.timerKey == key then return end
	self.timerKey = key
	clear(self.timerHolder)
	local size = math.floor(d.tSize + 0.5)
	local urgent = left <= 5
	local fg = urgent and { 255, 92, 138 } or { 111, 174, 92 }
	local img = Canvas.image(size, size)
	local s = size / 64
	local frac = math.clamp(left / total, 0, 1)
	for py = 0, size - 1 do
		for pxx = 0, size - 1 do
			-- 2x2 supersampling for smooth circles (the SVG is anti-aliased)
			local acc = { 0, 0, 0, 0 }
			for sy = 0, 1 do
				for sx = 0, 1 do
					local X, Y = (pxx + 0.25 + sx * 0.5) / s, (py + 0.25 + sy * 0.5) / s
					local dx, dy = X - 32, Y - 32
					local r = math.sqrt(dx * dx + dy * dy)
					local col, a = nil, 0
					if r <= 30 then col, a = { 15, 23, 18 }, 1 end -- t-disc fill
					if math.abs(r - 30) <= 1 then col, a = { 34, 48, 31 }, 1 end -- t-disc stroke
					if math.abs(r - 25) <= 2 then col, a = { 111, 174, 92 }, 0.18 end -- t-bg
					if math.abs(r - 25) <= 2 then
						local ang = (math.atan2(dx, -dy) / (2 * math.pi)) % 1 -- 0 at the top, clockwise
						if ang <= frac then col, a = fg, 1 end
					end
					if math.abs(r - 16) <= 0.75 then col, a = { 111, 174, 92 }, 0.35 end -- t-inner
					-- hand: from the centre toward the remaining-time angle
					local ha = frac * 2 * math.pi
					local hx, hy = math.sin(ha), -math.cos(ha)
					local along = dx * hx + dy * hy
					local across = math.abs(dx * hy - dy * hx)
					if along >= 0 and along <= 23 and across <= 1 then col, a = urgent and { 255, 92, 138 } or { 157, 255, 122 }, 0.55 end
					if col then
						acc[1] += col[1] * a; acc[2] += col[2] * a; acc[3] += col[3] * a; acc[4] += a
					end
				end
			end
			if acc[4] > 0 then
				Canvas.setPixel(img, pxx, py, math.floor(acc[1] / acc[4] + 0.5), math.floor(acc[2] / acc[4] + 0.5), math.floor(acc[3] / acc[4] + 0.5), math.floor(acc[4] / 4 * 255 + 0.5))
			end
		end
	end
	if Kit.makeImage then
		local im = Kit.makeImage(size, size)
		im:write(img.px)
		local l = im:label()
		l.Position = Kit.UDim2.fromOffset(math.floor(d.timerX + 0.5), math.floor(d.timerY + 0.5))
		l.Size = Kit.UDim2.fromOffset(size, size)
		l.Parent = self.timerHolder
	end
	local nf = Css.cr(1.2, 0.9, 0.8, 1.8)
	local st = { family = MONO, weight = 600, size = nf, color = urgent and C.pink or hex("#a8ff8c") }
	local w = Kit.measure(tostring(n), st)
	Kit.text(self.timerHolder, d.timerX + (size - w) / 2, d.timerY + (size - Kit.lh(nf)) / 2, tostring(n), st)
	-- time bar
	self.timeBar.Size = Kit.UDim2.fromOffset(math.floor(d.inW * frac + 0.5), 8)
	self.timeBar.BackgroundColor3 = urgent and C.pink or hex("#a8ff8c")
end

-- did-you-mean box above the dock: "typed" -> "fix" / submit again to confirm · or edit
function Game:setSuggest(typed, fix)
	clear(self.suggestHolder)
	if not fix then return end
	local m, d = self.m, self.m.dock
	local f = Css.cr(1, 0.8, 0.6, 1.4)
	local sf = Css.cr(0.72, 0.6, 0.25, 0.9)
	local a = { family = MONO, size = f, spacing = 0.1 * f, color = hex("#8aa384") }
	local b = { family = MONO, size = f, spacing = 0.1 * f, color = hex("#f2f6fb") }
	local c = { family = MONO, size = f, spacing = 0.1 * f, color = hex("#a8ff8c") }
	local s2 = { family = MONO, size = sf, spacing = 0.18 * sf, color = hex("#8aa384") }
	local t1, t3 = "“" .. typed .. "”", "“" .. fix .. "”"
	local w1, w2, w3 = Kit.measure(t1, a), Kit.measure("→", b), Kit.measure(t3, c)
	local wsub = Kit.measure("submit again to confirm · or edit", s2)
	local lineW = w1 + 0.35 * f + w2 + 0.35 * f + w3
	local padX, padT, padB = 2.2 * m.u, 0.85 * m.u, 0.8 * m.u
	local boxW = math.max(lineW, wsub) + 2 * padX
	local boxH = padT + Kit.lh(f) + 0.55 * sf + Kit.lh(sf) + padB
	local x = m.panelX + (m.panelW - boxW) / 2
	local y = d.y - 6 - boxH
	local box = Kit.new("Frame"); box.BackgroundTransparency = 1; box.Position = Kit.UDim2.fromOffset(x, y); box.Size = Kit.UDim2.fromOffset(boxW, boxH); box.Parent = self.suggestHolder
	Kit.frame(box, 10, 0, boxW - 20, boxH, rgb(16, 22, 17), 0.96)
	Kit.frame(box, 0, 5, 10, boxH - 10, rgb(16, 22, 17), 0.96)
	Kit.frame(box, boxW - 10, 5, 10, boxH - 10, rgb(16, 22, 17), 0.96)
	local lx = (boxW - lineW) / 2
	Kit.text(box, lx, padT, t1, a)
	Kit.text(box, lx + w1 + 0.35 * f, padT, "→", b)
	Kit.text(box, lx + w1 + 0.7 * f + w2, padT, t3, c)
	Kit.text(box, (boxW - wsub) / 2, padT + Kit.lh(f) + 0.55 * sf, "submit again to confirm · or edit", s2)
end

-- the first prompt's lead-in: "flushing · the clock starts in 2"
function Game:setIntro(n)
	clear(self.intro)
	self.dock.Visible = n == nil
	if not n then return end
	local m = self.m
	local f = m.narrow and 12 or 14.4
	local st = { family = MONO, size = f, spacing = 0.14 * f, color = hex("#b8c6d8") }
	local stB = { family = MONO, size = f, spacing = 0.14 * f, color = C.lime }
	local t1 = "flushing · the clock starts in "
	local w1, w2 = Kit.measure(t1, st), Kit.measure(tostring(n), stB)
	local padX, padY = 1.6 * f, 0.75 * f
	local w, h = w1 + w2 + 2 * padX, Kit.lh(f) + 2 * padY
	local x, y = (m.W - w) / 2, m.H - Css.clamp(24, Css.vh(9), 90) - h
	local box = Kit.new("Frame"); box.BackgroundTransparency = 1; box.Position = Kit.UDim2.fromOffset(x, y); box.Size = Kit.UDim2.fromOffset(w, h); box.Parent = self.intro
	Kit.frame(box, 8, 0, w - 16, h, C.card, 0.94); Kit.frame(box, 0, 8, w, h - 16, C.card, 0.94)
	for i = 1, 7 do Kit.frame(box, 8 - i, i, i, 1, C.card, 0.94); Kit.frame(box, w - 8, i, i, 1, C.card, 0.94); Kit.frame(box, 8 - i, h - i - 1, i, 1, C.card, 0.94); Kit.frame(box, w - 8, h - i - 1, i, 1, C.card, 0.94) end
	Kit.text(box, padX, padY, t1, st)
	Kit.text(box, padX + w1, padY, tostring(n), stB)
end

---------------------------------------------------------------- reveal
-- r = { score, answer, input, reason, depthGain, last (bool), endless (bool) }
function Game:showReveal(r)
	self.state.reveal = r
	clear(self.reveal)
	self.reveal.Visible = r ~= nil
	self.qbox.Visible = r == nil
	self.dock.Visible = r == nil
	self.suggestHolder.Visible = r == nil
	if not r then return end
	local m = self.m
	local t = Game.TIERS[r.score]
	local tc = t and t.color or hex("#8aa0b8")
	local nameF = Css.cr(1.8, 1.2, 1.8, 2.9)
	local ansF = Css.cr(1.2, 0.9, 0.7, 1.7)
	local ptsF = Css.cr(1.05, 0.8, 0.6, 1.45)
	local blF = 13.12
	local name = t and t.name:upper() or (r.reason == "skip" and "SKIPPED" or r.reason == "surfaced" and "SURFACED" or "TIME'S UP")
	local answer = t and ("“" .. r.answer .. "”") or (r.input and r.input ~= "" and ("“" .. r.input .. "”") or "—")
	local pts = t and ("+" .. r.score .. " PTS") or "+0 PTS"
	local rest = t and ("flush " .. fmt(t.depth) .. "m") or "stuck in the bowl"
	local blurb = t and t.blurb or (r.reason == "skip" and "Skipped. Every answer is in the flush log at the end." or "Nothing went down this time.")
	local nameSt = { family = MONO, weight = 600, size = nameF, spacing = 0.22 * nameF, padLeft = 0.22 * nameF, color = tc,
		shadows = { { 0, 0, 14, tc, 0.6 }, { 0, 0, 2, tc, 1 } } }
	local ansSt = { family = MONO, weight = 500, size = ansF, spacing = 0.1 * ansF, color = rgb(255, 255, 255), width = m.panelW, align = "center" }
	local ptsSt = { family = MONO, weight = 500, size = ptsF, spacing = 0.08 * ptsF, color = tc }
	local dotSt = { family = MONO, weight = 500, size = ptsF, spacing = 0.08 * ptsF, color = hex("#a7bba3") }
	local restSt = { family = MONO, weight = 500, size = ptsF, spacing = 0.08 * ptsF, color = C.white }
	local blSt = { family = MONO, size = blF, spacing = 0.2 * blF, color = hex("#8aa384"), width = m.panelW, align = "center" }
	-- icon: the tier's pixel sprite at k = max(2, round(64 / w))
	local Sprites = require(script and script.Parent and script.Parent:FindFirstChild("Sprites") or "./Sprites")
	local spr = Sprites[ICON_SPR[t and t.key or ""] or "icoNPC"]
	local k = math.max(2, math.floor(64 / spr.w + 0.5))
	local iconW, iconH = spr.w * k, spr.h * k
	local nw, nh = Kit.measure(name, nameSt)
	local aw, ah = Kit.measure(answer, ansSt)
	local pw = Kit.measure(pts, ptsSt) + Kit.measure("·", dotSt) + 0.8 * ptsF + Kit.measure(rest, restSt)
	local bw, bh = Kit.measure(blurb, blSt)
	local contentH = iconH + 1.2 * m.u + nh + 0.7 * ansF + ah + 0.9 * ptsF + Kit.lh(ptsF) + 0.8 * blF + bh
	-- KEEP FLUSHING at the bottom (margin-bottom clamp(14px, 5vh, 52px)), middle block centred above it
	local btnF = 16
	local btnLabel = r.last and "RESURFACE" or "KEEP FLUSHING"
	local tri = r.last and "▲" or "▼"
	local btnSt = { family = MONO, weight = 600, size = btnF, spacing = 0.3 * btnF, color = hex("#e8f4fb") }
	local lbW = Kit.measure(btnLabel, btnSt)
	local trW = Kit.measure(tri, { family = MONO, weight = 600, size = btnF })
	local btnW = lbW + 0.5 * btnF + trW + 2 * 2.2 * btnF + 6
	local btnH = math.max(3.2 * btnF, Kit.lh(btnF) + 2 * 0.3 * btnF + 6)
	local btnY = m.H - Css.clamp(14, Css.vh(5), 52) - btnH
	local midTop, midBot = m.stageY, btnY
	local y = midTop + ((midBot - midTop - Css.vh(6)) - contentH) / 2
	local cx = m.W / 2
	-- halo: radial gradient (32% -> 10% at 45% -> 0 at 70%) 150px
	local hc = { tc.R * 255, tc.G * 255, tc.B * 255 }
	local halo = Canvas.image(150, 150)
	for py = 0, 149 do
		for pxx = 0, 149 do
			local dd = math.sqrt((pxx + 0.5 - 75) ^ 2 + (py + 0.5 - 75) ^ 2) / 75
			local a = dd < 0.45 and (0.32 + (0.10 - 0.32) * dd / 0.45) or (dd < 0.7 and 0.10 * (1 - (dd - 0.45) / 0.25) or 0)
			if a > 0 then Canvas.setPixel(halo, pxx, py, math.floor(hc[1]), math.floor(hc[2]), math.floor(hc[3]), math.floor(a * 255 + 0.5)) end
		end
	end
	if Kit.makeImage then
		local im = Kit.makeImage(150, 150); im:write(halo.px)
		local l = im:label(); l.Position = Kit.UDim2.fromOffset(cx - 75, y + iconH / 2 - 75); l.Size = Kit.UDim2.fromOffset(150, 150); l.Parent = self.reveal
	end
	local iconHolder = Game.sprite(self.reveal, spr == Sprites.icoNPC and "icoNPC" or ICON_SPR[t and t.key or ""] or "icoNPC", cx - iconW / 2, y, k)
	self.revealIcon = iconHolder
	y += iconH + 1.2 * m.u
	Kit.text(self.reveal, cx - nw / 2, y, name, nameSt)
	y += nh + 0.7 * ansF
	Kit.text(self.reveal, m.panelX, y, answer, ansSt, m.panelW)
	y += ah + 0.9 * ptsF
	local x = cx - pw / 2
	Kit.text(self.reveal, x, y, pts, ptsSt); x += Kit.measure(pts, ptsSt) + 0.4 * ptsF
	Kit.text(self.reveal, x, y, "·", dotSt); x += Kit.measure("·", dotSt) + 0.4 * ptsF
	Kit.text(self.reveal, x, y, rest, restSt)
	y += Kit.lh(ptsF) + 0.8 * blF
	Kit.text(self.reveal, m.panelX, y, blurb, blSt, m.panelW)
	-- the button
	local bx = cx - btnW / 2
	local btn = Kit.box(self.reveal, bx, btnY, btnW, btnH, { bg = rgb(12, 20, 14), bgA = 0.92, border = 3, bc = hex("#7dff6a"), glow = { 18, hex("#7dff6a"), 0.3 } })
	local lx = (btnW - (lbW + 0.5 * btnF + trW)) / 2
	Kit.text(btn, lx, (btnH - Kit.lh(btnF)) / 2, btnLabel, btnSt)
	Kit.text(btn, lx + lbW + 0.5 * btnF, (btnH - Kit.lh(btnF)) / 2, tri, { family = MONO, weight = 600, size = btnF, color = hex("#e8f4fb") })
	hitButton(btn, 0, 0, btnW, btnH, self.cb.onNext)
	if r.endless then
		local eb = Kit.box(self.reveal, bx + btnW + 12, btnY, 140, btnH, { bg = rgb(16, 26, 20), bgA = 0.88, border = 2, bc = hex("#9dff7a") })
		local es = { family = MONO, weight = 600, size = 14, spacing = 0.14 * 14, color = hex("#c8ff9e") }
		Kit.text(eb, (140 - Kit.measure("END RUN ▲", es)) / 2, (btnH - Kit.lh(14)) / 2, "END RUN ▲", es)
		hitButton(eb, 0, 0, 140, btnH, self.cb.onEndRun)
	end
end

---------------------------------------------------------------- sinking answer card + tier lines
function Game:showSink(r, sinkFrom)
	clear(self.sinkLayer); clear(self.tierLines)
	self.sinkFrom = sinkFrom
	if not r then self.sinkCard = nil; return end
	local m = self.m
	local t = Game.TIERS[r.score] or Game.TIERS[10]
	local tc = t.color
	local f = Css.cr(1.1, 0.8, 1, 1.9)
	local text = ("“" .. r.answer .. "”"):upper()
	local st = { family = MONO, weight = 600, size = f, spacing = 0.12 * f, color = tc, shadows = { { 0, 0, 12, tc, 0.55 } } }
	local tw = Kit.measure(text, st)
	local cw = Kit.measure("▼", { family = MONO, weight = 600, size = 0.7 * f })
	local padX, padY = 1.3 * f, 0.6 * f
	local w = tw + 0.7 * f + cw + 2 * padX
	local h = Kit.lh(f) + 2 * padY
	local card = Kit.new("Frame"); card.BackgroundTransparency = 1; card.Size = Kit.UDim2.fromOffset(w, h); card.Parent = self.sinkLayer
	Kit.frame(card, 8, 0, w - 16, h, rgb(16, 22, 17), 0.9); Kit.frame(card, 0, 4, 8, h - 8, rgb(16, 22, 17), 0.9); Kit.frame(card, w - 8, 4, 8, h - 8, rgb(16, 22, 17), 0.9)
	Kit.text(card, padX, padY, text, st)
	Kit.text(card, padX + tw + 0.7 * f, padY + (Kit.lh(f) - Kit.lh(0.7 * f)) / 2, "▼", { family = MONO, weight = 600, size = 0.7 * f, color = tc })
	self.sinkCard = { holder = card, w = w, h = h, t0 = os.clock() }
	-- tier threshold lines (dashed) with "<ICON> NAME · SCORE" labels on the right
	self.tl = {}
	local tf = m.narrow and 10.56 or 12.8
	for _, sc in TIER_ORDER do
		local tt = Game.TIERS[sc]
		local holder = Kit.new("Frame"); holder.BackgroundTransparency = 1; holder.Size = Kit.UDim2.fromOffset(m.W, 2); holder.Visible = false; holder.Parent = self.tierLines
		local right = m.W - (m.gw + 4)
		local x = 0
		while x < right do Kit.frame(holder, x, 0, math.min(6, right - x), 2, hex("#dfe8f2"), 0.38); x += 10 end
		local ls = { family = MONO, size = tf, spacing = (m.narrow and 0.12 or 0.2) * tf, color = hex("#c9d5e3") }
		local label = tt.name:upper() .. " · " .. sc
		local lw = Kit.measure(label, ls)
		local lx = right - 10 - lw
		Kit.text(holder, lx, -6 - Kit.lh(tf), label, ls)
		Game.sprite(holder, ICON_SPR[tt.key], lx - 0.55 * tf - 18, -6 - Kit.lh(tf) + (Kit.lh(tf) - 18) / 2, math.max(1, math.floor(18 / 32 + 0.5)))
		table.insert(self.tl, { holder = holder, d = tt.depth })
	end
end

---------------------------------------------------------------- per-frame: labels, ruler, YOU, sink card
-- O = the Ocean module (depthToScreenY etc.), sinking = bool
function Game:update(O, sinking)
	local m = self.m
	local H = m.H
	for _, L in self.dl do
		local y = O.depthToScreenY(L.m)
		local vis = y >= -30 and y <= H + 30
		L.holder.Visible = vis and sinking
		if vis then L.holder.Position = Kit.UDim2.fromOffset(L.x, math.floor(y + 0.5)) end
	end
	if sinking and self.tl then
		for _, T in self.tl do
			local y = O.depthToScreenY((self.sinkFrom or 0) + T.d)
			T.holder.Visible = y >= -20 and y <= H + 20
			T.holder.Position = Kit.UDim2.fromOffset(0, math.floor(y + 0.5))
		end
	end
	-- ruler: a tick every 25 m, labels every 100 m
	local top, bot = O.screenYToDepth(0), O.screenYToDepth(H)
	local i = 0
	local d = math.ceil(math.max(0, top) / 25) * 25
	while d <= bot do
		i += 1
		local tk = self.ticks[i]
		local major = d % 100 == 0
		if not tk or tk.major ~= major or tk.d ~= d then
			if tk then tk.holder:Destroy() end
			local holder = Kit.new("Frame"); holder.BackgroundTransparency = 1; holder.Size = Kit.UDim2.fromOffset(m.gw, 2); holder.Parent = self.gauge
			if major then
				Kit.frame(holder, m.gw - 12 - 16, 0, 16, 2, rgb(190, 206, 224), 0.7)
				local f = m.narrow and 9.28 or 10.88
				local st = { family = MONO, size = f, color = C.muted }
				local label = d == 0 and "0m" or ("-" .. fmt(d) .. "m")
				local w = Kit.measure(label, st)
				Kit.text(holder, m.gw - 12 - 22 - w, -Kit.lh(f) / 2, label, st)
			else
				Kit.frame(holder, m.gw - 12 - 8, 0, 8, 1, rgb(170, 190, 212), 0.45)
			end
			tk = { holder = holder, major = major, d = d }
			self.ticks[i] = tk
		end
		tk.holder.Position = Kit.UDim2.fromOffset(m.W - m.gw, math.floor(O.depthToScreenY(d) + 0.5))
		tk.holder.Visible = true
		d += 25
	end
	for j = i + 1, #self.ticks do self.ticks[j].holder.Visible = false end
	local p = O.shrimpScreen()
	self.you.Position = Kit.UDim2.fromOffset(m.W - self.you.Size.X.Offset, math.floor(p.y + 0.5))
	if self.sinkCard then
		local sc = self.sinkCard
		local tt = os.clock() - sc.t0
		local wob = math.sin(tt / 1.3 * 2 * math.pi)
		sc.holder.Position = Kit.UDim2.fromOffset(math.floor(m.W / 2 - sc.w / 2 + wob * 4 + 0.5), math.floor(p.y - 46 - sc.h / 2 + math.abs(wob) * 4 + 0.5))
	end
	-- caret blink
	if self.caret then self.caret.Visible = (math.floor(os.clock() * 2) % 2 == 0) end
end

return Game
