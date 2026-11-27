-- FLUSHED scene: the pixel-art world behind the UI, ported from js/ocean.js.
-- Title: the duck bobbing in a big toilet bowl. FLUSH: foam swirl, a "whoops" backflip, pulled down the drain.
-- Dive: the duck sinks down the middle past pipes, then brick sewer walls whose colors blend zone to zone:
-- sewer -> Rat Kingdom (~400 pts, torches, crowned mice) -> Brainrot Core disco (~500) -> rainbow insanity (600+).
-- Junk floats past (toilet paper, floss picks, rats, party mice), ledges carry mice and hanging disco balls.
-- Every sprite is real pixel art built from Frames (Sprites.luau), so nothing needs uploading.
local RunService = game:GetService("RunService")
local Sprites = require(script.Parent.Sprites)

local Scene = {}

---------------------------------------------------------------- math + color helpers
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function hash(n) -- deterministic 0..1 (same as the website)
	n = math.floor(n)
	n = bit32.band(n * 374761393 + 668265263, 0xFFFFFFFF)
	n = bit32.band(bit32.bxor(n, bit32.rshift(n, 13)) * 1274126177, 0xFFFFFFFF)
	n = bit32.bxor(n, bit32.rshift(n, 16))
	return (n % 100000) / 100000
end
local function hex(h) return Color3.fromHex(h) end
local function mixC(a, b, t) return a:Lerp(b, clamp(t, 0, 1)) end
local function smooth(a, b, x) local t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t) end
local function easeIO(x) return x < 0.5 and 2 * x * x or 1 - ((-2 * x + 2) ^ 2) / 2 end
local function hsl(h, s, l)
	s /= 100; l /= 100
	local function f(n)
		local k = (n + h / 30) % 12
		local a = s * math.min(l, 1 - l)
		return l - a * math.max(-1, math.min(k - 3, 9 - k, 1))
	end
	return Color3.new(f(0), f(8), f(4))
end

