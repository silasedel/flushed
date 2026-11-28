-- FLUSHED client: the website (https://silasedel.github.io/flushed/) rebuilt for Roblox.
-- The scene is js/ocean.js ported line for line (Ocean.luau) and drawn into an EditableImage every frame; every
-- screen is the website's CSS as maths (TitleScreen / GameScreen / ResultsScreen / Panels), in the website's fonts.
-- The server (ServerScriptService.Flushed) owns the clock, judges answers and pays coins; this script only shows
-- things and forwards input.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local AssetService = game:GetService("AssetService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local here = script.Parent
local Kit = require(here.Kit)
local Ocean = require(here.Ocean)
local Title = require(here.TitleScreen)
local GameUI = require(here.GameScreen)
local Results = require(here.ResultsScreen)
local Panels = require(here.Panels)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Css = Kit.Css
local rgb, hex = Kit.rgb, Kit.hex
local fmt = GameUI.fmt
local TIERS = GameUI.TIERS

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Flushed")
local push = ReplicatedStorage:WaitForChild("FlushedPush")

-- Roblox's own chat / player list / backpack would sit on top of the game: hide them (the Roblox menu stays)
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false) then break end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- pixel images (EditableImage, with a Frames fallback)
local imagesOk = true
local function frameImage(w, h)
	-- fallback when Roblox won't give us an EditableImage: the buffer drawn as runs of Frames
	local obj = {}
	function obj:write(buf) self.buf = buf end
	function obj:label()
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		local buf = self.buf
		if buf then
			for y = 0, h - 1 do
				local x0, key = nil, nil
				for x = 0, w do
					local k = nil
					if x < w then
						local v = buffer.readu32(buf, (y * w + x) * 4)
						if v >= 0x10000000 then k = v end
					end
					if k ~= key then
						if key then
							local f = Instance.new("Frame")
							f.BorderSizePixel = 0
							f.BackgroundColor3 = Color3.fromRGB(key % 256, (key // 256) % 256, (key // 65536) % 256)
							f.BackgroundTransparency = 1 - (key // 16777216) / 255
							f.Position = UDim2.fromOffset(x0, y); f.Size = UDim2.fromOffset(x - x0, 1)
							f.Parent = holder
						end
						x0, key = x, k
					end
				end
			end
		end
		return holder
	end
	return obj
end
Kit.makeImage = function(w, h)
	if imagesOk then
		local ok, ei = pcall(function() return AssetService:CreateEditableImage({ Size = Vector2.new(w, h) }) end)
		if ok and ei then
			local obj = {}
			function obj:write(buf) ei:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf) end
			function obj:label(smooth)
				local l = Instance.new("ImageLabel")
				l.BackgroundTransparency = 1
				l.BorderSizePixel = 0
				l.ImageContent = Content.fromObject(ei)
				l.ResampleMode = smooth and Enum.ResamplerMode.Default or Enum.ResamplerMode.Pixelated
				l.Destroying:Connect(function() ei:Destroy() end)
				return l
			end
			return obj
		elseif not ok and tostring(ei):find("permission") then
			imagesOk = false
			warn("[FLUSHED] EditableImage is off for this game. Turn on Game Settings > Security > Allow Mesh / Image APIs (the creator must be ID-verified, 13+). Using a slower fallback.")
		end
	end
	return frameImage(w, h)
end

-- small text is drawn at 2x and smoothed down so thin strokes never vanish (and stays sharp on phones' dense screens)
Kit.smallTextScale = 2
Kit.minTextSize = 10 -- nothing smaller than 10px: every line of fine print stays readable

---------------------------------------------------------------- screen guis
local pg = player:WaitForChild("PlayerGui")
local sceneGui = Instance.new("ScreenGui")
sceneGui.Name = "FlushedScene"; sceneGui.IgnoreGuiInset = true; sceneGui.ResetOnSpawn = false; sceneGui.DisplayOrder = 0
sceneGui.ScreenInsets = Enum.ScreenInsets.None
sceneGui.Parent = pg
local gui = Instance.new("ScreenGui")
gui.Name = "Flushed"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 1
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Parent = pg

-- background colour under everything (the website's body: #14201a)
local bg = Instance.new("Frame")
bg.BackgroundColor3 = hex("#14201a"); bg.BorderSizePixel = 0; bg.Size = UDim2.fromScale(1, 1); bg.Parent = sceneGui
local sceneLabel = Instance.new("ImageLabel")
sceneLabel.Name = "Ocean"; sceneLabel.BackgroundTransparency = 1; sceneLabel.Size = UDim2.fromScale(1, 1)
sceneLabel.ResampleMode = Enum.ResamplerMode.Pixelated; sceneLabel.Parent = sceneGui
local sceneImg, sceneW, sceneH = nil, 0, 0

local function layer(name, z, class)
	local f = Instance.new(class or "Frame")
	f.Name = name; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1); f.ZIndex = z
	f.Parent = gui
	return f
end
local screenRoot = layer("Screen", 1)
local chromeRoot = layer("Chrome", 2)
local overlayRoot = layer("Overlay", 3, "CanvasGroup") -- a CanvasGroup so menus can fade in as one
local toastRoot = layer("Toast", 4)

---------------------------------------------------------------- state
local S = {
	screen = "title", len = 10, profile = nil, muted = false,
	settings = { sound = true, ambience = false, reduced = false, showMeta = false },
	overlay = nil, -- function that (re)builds the open overlay
	results = nil, resultsScroll = 0,
}
local G = nil -- the running game
local gameUI = nil
local busy = false
local function nowMs() return os.clock() * 1000 end

local function call(action, args)
	local ok, res = pcall(function() return remote:InvokeServer(action, args or {}) end)
	if not ok then return { error = "Connection problem. Try again." } end
	return res or { error = "No answer from the server." }
end

local function clear(f) for _, c in f:GetChildren() do c:Destroy() end end
-- toasts slide up 20px and fade in (like the website's .toast transition), then slide back down and fade out
local toastSeq = 0
local function toast(msg)
	clear(toastRoot)
	toastSeq += 1
	local my = toastSeq
	local cg = Instance.new("CanvasGroup")
	cg.BackgroundTransparency = 1; cg.Size = UDim2.fromScale(1, 1); cg.GroupTransparency = 1
	cg.Position = UDim2.fromOffset(0, 20)
	cg.Parent = toastRoot
	local box = Panels.toast(cg, msg)
	local info = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(cg, info, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }):Play()
	task.delay(2.4, function()
		if my ~= toastSeq then return end
		local t = TweenService:Create(cg, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1, Position = UDim2.fromOffset(0, 20) })
		t:Play()
		t.Completed:Wait()
		if my == toastSeq then cg:Destroy() end
	end)
	return box
end

---------------------------------------------------------------- sounds: slices of one sound file (Config.SFX_ID)
local sfxTemplate = nil
if Config.SFX_ID ~= "" then
	sfxTemplate = Instance.new("Sound")
	sfxTemplate.SoundId = Config.SFX_ID
	sfxTemplate.Volume = 0.8
	sfxTemplate.PlaybackRegionsEnabled = true
	sfxTemplate.Parent = SoundService
	task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({ sfxTemplate }) end) end)
end
local function play(name, length)
	if not sfxTemplate or not S.settings.sound or S.muted then return end
	local slot = Config.SOUND_SLOTS[name]
	if not slot then return end
	local s = sfxTemplate:Clone()
	s.PlaybackRegion = NumberRange.new(slot * 4, slot * 4 + (length or 3.95))
	s.Parent = SoundService
	s:Play()
	task.delay((length or 3.95) + 0.2, function() s:Destroy() end)
end

---------------------------------------------------------------- profile helpers
local function coins() return S.profile and S.profile.coins or 0 end
local function rankedLen() return S.len == 0 and Config.ENDLESS_RANKED_LENGTH or S.len end
local function price() return S.profile and S.profile.prices and S.profile.prices[tostring(rankedLen())] or 0 end
local function boost() return S.profile and S.profile.boost or { x = 1, why = "" } end
local function shopItem(id) for _, s in Config.SHOP do if s.id == id then return s end end return nil end
local function applySkin()
	local eq = S.profile and S.profile.equip or {}
	local d, t, tr = shopItem(eq.duck or "") or {}, shopItem(eq.toilet or "") or {}, shopItem(eq.trail or "") or {}
	Ocean.setSkin({ duckTint = d.fx == "rainbow" and nil or d.tint, duckFx = d.fx, toiletSprite = t.sprite, toiletTint = t.tint, toiletFx = t.fx, trail = tr.trail })
end
local function setProfile(p)
	if not p or p.error then return end
	S.profile = p
	applySkin()
end

---------------------------------------------------------------- chrome: menu button, sound / settings rail, coin corner
local render -- forward
local openMenu, openSettings, openStats, openShop, openHelp, openPlayAgain, showTitle, showPacks
local function railButton(parent, x, y, icon, fn)
	local b = Kit.box(parent, x, y, 40, 40, { bg = rgb(22, 32, 22), bgA = 0.78, border = 1, bc = rgb(167, 187, 163), bcA = 0.25 })
	Kit.icon(b, icon, 10, 10, 20, hex("#f2f8fc"), 1)
	Panels.hit(b, 0, 0, 40, 40, fn)
	return b
end
-- Roblox draws its own menu button in the top-left corner: keep ours just below it when they'd overlap
local function topbarBottom()
	local ok, r = pcall(function() return GuiService.TopbarInset end)
	if ok and r and r.Height > 0 then return r.Max.Y end
	return 0
end
local function buildChrome()
	clear(chromeRoot)
	local W, H = Css.W, Css.H
	local scr = S.screen
	local narrow, xs = W <= 760, W <= 700
	local top = Css.clamp(10, Css.vh(2.4), 26)
	local side = Css.clamp(8, Css.vw(1.4), 20)
	if scr ~= "game" then
		local ly = math.max(top, topbarBottom() + 6)
		railButton(chromeRoot, side, ly, "menu", function() openMenu() end)
	end
	if scr ~= "title" and scr ~= "game" then
		local x, y = W - side - 40, top
		railButton(chromeRoot, x, y, S.muted and "mute" or "sound", function() S.muted = not S.muted; render() end)
		if narrow then x -= 44 else y += 44 end
		railButton(chromeRoot, x, y, "gear", function() openSettings() end)
	end
	-- coin balance (earned coins; looks in the shop cost Robux)
	if scr == "game" and xs then return end
	local f = xs and 13.6 or 16
	local h = xs and 30 or 36
	local cw = Panels.coinW(coins(), f)
	local w = cw + 2 * 0.8 * f + 4
	local x = W - (xs and 8 or 12) - w
	local y = xs and 8 or 12
	if scr == "results" or scr == "packs" then x = W - 64 - w end
	if scr == "game" then y = H - 12 - h end
	local box = Kit.box(chromeRoot, x, y, w, h, { bg = rgb(10, 14, 12), bgA = 0.85, border = 2, bc = rgb(255, 255, 255), bcA = 0.55 })
	Panels.coinTag(box, 2 + 0.8 * f, 0, coins(), f, rgb(255, 255, 255), 0, false, h - 4 + 2)
end

---------------------------------------------------------------- overlays
local function closeOverlay()
	S.overlay = nil
	for _, c in overlayRoot:GetChildren() do if not c:IsA("UIScale") then c:Destroy() end end
end
overlayRoot.AnchorPoint = Vector2.new(0.5, 0.5); overlayRoot.Position = UDim2.fromScale(0.5, 0.5)
local overlayScale = Instance.new("UIScale"); overlayScale.Parent = overlayRoot
local function openOverlay(builder)
	local fresh = S.overlay == nil
	S.overlay = builder
	for _, c in overlayRoot:GetChildren() do if not c:IsA("UIScale") then c:Destroy() end end
	builder()
	if fresh and not S.settings.reduced then -- fade + settle in (website: .15s fade, .2s pop)
		overlayRoot.GroupTransparency = 1; overlayScale.Scale = 0.97
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(overlayRoot, info, { GroupTransparency = 0 }):Play()
		TweenService:Create(overlayScale, info, { Scale = 1 }):Play()
	else
		overlayRoot.GroupTransparency = 0; overlayScale.Scale = 1
	end
end

openHelp = function() openOverlay(function() Panels.help(overlayRoot, { onClose = closeOverlay }) end) end
openSettings = function()
	openOverlay(function()
		Panels.settings(overlayRoot, { sound = S.settings.sound and not S.muted, ambience = S.settings.ambience, reduced = S.settings.reduced, showMeta = S.settings.showMeta,
			prompts = S.profile and S.profile.bankPrompts or 0, answers = S.profile and S.profile.bankAnswers or 0 }, {
			onClose = closeOverlay,
			onToggle = function(k, v)
				if k == "sound" then S.settings.sound = v; S.muted = false else S.settings[k] = v end
				if k == "reduced" then Ocean.setReduced(v) end
				openSettings(); buildChrome()
			end,
		})
	end)
end
openStats = function()
	local p = call("profile")
	setProfile(p)
	local st = (S.profile and S.profile.stats) or {}
	local bins, tiers = {}, {}
	for i = 1, 10 do bins[i] = (st.bins or {})[tostring(i)] or 0 end
	for k, v in st.tiers or {} do tiers[tonumber(k)] = v end
	openOverlay(function()
		Panels.stats(overlayRoot, { games = st.games, best = st.best, avg = st.avg, avgPer = st.avgPer, deepest = st.deepest, answeredPct = st.answeredPct, bins = bins, tiers = tiers }, {
			onClose = closeOverlay,
			onReset = function() toast("Stats live on the server. Ask the game owner to reset them.") end,
		})
	end)
end
openShop = function()
	openOverlay(function()
		local p = S.profile or {}
		local items, any = {}, false
		for _, it in Config.SHOP do
			local d = table.clone(it)
			d.robux = it.type ~= "boost"
			d.owned = (p.owned or {})[it.id] and true or false
			d.equipped = d.owned and (p.equip or {})[it.type] == it.id
			if d.owned then any = true end
			d.preview = it.type == "toilet" and (it.sprite or "toilet") or "duck0"
			d.ph = it.type == "toilet" and 15 or 13
			d.tint = it.fx == "rainbow" and "~#ff7ad9" or it.tint
			table.insert(items, d)
		end
		local _, _, box = Panels.shop(overlayRoot, { coins = coins(), items = items, boosts = (p.boosts or {}).time or 0, anyOwned = any }, {
			onClose = closeOverlay,
			onBuy = function(id)
				local it = shopItem(id)
				if not it then return end
				if it.type == "boost" then
					local r = call("buy", { id = id })
					if r.error then toast(r.error) else setProfile(r); play("buy"); openShop(); buildChrome() end
				else
					local r = call("buyRobux", { id = id })
					if r.error then toast(r.error) end
				end
			end,
			onEquip = function(id)
				local r = call("equip", { id = id })
				if r.error then toast(r.error) else setProfile(r); openShop() end
			end,
			onDefault = function()
				for _, t in { "duck", "toilet", "trail" } do
					local cur = S.profile and S.profile.equip and S.profile.equip[t]
					if cur then setProfile(call("equip", { id = cur })) end
				end
				openShop()
			end,
		})
		if S.shopScroll and box then box.CanvasPosition = S.shopScroll end
		if box then box:GetPropertyChangedSignal("CanvasPosition"):Connect(function() S.shopScroll = box.CanvasPosition end) end
	end)
end
openPlayAgain = function()
	openOverlay(function()
		Panels.playAgain(overlayRoot, { len = S.len, price = price(), coins = coins(), boost = boost() }, {
			onClose = closeOverlay,
			onLen = function(n) S.len = n; openPlayAgain() end,
			onFlush = function() closeOverlay(); S.startGame("unlimited") end,
			onRanked = function() closeOverlay(); S.startGame("ranked") end,
		})
	end)
end
local function confirm(msg, fn)
	openOverlay(function() Panels.confirm(overlayRoot, msg, function() closeOverlay(); fn() end, closeOverlay) end)
end
openMenu = function()
	openOverlay(function()
		local items = {
			{ label = "HOME", icon = "home", act = "home" }, { label = "PLAY", icon = "play", act = "unlimited" }, { label = "THEMED PACKS", icon = "cube", act = "packs" },
			{ label = "SHOP", icon = "cube", act = "shop" }, { label = "STATISTICS", icon = "chart", act = "stats" }, { label = "SETTINGS", icon = "gear", act = "settings" },
			{ label = "HOW TO PLAY", icon = "help", act = "help" },
		}
		if G then table.insert(items, { label = "QUIT FLUSH", icon = "close", act = "quit", danger = true }) end
		local active = S.screen == "title" and "home" or S.screen == "packs" and "packs" or (S.screen == "game" and "unlimited") or nil
		local total = 0
		for _, pk in (S.profile and S.profile.packs) or {} do total += pk.count or 0 end
		Panels.menu(overlayRoot, items, active, total > 0 and (fmt(S.profile.bankPrompts or total) .. " prompts in the deep") or "", function(act)
			closeOverlay()
			if act == "home" then showTitle()
			elseif act == "unlimited" then if G then render() else S.startGame("unlimited") end
			elseif act == "packs" then showPacks()
			elseif act == "shop" then openShop()
			elseif act == "stats" then openStats()
			elseif act == "settings" then openSettings()
			elseif act == "help" then openHelp()
			elseif act == "quit" then S.quit() end
		end, closeOverlay)
	end)
end

---------------------------------------------------------------- the game
local INTRO = Config.INTRO_SECONDS
local function promptLabel()
	local r = G.ranked and "RANKED · " or ""
	if G.len > 0 then return string.format("%sPROMPT %d OF %d", r, G.idx, G.len) end
	return string.format("PROMPT %d · ENDLESS", G.idx)
end
local function renderHud(depthShown)
	if not (G and gameUI) then return end
	gameUI:setHud(depthShown or G.shownDepth or G.depth, G.score)
	local pips = {}
	local from, to = 1, G.len
	if G.len == 0 then from = math.max(1, G.idx - 8); to = from + 9 end
	for i = from, to do
		local r = G.results[i]
		if r then table.insert(pips, r.score > 0 and { state = "done", color = TIERS[r.score].color } or { state = "miss" })
		elseif i == G.idx then table.insert(pips, { state = "cur" })
		else table.insert(pips, { state = "todo" }) end
	end
	local label = promptLabel()
	if G.phase == "reveal" and G.len > 0 and G.idx >= G.len then label = "FLUSH COMPLETE" end
	gameUI:setProgress(pips, label)
end

local function focusInput()
	if gameUI and gameUI.textBox and not UserInputService.TouchEnabled then
		task.defer(function() if gameUI and gameUI.textBox then gameUI.textBox:CaptureFocus() end end)
	end
end

local function beginPrompt(pv, fresh)
	G.idx = pv.idx; G.prompt = pv.prompt; G.seconds = pv.seconds; G.fix = nil
	if gameUI then
		gameUI:showReveal(nil); gameUI:showSink(nil); gameUI:setFeedback(nil); gameUI:setSuggest(nil)
		gameUI.textBox.Text = ""
		gameUI:setPrompt(pv.prompt, promptLabel(), fresh)
	end
	if fresh then
		G.phase = "intro"; G.phaseEnd = os.clock() + INTRO
		Ocean.setView("intro", true); Ocean.flush(nowMs())
		play("flush")
	else
		G.phase = "answering"; G.phaseEnd = os.clock() + G.seconds
		if gameUI then gameUI:setIntro(nil) end
		focusInput()
	end
	renderHud()
end

local function revealNow()
	if not G then return end
	G.phase = "reveal"
	local r = G.results[G.idx]
	if gameUI then
		gameUI:setIntro(nil)
		gameUI:showReveal({ score = r.score, answer = r.answer, input = r.input, reason = r.reason, last = G.len > 0 and G.idx >= G.len, endless = G.len == 0 })
	end
	renderHud()
end

local function accept(res)
	local t = TIERS[res.score]
	G.results[G.idx] = { score = res.score, answer = res.answer, input = res.input, q = G.prompt }
	G.sinkFrom = G.depth
	G.score += res.score
	G.depth += t.depth
	G.phase = "sinking"
	play("correct" .. res.score)
	task.delay(S.settings.reduced and 0 or 0.45, function() play("descend" .. res.score) end)
	if gameUI then
		gameUI:setFeedback(nil); gameUI:setSuggest(nil)
		gameUI:showSink({ score = res.score, answer = res.answer }, G.sinkFrom)
	end
	Ocean.setShrimpX(0.5)
	local dur = S.settings.reduced and 0 or (1500 + t.depth * 1.9)
	local myGame = G
	task.delay(S.settings.reduced and 0 or 0.45, function()
		if G ~= myGame then return end
		Ocean.setDepth(G.depth, nowMs(), { duration = dur })
	end)
	task.delay(S.settings.reduced and 0.3 or (0.45 + dur / 1000 + 0.45), function()
		if G ~= myGame or G.phase ~= "sinking" then return end
		if gameUI then gameUI:showSink(nil) end
		Ocean.setShrimpX(nil)
		G.shownDepth = G.depth
		revealNow()
	end)
	renderHud(G.sinkFrom)
end

local function missWith(reason, input)
	G.results[G.idx] = { score = 0, answer = nil, input = input, reason = reason, q = G.prompt }
	play("miss")
	revealNow()
end

local function submit(text)
	if not G or G.phase ~= "answering" or busy then return end
	text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return end
	busy = true
	local r = call("submit", { text = text })
	busy = false
	if not G or G.phase ~= "answering" then return end
	if r.error then toast(r.error) return end
	if r.result == "hit" then
		r.input = text
		accept(r)
	elseif r.result == "suggest" then
		G.fix = r.label
		if gameUI then
			gameUI:setSuggest(text, r.label)
			gameUI:setFeedback(nil)
			gameUI.textBox.Text = r.label
		end
		focusInput()
	elseif r.result == "dup" then
		play("dup")
		if gameUI then gameUI:setFeedback(string.format('Already tried "%s".', text), "warn") end
		focusInput()
	elseif r.result == "miss" then
		if gameUI then gameUI:setSuggest(nil); gameUI:setFeedback(string.format('"%s" isn\'t on our list. Try again!', text), "bad") end
		play("wrong")
		focusInput()
	elseif r.result == "timeout" then
		missWith("time", text)
	end
end

local function timeUp()
	if not G or G.phase ~= "answering" then return end
	G.phase = "waiting"
	local text = gameUI and gameUI.textBox.Text or ""
	local r = call("timeout", { text = text })
	if not G then return end
	if r.result == "hit" then r.input = text; G.phase = "answering"; accept(r)
	else missWith("time", text ~= "" and text or nil) end
end

local function showResultsFrom(res)
	S.lastResult = res
	local n = res.prompts or #res.rows
	local mode
	if res.pack then mode = string.upper((res.packName or res.pack) .. " PACK COMPLETE")
	elseif res.ranked then mode = string.format("RANKED %d-PROMPT FLUSH", n)
	elseif (res.len or 0) == 0 then mode = string.format("ENDLESS RUN · %d PROMPTS", n)
	else mode = string.format("%d-PROMPT FLUSH COMPLETE", n) end
	local depth = res.depth or 0
	local line
	if res.cheated then line = { { "Cheat code used · no coins this time" } }
	elseif res.ranked then line = { { "Paid out " }, { fmt(res.paid or 0) .. " coins", bold = true } }
	else line = { { "Free game · +" .. fmt(res.paid or 0) .. " coins · play " }, { "Ranked", bold = true }, { " to win more" } } end
	local rows = {}
	for _, r in res.rows do table.insert(rows, { score = r.score, q = r.q, answer = r.answer, input = r.input, reason = r.reason, tries = r.tries }) end
	S.results = {
		modeLabel = mode, score = res.score, depth = depth, n = n,
		zone = depth > 0 and ("Reached the " .. Ocean.ZONES[Ocean.zoneIndex(depth) + 1].name) or "Never left the bowl",
		coinsLine = line, results = rows, stats = res.logbook, againLabel = res.pack and "PLAY PACK AGAIN" or "PLAY AGAIN",
		expanded = {}, pack = res.pack, countUp = true,
	}
	S.resultsScroll = 0
	if res.profile then setProfile(res.profile) end
	G = nil
	S.screen = "results"
	Ocean.setView("results")
	play("finish")
	render()
	S.results.countUp = false
end

local function nextPrompt()
	if not G or G.phase ~= "reveal" or busy then return end
	busy = true
	local r = call("next")
	busy = false
	if r.error then toast(r.error) return end
	if r.done then showResultsFrom(r) return end
	if r.prompt then beginPrompt(r.prompt, false) end
end

local function endRun()
	if not G or busy then return end
	busy = true
	local r = call("endRun")
	busy = false
	if r.error then toast(r.error) return end
	showResultsFrom(r)
end

function S.startGame(mode, packKey)
	if G then render() return end
	if busy then return end
	closeOverlay()
	busy = true
	local r = call("start", { mode = mode, len = S.len, pack = packKey })
	busy = false
	if r.error then toast(r.error) return end
	if S.profile then S.profile.coins = r.coins or S.profile.coins end
	G = { mode = mode, ranked = mode == "ranked", pack = packKey, len = (mode == "ranked" and rankedLen()) or S.len, idx = 1, score = 0, depth = 0, shownDepth = 0, results = {} }
	if r.extraTime then toast("Extra Time boost: +5s every prompt") end
	play("start")
	S.screen = "game"
	Ocean.setDepth(0, nowMs(), { instant = true })
	render()
	beginPrompt(r.prompt, true)
end

function S.quit()
	if not G then return showTitle() end
	local answered = 0
	for _ in G.results do answered += 1 end
	if G.ranked then return confirm("End this ranked run now? You get paid for the points you have so far.", endRun) end
	if G.len == 0 and answered > 0 then return confirm("End this endless run? Your score so far is saved.", endRun) end
	confirm("Quit this flush? Its progress will be thrown away.", function()
		call("endRun")
		G = nil
		Ocean.setDepth(0, nowMs(), { instant = true })
		showTitle()
	end)
end

---------------------------------------------------------------- screens
showTitle = function()
	if G then return render() end
	S.screen = "title"
	Ocean.setView("title")
	render()
end
showPacks = function()
	if G then return render() end
	S.screen = "packs"
	Ocean.setView("menu")
	render()
end

local function rulesText()
	local L = rankedLen()
	local profit = S.profile and S.profile.profitAt and S.profile.profitAt[tostring(S.len)] or 0
	return string.format("Ranked: the %d-coin entry is spent when the run starts · same price for everyone · score %d+ in %d prompts to come out ahead · your first 3 runs pay ×1.3/×1.2/×1.1, and ×1.3 after 3 losses in a row · free games pay coins too · coins are earned by playing, never bought · shop looks cost Robux and are cosmetic", price(), profit, L)
end

local function buildResults()
	local data = S.results
	local root = Results.build(screenRoot, data, {
		onCopy = function()
			local lines = {}
			local sq = { [0] = "⬛", [10] = "⬜", [30] = "🟦", [60] = "🟥", [85] = "🟪", [100] = "🟨" }
			for _, r in data.results do table.insert(lines, sq[r.score] or "⬛") end
			local text = string.format("FLUSHED · %d prompts 🦆\n%d/%d · -%sm\n%s", data.n, data.score, data.n * 100, fmt(data.depth), table.concat(lines))
			openOverlay(function()
				Panels.modal(overlayRoot, "COPY RESULT", function(b, w, U0)
					local tb = Instance.new("TextBox")
					tb.Text = text; tb.ClearTextOnFocus = false; tb.TextEditable = false; tb.MultiLine = true
					tb.Font = Enum.Font.Code; tb.TextSize = 16; tb.TextColor3 = hex("#f2f8fc"); tb.BackgroundColor3 = rgb(16, 26, 20); tb.BorderSizePixel = 0
					tb.TextXAlignment = Enum.TextXAlignment.Left; tb.TextYAlignment = Enum.TextYAlignment.Top
					tb.Position = UDim2.fromOffset(0, 0); tb.Size = UDim2.fromOffset(math.floor(w), 90); tb.Parent = b
					task.defer(function() tb:CaptureFocus(); tb.SelectionStart = 1; tb.CursorPosition = #tb.Text + 1 end)
					Kit.text(b, 0, 100, UserInputService.TouchEnabled and "Hold the text to copy it." or "Selected: press Ctrl+C (Cmd+C on a Mac) to copy.", { family = "plex", size = 0.85 * U0, color = Panels.C.muted })
					return 100 + Kit.lh(0.85 * U0)
				end, closeOverlay)
			end)
		end,
		onShare = function()
			pcall(function() SocialService:PromptGameInvite(player) end)
		end,
		onAgain = function()
			if data.pack then S.startGame("pack", data.pack) else openPlayAgain() end
		end,
		onPacks = showPacks, onStats = openStats, onHome = showTitle,
		onToggle = function(i)
			if data.expanded[i] then data.expanded[i] = nil
			else
				local r = call("answers", { i = i })
				if r.error then return toast(r.error) end
				data.expanded[i] = r.list
			end
			render()
		end,
	})
	root.CanvasPosition = Vector2.new(0, S.resultsScroll or 0)
	root:GetPropertyChangedSignal("CanvasPosition"):Connect(function() S.resultsScroll = root.CanvasPosition.Y end)
end

render = function()
	local size = gui.AbsoluteSize
	if size.X < 10 then return end
	Css.set(size.X, size.Y)
	do -- where Roblox's own top-left buttons end (the game HUD keeps clear of them)
		local ok, r = pcall(function() return GuiService.TopbarInset end)
		GameUI.topbar = (ok and r and r.Height > 0) and { right = r.Min.X, bottom = r.Max.Y } or nil
	end
	clear(screenRoot)
	gameUI = nil
	local scr = S.screen
	if scr == "title" then
		local b = boost()
		Title.build(screenRoot, { coins = coins(), len = S.len, price = price(), boost = b, rules = rulesText(), poor = coins() < price() }, {
			onFlush = function() S.startGame("unlimited") end,
			onRanked = function()
				if coins() < price() then toast(string.format("Ranked costs %d coins. Free games pay coins: play a few first!", price())) return end
				S.startGame("ranked")
			end,
			onLen = function(n) S.len = n; render() end,
			onPacks = showPacks, onShop = openShop, onStats = openStats, onMenu = openMenu, onHowTo = openHelp,
		})
	elseif scr == "game" and G then
		gameUI = GameUI.new(screenRoot, {
			onSubmit = submit,
			onInput = function(t)
				if G and G.fix and t ~= G.fix then G.fix = nil; if gameUI then gameUI:setSuggest(nil) end end
			end,
			onNext = nextPrompt, onEndRun = endRun, onMenu = function() openMenu() end, onQuit = function() S.quit() end,
			onRestart = function() S.quit() end,
			onSound = function() S.muted = not S.muted; render() end,
		})
		gameUI.state.muted = S.muted
		gameUI:setPrompt(G.prompt or "", promptLabel(), G.phase == "intro")
		if G.phase == "intro" then gameUI:setIntro(math.max(1, math.ceil(G.phaseEnd - os.clock()))) end
		if G.phase == "reveal" then revealNow() end
		renderHud()
	elseif scr == "results" and S.results then
		buildResults()
	elseif scr == "packs" then
		local packs = {}
		for _, pk in (S.profile and S.profile.packs) or {} do if pk.key ~= "general" then table.insert(packs, pk) end end
		-- the website's order
		local ORDER = { geography = 1, movies = 2, sports = 3, gaming = 4, science = 5, music = 6, language = 7, pop = 8, fun = 9, general = 10 }
		table.sort(packs, function(a, b) return (ORDER[a.key] or 99) < (ORDER[b.key] or 99) end)
		Panels.packs(screenRoot, packs, { onClose = showTitle, onPick = function(key) S.startGame("pack", key) end })
	else
		S.screen = "title"
		return render()
	end
	buildChrome()
	if S.overlay then
		for _, c in overlayRoot:GetChildren() do if not c:IsA("UIScale") then c:Destroy() end end
		S.overlay()
	end
end

---------------------------------------------------------------- the scene (Ocean) drawn every frame
local function resizeScene()
	local vp = sceneGui.AbsoluteSize
	if vp.X < 10 then return end
	Ocean.resize(vp.X, vp.Y)
	local ctx = Ocean.state.ctx
	if sceneImg then sceneImg:Destroy(); sceneImg = nil end
	sceneW, sceneH = ctx.W, ctx.H
	local ok, ei = pcall(function() return AssetService:CreateEditableImage({ Size = Vector2.new(sceneW, sceneH) }) end)
	if ok and ei then
		sceneImg = ei
		sceneLabel.ImageContent = Content.fromObject(ei)
	else
		warn("[FLUSHED] Couldn't make the scene image:", ei)
	end
end

local lastTimerDraw, lastIntroN, lastTickSec = 0, nil, nil
RunService.RenderStepped:Connect(function()
	local now = nowMs()
	local ctx = Ocean.frame(now)
	if sceneImg and ctx then sceneImg:WritePixelsBuffer(Vector2.zero, Vector2.new(sceneW, sceneH), ctx.buf) end
	if not G then return end
	local t = os.clock()
	if G.phase == "intro" then
		local left = G.phaseEnd - t
		local n = math.max(1, math.ceil(left))
		if n ~= lastIntroN and gameUI then lastIntroN = n; gameUI:setIntro(n) end
		if left <= 0 then
			lastIntroN = nil
			G.phase = "answering"; G.phaseEnd = t + G.seconds
			if gameUI then gameUI:setIntro(nil) end
			Ocean.setView("game"); Ocean.setShrimpX(nil); Ocean.setDepth(0, now, { duration = 900 })
			play("go")
			focusInput()
		end
	elseif G.phase == "answering" then
		local left = math.max(0, G.phaseEnd - t)
		if gameUI and t - lastTimerDraw > 1 / 20 then lastTimerDraw = t; gameUI:setTimer(left, G.seconds) end
		local sec = math.ceil(left)
		if left <= 5 and sec > 0 and sec ~= lastTickSec then lastTickSec = sec; play("tickUrgent", 0.2) end
		if left <= 0 then task.spawn(timeUp) end
	end
	if gameUI then gameUI:update(Ocean, G.phase == "sinking") end
end)
Ocean.onDepth(function(m)
	if G and G.phase == "sinking" and gameUI then gameUI:setHud(math.floor(m + 0.5), G.score) end
end)

-- keyboard: Enter = next on the reveal, M = menu, Esc = close
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if input.KeyCode == Enum.KeyCode.Escape and S.overlay then closeOverlay() return end
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
		if G and G.phase == "reveal" and not S.overlay then nextPrompt()
		elseif not G and S.screen == "title" and not S.overlay then S.startGame("unlimited") end
	elseif input.KeyCode == Enum.KeyCode.M then
		if S.overlay then closeOverlay() else openMenu() end
	end
end)

push.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then return end
	if msg.kind == "profile" then
		setProfile(msg.profile)
		if msg.bought then toast("Unlocked: " .. msg.bought); play("buy") end
		if S.overlay == nil then render() else openOverlay(S.overlay); buildChrome() end
	end
end)

-- relayout when the window / phone rotates
local pending = false
local function relayout()
	if pending then return end
	pending = true
	task.delay(0.15, function()
		pending = false
		resizeScene()
		render()
	end)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
sceneGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)

-- every button clicks (the website's Sound.click)
gui.DescendantAdded:Connect(function(d)
	if d:IsA("TextButton") then d.Activated:Connect(function() play("click", 0.15) end) end
end)

---------------------------------------------------------------- start
resizeScene()
Ocean.setView("title", true)
render()
task.spawn(function()
	for _ = 1, 20 do
		local p = call("profile")
		if p and not p.error and p.coins then setProfile(p); render(); break end
		task.wait(0.5)
	end
end)
