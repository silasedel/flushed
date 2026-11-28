--!native
-- FLUSHED world renderer: a line-for-line port of the website's js/ocean.js onto a Luau pixel canvas.
-- The bathroom wall + ceiling lamp, the toilet on the waterline with the duck in the bowl, the flush, the water,
-- light rays, the drain pipes, the brick sewer (sewer -> Rat Kingdom -> Brainrot Core -> rainbow insanity),
-- ledges with mice and disco balls, floating junk, bubbles, skins and trails: same maths, same pixels.
-- Pure Luau (no Roblox APIs) so tests can render it in the luau CLI and diff it against the website.
local Canvas = require(script and script.Parent and script.Parent:FindFirstChild("Canvas") or "./Canvas")
local Sprites = require(script and script.Parent and script.Parent:FindFirstChild("Sprites") or "./Sprites")
local TextRaster = require(script and script.Parent and script.Parent:FindFirstChild("TextRaster") or "./TextRaster")

local Ocean = {}

---------------------------------------------------------------- JS-compatible maths
local floor, sin, cos, abs, sqrt, min, max = math.floor, math.sin, math.cos, math.abs, math.sqrt, math.min, math.max
local fmod = math.fmod -- JS % (sign of the dividend)
local function round(x) return floor(x + 0.5) end -- JS Math.round
local function clamp(v, a, b) return max(a, min(b, v)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function toU32(x)
	local t = x >= 0 and floor(x) or -floor(-x)
	return t % 4294967296
end
local function toI32(x)
	local u = toU32(x)
	return u >= 2147483648 and u - 4294967296 or u
end
local bxor, rshift = bit32.bxor, bit32.rshift
local function hash(n) -- deterministic 0..1, bit-for-bit the same as the website
	n = toI32(n) * 374761393 + 668265263
	local u = toU32(n)
	n = toI32(bxor(u, rshift(u, 13))) * 1274126177
	u = toU32(n)
	local r = bxor(u, rshift(u, 16))
	return (r % 100000) / 100000
end
Ocean.hash = hash
local function hex(h)
	local r, g, b = Canvas.parseColor(h)
	return { r, g, b }
end
local function trunc(x) return x >= 0 and floor(x) or -floor(-x) end -- JS x|0
local function mix(a, b, t) return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) } end
local function toFixed3(a) return floor(a * 1000 + 0.5) / 1000 end
-- ctx.fillStyle = rgb(c[, a])
local function fillRGB(ctx, c, a) ctx:setRGBA(clamp(trunc(c[1]), 0, 255), clamp(trunc(c[2]), 0, 255), clamp(trunc(c[3]), 0, 255), a and clamp(a, 0, 1) or 1) end

-- random numbers: math.random in the game; tests swap in the same seeded generator as the website reference
Ocean.random = math.random