-- shade-preserving tint (the website's "~#hex" skins): recolor each pixel by its original brightness
local tintCache = {}
local function tinted(h, tint)
	if not tint then return hex(h) end
	local key = h .. tint
	if tintCache[key] then return tintCache[key] end
	local o, t = hex(h), hex(tint)
	local lum = 0.3 * o.R + 0.59 * o.G + 0.11 * o.B
	local c
	if lum < 0.16 then c = hex("#0a1222")
	else
		local k = 0.5 + 0.7 * lum
		c = Color3.new(math.min(1, t.R * k), math.min(1, t.G * k), math.min(1, t.B * k))
	end
	tintCache[key] = c
	return c
end

---------------------------------------------------------------- pixel sprites
local templates = {}
-- opts: tint ("#hex"), flip (mirror), rowMin (skip rows above this: the bowl's front), z (ZIndex)
local function pixel(name, px, opts)
	opts = opts or {}
	local key = table.concat({ name, px, opts.tint or "", opts.flip and 1 or 0, opts.rowMin or 0 }, "|")
	local tpl = templates[key]
	if not tpl then
		local s = Sprites[name]
		assert(s, "no sprite " .. tostring(name))
		tpl = Instance.new("Frame")
		tpl.Name = name
		tpl.BackgroundTransparency = 1
		tpl.Size = UDim2.fromOffset(s.w * px, s.h * px)
		local r = s.runs
		for i = 1, #r, 4 do
			local x, y, len, ci = r[i], r[i + 1], r[i + 2], r[i + 3]
			if y >= (opts.rowMin or 0) then
				local f = Instance.new("Frame")
				f.BorderSizePixel = 0
				f.BackgroundColor3 = tinted(s.pal[ci], opts.tint)
				f.Position = UDim2.fromOffset((opts.flip and (s.w - x - len) or x) * px, y * px)
				f.Size = UDim2.fromOffset(len * px, px)
				f.Parent = tpl
			end
		end
		templates[key] = tpl
	end
	local c = tpl:Clone()
	if opts.z then
		c.ZIndex = opts.z
		for _, ch in c:GetChildren() do ch.ZIndex = opts.z end
	end
	return c
end
Scene.pixel = pixel
local function spriteSize(name) local s = Sprites[name]; return s.w, s.h end

local function frame(props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do f[k] = v end
	return f
end

---------------------------------------------------------------- world constants (same as the website)
local Z_RAT, Z_CORE, Z_MAD = 3600, 4600, 5600
local PIPE_TOP, SEWER_TOP = 110, 1000
local TIER_DEPTH = { [100] = 1000, [85] = 750, [60] = 450, [30] = 200, [10] = 30 }
local WATER = {
	{ 0, "#6fb3bf" }, { 120, "#4f8f9b" }, { 200, "#3f6b74" }, { 500, "#34555b" }, { 1000, "#2b3f31" },
	{ 2400, "#203022" }, { 3600, "#25183a" }, { 4300, "#1b1130" }, { 4600, "#200a26" }, { 5800, "#15041a" },
}
for _, w in WATER do w[2] = hex(w[2]) end
local function waterColor(m)
	if m <= WATER[1][1] then return WATER[1][2] end
	for i = 2, #WATER do
		if m <= WATER[i][1] then
			local a, b = WATER[i - 1], WATER[i]
			return mixC(a[2], b[2], (m - a[1]) / (b[1] - a[1]))
		end
	end
	return WATER[#WATER][2]
end
local function rgbList(t) local out = {}; for i, c in t do out[i] = Color3.fromRGB(c[1], c[2], c[3]) end; return out end
local WALL = {
	sewer = rgbList({ { 46, 61, 45 }, { 67, 87, 63 }, { 27, 36, 26 }, { 21, 29, 21 }, { 125, 255, 106 } }),
	rat = rgbList({ { 47, 34, 68 }, { 67, 50, 95 }, { 27, 18, 41 }, { 20, 13, 31 }, { 255, 213, 74 } }),
	core = rgbList({ { 58, 18, 54 }, { 86, 32, 79 }, { 30, 8, 28 }, { 22, 6, 26 }, { 255, 63, 180 } }),
}
local t = 0 -- scene clock
local function beatPulse() return (1 - ((t * 2.1) % 1)) ^ 3 end -- ~126 bpm kick
local function madWall(m)
	local ins = clamp((m - Z_MAD) / 1500, 0, 2.5)
	local h = (m / 6 + t * (40 + ins * 70)) % 360
	local l = 18 + beatPulse() * (8 + ins * 6)
	return { hsl(h, 55, l), hsl(h, 70, l + 14), hsl(h, 50, math.max(4, l - 8)), hsl(h, 40, math.max(4, l - 12)), hsl((h + 180) % 360, 100, 65) }
end
local function mixP(A, B, q)
	local out = {}
	for i = 1, 5 do out[i] = mixC(A[i], B[i], q) end
	return out
end
local function wallColors(m)
	local band = 260
	local P
	if m < Z_RAT + band then P = mixP(WALL.sewer, WALL.rat, smooth(Z_RAT - band, Z_RAT + band, m))
	else P = mixP(WALL.rat, WALL.core, smooth(Z_CORE - band, Z_CORE + band, m)) end
	if m > Z_MAD - band then P = mixP(P, madWall(m), smooth(Z_MAD - band, Z_MAD + band, m)) end
	return P
end
local function zoneIndex(m)
	if m < 200 then return 0 elseif m < 1000 then return 1 elseif m < Z_RAT then return 2 elseif m < Z_CORE then return 3 end
	return 4
end
local ZONE_JUNK = {
	[0] = { "tpWad", "tpWad", "tpSheet", "flossPick", "qtip", "gum", "bandaid", "soapBar", "toothbrush", "tpWad", "duckling" },
	[1] = { "tpWad", "ring", "lego", "keys", "phone", "coin", "sock", "airpod", "goldfish", "flossPick", "duckling", "tpSheet" },
	[2] = { "mouse", "mouse", "rat", "rat", "pizza", "gatorEyes", "tpWad", "coin", "mouse", "tpSheet" },
	[3] = { "crownMouse", "ratking", "cheese", "chain", "crownMouse", "coin", "coin", "rat", "cheese", "ratking" },
	[4] = { "partyMouse", "partyMouse", "disco", "boombox", "partyMouse", "cheese", "disco", "partyMouseB" },
}
-- two-frame animations for things that swim/scurry
local ANIM = { mouse = { "mouse0", "mouse1" }, rat = { "rat0", "rat1" }, goldfish = { "fish", "fish" } }
local RAINBOW = { "#ff4d6a", "#ff9a2a", "#ffe14a", "#7dff6a", "#4ad0ff", "#8a7aff", "#ff7ad9" }
local TIER_ICON = { [100] = "icoSigma", [85] = "icoSkibidi", [60] = "icoRizz", [30] = "icoMid", [10] = "icoNPC" }

---------------------------------------------------------------- state
local root, layers
local W, H, px, ppm = 0, 0, 3, 2
local view = "title" -- title | flush | dive
local depthM, targetM = 0, 0
local skin = { duckTint = nil, duckFx = nil, toiletSprite = "toilet", toiletTint = nil, trail = nil }

-- title objects
local title = {}
-- dive objects
local duckObj, duckFrames, duckKey = nil, {}, ""
local wallRows = {} -- pool of brick rows {left, right, k}
local pipes = {}
local floaters = {}
local ledges = {} -- [L] = frame
local trailDots = {}
local fxObjs = {}

local function anchorY() return H * (W < 700 and 0.74 or 0.62) end
local function yOf(m) return anchorY() + (m - depthM) * ppm end

---------------------------------------------------------------- build / rebuild on resize
local function clearChildren(f) for _, c in f:GetChildren() do c:Destroy() end end

local function buildTitle()
	clearChildren(layers.title)
	-- sits where the title screen leaves room for it (between the subtitle and the PROMPTS picker)
	local padded = H - 130
	local k = math.max(3, math.floor(padded * 0.215 / 15))
	local tw, th = spriteSize(skin.toiletSprite)
	local x0, y0 = math.floor(W / 2 - tw * k / 2), math.floor(60 + padded * 0.215)
	local tint = skin.toiletTint
	local back = pixel(skin.toiletSprite, k, { tint = tint, z = 2 })
	back.Position = UDim2.fromOffset(x0, y0)
	back.Parent = layers.title
	local front = pixel(skin.toiletSprite, k, { tint = tint, rowMin = 7, z = 4 }) -- the bowl front hides the duck going down
	front.Position = UDim2.fromOffset(x0, y0)
	front.Parent = layers.title
	local dk = math.max(1, math.floor(k * 0.42 + 0.5))
	local duck = pixel("duck0", dk, { tint = skin.duckTint, z = 3 })
	duck.AnchorPoint = Vector2.new(0.5, 0.5)
	local scale = Instance.new("UIScale")
	scale.Parent = duck
	duck.Parent = layers.title
	local foam = {}
	for i = 1, 16 do
		local f = frame({ Size = UDim2.fromOffset(2 * math.max(2, math.floor(k * 0.3)), math.max(2, math.floor(k * 0.3))), BackgroundColor3 = (i - 1) % 4 == 0 and Color3.new(1, 1, 1) or hex("#9fd6e0"), ZIndex = 3, Visible = false, Parent = layers.title })
		foam[i] = f
	end
	title = { k = k, x0 = x0, y0 = y0, tw = tw, th = th, duck = duck, dk = dk, foam = foam, back = back, front = front }
end

local function buildDuck()
	if duckObj then duckObj:Destroy() end
	duckObj = frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(16 * px, 13 * px), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = layers.duck })
	duckFrames = {}
	for i, n in { "duck0", "duck1" } do
		local d = pixel(n, px, { tint = skin.duckTint, z = 6 })
		d.Visible = i == 1
		d.Parent = duckObj
		duckFrames[i] = d
	end
	duckKey = tostring(skin.duckTint)
	-- skin effects: a soft glow (diamond / rainbow / million) and a tiny crown for the million-coin duck
	for _, o in fxObjs do o:Destroy() end
	fxObjs = {}
	if skin.duckFx then
		local g = frame({ BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, Size = UDim2.fromOffset(40 * px, 40 * px), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5, Parent = duckObj })
		Instance.new("UICorner", g).CornerRadius = UDim.new(1, 0)
		fxObjs.glow = g
		for i = 1, 6 do
			fxObjs["sp" .. i] = frame({ BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(px, 3 * px), ZIndex = 7, Parent = duckObj })
		end
		if skin.duckFx == "million" then
			local crown = frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(7 * px, 4 * px), Position = UDim2.new(0.5, -3 * px, 0, -5 * px), ZIndex = 7, Parent = duckObj })
			for _, r in { { 0, 2, 7, 2 }, { 0, 0, 1, 2 }, { 3, 0, 1, 2 }, { 6, 0, 1, 2 } } do
				frame({ BackgroundColor3 = hex("#ffd23f"), Position = UDim2.fromOffset(r[1] * px, r[2] * px), Size = UDim2.fromOffset(r[3] * px, r[4] * px), ZIndex = 7, Parent = crown })
			end
			frame({ BackgroundColor3 = hex("#ff3f6a"), Position = UDim2.fromOffset(3 * px, 2 * px), Size = UDim2.fromOffset(px, px), ZIndex = 8, Parent = crown })
		end
	end
	-- trail dots stream up behind the duck
	for _, d in trailDots do d:Destroy() end
	trailDots = {}
	if skin.trail then
		for k = 1, 17 do
			local d = frame({ BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(2 * px, 2 * px), ZIndex = 5, Visible = false, Parent = layers.duck })
			trailDots[k] = d
		end
	end
