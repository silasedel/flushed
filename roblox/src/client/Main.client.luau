-- FLUSHED client: every screen, built in code (title, prompt, reveal, results, shop, stats).
-- The server does all judging and money; this script only shows things and sends what you type.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Match = require(Shared.Match) -- only for tier names/colors
local remote = ReplicatedStorage:WaitForChild("Flushed")
local player = Players.LocalPlayer

-- FLUSHED is a full-screen single-player game: hide Roblox's player list and chat window so they don't cover
-- the score and coins (coins and best score are shown by the game itself)
local StarterGui = game:GetService("StarterGui")
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		end)
		if ok then break end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- look
local TITLE_FONT = Enum.Font.Arcade
local BODY_FONT = Enum.Font.GothamBold
local INK = Color3.fromRGB(255, 255, 255)
local DIM = Color3.fromRGB(190, 205, 200)
local GOLD = Color3.fromHex("#ffd23f")
local PANEL = Color3.fromRGB(12, 18, 16)
local GREEN = Color3.fromHex("#7dff6a")
local RED = Color3.fromHex("#ff5a5a")

local function make(class, props, children)
	local o = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then o[k] = v end
	end
	for _, c in children or {} do c.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
-- labels get a text outline (Contextual); buttons and boxes get a border (Border), not an outline around their letters
local function stroke(o, thickness, color, border)
	make("UIStroke", { Thickness = thickness or 2, Color = color or Color3.new(0, 0, 0), ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual, Parent = o })
	return o
end
local function maxText(o, px) make("UITextSizeConstraint", { MaxTextSize = px, Parent = o }); return o end
local function label(props)
	local l = make("TextLabel", {
		BackgroundTransparency = 1, Font = props.Font or BODY_FONT, TextColor3 = props.TextColor3 or INK, TextScaled = true,
		TextWrapped = true, Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint or Vector2.zero,
		Text = props.Text or "", TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center, RichText = true,
		Parent = props.Parent, ZIndex = props.ZIndex or 1, LayoutOrder = props.LayoutOrder or 0,
	})
	return maxText(l, props.Max or 28)
end
local function button(props)
	local b = make("TextButton", {
		AutoButtonColor = true, BackgroundColor3 = props.Color or Color3.fromRGB(20, 30, 26), BorderSizePixel = 0,
		Font = props.Font or BODY_FONT, TextColor3 = props.TextColor3 or INK, TextScaled = true, RichText = true,
		Text = props.Text or "", Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint or Vector2.zero,
		Parent = props.Parent, LayoutOrder = props.LayoutOrder or 0, ZIndex = props.ZIndex or 1,
	})
	stroke(b, props.Stroke or 3, props.StrokeColor or INK, true)
	maxText(b, props.Max or 26)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = b })
	return b
end
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local function coinText(n) return "💰" .. commas(n) end

---------------------------------------------------------------- sound
local sounds = {}
for name, id in Config.SOUNDS do
	if id ~= "" then sounds[name] = make("Sound", { SoundId = id, Volume = 0.6, Parent = SoundService }) end
end
local function play(name) if sounds[name] then sounds[name]:Play() end end

---------------------------------------------------------------- server calls
local gui = make("ScreenGui", { Name = "Flushed", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local toastLabel
local function toast(msg)
	toastLabel.Text = msg
	toastLabel.Visible = true
	local token = {}
	toastLabel:SetAttribute("t", tostring(token))
	task.delay(2.6, function() if toastLabel:GetAttribute("t") == tostring(token) then toastLabel.Visible = false end end)
end
local busy = false
local function call(action, args)
	if busy then return nil end
	busy = true
	local ok, res = pcall(remote.InvokeServer, remote, action, args or {})
	busy = false
	if not ok then toast("Connection hiccup, try again."); return nil end
	if type(res) == "table" and res.error then toast(res.error); return nil end
	return res
end

---------------------------------------------------------------- the pixel-art world (Scene.luau): bowl, flush, sewer dive
local Scene = require(script.Parent.Scene)
Scene.init(gui)
local ALL_ITEMS = table.clone(Config.SHOP)
for _, s in Config.ROBUX_PASSES do table.insert(ALL_ITEMS, s) end

-- coins in the corner
local coinCorner = label({ Parent = gui, Size = UDim2.new(0, 170, 0, 36), Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0), Max = 22, ZIndex = 5 })
coinCorner.BackgroundColor3 = PANEL; coinCorner.BackgroundTransparency = 0.15
stroke(coinCorner, 2, GOLD, true)

toastLabel = label({ Parent = gui, Size = UDim2.new(0.6, 0, 0, 44), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 1), Max = 20, ZIndex = 50 })
toastLabel.BackgroundColor3 = PANEL; toastLabel.BackgroundTransparency = 0.05; toastLabel.Visible = false
stroke(toastLabel, 2, INK, true)