---------------------------------------------------------------- zones
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
			return mix(a[2], b[2], (m - a[1]) / (b[1] - a[1]))
		end
	end
	return WATER[#WATER][2]
end
Ocean.waterColor = waterColor
local Z_RAT, Z_CORE, Z_MAD = 3600, 4600, 5600
Ocean.ZONES = {
	{ name = "Bowl", from = 0, to = 200 }, { name = "Pipes", from = 200, to = 1000 }, { name = "Sewer", from = 1000, to = Z_RAT },
	{ name = "Rat Kingdom", from = Z_RAT, to = Z_CORE }, { name = "Brainrot Core", from = Z_CORE, to = 99999 },
}
local function zoneIndex(m)
	if m < 200 then return 0 elseif m < 1000 then return 1 elseif m < Z_RAT then return 2 elseif m < Z_CORE then return 3 end
	return 4
end
Ocean.zoneIndex = zoneIndex
local OFF = 275
local function dz(m) return m - OFF end

---------------------------------------------------------------- sprites
local spriteCache = {}
local function sprite(name, tint)
	local key = name .. (tint or "")
	local c = spriteCache[key]
	if c then return c end
	local s = Sprites[name]
	assert(s, "no sprite " .. tostring(name))
	local w, h = s.w, s.h
	local img, flip = Canvas.image(w, h), Canvas.image(w, h)
	local pal = {}
	for i, ph in s.pal do
		local col
		if tint and tint:sub(1, 1) == "~" then
			local t = hex(tint:sub(2))
			local o = hex(ph)
			local lum = (0.3 * o[1] + 0.59 * o[2] + 0.11 * o[3]) / 255
			if lum < 0.16 then col = hex("#0a1222")
			else col = { trunc(min(255, t[1] * (0.5 + 0.7 * lum))), trunc(min(255, t[2] * (0.5 + 0.7 * lum))), trunc(min(255, t[3] * (0.5 + 0.7 * lum))) } end
		elseif tint then
			col = hex(tint)
		else
			col = hex(ph)
		end
		pal[i] = col
	end
	local r = s.runs
	for i = 1, #r, 4 do
		local x0, y, len, ci = r[i], r[i + 1], r[i + 2], r[i + 3]
		local col = pal[ci]
		for x = x0, x0 + len - 1 do
			Canvas.setPixel(img, x, y, col[1], col[2], col[3], 255)
			Canvas.setPixel(flip, w - 1 - x, y, col[1], col[2], col[3], 255)
		end
	end
	c = { c = img, f = flip, w = w, h = h }
	spriteCache[key] = c
	return c
end
Ocean.sprite = sprite
local function drawSprite(ctx, name, x, y, flip, tint)
	local s = sprite(name, tint)
	ctx:drawImage(flip and s.f or s.c, round(x), round(y))
	return s
end
Ocean.drawSprite = drawSprite

---------------------------------------------------------------- state
local O = {
	ctx = nil, W = 0, H = 0, scale = 3, cssW = 1280, cssH = 720,
	view = "title", reduced = false, tmix = 1,
	shrimpM = 0, shrimpFrom = 0, shrimpTo = 0, tweenT0 = 0, tweenDur = 0,
	topM = -9999, ppm = 0,
	t = 0, last = nil, bubbles = {}, showShrimp = false, sinking = false, skin = {},
	sxf = nil, sxTarget = nil, flushT0 = nil, flushDropped = false, camV = 0, dusk = 0, toiletCX = nil, onDepth = nil,
}
Ocean.state = O

local function gameAnchor() return O.cssW < 700 and 0.74 or 0.62 end
local function resize(cssW, cssH)
	O.cssW, O.cssH = cssW, cssH
	O.scale = cssW < 700 and 2 or (cssW > 1900 and 4 or 3)
	O.W, O.H = math.ceil(cssW / O.scale), math.ceil(cssH / O.scale)
	O.ctx = Canvas.new(O.W, O.H)
	O.ppm = O.H / 420
	OFF = math.ceil(gameAnchor() * 420) + 15
end
local function shrimpWorld() return O.shrimpM + OFF end
local function midX() return (O.W / 2 - 8) / O.W end
local function shrimpX() return round(O.W * (O.sxf ~= nil and O.sxf or midX())) end
local function viewTop()
	local H, ppm = O.H, O.ppm
	if O.view == "title" then return -(H * (O.cssW < 700 and 0.5 or 0.61)) / ppm end
	if O.view == "results" then return -(H * (O.cssW < 700 and 0.45 or 0.58)) / ppm end
	if O.view == "menu" then return -(H * 0.3) / ppm end
	if O.view == "intro" then return -(H * 0.42) / ppm end
	return shrimpWorld() - (H * gameAnchor()) / ppm
end

---------------------------------------------------------------- drawing
local function disc(ctx, cx, cy, r)
	for y = -r, r do
		local w = floor(sqrt(r * r - y * y))
		ctx:fillRect(cx - w, cy + y, w * 2 + 1, 1)
	end
end

local function glow(ctx, x, y, r, col, a)
	local i = r
	while i > 0 do
		fillRGB(ctx, col, toFixed3(a * 0.6 * (1 - i / (r + 1))))
		local k = round(i * 0.55)
		ctx:fillRect(round(x - i), round(y - k), i * 2, k * 2)
		ctx:fillRect(round(x - k), round(y - i), k * 2, i * 2)
		i -= 2
	end
end

local function drawSky(ctx, yTop, ySurf)
	if ySurf <= 0 then return end
	local T, top, bot = 14, 0, math.ceil(ySurf)
	ctx:setFill("#e3eaef"); ctx:fillRect(0, top, O.W, bot)
	ctx:setFill("#d4dde4"); ctx:fillRect(0, max(0, bot - round(bot * 0.25)), O.W, round(bot * 0.25))
	ctx:setFill("#c2ccd5")
	local y = fmod(bot, T)
	while y < bot do ctx:fillRect(0, y, O.W, 1); y += T end
	local x = 0
	while x < O.W do ctx:fillRect(x, 0, 1, bot); x += T end
	ctx:setRGBA(255, 255, 255, 0.55)
	y = fmod(bot, T)
	while y < bot do
		x = 0
		while x < O.W do ctx:fillRect(x + 2, y + 2, 3, 1); x += T end
		y += T
	end
	if ySurf > 60 then -- ceiling lamp, top right
		local cx, r = round(O.W * 0.86), max(6, round(O.H * 0.035))
		ctx:setFill("#7d8894"); ctx:fillRect(cx, 0, 1, r * 2)
		for k = 4, 1, -1 do
			ctx:setRGBA(255, 236, 170, 0.09 * (5 - k) / 4)
			disc(ctx, cx, r * 3, r + k * 6)
		end
		ctx:setFill("#5a6470"); ctx:fillRect(cx - r, r * 2, r * 2 + 1, 3)
		ctx:setFill("#fff3b0"); disc(ctx, cx, r * 3, r)
		ctx:setFill("#ffffff"); disc(ctx, cx - round(r * 0.3), r * 3 - round(r * 0.3), round(r * 0.35))
	end
end

local function drawWater(ctx, ySurf)
	local ppm = O.ppm
	local start = max(0, floor(ySurf))
	local band = 3
	local y = start
	while y < O.H do
		local m = O.topM + y / ppm
		local c = waterColor(lerp(dz(m), max(0, m) * 6, O.tmix))
		ctx:setRGBA(round(c[1] / 4) * 4, round(c[2] / 4) * 4, round(c[3] / 4) * 4, 1)
		ctx:fillRect(0, y, O.W, band)
		y += band
	end
end

local function drawRays(ctx, ySurf)
	local ppm = O.ppm
	local yEnd = min(O.H, ySurf + 900 * ppm)
	if yEnd <= 0 then return end
	for r = 0, 4 do
		local base = (hash(r * 91) * O.W * 1.3) - O.W * 0.15 + sin(O.t * 0.15 + r) * 8
		local width = 6 + hash(r * 7) * 14
		local y = max(0, floor(ySurf))
		while y < yEnd do
			local m = O.topM + y / ppm
			local a = 0.09 * (1 - O.tmix) * (1 - clamp(m / 900, 0, 1)) * (0.7 + 0.3 * sin(O.t * 0.5 + r * 2))
			if a > 0.005 then
				ctx:setRGBA(210, 245, 255, toFixed3(a))
				ctx:fillRect(round(base - (y - ySurf) * 0.35), y, round(width), 2)
			end
			y += 2
		end
	end
end

local RAINBOW = { "#ff4d6a", "#ff9a2a", "#ffe14a", "#7dff6a", "#4ad0ff", "#8a7aff", "#ff7ad9" }
local function duckTint()
	if O.skin.duckFx == "rainbow" then return "~" .. RAINBOW[floor(O.t * 4) % #RAINBOW + 1] end
	return O.skin.duckTint
end
local function sparkles(ctx, cx, cy, r, n, cols)
	for i = 0, n - 1 do
		local a = O.t * 1.3 + i * 2.39
		local on = sin(O.t * 5 + i * 1.7) > 0.3
		if on then
			local x, y = round(cx + cos(a) * r * (0.6 + 0.4 * sin(i))), round(cy + sin(a) * r * 0.7)
			ctx:setFill(cols[i % #cols + 1]); ctx:fillRect(x, y - 1, 1, 3); ctx:fillRect(x - 1, y, 3, 1)
		end
	end
end

local FLUSH_SWIRL, FLUSH_DROP = 2300, 750
local function flushP(now) return O.flushT0 and (now - O.flushT0) / FLUSH_SWIRL or -1 end
local function easeIO(x) return x < 0.5 and 2 * x * x or 1 - ((-2 * x + 2) ^ 2) / 2 end
local function drawDuckInBowl(ctx, bs, bx, ty, k, now)
	local p = O.view == "intro" and (O.reduced and 1 or flushP(now)) or -1
	local cx, rimY, bowlR = bx + round(bs.w * k / 2), ty + 6 * k, 6.5 * k
	local ds = sprite("duck0", duckTint())
	local ds0 = k * 0.42
	if p >= 0 and p < 1.05 then -- calm swirl of foam that slowly tightens
		local sw, n = clamp(p / 0.9, 0, 1), 16
		for i = 0, n - 1 do
			local a = O.t * (2.5 + sw * 5) + i * (math.pi * 2 / n)
			local r = bowlR * (0.85 - sw * 0.45) * (0.7 + 0.3 * ((i * 7) % 5) / 4)
			if i % 4 ~= 0 then ctx:setRGBA(159, 214, 224, 0.9) else ctx:setFill("#ffffff") end
			ctx:fillRect(round(cx + cos(a) * r), round(rimY + 2 + sin(a) * r * 0.22), 2, 1)
		end
	end
	if p >= 1 then
		ctx:drawImage(bs.c, 0, 7, bs.w, bs.h - 7, bx, ty + 7 * k, bs.w * k, (bs.h - 7) * k)
		return
	end
	local dx, dy, rot, s = 0, 0, 0, ds0
	if p < 0 then dy = sin(O.t * 1.8) * 1.5; rot = sin(O.t * 1.3) * 0.08
	elseif p < 0.3 then
		local q = p / 0.3
		dx = sin(O.t * 3) * bowlR * 0.18 * q; rot = sin(O.t * 5) * 0.22 * q; dy = sin(O.t * 4) * 0.8
	elseif p < 0.58 then
		local q = (p - 0.3) / 0.28
		dy = -sin(math.pi * q) * k * 3.2; rot = -easeIO(q) * math.pi * 2
	else
		local q = (p - 0.58) / 0.42
		local e = easeIO(q)
		rot = sin(O.t * 6) * 0.15 * (1 - q); dy = e * ds.h * ds0 * 1.15; s = ds0 * (1 - e * 0.25)
	end
	local cy = rimY + 2 - ds.h * ds0 / 2 + dy
	ctx:save(); ctx:translate(round(cx + dx), round(cy)); ctx:rotate(rot)
	ctx:drawImage(ds.c, round(-ds.w * s / 2), round(-ds.h * s / 2), round(ds.w * s), round(ds.h * s)); ctx:restore()
	ctx:drawImage(bs.c, 0, 7, bs.w, bs.h - 7, bx, ty + 7 * k, bs.w * k, (bs.h - 7) * k) -- bowl front hides the duck going down
end

local function drawSurface(ctx, ySurf, now)
	if ySurf < -40 or ySurf > O.H + 10 then return end
	local y = round(ySurf)
	for x = 0, O.W - 1 do
		local w = round(1.6 + sin(x * 0.035 + O.t * 0.9) * 1.3 + sin(x * 0.011 - O.t * 0.5) * 0.9)
		if w > 0 then ctx:setFill("#d4dde4"); ctx:fillRect(x, y, 1, w) end
		ctx:setFill("#c4eef3"); ctx:fillRect(x, y + w, 1, 1)
		ctx:setFill("#4f8f9b"); ctx:fillRect(x, y + w + 1, 1, 1)
	end
	-- the toilet the duck got flushed down, sitting on the waterline
	local big = O.view == "title" or O.view == "intro"
	local k = O.view == "results" and 2 or (big and (O.cssW < 700 and 4 or 5) or 3)
	local bs = sprite(O.skin.toiletSprite or "toilet", (not O.skin.toiletSprite) and O.skin.toiletTint or nil)
	local cxF = O.view == "results" and 0.1 or (big and (O.cssW < 700 and 0.24 or 0.17) or 0.17)
	local bx = round(O.W * cxF - bs.w * k / 2)
	O.toiletCX = bx + bs.w * k / 2
	local surfAt = round(1.6 + sin((bx + bs.w * k / 2) * 0.035 + O.t * 0.9) * 1.3)
	local ty = y + surfAt - (bs.h - 2) * k
	if O.skin.toiletFx == "diamond" then glow(ctx, bx + bs.w * k / 2, ty + bs.h * k / 2, bs.w * k * 0.7, { 200, 240, 255 }, 0.2) end
	ctx:drawImage(bs.c, bx, ty, bs.w * k, bs.h * k)
	if O.skin.toiletFx == "diamond" then sparkles(ctx, bx + bs.w * k / 2, ty + bs.h * k / 2, bs.w * k * 0.6, 10, { "#ffffff", "#bff0ff" }) end
	if O.skin.toiletFx == "crown" then -- the rat king's crown on the tank
		local cw = 8 * k / 2
		local cx0, cy0, u = round(bx + bs.w * k / 2 - cw / 2), round(ty - 5 * k / 2), max(1, round(k / 2))
		ctx:setFill("#ffd23f"); ctx:fillRect(cx0, cy0 + 2 * u, cw, 3 * u)
		for i = 0, 2 do ctx:fillRect(cx0 + round(i * (cw - u) / 2), cy0, u, 2 * u) end
		ctx:setFill("#ff3f6a"); ctx:fillRect(cx0 + round(cw / 2) - u, cy0 + 3 * u, u * 2, u)
		glow(ctx, cx0 + cw / 2, cy0 + 2 * u, cw, { 255, 210, 63 }, 0.2)
	end
	if O.view == "title" or O.view == "intro" then drawDuckInBowl(ctx, bs, bx, ty, k, now) end
end

local ZONE_JUNK = {
	[0] = { "tpWad", "tpWad", "tpSheet", "flossPick", "qtip", "gum", "bandaid", "soapBar", "toothbrush", "tpWad", "duckling" },
	[1] = { "tpWad", "ring", "lego", "keys", "phone", "coin", "sock", "airpod", "goldfish", "flossPick", "duckling", "tpSheet" },
	[2] = { "mouse", "mouse", "rat", "rat", "pizza", "gatorEyes", "tpWad", "coin", "mouse", "tpSheet" },
	[3] = { "crownMouse", "ratking", "cheese", "chain", "crownMouse", "coin", "coin", "rat", "cheese", "ratking" },
	[4] = { "partyMouse", "partyMouse", "disco", "boombox", "partyMouse", "cheese", "disco", "partyMouseB" },
}
local function zoneCreatures(z, rnd)
	local arr = ZONE_JUNK[z]
	return arr[fmod(floor(rnd * #arr), #arr) + 1]
end

---------------------------------------------------------------- walls
local function smooth(a, b, x)
	local q = clamp((x - a) / (b - a), 0, 1)
	return q * q * (3 - 2 * q)
end
local function beatPulse() return (1 - fmod(O.t * 2.1, 1)) ^ 3 end
local function rgbA(t) return { t[1], t[2], t[3] } end
local WALL = {
	sewer = { { 46, 61, 45 }, { 67, 87, 63 }, { 27, 36, 26 }, { 21, 29, 21 }, { 125, 255, 106 } },
	rat = { { 47, 34, 68 }, { 67, 50, 95 }, { 27, 18, 41 }, { 20, 13, 31 }, { 255, 213, 74 } },
	core = { { 58, 18, 54 }, { 86, 32, 79 }, { 30, 8, 28 }, { 22, 6, 26 }, { 255, 63, 180 } },
}
local function hsl2rgb(h, s, l)
	s /= 100; l /= 100
	local a = s * min(l, 1 - l)
	local function f(n)
		local k = fmod(n + h / 30, 12)
		return l - a * max(-1, min(k - 3, 9 - k, 1))
	end
	return { f(0) * 255, f(8) * 255, f(4) * 255 }
end
local function madWall(m)
	local ins = clamp((m - Z_MAD) / 1500, 0, 2.5)
	local h = fmod(m / 6 + O.t * (40 + ins * 70), 360)
	local l = 18 + beatPulse() * (8 + ins * 6)
	return { hsl2rgb(h, 55, l), hsl2rgb(h, 70, l + 14), hsl2rgb(h, 50, max(4, l - 8)), hsl2rgb(h, 40, max(4, l - 12)), hsl2rgb(fmod(h + 180, 360), 100, 65) }
end
local function mixP(A, B, q)
	local out = {}
	for i = 1, 5 do out[i] = mix(A[i], B[i], q) end
	return out
end
-- returns 5 colours; [5] is drawn at 0.6 alpha (the website's rgb(P[4], 0.6)).
-- Cached by depth in 1/4 m steps (colour changes by far less than 1/255 per step): outside the rainbow zone the
-- colours never change, inside it they're recomputed once per frame.
local staticCache, madCache, madCacheT, staticCount = {}, {}, -1, 0
local wallColorsRaw
local function wallColors(m, jitter)
	m += jitter or 0
	local key = floor(m * 4)
	if m > Z_MAD - 260 then
		if madCacheT ~= O.t then table.clear(madCache); madCacheT = O.t end
		local mk = floor(m / 3) -- 3 m buckets: hue moves 0.5 degrees per bucket, invisible
		local c = madCache[mk]
		if not c then c = wallColorsRaw(mk * 3 + 1.5); madCache[mk] = c end
		return c
	end
	local c = staticCache[key]
	if not c then
		if staticCount > 50000 then table.clear(staticCache); staticCount = 0 end
		c = wallColorsRaw(key / 4); staticCache[key] = c; staticCount += 1
	end
	return c
end
function wallColorsRaw(m)
	local band = 260
	local P
	if m < Z_RAT then P = mixP(WALL.sewer, WALL.rat, smooth(Z_RAT - band, Z_RAT + band, m))
	elseif m < Z_CORE then P = mixP(WALL.rat, WALL.core, smooth(Z_CORE - band, Z_CORE + band, m))
	else P = WALL.core end
	if m < Z_RAT + band and m >= Z_RAT then P = mixP(WALL.sewer, WALL.rat, smooth(Z_RAT - band, Z_RAT + band, m)) end
	if m > Z_MAD - band then P = mixP(P, madWall(m), smooth(Z_MAD - band, Z_MAD + band, m)) end
	return P
end

local PIPE_TOP, SEWER_TOP = 110, 1000
local PIPES = { { 0.018, 10, 120, 988 }, { 0.07, 6, 170, 988 }, { 0.93, 7, 145, 988 }, { 0.978, 10, 120, 988 } }
local function pipeW(d) return d < PIPE_TOP and 0 or O.W * 0.07 + 8 end
local function sewerW(d, side)
	local n = sin(d * (side == 1 and 0.027 or 0.031) + side * 2) * 6 + sin(d * (side == 1 and 0.09 or 0.11)) * 3
	return O.W * (0.2 + 0.1 * clamp((d - SEWER_TOP) / 5000, 0, 1)) + n
end
local BH, BW = 10, 20
local function rowDepth(r) return (r * BH + BH / 2) / O.ppm - OFF end
local function wallAt(d, side) return round(sewerW(rowDepth(floor(((d + OFF) * O.ppm) / BH)), side)) end

local function drawPipes(ctx)
	local ppm, W = O.ppm, O.W
	local function Y(m) return round((m + OFF - O.topM) * ppm) end
	for i, P in PIPES do
		local fx, w, top, bot = P[1], P[2], P[3], P[4]
		local x, right = round(W * fx - w / 2), fx > 0.5
		local y0, y1 = Y(top), Y(bot)
		if not (y1 < -10 or y0 > O.H + 10) then
			local ya, yb = max(-2, y0), min(O.H + 2, y1)
			ctx:setFill("#4c5660"); ctx:fillRect(x, ya, w, yb - ya)
			ctx:setFill("#6e7b86"); ctx:fillRect(x + 1, ya, 2, yb - ya)
			ctx:setFill("#323a41"); ctx:fillRect(x + w - 2, ya, 2, yb - ya)
			local m = top + 40 + (i - 1) * 9
			while m < bot - 10 do
				local y = Y(m)
				if not (y < -6 or y > O.H + 6) then
					ctx:setFill("#5d6872"); ctx:fillRect(x - 2, y, w + 4, 4)
					ctx:setFill("#88949f"); ctx:fillRect(x - 2, y, w + 4, 1)
					ctx:setFill("#2a3036"); ctx:fillRect(x - 1, y + 2, 1, 1); ctx:fillRect(x + w, y + 2, 1, 1)
				end
				m += 60
			end
			if y0 > -20 and y0 < O.H + 20 then -- elbow back into the wall
				local ex0, ew = right and x or 0, right and (W - x) or (x + w)
				ctx:setFill("#4c5660"); ctx:fillRect(ex0, y0 - w, ew, w)
				ctx:setFill("#6e7b86"); ctx:fillRect(ex0, y0 - w + 1, ew, 2)
				ctx:setFill("#323a41"); ctx:fillRect(ex0, y0 - 2, ew, 2)
				ctx:setFill("#5d6872"); ctx:fillRect(right and x or (x + w - 1), y0 - w - 1, 2, w + 2)
			end
			if y1 > -20 and y1 < O.H + 20 then -- collar into the archway
				ctx:setFill("#5d6872"); ctx:fillRect(x - 2, y1 - 5, w + 4, 5); ctx:setFill("#88949f"); ctx:fillRect(x - 2, y1 - 5, w + 4, 1)
				ctx:setFill("#2a3036"); ctx:fillRect(x - 1, y1 - 3, 1, 1); ctx:fillRect(x + w, y1 - 3, 1, 1)
			end
		end
	end
end

local function drawLedges(ctx)
	local ppm, W, STEP, kick = O.ppm, O.W, 70, beatPulse()
	local top, bot = dz(O.topM) - 60, dz(O.topM + O.H / ppm) + 60
	local L = max(SEWER_TOP + 150, floor(top / STEP) * STEP)
	while L < bot do
		local s = L * 7 + 13
		local deepness = clamp((L - Z_CORE) / 2600, 0, 1.4)
		local chance = L < Z_RAT and 0.16 or (L < Z_CORE and 0.55 or min(0.95, 0.42 + 0.38 * deepness))
		if hash(s) <= chance then
			local side = hash(s + 1) > 0.5 and 1 or 0
			local y = round(round(((L + OFF) * ppm) / BH) * BH - O.topM * ppm)
			local edge, len, zc = wallAt(L, side), 30 + floor(hash(s + 2) * 3) * 6, wallColors(L)
			local x0 = side == 1 and round(W - edge - len) or round(edge - 2)
			fillRGB(ctx, zc[3]); ctx:fillRect(x0, y, len + 2, 7)
			fillRGB(ctx, zc[1]); ctx:fillRect(x0 + 1, y, len, 3); ctx:fillRect(x0 + 1, y + 4, len, 2)
			fillRGB(ctx, zc[2]); ctx:fillRect(x0 + 1, y, len, 1)
			fillRGB(ctx, zc[4])
			local bx = x0 + 6 + (side == 1 and 0 or 3)
			while bx < x0 + len do ctx:fillRect(bx, y + 1, 1, 2); bx += 9 end
			local mid = side == 1 and (x0 + round(len * 0.4)) or (x0 + round(len * 0.6))
			local kind = hash(s + 3)
			local flip = side == 1
			if L < Z_RAT then
				if kind < 0.6 then drawSprite(ctx, "mouse0", mid - 15, y - sprite("mouse0").h + 1, flip)
				else drawSprite(ctx, "rat0", mid - 15, y - sprite("rat0").h + 1, flip) end
			elseif L < Z_CORE then
				if kind < 0.45 then drawSprite(ctx, "crownMouse", mid - 15, y - sprite("crownMouse").h + 1, flip)
				elseif kind < 0.75 then glow(ctx, mid, y - 6, 10, { 255, 213, 74 }, 0.14); drawSprite(ctx, "cheese", mid - 11, y - sprite("cheese").h + 1, flip)
				else drawSprite(ctx, "coin", mid - 8, y - 11); drawSprite(ctx, "coin", mid - 2, y - 11); drawSprite(ctx, "coin", mid - 5, y - 19) end
				if hash(s + 4) > 0.6 then drawSprite(ctx, "chain", x0 + 2, y + 6) end
			else
				local v = ({ "partyMouse", "partyMouseB", "partyMouseC" })[floor(hash(s + 5) * 3) + 1]
				local ms = sprite(v)
				local jump = round((fmod(floor(L / STEP), 2) ~= 0 and kick or (1 - fmod(O.t * 2.1 + 0.5, 1)) ^ 3) * 3)
				if kind < 0.5 then
					drawSprite(ctx, v, mid - 15, y - ms.h + 1 - jump, flip)
				elseif kind < 0.75 then
					drawSprite(ctx, "boombox", mid - 14, y - sprite("boombox").h + 1)
					ctx:setFill(({ "#ff3fb4", "#7dff6a", "#4ad0ff" })[floor(O.t * 2) % 3 + 1])
					local ny = y - 22 - round(fmod(O.t * 12, 14))
					ctx:fillRect(mid + 2, ny, 2, 2); ctx:fillRect(mid + 3, ny - 4, 1, 4)
				else
					drawSprite(ctx, v, mid - 15, y - ms.h + 1 - jump, flip)
					drawSprite(ctx, "cheese", flip and (mid + 12) or (mid - 34), y - sprite("cheese").h + 1, flip)
				end
				if hash(s + 7) > 0.45 then -- disco ball under the ledge, throwing beams across the tunnel
					local bx2, by = flip and (x0 + 4) or (x0 + len - 4), y + 14
					ctx:setFill("#5a5a6a"); ctx:fillRect(bx2, y + 6, 1, 8)
					local beams = { "#ff3fb4", "#7dff6a", "#4ad0ff", "#ffe14a" }
					for i = 0, 3 do
						local a = O.t * 0.9 + i * 1.57 + hash(s + 8) * 6
						local c = hex(beams[i + 1])
						ctx:setRGBA(c[1], c[2], c[3], toFixed3(0.06 + 0.05 * kick))
						ctx:beginPath(); ctx:moveTo(bx2, by + 11)
						ctx:lineTo(bx2 + cos(a - 0.08) * 90, by + 11 + sin(a - 0.08) * 90)
						ctx:lineTo(bx2 + cos(a + 0.08) * 90, by + 11 + sin(a + 0.08) * 90); ctx:fill()
					end
					glow(ctx, bx2, by + 11, 14, { 255, 255, 255 }, 0.14 + 0.1 * kick)
					drawSprite(ctx, "disco", bx2 - 11, by, floor(O.t * 4) % 2 == 1)
				end
			end
		end
		L += STEP
	end
end

local drawBurrow, drawWord
-- Burrows: a hollowed-out arch in the bricks, a little home. Some have a mouse peeking out, some just eyes.
drawBurrow = function(ctx, r, side, yb, wall, d)
	local W = O.W
	local s = r * 53 + side * 17
	local hw, hh = 22, 16
	local cx = wall * (0.35 + hash(s + 1) * 0.35)
	local x = round(side == 1 and (W - cx - hw / 2) or (cx - hw / 2))
	local y = yb - 6
	local zc = wallColors(d)
	-- frame (lighter stones around the arch), then the dark inside
	fillRGB(ctx, zc[2]); ctx:fillRect(x - 2, y + 2, hw + 4, hh); ctx:fillRect(x, y, hw, 2)
	ctx:setRGBA(8, 6, 12, 1)
	ctx:fillRect(x, y + 4, hw, hh - 4); ctx:fillRect(x + 2, y + 2, hw - 4, 2); ctx:fillRect(x + 5, y + 1, hw - 10, 1)
	-- floor: a tiny rug
	local rugs = { { 255, 63, 180 }, { 125, 255, 106 }, { 255, 213, 74 }, { 74, 208, 255 } }
	fillRGB(ctx, rugs[floor(hash(s + 2) * 4) + 1], 0.7); ctx:fillRect(x + 3, y + hh - 2, hw - 6, 1)
	local kind = hash(s + 3)
	local t = O.t + hash(s + 4) * 9
	if kind < 0.55 then
		-- a mouse leaning out: slides out, looks around, ducks back in
		local cyc = fmod(t, 7) / 7
		local out = cyc < 0.15 and cyc / 0.15 or (cyc < 0.6 and 1 or (cyc < 0.75 and 1 - (cyc - 0.6) / 0.15 or 0))
		local face = side == 0 -- left wall: face right, into the tunnel
		local name = d >= Z_CORE and "partyMouse" or "mouse0"
		local sp = sprite(name)
		local px = face and round(x + hw - sp.w * 0.55 + out * 8) or round(x - sp.w * 0.45 - out * 8)
		ctx:save(); ctx:clipRect(face and x or (x - 24), y - 4, hw + 24, hh + 3)
		drawSprite(ctx, name, px, y + hh - sp.h - 1, not face)
		ctx:restore()
	else
		-- eyes in the dark, blinking
		if fmod(t, 4) > 0.25 then
			ctx:setRGBA(255, 220, 90, 1)
			local ex = x + 7 + round(sin(t * 0.7) * 2)
			ctx:fillRect(ex, y + 9, 2, 2); ctx:fillRect(ex + 6, y + 9, 2, 2)
			glow(ctx, ex + 4, y + 10, 7, { 255, 213, 74 }, 0.18)
		end
	end
	if d >= Z_CORE then -- party zone: string lights over the door
		local cols = { "#ff3fb4", "#7dff6a", "#4ad0ff", "#ffe14a" }
		for i = 0, 4 do
			ctx:setFill(cols[(i + floor(O.t * 3)) % 4 + 1]); ctx:fillRect(x - 1 + i * 6, y - 3 + (i % 2), 2, 2)
		end
	end
end
-- Words painted on the bricks, like graffiti (zone-themed brainrot)
local WORDS = {
	sewer = { "HELP", "TURN BACK", "WET FLOOR", "NO DIVING", "FLUSHED", "WHO DID THIS" },
	rat = { "RAT KING", "SQUEAK", "NO CATS", "CHEESE=LIFE", "KEEP OUT", "W RIZZ", "OHIO ->" },
	core = { "SKIBIDI", "SIGMA", "GYATT", "NO CAP", "FANUM TAX", "BRAINROT", "SUS", "LOCK IN" },
}
drawWord = function(ctx, r, side, yb, wall, d)
	local list = d < Z_RAT and WORDS.sewer or (d < Z_CORE and WORDS.rat or WORDS.core)
	local s = r * 29 + side * 3
	local word = list[floor(hash(s + 1) * #list) + 1]
	local opts = { family = "vt323", size = 12 }
	local L = TextRaster.layout(word, opts)
	if L.w > wall - 12 then return end
	local cx = wall * (0.3 + hash(s + 2) * 0.4)
	cx = clamp(cx, L.w / 2 + 4, wall - L.w / 2 - 6)
	local x = side == 1 and (O.W - cx - L.w / 2) or (cx - L.w / 2)
	local zc = wallColors(d)
	local col = zc[5]
	local a = 0.85 + 0.1 * sin(O.t * 1.5 + r)
	ctx:setRGBA(clamp(trunc(col[1]), 0, 255), clamp(trunc(col[2]), 0, 255), clamp(trunc(col[3]), 0, 255), a)
	TextRaster.draw(word, opts, L, x, yb - 2, L.w, function(x0, x1, yy) ctx:fillRect(x0, yy, x1 - x0 + 1, 1) end)
	-- drips under some letters
	if hash(s + 3) > 0.5 then ctx:fillRect(round(x + L.w * 0.3), yb + 9, 1, 2 + floor(hash(s + 4) * 3)) end
end

local function drawTrench(ctx)
	local ppm = O.ppm
	local yStart = (PIPE_TOP - 40 + OFF - O.topM) * ppm
	if yStart > O.H then return end
	local W = O.W
	drawPipes(ctx)
	local r0, r1 = floor((O.topM * ppm) / BH) - 1, math.ceil(((O.topM * ppm) + O.H) / BH) + 1
	local deco = {} -- burrows and wall words, drawn after every brick row so nothing covers them
	for r = r0 - 2, r1 + 2 do
		local yb, d = round(r * BH - O.topM * ppm), rowDepth(r)
		if d >= SEWER_TOP then
			local row = wallColors(d)
			for side = 0, 1 do
				local wall = wallAt(d, side)
				if wall >= 2 then
					fillRGB(ctx, row[4]); ctx:fillRect(side == 1 and (W - wall) or 0, yb, wall, BH)
					local off = fmod(r, 2) ~= 0 and (BW / 2) or 0
					local c = 0
					while c * BW - off < wall do
						local s = r * 131 + c * 17 + side * 7919
						local bx0, bx1 = max(0, c * BW - off), min(c * BW - off + BW - 2, wall - 1)
						if bx1 - bx0 >= 3 then
							local w, h = bx1 - bx0, BH - 2
							local x = side == 1 and (W - bx1) or bx0
							local zc = wallColors(d, (hash(s + 99) - 0.5) * 320)
							fillRGB(ctx, zc[1]); ctx:fillRect(x, yb, w, h)
							fillRGB(ctx, zc[2]); ctx:fillRect(x, yb, w, 1); ctx:fillRect(side == 1 and (x + w - 1) or x, yb, 1, h)
							fillRGB(ctx, zc[3]); ctx:fillRect(x, yb + h - 1, w, 1)
							if hash(s + 4) > 0.84 and w > 8 then
								fillRGB(ctx, zc[5], 0.6)
								ctx:fillRect(x + 2 + floor(hash(s + 6) * (w - 5)), yb + h - 1, 2, 2 + floor(hash(s + 7) * 3))
							end
						end
						c += 1
					end
					ctx:setRGBA(0, 0, 0, 0.32); ctx:fillRect(side == 1 and (W - wall - 2) or wall, yb, 2, BH)
					fillRGB(ctx, row[2]); ctx:fillRect(side == 1 and (W - wall) or (wall - 1), yb, 1, BH - 2)
					if d >= Z_RAT - 150 and d < Z_CORE + 300 and hash(r * 11 + side * 5) > 0.9 then -- torches
						local tx, ty = side == 1 and (W - wall + 3) or (wall - 7), yb - 4
						local fl = sin(O.t * 13 + r) * 0.5 + sin(O.t * 7.3 + r * 2) * 0.5
						glow(ctx, tx + 2, ty - 3, 14, { 255, 170, 60 }, 0.22 + 0.08 * fl)
						ctx:setFill("#3a2a1a"); ctx:fillRect(tx + 1, ty, 3, 7); ctx:setFill("#7a5a3a"); ctx:fillRect(tx, ty, 5, 2)
						ctx:setFill("#ff6a1f"); ctx:fillRect(tx + 1, ty - 4, 3, 4); ctx:setFill("#ffd23f"); ctx:fillRect(tx + 2, ty - 5 - round(fl), 1, 4)
						ctx:setFill("#fff3b0"); ctx:fillRect(tx + 2, ty - 2, 1, 1)
					end
					if d >= Z_RAT - 150 and fmod(r, 3) == 0 and hash(r * 53 + side * 17) > 0.86 and wall > 40 then table.insert(deco, { drawBurrow, r, side, yb, wall, d }) end
					if d >= SEWER_TOP + 200 and fmod(r, 3) == 1 and hash(r * 29 + side * 3) > (d < Z_RAT and 0.95 or 0.9) and wall > 44 then table.insert(deco, { drawWord, r, side, yb, wall, d }) end
					if hash(r * 7 + side * 13) > 0.94 then -- glowing speck in the mortar
						local gx = side == 1 and (W - wall * (0.3 + hash(r + 3) * 0.5)) or (wall * (0.3 + hash(r + 3) * 0.5))
						local col = d < Z_RAT and { 125, 255, 106 } or (d < Z_CORE and { 255, 213, 74 } or { 255, 143, 209 })
						glow(ctx, gx, yb + BH - 1, 4, col, 0.3 + 0.2 * sin(O.t * 2 + r)); fillRGB(ctx, col); ctx:fillRect(round(gx), yb + BH - 1, 1, 1)
					end
				end
			end
		end
	end
	for _, q in deco do q[1](ctx, q[2], q[3], q[4], q[5], q[6]) end
	-- brick archway where the sewer starts
	local ya = round((SEWER_TOP + OFF - O.topM) * ppm)
	if ya > -20 and ya < O.H + 20 then
		for side = 0, 1 do
			local w = wallAt(SEWER_TOP + 20, side) + 10
			local x0, zc = side == 1 and (W - w) or 0, wallColors(SEWER_TOP + 50)
			fillRGB(ctx, zc[4]); ctx:fillRect(x0, ya - 12, w, 14)
			local bx = 0
			while bx < w do
				fillRGB(ctx, zc[1])
				ctx:fillRect(side == 1 and (W - bx - 11) or bx, ya - 11, 11, 5)
				ctx:fillRect(side == 1 and (W - bx - 5 - 11) or (bx + 5), ya - 5, 11, 5)
				bx += 12
			end
			fillRGB(ctx, zc[2]); ctx:fillRect(x0, ya - 12, w, 1)
			fillRGB(ctx, zc[3]); ctx:fillRect(side == 1 and x0 or (w - 7), ya - 14, 7, 16)
		end
	end
	drawLedges(ctx)
end

---------------------------------------------------------------- far silhouettes, creatures, snow
local function drawFar(ctx)
	local ppm, top, CH = O.ppm * 0.55, O.topM * 0.55, 70
	local c0, c1 = floor(top / CH) - 1, floor((top + O.H / ppm) / CH) + 1
	for c = c0, c1 do
		if c >= 1 then
			local n = 1 + floor(hash(c * 5 + 1) * 2)
			for k = 0, n - 1 do
				local s = c * 13 + k * 101
				local m = c * CH + hash(s) * CH
				local y = (m - top) * ppm
				if not (y < -20 or y > O.H + 20) then
					local realM = O.topM + y / O.ppm
					if realM >= 25 then
						local wc = waterColor(lerp(dz(realM), max(0, realM) * 22, O.tmix))
						local tc = mix(wc, { 4, 10, 22 }, 0.35)
						local tint = string.format("rgb(%d,%d,%d)", trunc(tc[1]), trunc(tc[2]), trunc(tc[3]))
						local dir = hash(s + 3) > 0.5 and 1 or -1
						local sp = (2 + hash(s + 4) * 4) * dir
						local big = hash(s + 9) > 0.9 and dz(realM) > 600
						local dd = dz(realM)
						if dd >= SEWER_TOP + 100 then
							local name = big and "fatberg" or (dd < 1000 and "tpWad" or (hash(s + 7) > 0.5 and "mouse0" or "rat0"))
							local w = big and 24 or 32
							local span = O.W + w * 2
							local x = fmod(fmod(hash(s + 2) * span + O.t * sp, span) + span, span) - w
							ctx.globalAlpha = 0.35; drawSprite(ctx, name, x, y, dir < 0, tint); ctx.globalAlpha = 1
						end
					end
				end
			end
		end
	end
end

local GLOWS = { phone = { 80, 200, 255, 0.22 }, glowstick = { 125, 255, 106, 0.35 }, disco = { 255, 255, 255, 0.2 }, sludge = { 125, 255, 106, 0.2 },
	auraBlob = { 197, 139, 255, 0.2 }, ratking = { 255, 213, 74, 0.2 }, cheese = { 255, 213, 74, 0.12 }, gatorEyes = { 240, 255, 74, 0.18 } }
local function drawOne(ctx, kind, x, y, yy, dir, ph, s, z, swims)
	if kind == "goldfish" then drawSprite(ctx, "fish", x, yy, dir < 0, "~#ff8a3d"); return end
	if kind == "mouse" or kind == "rat" then drawSprite(ctx, kind .. tostring(floor(O.t * 6 + ph) % 2), x, yy, dir < 0); return end
	if kind == "partyMouse" then
		local v = ({ "partyMouse", "partyMouseB", "partyMouseC" })[floor(hash(s + 8) * 3) + 1]
		drawSprite(ctx, v, x, y - round(beatPulse() * 3), dir < 0); return
	end
	if kind == "tpWad" and z >= 2 then drawSprite(ctx, "tpWad", x, yy, false, "~#c8c09a"); return end
	local G = GLOWS[kind]
	if kind == "gatorEyes" and floor(O.t * 1.3 + ph) % 5 == 0 then return end
	if G then glow(ctx, x + 6, yy + 4, 9, G, G[4] + 0.06 * sin(O.t * 2 + ph)) end
	drawSprite(ctx, kind, x, yy, swims and dir < 0 or (not swims and hash(s + 6) > 0.5))
	if (kind == "ring" or kind == "coin" or kind == "disco") and sin(O.t * 4 + ph) > 0.85 then
		ctx:setFill("#ffffff")
		local sx, sy = round(x + 2 + hash(s + 9) * 5), round(yy + 1)
		ctx:fillRect(sx, sy - 1, 1, 3); ctx:fillRect(sx - 1, sy, 3, 1)
	end
end

local MAD_TYPES = { "partyMouse", "goldtoilet", "duckling", "disco", "partyMouseB", "ratking", "partyMouseC", "cheese" }
local SWIMMERS = { mouse = true, rat = true, goldfish = true, crownMouse = true, partyMouse = true }
local RB6 = { "#ff3f6a", "#ff9a2a", "#ffe14a", "#7dff6a", "#4ad0ff", "#c58bff" }
local function drawCreatures(ctx)
	local ppm, CH = O.ppm, 55
	local c0, c1 = floor(O.topM / CH) - 1, floor((O.topM + O.H / ppm) / CH) + 1
	for c = c0, c1 do
		if c >= 0 then
			local midM = c * CH + CH / 2
			local z = zoneIndex(dz(midM))
			local n
			-- Roblox version: the deep zones are calmer (a few crossers; the rest live on ledges and in burrows)
			if dz(c * CH) > Z_MAD then n = hash(c * 13) > 0.55 and 1 or 0
			elseif z >= 3 then n = hash(c * 7) > 0.62 and 1 or 0
			else n = hash(c * 7) > 0.45 and 1 or (hash(c * 11) > 0.75 and 2 or 0) end
			for k = 0, n - 1 do
				local s = c * 97 + k * 31 + 5
				local mad = dz(midM) > Z_MAD
				local kind = mad and MAD_TYPES[floor(hash(s) * 8) + 1] or zoneCreatures(z, hash(s))
				local m = c * CH + 6 + hash(s + 1) * (CH - 12)
				local y = (m - O.topM) * ppm
				if not (y < -30 or y > O.H + 30) then
					local dir = hash(s + 2) > 0.5 and 1 or -1
					local swims = mad or SWIMMERS[kind] == true
					local sp = mad and (7 + hash(s + 3) * 9) or (swims and (4 + hash(s + 3) * 7) or (1.2 + hash(s + 3) * 2.2))
					local span = O.W + 40
					local x = fmod(fmod(hash(s + 4) * span + O.t * sp * dir, span) + span, span) - 20
					local ph = hash(s + 5) * 6.28
					local bob = round(sin(O.t * (swims and 3 or 1.4) + ph) * (swims and 1 or 2))
					local yy = y + bob
					local dd = dz(m)
					local wl = dd < SEWER_TOP and pipeW(dd) or wallAt(dd, 0) + 2
					local wr = dd < SEWER_TOP and pipeW(dd) or wallAt(dd, 1) + 2
					ctx:save(); ctx:clipRect(round(wl), yy - 40, round(O.W - wl - wr), 80)
					if mad then -- rainbow trail streaming behind
						local len = 26
						local kk = 0
						while kk < len do
							for b = 0, 5 do
								ctx:setFill(RB6[b + 1]); ctx.globalAlpha = 0.75 * (1 - kk / len)
								ctx:fillRect(round(dir > 0 and (x - kk) or (x + 22 + kk)), round(yy + 3 + b + sin(O.t * 8 + kk * 0.4) * 1.5), 2, 1)
							end
							kk += 2
						end
						ctx.globalAlpha = 1
					end
					drawOne(ctx, kind, x, y, yy, dir, ph, s, z, swims)
					ctx:restore()
				end
			end
		end
	end
end

local SNOW_RB = { "#ff3f6a", "#ffe14a", "#7dff6a", "#4ad0ff", "#c58bff", "#ffffff" }
local SNOW_CF = { "#ff3fb4", "#7dff6a", "#4ad0ff", "#ffe14a", "#c58bff" }
local function drawSnow(ctx)
	local n = O.reduced and 25 or 70
	local camPx = O.topM * O.ppm * 1.15
	for i = 0, n - 1 do
		local x = fmod(hash(i * 3 + 1) * O.W + sin(O.t * 0.3 + i) * 3, O.W)
		local sp = 3 + hash(i * 5) * 5
		local y = fmod(fmod(hash(i * 7) * O.H - camPx + O.t * sp, O.H) + O.H, O.H)
		local m = O.topM + y / O.ppm
		if m >= 4 then
			local d = dz(m)
			local deep = d > 1000
			if d > Z_MAD and i % 3 == 0 then
				if sin(O.t * 6 + i * 1.7) > 0.2 then
					ctx:setFill(SNOW_RB[(i + floor(O.t * 4)) % 6 + 1])
					local sx, sy = round(x), round(y)
					ctx:fillRect(sx, sy - 1, 1, 3); ctx:fillRect(sx - 1, sy, 3, 1)
				end
			elseif d > Z_CORE and i % 2 == 0 then
				ctx:setFill(SNOW_CF[i % 5 + 1])
				local odd = (i + floor(O.t * 3)) % 2 ~= 0
				ctx:fillRect(round(x), round(y), odd and 2 or 1, odd and 1 or 2)
			else
				if deep then
					if i % 9 == 0 then
						if d > Z_RAT then ctx:setRGBA(255, 110, 200, 0.6) else ctx:setRGBA(125, 255, 106, 0.55) end
					else ctx:setRGBA(170, 210, 170, 0.28) end
				else ctx:setRGBA(230, 250, 255, 0.35) end
				ctx:fillRect(round(x), round(y), 1, 1)
			end
		end
	end
end

---------------------------------------------------------------- the duck, trails, bubbles, vignette
local function duckFx(ctx, cx, cy, s)
	local fx = O.skin.duckFx
	if not fx then return end
	if fx == "diamond" then glow(ctx, cx, cy, 14 * s, { 200, 240, 255 }, 0.2); sparkles(ctx, cx, cy, 14 * s, 6, { "#ffffff", "#bff0ff" }) end
	if fx == "rainbow" then glow(ctx, cx, cy, 16 * s, hex(RAINBOW[floor(O.t * 4) % #RAINBOW + 1]), 0.22) end
	if fx == "million" then
		glow(ctx, cx, cy, 20 * s, { 255, 210, 63 }, 0.3 + 0.1 * sin(O.t * 3)); sparkles(ctx, cx, cy, 18 * s, 8, { "#fff3b0", "#ffd23f", "#ffffff" })
		local kx, ky = round(cx - 3), round(cy - 12 * s)
		ctx:setFill("#ffd23f"); ctx:fillRect(kx, ky + 1, 7, 2); ctx:fillRect(kx, ky - 1, 1, 2); ctx:fillRect(kx + 3, ky - 1, 1, 2); ctx:fillRect(kx + 6, ky - 1, 1, 2)
		ctx:setFill("#ff3f6a"); ctx:fillRect(kx + 3, ky + 1, 1, 1)
	end
end
local TRAIL_RB = { "#ff3f6a", "#ff9a2a", "#ffe14a", "#7dff6a", "#4ad0ff", "#c58bff" }
local TRAIL_CF = { "#ff3fb4", "#7dff6a", "#4ad0ff", "#ffe14a" }
local function drawTrail(ctx, cx, top)
	local kind, len = O.skin.trail, 34
	local k = 0
	while k < len do
		local a = 0.8 * (1 - k / len)
		local y = round(top - 4 - k)
		local wob = round(sin(O.t * 9 + k * 0.35) * 1.5)
		ctx.globalAlpha = a
		if kind == "rainbow" then
			for b, col in TRAIL_RB do ctx:setFill(col); ctx:fillRect(round(cx - 6 + (b - 1) * 2 + wob), y, 2, 2) end
		elseif kind == "fire" then
			ctx:setFill(k < 10 and "#fff3b0" or (k < 20 and "#ffb020" or "#ff4d2a"))
			local w = max(1, 8 - floor(k / 5))
			ctx:fillRect(round(cx - w / 2 + wob), y, w, 2)
		elseif kind == "bubble" and (k + floor(O.t * 10)) % 5 == 0 then
			ctx:setRGBA(200, 240, 255, 0.9)
			ctx:fillRect(round(cx + sin(k + O.t * 4) * 4), y, 2, 2)
		elseif kind == "confetti" and (k + floor(O.t * 10)) % 3 == 0 then
			ctx:setFill(TRAIL_CF[fmod(k / 2, 4) + 1]); ctx:fillRect(round(cx + sin(k * 2.1 + O.t * 5) * 6), y, 2, 1)
		elseif kind == "money" and (k + floor(O.t * 8)) % 8 == 0 then
			local rx = round(cx - 6 + sin(k * 1.3 + O.t * 3) * 6)
			ctx.globalAlpha = a; ctx:drawImage(sprite("robux").c, rx, y - 6, 8, 8); glow(ctx, rx + 4, y - 2, 6, { 255, 255, 255 }, 0.15)
		elseif kind == "aura" then
			local w = max(2, 12 - floor(k / 3))
			ctx:setFill(k % 4 ~= 0 and "#8a5cff" or "#1a0b2e"); ctx:fillRect(round(cx - w / 2 + sin(O.t * 7 + k * 0.5) * 2), y, w, 2)
			if k % 6 == 0 then glow(ctx, cx, y, 8, { 160, 110, 255 }, 0.12) end
		elseif kind == "sparkle" and (k + floor(O.t * 12)) % 6 == 0 then
			ctx:setFill(k % 4 ~= 0 and "#ffffff" or "#ffe14a")
			local sx = round(cx + sin(k * 1.7 + O.t * 3) * 7)
			ctx:fillRect(sx, y - 1, 1, 3); ctx:fillRect(sx - 1, y, 3, 1)
		end
		k += 2
	end
	ctx.globalAlpha = 1
end

local function drawShrimp(ctx, now)
	if not O.showShrimp then return end
	if O.view == "intro" and O.flushT0 and flushP(now) < 1 and not O.reduced then return end
	local sx = shrimpX()
	local sy = (shrimpWorld() - O.topM) * O.ppm
	if sy < -20 or sy > O.H + 20 then return end
	local frame = floor(O.t * (O.sinking and 10 or 4)) % 2
	local bob = O.sinking and 0 or round(sin(O.t * 2.2) * 1.5)
	local m = O.shrimpM
	if m > 800 then glow(ctx, sx + 8, sy + 5, 18, { 140, 220, 255 }, clamp((m - 800) / 3000, 0, 1) * 0.08) end
	local cs = sprite("duck" .. frame, duckTint())
	duckFx(ctx, sx + cs.w / 2, round(sy) + bob + cs.h / 2, 1)
	if O.skin.trail and O.sinking then drawTrail(ctx, sx + cs.w / 2, round(sy) + bob + 2) end
	glow(ctx, sx + cs.w / 2, round(sy) + bob + cs.h / 2, 12, { 255, 214, 60 }, 0.18)
	ctx:drawImage(cs.c, sx, round(sy) + bob, cs.w, cs.h)
	if not O.reduced and Ocean.random() < (O.sinking and 0.5 or 0.04) then
		table.insert(O.bubbles, { x = sx + 12 + Ocean.random() * 4, y = sy, vy = -(8 + Ocean.random() * 10), life = 3 })
	end
end

local function drawBubbles(ctx, dt)
	local camV = O.camV or 0
	for i = #O.bubbles, 1, -1 do
		local b = O.bubbles[i]
		b.y += (b.vy - camV * O.ppm) * dt; b.x += sin(O.t * 4 + (i - 1)) * 0.15; b.life -= dt
		if b.life <= 0 or b.y < -5 then
			table.remove(O.bubbles, i)
		else
			ctx:setRGBA(200, 240, 255, 0.7)
			local big = b.big and 2 or 1
			ctx:fillRect(round(b.x), round(b.y), big, big)
			if b.big then ctx:setRGBA(255, 255, 255, 0.9); ctx:fillRect(round(b.x), round(b.y), 1, 1) end
		end
	end
end

local function vignette(ctx)
	local m = O.topM + O.H / O.ppm / 2
	local a = clamp((dz(m) - 1500) / 5000, 0, 0.55)
	if a <= 0 then return end
	local steps = 6
	for i = 0, steps - 1 do
		local pad = round((i + 1) * min(O.W, O.H) * 0.035)
		ctx:setRGBA(0, 0, 6, toFixed3(a / steps))
		ctx:fillRect(0, 0, O.W, pad); ctx:fillRect(0, O.H - pad, O.W, pad)
		ctx:fillRect(0, 0, pad, O.H); ctx:fillRect(O.W - pad, 0, pad, O.H)
	end
end

---------------------------------------------------------------- the frame
-- now = milliseconds (like performance.now())
function Ocean.frame(now)
	local dt = min(0.05, (now - (O.last or now)) / 1000)
	O.last = now
	O.t += dt
	if O.tweenDur > 0 then
		local p = clamp((now - O.tweenT0) / O.tweenDur, 0, 1)
		local e = p < 0.5 and 4 * p * p * p or 1 - ((-2 * p + 2) ^ 3) / 2
		O.shrimpM = lerp(O.shrimpFrom, O.shrimpTo, e)
		O.sinking = p < 1
		if O.onDepth then O.onDepth(O.shrimpM, p >= 1) end
		if p >= 1 then O.tweenDur = 0; O.sinking = false end
	end
	if O.flushT0 and not O.flushDropped and (O.reduced or flushP(now) >= 1) then
		O.flushDropped = true
		O.shrimpFrom = O.shrimpM; O.shrimpTo = -OFF + 150; O.tweenT0 = now; O.tweenDur = FLUSH_DROP
		for _ = 1, 18 do
			table.insert(O.bubbles, { x = shrimpX() + Ocean.random() * 16, y = (shrimpWorld() - O.topM) * O.ppm, vy = -(10 + Ocean.random() * 30), life = 1.6, big = Ocean.random() < 0.5 })
		end
	end
	local sxTarget = O.sxTarget ~= nil and O.sxTarget or midX()
	if O.sxf == nil then O.sxf = sxTarget
	else O.sxf = O.sxf + (sxTarget - O.sxf) * (O.reduced and 1 or 1 - math.exp(-dt * 3)) end
	local target = viewTop()
	local prev = O.topM
	if O.topM < -5000 or O.reduced then O.topM = target
	else O.topM += (target - O.topM) * (1 - math.exp(-dt * (O.sinking and 9 or 2.6))) end
	O.camV = dt > 0 and (O.topM - prev) / dt or 0
	local tm = (O.view == "game" or O.view == "intro") and 0 or 1
	O.tmix = O.reduced and tm or O.tmix + (tm - O.tmix) * (1 - math.exp(-dt * 2.2))
	local ctx = O.ctx
	local ySurf = (0 - O.topM) * O.ppm
	ctx:setTransform(1, 0, 0, 1, 0, 0)
	ctx:clear()
	drawSky(ctx, 0, ySurf)
	O.dusk = O.dusk + ((O.view == "results" and 1 or 0) - O.dusk) * (O.reduced and 1 or 1 - math.exp(-dt * 2))
	if O.dusk > 0.01 and ySurf > 0 then ctx:setRGBA(22, 30, 46, toFixed3(0.78 * O.dusk)); ctx:fillRect(0, 0, O.W, math.ceil(ySurf) + 3) end
	drawWater(ctx, ySurf)
	drawRays(ctx, ySurf)
	drawFar(ctx)
	drawTrench(ctx)
	if O.tmix < 0.98 then ctx.globalAlpha = 1 - O.tmix; drawCreatures(ctx); ctx.globalAlpha = 1 end
	drawSnow(ctx)
	drawSurface(ctx, ySurf, now)
	drawShrimp(ctx, now)
	drawBubbles(ctx, dt)
	vignette(ctx)
	return ctx
end

---------------------------------------------------------------- public API (same as the website's Ocean)
function Ocean.init(cssW, cssH) resize(cssW, cssH) end
Ocean.resize = resize
function Ocean.setView(v, instant)
	O.view = v
	O.showShrimp = v == "game" or v == "intro"
	if instant then O.topM = viewTop() end
end
function Ocean.setReduced(r) O.reduced = r and true or false end
function Ocean.setSkin(s) O.skin = table.clone(s or {}) end
function Ocean.flush(now)
	O.flushT0 = now; O.flushDropped = false
	local f = ((O.toiletCX or O.W * 0.2) - 8) / O.W
	O.sxTarget = f; O.sxf = f
	O.shrimpM = -OFF + 6; O.tweenDur = 0; O.sinking = false
end
function Ocean.setDepth(m, now, opts)
	opts = opts or {}
	if opts.instant or O.reduced then
		O.shrimpM = m; O.tweenDur = 0; O.sinking = false
		if O.onDepth then O.onDepth(m, true) end
		return 0
	end
	O.shrimpFrom = O.shrimpM; O.shrimpTo = m; O.tweenT0 = now
	O.tweenDur = opts.duration or clamp(900 + abs(m - O.shrimpM) * 1.6, 900, 2800)
	for _ = 1, 14 do
		table.insert(O.bubbles, { x = shrimpX() + 6 + Ocean.random() * 10, y = (shrimpWorld() - O.topM) * O.ppm, vy = -(10 + Ocean.random() * 25), life = 2.5, big = Ocean.random() < 0.4 })
	end
	return O.tweenDur
end
function Ocean.depth() return O.shrimpM end
function Ocean.burst(n)
	for _ = 1, n or 10 do
		table.insert(O.bubbles, { x = shrimpX() + Ocean.random() * 16, y = (shrimpWorld() - O.topM) * O.ppm, vy = -(12 + Ocean.random() * 20), life = 2, big = Ocean.random() < 0.5 })
	end
end
function Ocean.onDepth(fn) O.onDepth = fn end
function Ocean.setShrimpX(f) O.sxTarget = (f == 0.5) and midX() or f end
-- CSS-pixel helpers for the UI overlays (depth labels, the sinking answer card)
function Ocean.depthToScreenY(d) return ((OFF + d) - O.topM) * O.ppm * O.scale end
function Ocean.screenYToDepth(y) return y / (O.ppm * O.scale) + O.topM - OFF end
function Ocean.shrimpScreen() return { x = (shrimpX() + 8) * O.scale, y = ((shrimpWorld() - O.topM) * O.ppm + 5) * O.scale } end

return Ocean