end

local function buildWalls()
	clearChildren(layers.walls)
	wallRows = {}
	local BHs, BWs = 10 * px, 20 * px
	local WW = math.floor(W * 0.07) + 8 * px
	local n = math.ceil(H / BHs) + 2
	for i = 1, n do
		local row = { k = nil, sides = {} }
		for side = 0, 1 do
			local c = frame({ Size = UDim2.fromOffset(WW, BHs), Position = UDim2.fromOffset(side == 0 and 0 or W - WW, 0), ClipsDescendants = true, ZIndex = 2, Parent = layers.walls })
			local bricks = {}
			for j = 0, math.ceil(WW / BWs) + 1 do
				local b = frame({ Size = UDim2.fromOffset(BWs - px, BHs - px), ZIndex = 2, Parent = c })
				local hl = frame({ Size = UDim2.new(1, 0, 0, px), ZIndex = 2, Parent = b })
				local sh = frame({ Size = UDim2.new(1, 0, 0, px), Position = UDim2.new(0, 0, 1, -px), ZIndex = 2, Parent = b })
				bricks[j + 1] = { b = b, hl = hl, sh = sh }
			end
			local moss = frame({ Size = UDim2.new(1, 0, 0, px), Position = UDim2.new(0, 0, 1, -px), BackgroundTransparency = 0.45, ZIndex = 2, Visible = false, Parent = c })
			row.sides[side + 1] = { c = c, bricks = bricks, moss = moss }
		end
		wallRows[i] = row
	end
	layers.walls:SetAttribute("WW", WW)