local function screen(name)
	local f = make("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	make("UIPadding", { PaddingTop = UDim.new(0, 60), PaddingBottom = UDim.new(0, 70), PaddingLeft = UDim.new(0.06, 0), PaddingRight = UDim.new(0.06, 0), Parent = f })
	return f
end
local screens = { title = screen("Title"), play = screen("Play"), results = screen("Results") }
local function show(name)
	for k, f in screens do f.Visible = (k == name) end
end

---------------------------------------------------------------- state
local profile = nil
local len = 7
local lastMode, lastPack = "free", nil
local function itemById(id)
	for _, s in Config.SHOP do if s.id == id then return s end end
	for _, s in Config.ROBUX_PASSES do if s.id == id then return s end end
	return nil
end

---------------------------------------------------------------- TITLE
local T = screens.title
local titleText = label({ Parent = T, Text = "FLUSHED", Font = TITLE_FONT, Size = UDim2.new(1, 0, 0.16, 0), Max = 110, TextColor3 = GOLD })
stroke(titleText, 4)
local sub = label({ Parent = T, Text = "25 seconds a prompt · rarer answers flush you deeper", Size = UDim2.new(1, 0, 0.05, 0), Position = UDim2.fromScale(0, 0.16), Max = 20 })
stroke(sub, 2)
local skinLabel = label({ Parent = T, Text = "", Size = UDim2.new(1, 0, 0.03, 0), Position = UDim2.fromScale(0, 0.435), Max = 15, TextColor3 = DIM })
local lenRow = make("Frame", { Parent = T, BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0.065, 0), Position = UDim2.fromScale(0.5, 0.47), AnchorPoint = Vector2.new(0.5, 0) }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
label({ Parent = lenRow, Text = "PROMPTS", Size = UDim2.new(0.22, 0, 1, 0), Max = 18, LayoutOrder = 0 })
local lenButtons = {}
for i, L in Config.LENGTHS do
	local b = button({ Parent = lenRow, Text = L == 0 and "∞" or tostring(L), Size = UDim2.new(0.13, 0, 1, 0), LayoutOrder = i, Max = 22 })
	lenButtons[L] = b
end

local flushBtn = button({ Parent = T, Text = "▼  FLUSH  ▼", Font = TITLE_FONT, Size = UDim2.new(0.7, 0, 0.11, 0), Position = UDim2.fromScale(0.5, 0.56), AnchorPoint = Vector2.new(0.5, 0), Color = Color3.fromRGB(16, 40, 22), StrokeColor = GREEN, Stroke = 4, Max = 48, TextColor3 = GREEN })
local rankedBtn = button({ Parent = T, Text = "RANKED", Size = UDim2.new(0.7, 0, 0.075, 0), Position = UDim2.fromScale(0.5, 0.69), AnchorPoint = Vector2.new(0.5, 0), Color = Color3.fromRGB(40, 30, 6), StrokeColor = GOLD, Max = 24, TextColor3 = Color3.fromHex("#ffe27a") })
local fine = label({ Parent = T, Text = "", Size = UDim2.new(0.86, 0, 0.065, 0), Position = UDim2.fromScale(0.5, 0.765), AnchorPoint = Vector2.new(0.5, 0), Max = 14, TextColor3 = DIM, Font = Enum.Font.GothamMedium })
fine.BackgroundColor3 = PANEL; fine.BackgroundTransparency = 0.2 -- readable on the light bowl water
make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = fine })
local row2 = make("Frame", { Parent = T, BackgroundTransparency = 1, Size = UDim2.new(0.7, 0, 0.065, 0), Position = UDim2.fromScale(0.5, 0.85), AnchorPoint = Vector2.new(0.5, 0) }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) }),
})
local packsBtn = button({ Parent = row2, Text = "THEMED PACKS", Size = UDim2.new(0.38, 0, 1, 0), Max = 20 })
local shopBtn = button({ Parent = row2, Text = "SHOP", Size = UDim2.new(0.27, 0, 1, 0), Max = 20 })
local statsBtn = button({ Parent = row2, Text = "STATS", Size = UDim2.new(0.27, 0, 1, 0), Max = 20 })

local function renderTitle()
	for L, b in lenButtons do
		local on = (L == len)
		b.BackgroundColor3 = on and Color3.fromRGB(60, 120, 70) or Color3.fromRGB(20, 30, 26)
	end
	if not profile then return end
	coinCorner.Text = coinText(profile.coins)
	local key = tostring(len)
	local price = profile.prices[key]
	local L = len == 0 and Config.ENDLESS_RANKED_LENGTH or len
	local b = profile.boost
	local tag = b.x > 1 and string.format('  <font color="#7dff6a">%s ×%s</font>', b.why, tostring(b.x)) or ""
	rankedBtn.Text = string.format("RANKED · %d PROMPTS · %s%s", L, coinText(price), tag)
	rankedBtn.BackgroundTransparency = profile.coins < price and 0.5 or 0
	fine.Text = string.format("Ranked: entry spent at start · same price for everyone · score %d+ to profit\nBoosts show on the button · coins are earned in-game, never bought", profile.profitAt[key] or 0)
	local d = itemById(profile.equip.duck or "")
	local t = itemById(profile.equip.toilet or "")
	skinLabel.Text = (d and d.name or "Classic Duck") .. "  ·  " .. (t and t.name or "Classic Toilet")
	skinLabel.TextColor3 = d and Color3.fromHex(d.color) or DIM
	Scene.setSkin(profile.equip, ALL_ITEMS)
end
for L, b in lenButtons do b.Activated:Connect(function() len = L; renderTitle() end) end