end

local PIPES = { { 0.018, 10, 120, 988 }, { 0.07, 6, 170, 988 }, { 0.93, 7, 145, 988 }, { 0.978, 10, 120, 988 } }
local function buildPipes()
	clearChildren(layers.pipes)
	pipes = {}
	for i, p in PIPES do
		local w = p[2] * px
		local x = math.floor(W * p[1] - w / 2)
		local body = frame({ BackgroundColor3 = hex("#4c5660"), Size = UDim2.fromOffset(w, 0), Position = UDim2.fromOffset(x, 0), ZIndex = 2, Parent = layers.pipes })
		frame({ BackgroundColor3 = hex("#6e7b86"), Size = UDim2.new(0, 2 * px, 1, 0), Position = UDim2.fromOffset(px, 0), ZIndex = 2, Parent = body })
		frame({ BackgroundColor3 = hex("#323a41"), Size = UDim2.new(0, 2 * px, 1, 0), Position = UDim2.new(1, -2 * px, 0, 0), ZIndex = 2, Parent = body })
		local joints = {}
		for j = 1, 8 do
			local jf = frame({ BackgroundColor3 = hex("#5d6872"), Size = UDim2.fromOffset(w + 4 * px, 4 * px), ZIndex = 3, Visible = false, Parent = layers.pipes })
			frame({ BackgroundColor3 = hex("#88949f"), Size = UDim2.new(1, 0, 0, px), ZIndex = 3, Parent = jf })
			joints[j] = jf
		end
		-- elbow at the top bending back into the wall it comes out of
		local right = p[1] > 0.5
		local elbow = frame({ BackgroundColor3 = hex("#4c5660"), Size = UDim2.fromOffset(right and (W - x) or (x + w), w), ZIndex = 2, Parent = layers.pipes })
		frame({ BackgroundColor3 = hex("#6e7b86"), Size = UDim2.new(1, 0, 0, 2 * px), Position = UDim2.fromOffset(0, px), ZIndex = 2, Parent = elbow })
		frame({ BackgroundColor3 = hex("#323a41"), Size = UDim2.new(1, 0, 0, 2 * px), Position = UDim2.new(0, 0, 1, -2 * px), ZIndex = 2, Parent = elbow })
		pipes[i] = { x = x, w = w, top = p[3], bot = p[4], body = body, joints = joints, elbow = elbow, right = right, i = i }
	end
end

local function rebuild()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
	W, H = vs.X, vs.Y
	px = math.max(2, math.floor(H / 240 + 0.5))
	ppm = H / 420
	buildTitle()
	buildDuck()
	buildWalls()
	buildPipes()
	for _, f in floaters do f.obj:Destroy() end
	floaters = {}
	for _, l in ledges do if l then l:Destroy() end end
	ledges = {}
end