---------------------------------------------------------------- PLAY
local P = screens.play
local topLeft = label({ Parent = P, Text = "", Size = UDim2.new(0.6, 0, 0.05, 0), TextXAlignment = Enum.TextXAlignment.Left, Max = 20, TextColor3 = DIM })
stroke(topLeft, 2)
local scoreLabel = label({ Parent = P, Text = "0", Font = TITLE_FONT, Size = UDim2.new(0.38, 0, 0.07, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right, Max = 40, TextColor3 = GOLD })
stroke(scoreLabel, 3)
local promptLabel = label({ Parent = P, Text = "", Font = BODY_FONT, Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.fromScale(0, 0.1), Max = 44 })
stroke(promptLabel, 3)
local barBack = make("Frame", { Parent = P, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromScale(0, 0.33), BackgroundColor3 = PANEL, BorderSizePixel = 0 })
stroke(barBack, 2, INK)
local bar = make("Frame", { Parent = barBack, Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0 })
local box = make("TextBox", {
	Parent = P, Size = UDim2.new(1, 0, 0.1, 0), Position = UDim2.fromScale(0, 0.37), BackgroundColor3 = PANEL, BorderSizePixel = 0,
	Font = BODY_FONT, TextColor3 = INK, PlaceholderText = "type an answer and press Enter", PlaceholderColor3 = Color3.fromRGB(120, 140, 130),
	Text = "", TextScaled = true, ClearTextOnFocus = false,
})
stroke(box, 3, INK, true); maxText(box, 32)
local feedback = label({ Parent = P, Text = "", Size = UDim2.new(1, 0, 0.06, 0), Position = UDim2.fromScale(0, 0.49), Max = 22 })
stroke(feedback, 2)
local endBtn = button({ Parent = P, Text = "END RUN", Size = UDim2.new(0.25, 0, 0.06, 0), Position = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(1, 1), Max = 18 })

-- reveal card (after you answer or time runs out)
local reveal = make("Frame", { Parent = P, Size = UDim2.new(1, 0, 0.36, 0), Position = UDim2.fromScale(0, 0.56), BackgroundColor3 = PANEL, BackgroundTransparency = 0.1, BorderSizePixel = 0, Visible = false })
stroke(reveal, 3, INK)
local tierLabel = label({ Parent = reveal, Text = "", Font = TITLE_FONT, Size = UDim2.new(1, -20, 0.3, 0), Position = UDim2.new(0, 10, 0.04, 0), Max = 52 })
local tierIcon = make("Frame", { Parent = reveal, BackgroundTransparency = 1, Size = UDim2.new(0.3, 0, 0.3, 0), Position = UDim2.new(0, 10, 0.04, 0), ZIndex = 2 })
make("UIAspectRatioConstraint", { Parent = tierIcon })
stroke(tierLabel, 3)
local answerLabel = label({ Parent = reveal, Text = "", Size = UDim2.new(1, -20, 0.17, 0), Position = UDim2.new(0, 10, 0.34, 0), Max = 26 })
local blurbLabel = label({ Parent = reveal, Text = "", Size = UDim2.new(1, -20, 0.12, 0), Position = UDim2.new(0, 10, 0.51, 0), Max = 18, TextColor3 = DIM, Font = Enum.Font.Gotham })
local othersLabel = label({ Parent = reveal, Text = "", Size = UDim2.new(1, -20, 0.14, 0), Position = UDim2.new(0, 10, 0.64, 0), Max = 16, TextColor3 = DIM, Font = Enum.Font.Gotham })
local nextBtn = button({ Parent = reveal, Text = "NEXT ▶", Size = UDim2.new(0.3, 0, 0.17, 0), Position = UDim2.new(0.5, 0, 0.97, 0), AnchorPoint = Vector2.new(0.5, 1), Max = 22, Color = Color3.fromRGB(40, 120, 50), StrokeColor = GREEN, TextColor3 = INK })

local game_ = nil -- {ranked, total, deadline, seconds, phase}
local pendingSuggest = nil

local function showPrompt(pv)
	game_.phase = "answering"
	game_.total = pv.total
	game_.seconds = pv.seconds
	game_.deadline = os.clock() + pv.seconds
	topLeft.Text = (pv.ranked and "RANKED · " or pv.packName and (string.upper(pv.packName) .. " · ") or "") .. (pv.total and string.format("PROMPT %d OF %d", pv.idx, pv.total) or string.format("PROMPT %d · ENDLESS", pv.idx))
	scoreLabel.Text = tostring(pv.score)
	promptLabel.Text = pv.prompt
	feedback.Text = ""
	reveal.Visible = false
	box.Text = ""
	box.TextEditable = true
	endBtn.Visible = (pv.total == nil)
	pendingSuggest = nil
	show("play")
	task.defer(function() box:CaptureFocus() end)
end

local function showReveal(res)
	game_.phase = "reveal"
	box.TextEditable = false
	box:ReleaseFocus()
	scoreLabel.Text = tostring(res.total)
	if res.result == "hit" then
		local t = Match.tierOf(res.score)
		tierLabel.Text = string.upper(t.name) .. "  +" .. res.score
		tierLabel.TextColor3 = t.color
		answerLabel.Text = res.answer .. ((res.official and res.official ~= res.answer) and ("  (" .. res.official .. ")") or "")
		blurbLabel.Text = t.blurb
		play(res.score >= 85 and "flush" or "correct")
	else
		tierLabel.Text = "TIME'S UP  +0"
		tierLabel.TextColor3 = RED
		answerLabel.Text = "The duck stays put."
		blurbLabel.Text = ""
		play("miss")
	end
	local rv = res.reveal or {}
	local parts = {}
	if rv.common and #rv.common > 0 then table.insert(parts, "Most said: " .. table.concat(rv.common, ", ")) end
	if rv.sigma then table.insert(parts, "Sigma answer: " .. rv.sigma) end
	othersLabel.Text = table.concat(parts, "   ·   ")
	nextBtn.Text = res.last and "RESULTS ▶" or "NEXT ▶"
	reveal.Visible = true
	if res.result == "hit" then Scene.sink(res.score) end
	for _, c in tierIcon:GetChildren() do c:Destroy() end
	if res.result == "hit" then
		local ico = Scene.tierIcon(res.score, math.max(48, tierIcon.AbsoluteSize.Y))
		ico.AnchorPoint = Vector2.new(0.5, 0.5); ico.Position = UDim2.fromScale(0.5, 0.5); ico.Parent = tierIcon
	end
end

---------------------------------------------------------------- RESULTS
local R = screens.results
local resTitle = label({ Parent = R, Text = "", Font = TITLE_FONT, Size = UDim2.new(1, 0, 0.08, 0), Max = 40, TextColor3 = GOLD })
stroke(resTitle, 3)
local resScore = label({ Parent = R, Text = "", Font = TITLE_FONT, Size = UDim2.new(1, 0, 0.13, 0), Position = UDim2.fromScale(0, 0.08), Max = 90 })
stroke(resScore, 4)
local resPct = label({ Parent = R, Text = "", Size = UDim2.new(1, 0, 0.05, 0), Position = UDim2.fromScale(0, 0.21), Max = 22 })
stroke(resPct, 2)
local resCoins = label({ Parent = R, Text = "", Size = UDim2.new(1, 0, 0.05, 0), Position = UDim2.fromScale(0, 0.26), Max = 22, TextColor3 = GOLD })
stroke(resCoins, 2)
local resList = make("ScrollingFrame", { Parent = R, Size = UDim2.new(1, 0, 0.52, 0), Position = UDim2.fromScale(0, 0.33), BackgroundColor3 = PANEL, BackgroundTransparency = 0.15, BorderSizePixel = 0, ScrollBarThickness = 8, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, {
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 14) }),
})
stroke(resList, 2, INK)
local resRow = make("Frame", { Parent = R, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0.09, 0), Position = UDim2.fromScale(0, 0.88) }, {
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12) }),
})
local againBtn = button({ Parent = resRow, Text = "PLAY AGAIN", Size = UDim2.new(0.4, 0, 1, 0), Max = 24, StrokeColor = GREEN, TextColor3 = GREEN })
local homeBtn = button({ Parent = resRow, Text = "HOME", Size = UDim2.new(0.25, 0, 1, 0), Max = 24 })

local function showResults(res)
	game_ = nil
	if res.profile then profile = res.profile end
	local n = res.prompts
	resTitle.Text = res.packName and (string.upper(res.packName) .. " PACK COMPLETE") or res.ranked and string.format("RANKED %d-PROMPT FLUSH", n) or string.format("%d-PROMPT FLUSH COMPLETE", n)
	resScore.Text = tostring(res.score)
	resPct.Text = string.format("Better than %d%% of players", res.percentile)
	if res.cheated then
		resCoins.Text = "Test code used · no coins this time"
	elseif res.ranked then
		resCoins.Text = "Paid out " .. coinText(res.paid)
		resCoins.TextColor3 = res.paid > (res.price or 0) and GREEN or GOLD
	else
		resCoins.Text = "+" .. coinText(res.paid) .. " earned · play Ranked to win more"
		resCoins.TextColor3 = GOLD
	end
	for _, c in resList:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	for i, r in res.rows do
		local t = Match.tierOf(r.score)
		local f = make("Frame", { Parent = resList, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = i })
		if r.score > 0 then local ico = Scene.tierIcon(r.score, 40); ico.Position = UDim2.fromOffset(0, 3); ico.Parent = f end
		label({ Parent = f, Text = r.prompt, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromOffset(48, 0), TextXAlignment = Enum.TextXAlignment.Left, Max = 16, Font = Enum.Font.Gotham })
		label({ Parent = f, Text = r.answer, Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.56, 0), TextXAlignment = Enum.TextXAlignment.Left, Max = 16 })
		local s = label({ Parent = f, Text = r.score > 0 and (t.name .. " +" .. r.score) or "+0", Size = UDim2.new(0.16, 0, 1, 0), Position = UDim2.fromScale(0.84, 0), TextXAlignment = Enum.TextXAlignment.Right, Max = 16, Font = TITLE_FONT })
		s.TextColor3 = r.score > 0 and t.color or RED
	end
	renderTitle()
	show("results")