---------------------------------------------------------------- floating junk
local function spawnFloater(m)
	local z = zoneIndex(m)
	local list = ZONE_JUNK[z]
	local kind = list[math.random(1, #list)]
	local names = ANIM[kind] or { kind, kind }
	local dir = math.random() < 0.5 and -1 or 1
	local tint = kind == "goldfish" and "#ff8a3d" or nil
	local obj = frame({ BackgroundTransparency = 1, ZIndex = 4, Parent = layers.float })
	local fr = {}
	for i, n in names do
		local p = pixel(n, px, { flip = dir < 0, tint = tint, z = 4 })
		p.Visible = i == 1
		p.Parent = obj
		fr[i] = p
	end
	local w, h = spriteSize(names[1])
	obj.Size = UDim2.fromOffset(w * px, h * px)
	local WW = layers.walls:GetAttribute("WW") or 0
	local trail = {}
	if m >= Z_MAD then -- rainbow trails on everything in the insanity zone
		for i = 1, 7 do trail[i] = frame({ BackgroundColor3 = hex(RAINBOW[i]), Size = UDim2.fromOffset(4 * px, 2 * px), BackgroundTransparency = 0.15 + i * 0.1, ZIndex = 3, Parent = layers.float }) end
	end
	local f = {
		obj = obj, frames = fr, m = m, x = WW + math.random() * math.max(10, W - 2 * WW - w * px), dir = dir,
		speed = 8 + math.random() * 18, ph = math.random() * 6, w = w * px, h = h * px, trail = trail,
		swims = ANIM[kind] ~= nil or kind:find("Mouse") ~= nil, spin = kind == "disco" or kind == "coin",
	}
	table.insert(floaters, f)
end

local function updateFloaters(dt)
	-- keep ~7 things in view, entering from below as the duck sinks
	local visible = 0
	for i = #floaters, 1, -1 do
		local f = floaters[i]
		f.m -= dt * 4 -- everything drifts up a little, even when the duck is still
		f.x += f.dir * f.speed * dt * (f.swims and 2 or 0.6)
		local WW = layers.walls:GetAttribute("WW") or 0
		if f.x < WW then f.x = WW; f.dir = 1 elseif f.x > W - WW - f.w then f.x = W - WW - f.w; f.dir = -1 end
		local y = yOf(f.m) + math.sin(t * 1.6 + f.ph) * 3 * px
		if y < -f.h - 40 * px or y > H + 400 * px then
			f.obj:Destroy()
			for _, d in f.trail do d:Destroy() end
			table.remove(floaters, i)
		else
			if y > -f.h and y < H then visible += 1 end
			f.obj.Position = UDim2.fromOffset(math.floor(f.x), math.floor(y))
			local fi = (math.floor(t * (f.swims and 6 or 2) + f.ph) % #f.frames) + 1
			for j, fr in f.frames do fr.Visible = j == fi end
			f.obj.Rotation = f.swims and 0 or math.sin(t * 0.8 + f.ph) * 12
			for j, d in f.trail do
				d.Position = UDim2.fromOffset(math.floor(f.x + f.w / 2 - f.dir * (j * 4 * px) - 2 * px), math.floor(y + f.h / 2 + math.sin(t * 6 + j) * px))
			end
		end
	end
	if view == "dive" and visible < 7 and #floaters < 12 then
		spawnFloater(depthM + (H - anchorY()) / ppm + 20 + math.random() * 120)
	end
end

---------------------------------------------------------------- per-frame drawing
local function drawWater()
	local c = waterColor(depthM)
	if view ~= "title" and depthM >= Z_MAD - 300 then
		local m = madWall(depthM)
		c = mixC(c, m[3], smooth(Z_MAD - 300, Z_MAD + 300, depthM))
	end
	if view == "title" then c = hex("#9fd6e0") end
	root.BackgroundColor3 = c
end

local function drawWalls()
	local BHs, BWs = 10 * px, 20 * px
	local topWorldPx = depthM * ppm - anchorY() -- world pixel at the top of the screen
	local k0 = math.floor(topWorldPx / BHs)
	local mad = depthM >= Z_MAD - 300
	for i, row in wallRows do
		local k = k0 + i - 1
		local y = k * BHs - topWorldPx
		local m = k * BHs / ppm
		local show = view == "dive" and m >= SEWER_TOP and y > -BHs and y < H
		for _, s in row.sides do
			s.c.Visible = show
			s.c.Position = UDim2.fromOffset(s.c.Position.X.Offset, math.floor(y))
		end
		if show and (row.k ~= k or mad) then
			row.k = k
			local P = wallColors(m + (hash(k) - 0.5) * 40)
			local off = (k % 2 == 0) and 0 or -BWs / 2
			for side, s in row.sides do
				s.c.BackgroundColor3 = P[4]
				for j, b in s.bricks do
					b.b.Position = UDim2.fromOffset(off + (j - 1) * BWs, 0)
					b.b.BackgroundColor3 = (hash(k * 31 + j * 7 + side) > 0.82) and P[3] or P[1]
					b.hl.BackgroundColor3 = P[2]
					b.sh.BackgroundColor3 = P[3]
				end
				local mossy = hash(k * 13 + side * 5) > 0.8
				s.moss.Visible = mossy
				s.moss.BackgroundColor3 = P[5]
			end
		end
	end
end

local function drawPipes()
	for _, p in pipes do
		local y0, y1 = yOf(p.top), yOf(p.bot)
		local show = view == "dive" and y1 > -10 and y0 < H + 10
		p.body.Visible = show
		p.elbow.Visible = show and y0 > -40 and y0 < H
		for _, j in p.joints do j.Visible = false end
		if show then
			local ya, yb = math.max(-2, y0), math.min(H + 2, y1)
			p.body.Position = UDim2.fromOffset(p.x, ya)
			p.body.Size = UDim2.fromOffset(p.w, math.max(0, yb - ya))
			p.elbow.Position = UDim2.fromOffset(p.right and p.x or 0, y0 - p.w)
			local ji = 1
			local m = p.top + 40 + p.i * 9
			while m < p.bot - 10 and ji <= #p.joints do
				local y = yOf(m)
				if y > -6 * px and y < H + 6 * px then
					local j = p.joints[ji]
					j.Visible = true
					j.Position = UDim2.fromOffset(p.x - 2 * px, math.floor(y))
					ji += 1
				end
				m += 60
			end
		end
	end
end

-- ledges: bricks jutting out of the walls with things on them (busier the deeper you go)
local function makeLedge(L)
	local s = L * 7 + 13
	local deep = clamp((L - Z_CORE) / 2600, 0, 1.4)
	local chance = L < Z_RAT and 0.16 or L < Z_CORE and 0.55 or math.min(0.95, 0.42 + 0.38 * deep)
	if hash(s) > chance then return false end
	local side = hash(s + 1) > 0.5 and 1 or 0
	local WW = layers.walls:GetAttribute("WW") or 0
	local len = (30 + math.floor(hash(s + 2) * 3) * 6) * px
	local P = wallColors(L)
	local holder = frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(len, 7 * px), ZIndex = 3, Parent = layers.ledges })
	holder:SetAttribute("side", side)
	holder:SetAttribute("L", L)
	frame({ BackgroundColor3 = P[3], Size = UDim2.new(1, 2 * px, 0, 7 * px), ZIndex = 3, Parent = holder })
	frame({ BackgroundColor3 = P[1], Size = UDim2.new(1, 0, 0, 3 * px), Position = UDim2.fromOffset(px, 0), ZIndex = 3, Parent = holder })
	frame({ BackgroundColor3 = P[1], Size = UDim2.new(1, 0, 0, 2 * px), Position = UDim2.fromOffset(px, 4 * px), ZIndex = 3, Parent = holder })
	frame({ BackgroundColor3 = P[2], Size = UDim2.new(1, 0, 0, px), Position = UDim2.fromOffset(px, 0), ZIndex = 3, Parent = holder })
	local mid = side == 1 and math.floor(len * 0.4) or math.floor(len * 0.6)
	local kind = hash(s + 3)
	local flip = side == 1
	local function put(name, dx, opts)
		local w, h = spriteSize(name)
		local o = pixel(name, px, { flip = flip, tint = opts and opts.tint, z = 3 })
		o.Position = UDim2.fromOffset(mid + dx * px - (opts and opts.center == false and 0 or w * px / 2), -(h - 1) * px - ((opts and opts.lift) or 0) * px)
		o.Parent = holder
		return o
	end
	if L < Z_RAT then
		put(kind < 0.6 and "mouse0" or "rat0", 0)
	elseif L < Z_CORE then
		if kind < 0.45 then put("crownMouse", 0)
		elseif kind < 0.75 then put("cheese", 0)
		else put("coin", -3); put("coin", 3); put("coin", 0, { lift = 8 }) end
		-- a torch on the wall above (the Rat Kingdom is lit by torches)
		local torch = frame({ BackgroundColor3 = hex("#5a3a1a"), Size = UDim2.fromOffset(2 * px, 7 * px), Position = UDim2.fromOffset(side == 1 and len - 4 * px or 2 * px, -16 * px), ZIndex = 3, Parent = holder })
		local flame = frame({ Name = "Flame", BackgroundColor3 = hex("#ffb020"), Size = UDim2.fromOffset(4 * px, 4 * px), Position = UDim2.fromOffset(-px, -4 * px), ZIndex = 3, Parent = torch })
		frame({ Name = "Core", BackgroundColor3 = hex("#fff3b0"), Size = UDim2.fromOffset(2 * px, 2 * px), Position = UDim2.fromOffset(px, 2 * px), ZIndex = 3, Parent = flame })
	else
		local v = ({ "partyMouse", "partyMouseB", "partyMouseC" })[math.floor(hash(s + 5) * 3) + 1]
		local dancer
		if kind < 0.5 then dancer = put(v, 0)
		elseif kind < 0.75 then put("boombox", 0)
		else dancer = put(v, -6); put("cheese", flip and 14 or -26) end
		if dancer then dancer.Name = "Dancer" end
		if hash(s + 7) > 0.45 then -- disco ball hanging under the ledge
			local bx = side == 1 and 4 * px or len - 4 * px
			frame({ BackgroundColor3 = hex("#5a5a6a"), Size = UDim2.fromOffset(px, 8 * px), Position = UDim2.fromOffset(bx, 6 * px), ZIndex = 3, Parent = holder })
			local dw = spriteSize("disco")
			local ball = pixel("disco", px, { z = 3 })
			ball.Name = "Disco"
			ball.Position = UDim2.fromOffset(bx - math.floor(dw * px / 2), 14 * px)
			ball.Parent = holder
		end
	end
	holder.Position = UDim2.fromOffset(side == 1 and (W - WW - len) or (WW - 2 * px), 0)
	return holder
end

local function drawLedges()
	local STEP = 70
	local topM = depthM - anchorY() / ppm - 60
	local botM = depthM + (H - anchorY()) / ppm + 60
	local want = {}
	if view == "dive" then
		local L = math.max(SEWER_TOP + 150, math.floor(topM / STEP) * STEP)
		while L < botM do want[L] = true; L += STEP end
	end
	for L, obj in ledges do
		if not want[L] then
			if obj then obj:Destroy() end
			ledges[L] = nil
		end
	end
	local kick = beatPulse()
	for L in want do
		if ledges[L] == nil then ledges[L] = makeLedge(L) end
		local obj = ledges[L]
		if obj then
			obj.Position = UDim2.fromOffset(obj.Position.X.Offset, math.floor(yOf(L)))
			local d = obj:FindFirstChild("Dancer")
			if d then d.Position = UDim2.fromOffset(d.Position.X.Offset, -(21 - 1) * px - math.floor(kick * 3) * px) end
			local disco = obj:FindFirstChild("Disco")
			if disco then disco.Rotation = (math.floor(t * 4) % 2) * 8 - 4 end
			for _, torch in obj:GetChildren() do
				local fl = torch:FindFirstChild("Flame")
				if fl then fl.BackgroundColor3 = (math.floor(t * 9 + L) % 3 == 0) and hex("#ff7a20") or hex("#ffb020") end
			end
		end
	end
end

local function drawDuck(dt)
	local sinking = math.abs(targetM - depthM) > 2
	duckObj.Visible = view == "dive"
	if view ~= "dive" then
		for _, d in trailDots do d.Visible = false end
		return
	end
	local bob = sinking and 0 or math.sin(t * 2.2) * 1.5 * px
	local cx, cy = W / 2, anchorY() + bob
	duckObj.Position = UDim2.fromOffset(math.floor(cx), math.floor(cy))
	duckObj.Rotation = sinking and math.sin(t * 10) * 6 or math.sin(t * 1.3) * 4
	local fi = (math.floor(t * (sinking and 10 or 4)) % 2) + 1
	for i, d in duckFrames do d.Visible = i == fi end
	if skin.duckFx == "rainbow" then
		local col = RAINBOW[(math.floor(t * 4) % #RAINBOW) + 1]
		if duckKey ~= col then
			duckKey = col
			for i, n in { "duck0", "duck1" } do
				local old = duckFrames[i]
				local d = pixel(n, px, { tint = col, z = 6 })
				d.Visible = old.Visible
				d.Parent = duckObj
				old:Destroy()
				duckFrames[i] = d
			end
		end
	end
	if fxObjs.glow then
		local fx = skin.duckFx
		local g = fxObjs.glow
		g.BackgroundColor3 = fx == "million" and hex("#ffd23f") or fx == "rainbow" and hex(RAINBOW[(math.floor(t * 4) % #RAINBOW) + 1]) or hex("#c8f0ff")
		g.BackgroundTransparency = fx == "million" and (0.68 - 0.08 * math.sin(t * 3)) or 0.8
		for i = 1, 6 do
			local sp = fxObjs["sp" .. i]
			local a = t * 1.3 + i * 2.39
			sp.Visible = math.sin(t * 5 + i * 1.7) > 0.3
			sp.Position = UDim2.fromOffset(8 * px + math.cos(a) * 14 * px * (0.6 + 0.4 * math.sin(i)), 6 * px + math.sin(a) * 10 * px)
			sp.BackgroundColor3 = (i % 2 == 0 and fx == "million") and hex("#ffd23f") or Color3.new(1, 1, 1)
		end
	end
	-- trail streaming up behind the duck
	local kind = skin.trail
	for k, d in trailDots do
		local kk = (k - 1) * 2
		local y = cy - 6.5 * px - 4 * px - kk * px
		local wob = math.sin(t * 9 + kk * 0.35) * 1.5 * px
		local a = 0.2 + 0.8 * (kk / 34)
		local show, col, w = sinking or kind == "aura" or kind == "fire", Color3.new(1, 1, 1), 2
		if kind == "rainbow" then col = hex(RAINBOW[(k % #RAINBOW) + 1]); w = 4
		elseif kind == "fire" then col = kk < 10 and hex("#fff3b0") or kk < 20 and hex("#ffb020") or hex("#ff4d2a"); w = math.max(1, 8 - math.floor(kk / 5))
		elseif kind == "bubble" then show = show and (kk + math.floor(t * 10)) % 5 == 0; col = hex("#c8f0ff"); wob = math.sin(kk + t * 4) * 4 * px
		elseif kind == "confetti" then show = show and (kk + math.floor(t * 10)) % 3 == 0; col = hex(({ "#ff3fb4", "#7dff6a", "#4ad0ff", "#ffe14a" })[(k % 4) + 1]); wob = math.sin(kk * 2.1 + t * 5) * 6 * px
		elseif kind == "sparkle" then show = show and (kk + math.floor(t * 12)) % 6 == 0; col = k % 2 == 0 and Color3.new(1, 1, 1) or hex("#ffe14a"); wob = math.sin(kk * 1.7 + t * 3) * 7 * px
		elseif kind == "money" then show = show and (kk + math.floor(t * 8)) % 4 == 0; col = hex("#7dff6a"); w = 3; wob = math.sin(kk * 1.3 + t * 3) * 6 * px
		elseif kind == "aura" then col = k % 2 == 0 and hex("#1a0b2e") or hex("#8a5cff"); w = math.max(2, 12 - math.floor(kk / 3)); wob = math.sin(t * 7 + kk * 0.5) * 2 * px end
		d.Visible = show
		d.BackgroundColor3 = col
		d.BackgroundTransparency = a
		d.Size = UDim2.fromOffset(w * px, 2 * px)
		d.Position = UDim2.fromOffset(math.floor(cx - w * px / 2 + wob), math.floor(y))
	end
end

-- title: the duck bobbing in the bowl; flush: swirl, whoops backflip, pulled down
local flushT0, flushDone = nil, nil
local FLUSH_SWIRL, FLUSH_DROP = 2.3, 0.75
local function drawTitle()
	local tt = title
	local show = view == "title" or view == "flush"
	layers.title.Visible = show
	if not show then return end
	local k = tt.k
	local cx, rimY, bowlR = tt.x0 + tt.tw * k / 2, tt.y0 + 6 * k, 6.5 * k
	local p = (view == "flush" and flushT0) and (os.clock() - flushT0) / FLUSH_SWIRL or -1
	-- after the swirl, the whole bathroom slides up and away as the duck drops into the pipes
	local slide = p >= 1 and easeIO(clamp((p - 1) * FLUSH_SWIRL / FLUSH_DROP, 0, 1)) or 0
	layers.title.Position = UDim2.fromOffset(0, -slide * H)
	for i, f in tt.foam do
		f.Visible = p >= 0 and p < 1.05
		if f.Visible then
			local sw = clamp(p / 0.9, 0, 1)
			local a = t * (2.5 + sw * 5) + (i - 1) * (math.pi * 2 / 16)
			local r = bowlR * (0.85 - sw * 0.45) * (0.7 + 0.3 * (((i - 1) * 7) % 5) / 4)
			f.Position = UDim2.fromOffset(math.floor(cx + math.cos(a) * r), math.floor(rimY + 2 * k / 3 + math.sin(a) * r * 0.22))
		end
	end
	local dh = 13 * tt.dk
	local dx, dy, rot, s = 0, 0, 0, 1
	if p < 0 then dy = math.sin(t * 1.8) * 1.5 * tt.dk; rot = math.sin(t * 1.3) * 0.08
	elseif p < 0.3 then local q = p / 0.3; dx = math.sin(t * 3) * bowlR * 0.18 * q; rot = math.sin(t * 5) * 0.22 * q; dy = math.sin(t * 4) * 0.8 * tt.dk
	elseif p < 0.58 then local q = (p - 0.3) / 0.28; dy = -math.sin(math.pi * q) * k * 3.2; rot = -easeIO(q) * math.pi * 2
	else local q = math.min(1, (p - 0.58) / 0.42); local e = easeIO(q); rot = math.sin(t * 6) * 0.15 * (1 - q); dy = e * dh * 1.15; s = 1 - e * 0.25 end
	tt.duck.Visible = p < 1
	tt.duck.Position = UDim2.fromOffset(math.floor(cx + dx), math.floor(rimY + k - dh / 2 + dy)) -- sits down in the bowl
	tt.duck.Rotation = math.deg(rot)
	tt.duck.UIScale.Scale = s
	if view == "flush" and p >= 1 + FLUSH_DROP / FLUSH_SWIRL then
		view = "dive"
		layers.title.Position = UDim2.fromOffset(0, 0)
		for _ = 1, 6 do spawnFloater(depthM - anchorY() / ppm + math.random() * H / ppm) end
		local cb = flushDone
		flushDone = nil
		if cb then task.spawn(cb) end
	end
end

local function step(dt)
	t += dt
	if view == "dive" or view == "flush" then
		depthM += (targetM - depthM) * math.min(1, dt * 1.6)
		if math.abs(targetM - depthM) < 0.5 then depthM = targetM end
	end
	drawWater()
	drawTitle()
	drawWalls()
	drawPipes()
	drawLedges()
	updateFloaters(dt)
	drawDuck(dt)
end

---------------------------------------------------------------- public API
function Scene.init(parent)
	root = frame({ Name = "Scene", Size = UDim2.fromScale(1, 1), BackgroundColor3 = hex("#9fd6e0"), ClipsDescendants = true, ZIndex = 0, Parent = parent })
	layers = {}
	for i, n in { "pipes", "walls", "ledges", "float", "duck", "title" } do
		layers[n] = frame({ Name = n, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = i, Parent = root })
	end
	rebuild()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(rebuild) end) end
	RunService.RenderStepped:Connect(step)
	return root
end

-- equip = profile.equip; shop = Config.SHOP (+ passes)
function Scene.setSkin(equip, shop)
	local function item(id)
		for _, s in shop do if s.id == id then return s end end
		return nil
	end
	local d, tl, tr = item(equip.duck or ""), item(equip.toilet or ""), item(equip.trail or "")
	local new = {
		duckTint = d and d.fx ~= "rainbow" and d.color or nil, duckFx = d and d.fx or nil,
		toiletSprite = tl and tl.sprite or "toilet", toiletTint = tl and not tl.sprite and tl.color or nil,
		trail = tr and tr.trail or nil,
	}
	local changed = false
	for k, v in new do if skin[k] ~= v then changed = true end end
	if not changed then return end
	skin = new
	if root then buildTitle(); buildDuck() end
end

function Scene.title()
	view = "title"
	depthM, targetM = 0, 0
end

-- plays the flush, then calls onDone once the duck is in the pipes
function Scene.flush(onDone)
	depthM, targetM = 0, 0
	for _, f in floaters do f.obj:Destroy(); for _, d in f.trail do d:Destroy() end end
	floaters = {}
	view = "flush"
	flushT0 = os.clock()
	flushDone = onDone
end

-- sink by the answer's tier (Sigma 1000 m ... NPC 30 m); depth follows points, like the website
function Scene.sink(score)
	targetM += TIER_DEPTH[score] or 0
end
function Scene.depth() return targetM end

-- a tier's pixel icon (for the reveal card / results)
function Scene.tierIcon(score, size)
	local name = TIER_ICON[score] or "icoNPC"
	local w = spriteSize(name)
	return pixel(name, math.max(1, math.floor(size / w)), {})
end

return Scene