end

---------------------------------------------------------------- game actions
local function startGame(mode, packKey)
	local res = call("start", { mode = mode, len = len, pack = packKey })
	if not res then return end
	lastMode, lastPack = mode, packKey
	game_ = { ranked = mode == "ranked" }
	if profile then profile.coins = res.coins; coinCorner.Text = coinText(res.coins) end
	if res.extraTime then toast("Extra Time boost: +5s every prompt") end
	play("flush")
	show("none") -- hide the menus while the duck gets flushed
	Scene.flush(function() showPrompt(res.prompt) end)
end

local function submit()
	if not game_ or game_.phase ~= "answering" then return end
	local text = box.Text
	if text:match("^%s*$") then return end
	local res = call("submit", { text = text })
	if not res then return end
	if res.result == "hit" or res.result == "timeout" then
		showReveal(res)
	elseif res.result == "suggest" then
		pendingSuggest = res.label
		box.Text = res.label
		feedback.Text = string.format('Did you mean <b>"%s"</b>? Press Enter to lock it in.', res.label)
		feedback.TextColor3 = GOLD
		task.defer(function() box:CaptureFocus(); box.CursorPosition = #box.Text + 1 end)
	elseif res.result == "miss" then
		feedback.Text = string.format('"%s" isn\'t on the list. Try another!', text)
		feedback.TextColor3 = RED
		play("miss")
		box.Text = ""
		task.defer(function() box:CaptureFocus() end)
	end
end

local function goNext()
	if not game_ or game_.phase ~= "reveal" then return end
	local res = call("next")
	if not res then return end
	if res.done then showResults(res) else showPrompt(res.prompt) end
end

box.FocusLost:Connect(function(enter) if enter then submit() end end)
nextBtn.Activated:Connect(goNext)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Return and game_ and game_.phase == "reveal" then goNext() end
end)
endBtn.Activated:Connect(function()
	local res = call("endRun")
	if res then showResults(res) end
end)

-- the clock
local timingOut = false
RunService.Heartbeat:Connect(function()
	if not game_ or game_.phase ~= "answering" then return end
	local left = game_.deadline - os.clock()
	local frac = math.clamp(left / game_.seconds, 0, 1)
	bar.Size = UDim2.fromScale(frac, 1)
	bar.BackgroundColor3 = frac > 0.4 and GREEN or frac > 0.15 and GOLD or RED
	if left <= 0 and not timingOut then
		timingOut = true
		task.spawn(function()
			local res
			for _ = 1, 5 do
				res = call("timeout")
				if res then break end
				task.wait(0.4)
			end
			timingOut = false
			if res and res.result then showReveal(res) end
		end)
	end
end)

flushBtn.Activated:Connect(function() startGame("free") end)
rankedBtn.Activated:Connect(function() startGame("ranked") end)
againBtn.Activated:Connect(function() startGame(lastMode, lastPack) end)
homeBtn.Activated:Connect(function() Scene.title(); show("title") end)

---------------------------------------------------------------- SHOP + STATS (modal)
local modal = make("Frame", { Parent = gui, Size = UDim2.fromScale(0.86, 0.8), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = PANEL, BorderSizePixel = 0, Visible = false, ZIndex = 20 })
stroke(modal, 3, INK)
local modalTitle = label({ Parent = modal, Text = "", Font = TITLE_FONT, Size = UDim2.new(1, -120, 0, 44), Position = UDim2.new(0, 16, 0, 10), TextXAlignment = Enum.TextXAlignment.Left, Max = 36, ZIndex = 21, TextColor3 = GOLD })
local closeBtn = button({ Parent = modal, Text = "✕", Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(1, -12, 0, 10), AnchorPoint = Vector2.new(1, 0), Max = 24, ZIndex = 21 })
local modalBody = make("ScrollingFrame", { Parent = modal, Size = UDim2.new(1, -24, 1, -70), Position = UDim2.new(0, 12, 0, 62), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 21 })
closeBtn.Activated:Connect(function() modal.Visible = false end)

local function clearBody()
	for _, c in modalBody:GetChildren() do c:Destroy() end
end
local function rarity(p)
	if p >= 100000 then return "MYTHIC", Color3.fromHex("#ff7ad9") end
	if p >= 10000 then return "LEGENDARY", GOLD end
	if p >= 500 then return "RARE", Color3.fromHex("#6fc8ff") end
	return "COMMON", DIM
end

local openShop
openShop = function()
	if not profile then return end
	clearBody()
	modalTitle.Text = "SHOP  ·  " .. coinText(profile.coins)
	make("UIGridLayout", { Parent = modalBody, CellSize = UDim2.new(0.31, 0, 0, 130), CellPadding = UDim2.new(0.02, 0, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	local items = table.clone(Config.SHOP)
	for _, s in Config.ROBUX_PASSES do if s.passId > 0 then table.insert(items, s) end end
	table.sort(items, function(a, b) return (a.price or 1e12) < (b.price or 1e12) end)
	for i, s in items do
		local card = make("Frame", { Parent = modalBody, BackgroundColor3 = Color3.fromRGB(22, 30, 27), BorderSizePixel = 0, LayoutOrder = i, ZIndex = 22 })
		local rName, rColor = rarity(s.price or 0)
		stroke(card, 2, s.passId and Color3.fromHex("#39ff14") or rColor)
		local holder = make("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0.32, 0), ZIndex = 23 })
		local pv
		if s.type == "duck" then pv = Scene.pixel("duck0", 3, { tint = s.fx ~= "rainbow" and s.color or "#ff7ad9", z = 23 })
		elseif s.type == "toilet" then pv = Scene.pixel(s.sprite or "toilet", 3, { tint = not s.sprite and s.color or nil, z = 23 })
		elseif s.type == "trail" then
			pv = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(42, 30), ZIndex = 23 })
			for k = 0, 5 do make("Frame", { Parent = pv, BorderSizePixel = 0, BackgroundColor3 = Color3.fromHex(s.color), BackgroundTransparency = k * 0.14, Size = UDim2.fromOffset(42 - k * 6, 4), Position = UDim2.fromOffset(k * 3, k * 5), ZIndex = 23 }) end
		else pv = label({ Text = "⏱️", Size = UDim2.fromOffset(40, 36), Max = 30, ZIndex = 23 }) end
		pv.AnchorPoint = Vector2.new(0.5, 0.5); pv.Position = UDim2.fromScale(0.5, 0.5); pv.Parent = holder
		label({ Parent = card, Text = s.name, Size = UDim2.new(1, -10, 0.2, 0), Position = UDim2.new(0, 5, 0.32, 0), Max = 16, ZIndex = 23 })
		local rl = label({ Parent = card, Text = s.passId and "ROBUX PASS" or rName, Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.fromScale(0, 0.52), Max = 12, ZIndex = 23, Font = TITLE_FONT })
		rl.TextColor3 = s.passId and Color3.fromHex("#39ff14") or rColor
		local owned = profile.owned[s.id]
		local equipped = profile.equip[s.type] == s.id
		local text
		if s.type == "boost" then text = "BUY " .. coinText(s.price) .. "  (have " .. tostring(profile.boosts.time or 0) .. ")"
		elseif equipped then text = "EQUIPPED"
		elseif owned then text = "EQUIP"
		elseif s.passId then text = "BUY WITH ROBUX"
		else text = "BUY " .. coinText(s.price) end
		local b = button({ Parent = card, Text = text, Size = UDim2.new(1, -12, 0.28, 0), Position = UDim2.new(0, 6, 0.68, 0), Max = 15, ZIndex = 23, Stroke = 2 })
		if not owned and s.price and profile.coins < s.price then b.BackgroundTransparency = 0.6 end
		b.Activated:Connect(function()
			local res
			if s.passId and not owned then res = call("buyPass", { id = s.id })
			elseif owned then res = call("equip", { id = s.id })
			else res = call("buy", { id = s.id }) end
			if res and res.coins then profile = res; renderTitle(); openShop() end
		end)
	end
	modal.Visible = true
end

local function openPacks()
	if not profile then return end
	clearBody()
	modalTitle.Text = "THEMED PACKS"
	make("UIListLayout", { Parent = modalBody, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	label({ Parent = modalBody, Text = string.format("One topic, easy to hard. %s prompts. Free to play, pays like a normal game.", len == 0 and "Endless" or tostring(len)), Size = UDim2.new(1, 0, 0, 28), Max = 16, TextColor3 = DIM, ZIndex = 23, LayoutOrder = 0, Font = Enum.Font.Gotham })
	for i, pk in profile.packs do
		local b = button({ Parent = modalBody, Text = "", Size = UDim2.new(1, -12, 0, 70), LayoutOrder = i, ZIndex = 22, Stroke = 2 })
		local nm = label({ Parent = b, Text = string.format("%02d  %s", i, string.upper(pk.name)), Size = UDim2.new(0.62, 0, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Left, Font = TITLE_FONT, Max = 24, ZIndex = 23, TextColor3 = GOLD })
		label({ Parent = b, Text = pk.blurb, Size = UDim2.new(0.62, 0, 0.45, 0), Position = UDim2.fromScale(0, 0.52), TextXAlignment = Enum.TextXAlignment.Left, Max = 14, ZIndex = 23, TextColor3 = DIM, Font = Enum.Font.Gotham })
		label({ Parent = b, Text = pk.count .. " PROMPTS" .. (pk.best and ("  ·  BEST " .. pk.best) or ""), Size = UDim2.new(0.36, 0, 1, 0), Position = UDim2.fromScale(0.64, 0), TextXAlignment = Enum.TextXAlignment.Right, Max = 16, ZIndex = 23 })
		b.Activated:Connect(function() modal.Visible = false; startGame("pack", pk.key) end)
		local _ = nm
	end
	modal.Visible = true
end

local function openStats()
	if not profile then return end
	clearBody()
	modalTitle.Text = "STATS"
	make("UIListLayout", { Parent = modalBody, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local st = profile.stats
	local lines = {
		{ "Games played", tostring(st.games) },
		{ "Best score", tostring(st.best) },
		{ "Average per prompt", tostring(st.avg) },
		{ "Coins", coinText(profile.coins) },
	}
	for _, t in Match.TIERS do table.insert(lines, { t.name .. " answers", tostring(st.tiers[tostring(t.score)] or 0), t.color }) end
	for i, l in lines do
		local f = make("Frame", { Parent = modalBody, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = i, ZIndex = 22 })
		local a = label({ Parent = f, Text = l[1], Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Max = 22, ZIndex = 23 })
		if l[3] then a.TextColor3 = l[3] end
		label({ Parent = f, Text = l[2], Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromScale(0.6, 0), TextXAlignment = Enum.TextXAlignment.Right, Max = 22, ZIndex = 23, Font = TITLE_FONT })
	end
	modal.Visible = true
end
shopBtn.Activated:Connect(openShop)
packsBtn.Activated:Connect(openPacks)
statsBtn.Activated:Connect(openStats)

---------------------------------------------------------------- boot
show("title")
renderTitle()
coinCorner.Text = "loading…"
task.spawn(function()
	for _ = 1, 20 do
		local res = call("profile")
		if res then profile = res; renderTitle(); return end
		task.wait(0.5)
	end
	toast("Couldn't load your profile. Rejoin to try again.")
end)
