--!native
-- UI kit for the Roblox port: rebuilds the website's CSS look out of Frames and pixel images.
--  * Css: clamp()/rem/vw/vh maths so sizes follow the same formulas as the stylesheet
--  * box(): background, inner border (CSS border-box), drop shadow ("0 3px 0"), glow ("0 0 22px")
--  * text(): website fonts drawn crisp (TextRaster) with letter-spacing, wrapping, -webkit-text-stroke and
--    text-shadow layers (offset + blur), shown through an EditableImage (Frames as a fallback)
--  * icon(): the website's 16x16 pixel SVG icons
--  * scanlines(): the CRT overlay
local TextRaster = require(script and script.Parent and script.Parent:FindFirstChild("TextRaster") or "./TextRaster")

local Kit = {}
-- Roblox datatypes (swappable for headless tests)
Kit.Color3 = Color3
Kit.UDim2 = UDim2

---------------------------------------------------------------- environment hooks (Roblox vs. tests)
-- Kit.newImage(w, h) -> object with :write(buffer) and an ImageLabel-compatible way to show it.
-- Set by the client (EditableImage) or by tests (mock). nil => Frames fallback.
Kit.makeImage = nil
Kit.new = function(class) return Instance.new(class) end

---------------------------------------------------------------- CSS maths
local Css = {}
Kit.Css = Css
Css.W, Css.H = 1280, 720
function Css.set(w, h) Css.W, Css.H = w, h end
function Css.rem(n) return 16 * n end
function Css.vw(n) return Css.W * n / 100 end
function Css.vh(n) return Css.H * n / 100 end
function Css.clamp(a, v, b) return math.max(a, math.min(v, b)) end
-- clamp(minRem, baseRem + vwN, maxRem) in px
function Css.cr(minRem, baseRem, vwN, maxRem) return Css.clamp(minRem * 16, baseRem * 16 + Css.vw(vwN), maxRem * 16) end
function Css.narrow() return Css.W <= 760 end

---------------------------------------------------------------- colours
local function rgb(r, g, b) return Kit.Color3.fromRGB(r, g, b) end
Kit.rgb = rgb
function Kit.hex(h) return Kit.Color3.fromHex(h) end

---------------------------------------------------------------- frames
local function frame(parent, x, y, w, h, color, alpha, z)
	local f = Kit.new("Frame")
	f.BorderSizePixel = 0
	f.Position = Kit.UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	f.Size = Kit.UDim2.fromOffset(math.max(0, math.floor(x + w + 0.5) - math.floor(x + 0.5)), math.max(0, math.floor(y + h + 0.5) - math.floor(y + 0.5)))
	f.BackgroundColor3 = color or rgb(0, 0, 0)
	f.BackgroundTransparency = 1 - (alpha == nil and 1 or alpha)
	if z then f.ZIndex = z end
	f.Parent = parent
	return f
end
Kit.frame = frame

-- A CSS box. style: bg, bgA, border (px), bc (border colour), bcA, shadow = {dx, dy, color, a},
-- glow = {radius, color, a}, inset = {px, color, a} (inner ring like "0 0 0 2px inset")
-- Returns the container Frame (children are positioned relative to its top-left).
function Kit.box(parent, x, y, w, h, style)
	style = style or {}
	local holder = Kit.new("Frame")
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = Kit.UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	holder.Size = Kit.UDim2.fromOffset(math.floor(w + 0.5), math.floor(h + 0.5))
	holder.Parent = parent
	if style.glow then
		local r, c, a = style.glow[1], style.glow[2], style.glow[3]
		local steps = 4
		for i = steps, 1, -1 do
			local grow = r * i / steps
			frame(holder, -grow, -grow, w + grow * 2, h + grow * 2, c, a * 0.35 * (1 - (i - 1) / steps))
		end
	end
	if style.shadow then
		local s = style.shadow
		frame(holder, s[1], s[2], w, h, s[3], s[4])
	end
	local body = frame(holder, 0, 0, w, h, style.bg or rgb(0, 0, 0), style.bg and (style.bgA or 1) or 0)
	body.Name = "Body"
	local b = style.border or 0
	if b > 0 then
		local c, a = style.bc or rgb(255, 255, 255), style.bcA or 1
		frame(holder, 0, 0, w, b, c, a)
		frame(holder, 0, h - b, w, b, c, a)
		frame(holder, 0, b, b, h - 2 * b, c, a)
		frame(holder, w - b, b, b, h - 2 * b, c, a)
	end
	if style.inset then
		local p, c, a = style.inset[1], style.inset[2], style.inset[3]
		frame(holder, b, b, w - 2 * b, p, c, a)
		frame(holder, b, h - b - p, w - 2 * b, p, c, a)
		frame(holder, b, b + p, p, h - 2 * b - 2 * p, c, a)
		frame(holder, w - b - p, b + p, p, h - 2 * b - 2 * p, c, a)
	end
	return holder
end

-- The HUD's chamfered box (clip-path with 8px x 4px notches at the corners)
function Kit.chamfer(parent, x, y, w, h, color, alpha)
	local holder = Kit.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = Kit.UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	holder.Size = Kit.UDim2.fromOffset(math.floor(w + 0.5), math.floor(h + 0.5))
	holder.Parent = parent
	frame(holder, 8, 0, w - 16, h, color, alpha)
	frame(holder, 0, 4, 8, h - 8, color, alpha)
	frame(holder, w - 8, 4, 8, h - 8, color, alpha)
	return holder
end

---------------------------------------------------------------- text
-- style: family ("plex" | "vt323"), weight, size, spacing (px), color (Color3), alpha, align, width (wrap),
--        lineHeight (px), padLeft (CSS padding-left before the text), upper (uppercase),
--        stroke = {width, Color3}, shadows = { {dx, dy, blur, Color3, alpha}, ... } (CSS order: first on top)
-- Returns a Frame sized to the text box (w x h) with the text image inside; .W/.H fields on the result table.
local function blurAlpha(a, w, h, r)
	if r <= 0 then return a end
	-- two box-blur passes approximate a Gaussian of sigma ~ r/2
	local rad = math.max(1, math.floor(r / 2 + 0.5))
	local tmp = table.create(w * h, 0)
	local out = table.create(w * h, 0)
	for pass = 1, 2 do
		local src = pass == 1 and a or out
		for y = 0, h - 1 do
			local acc = 0
			for x = -rad, rad do if x >= 0 and x < w then acc += src[y * w + x + 1] end end
			for x = 0, w - 1 do
				tmp[y * w + x + 1] = acc / (rad * 2 + 1)
				local xo, xi = x - rad, x + rad + 1
				if xo >= 0 then acc -= src[y * w + xo + 1] end
				if xi < w then acc += src[y * w + xi + 1] end
			end
		end
		for x = 0, w - 1 do
			local acc = 0
			for y = -rad, rad do if y >= 0 and y < h then acc += tmp[y * w + x + 1] end end
			for y = 0, h - 1 do
				out[y * w + x + 1] = acc / (rad * 2 + 1)
				local yo, yi = y - rad, y + rad + 1
				if yo >= 0 then acc -= tmp[yo * w + x + 1] end
				if yi < h then acc += tmp[yi * w + x + 1] end
			end
		end
	end
	return out
end

local function dilate(mask, w, h, r)
	if r <= 0 then return mask end
	local out = table.create(w * h, 0)
	local ri = math.ceil(r)
	local offs = {}
	for dy = -ri, ri do
		for dx = -ri, ri do
			if dx * dx + dy * dy <= r * r + 0.25 then table.insert(offs, { dx, dy }) end
		end
	end
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			if mask[y * w + x + 1] > 0 then
				for _, o in offs do
					local xx, yy = x + o[1], y + o[2]
					if xx >= 0 and yy >= 0 and xx < w and yy < h then out[yy * w + xx + 1] = 1 end
				end
			end
		end
	end
	return out
end

-- CSS line-height: normal for a font size (Chrome: rounded ascent + rounded descent)
function Kit.lh(size, family)
	if family == "vt323" then return math.floor(0.8 * size + 0.5) + math.floor(0.2 * size + 0.5) end
	return math.floor(1.025 * size + 0.5) + math.floor(0.275 * size + 0.5)
end

-- smallest text size drawn (the app sets 10 so fine print stays readable on phones; 0 = exact website sizes)
Kit.minTextSize = 0
local function floorSize(style)
	if style.size and style.size < Kit.minTextSize then
		style = table.clone(style)
		local k = Kit.minTextSize / style.size
		style.size = Kit.minTextSize
		if style.spacing then style.spacing *= k end
		if style.lineHeight then style.lineHeight *= k end
	end
	return style
end
Kit.floorSize = floorSize
function Kit.measure(text, style)
	style = floorSize(style)
	if style.upper then text = text:upper() end
	local L = TextRaster.layout(text, { family = style.family, weight = style.weight, size = style.size, spacing = style.spacing, width = style.width and (style.width - (style.padLeft or 0)), lineHeight = style.lineHeight })
	return L.w + (style.padLeft or 0), L.h, L
end

function Kit.text(parent, x, y, text, style, boxW)
	style = floorSize(style)
	if style.upper then text = text:upper() end
	local opts = { family = style.family or "plex", weight = style.weight or 400, size = style.size, spacing = style.spacing or 0,
		width = style.width and (style.width - (style.padLeft or 0)) or nil, lineHeight = style.lineHeight, align = style.align }
	local L = TextRaster.layout(text, opts)
	local tw = math.ceil(boxW or (L.w + (style.padLeft or 0)))
	local th = math.ceil(L.h)
	-- margin for stroke/shadows/blur
	local m = 0
	if style.stroke then m = math.max(m, math.ceil(style.stroke[1] / 2) + 1) end
	for _, s in style.shadows or {} do m = math.max(m, math.ceil(math.abs(s[1]) + (s[3] or 0)) + 2, math.ceil(math.abs(s[2]) + (s[3] or 0)) + 2) end
	local W, H = tw + 2 * m, th + 2 * m
	local holder = Kit.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = Kit.UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	holder.Size = Kit.UDim2.fromOffset(tw, th)
	holder.Parent = parent
	-- small text: rasterize at SS x and let the image be smoothed down to size (readable, nothing drops out)
	local SS = 1
	if Kit.makeImage and Kit.smallTextScale and style.size < 20 and W * Kit.smallTextScale <= 1024 and H * Kit.smallTextScale <= 1024 then SS = Kit.smallTextScale end
	local dW, dH = W, H -- display size
	local rOpts, rL = opts, L
	if SS > 1 then
		rOpts = table.clone(opts)
		rOpts.size *= SS; rOpts.spacing *= SS
		if rOpts.width then rOpts.width *= SS end
		if rOpts.lineHeight then rOpts.lineHeight *= SS end
		rL = TextRaster.layout(text, rOpts)
		W, H = W * SS, H * SS
	end
	-- glyph mask
	local mask = table.create(W * H, 0)
	TextRaster.draw(text, rOpts, rL, (m + (style.padLeft or 0)) * SS, m * SS, (tw - (style.padLeft or 0)) * SS, function(x0, x1, yy)
		if yy >= 0 and yy < H then
			for xx = math.max(0, x0), math.min(W - 1, x1) do mask[yy * W + xx + 1] = 1 end
		end
	end)
	local shape = mask
	local strokeMask = nil
	if style.stroke then
		-- paint-order: stroke fill -> the outer half of the stroke shows around the glyphs
		strokeMask = dilate(mask, W, H, style.stroke[1] * SS / 2)
		shape = strokeMask
	end
	local color = style.color or rgb(255, 255, 255)
	local alpha = style.alpha or 1
	if Kit.makeImage and W * H <= 1024 * 1024 and W <= 1024 and H <= 1024 then
		local buf = buffer.create(W * H * 4)
		local function paint(a, c, ca, dx, dy)
			local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
			for yy = 0, H - 1 do
				local sy = yy - dy
				if sy >= 0 and sy < H then
					for xx = 0, W - 1 do
						local sx = xx - dx
						if sx >= 0 and sx < W then
							local v = a[sy * W + sx + 1] * ca
							if v > 0.002 then
								local o = (yy * W + xx) * 4
								local da = buffer.readu8(buf, o + 3) / 255
								local oa = v + da * (1 - v)
								local k = da * (1 - v)
								buffer.writeu8(buf, o, math.floor((r * v + buffer.readu8(buf, o) * k) / oa + 0.5))
								buffer.writeu8(buf, o + 1, math.floor((g * v + buffer.readu8(buf, o + 1) * k) / oa + 0.5))
								buffer.writeu8(buf, o + 2, math.floor((b * v + buffer.readu8(buf, o + 2) * k) / oa + 0.5))
								buffer.writeu8(buf, o + 3, math.floor(oa * 255 + 0.5))
							end
						end
					end
				end
			end
		end
		local sh = style.shadows or {}
		for i = #sh, 1, -1 do -- CSS draws the first shadow on top
			local s = sh[i]
			paint(blurAlpha(shape, W, H, (s[3] or 0) * SS), s[4], s[5] or 1, math.floor(s[1] * SS + 0.5), math.floor(s[2] * SS + 0.5))
		end
		if strokeMask then paint(strokeMask, style.stroke[2], 1, 0, 0) end
		paint(mask, color, alpha, 0, 0)
		local img = Kit.makeImage(W, H)
		img:write(buf)
		local lbl = img:label(SS > 1)
		lbl.Position = Kit.UDim2.fromOffset(-m, -m)
		lbl.Size = Kit.UDim2.fromOffset(dW, dH)
		lbl.Parent = holder
	else
		-- Frames fallback: runs of the glyph mask (no blur), shadows as offset copies, stroke via dilated mask
		local function runs(a, c, ca, dx, dy)
			for yy = 0, H - 1 do
				local x0 = nil
				for xx = 0, W do
					local on = xx < W and a[yy * W + xx + 1] > 0.5
					if on and not x0 then x0 = xx end
					if not on and x0 then
						frame(holder, x0 - m + dx, yy - m + dy, xx - x0, 1, c, ca)
						x0 = nil
					end
				end
			end
		end
		for i = #(style.shadows or {}), 1, -1 do
			local s = style.shadows[i]
			if (s[3] or 0) <= 2 then runs(shape, s[4], s[5] or 1, math.floor(s[1] + 0.5), math.floor(s[2] + 0.5)) end
		end
		if strokeMask then runs(strokeMask, style.stroke[2], 1, 0, 0) end
		runs(mask, color, alpha, 0, 0)
	end
	return holder, tw, th, L
end

---------------------------------------------------------------- icons (the website's SVG symbols, 16x16 pixel paths)
local ICONS = {
	menu = { 16, "M1 3h14v2H1zM1 7h14v2H1zM1 11h14v2H1z" },
	sound = { 16, "M1 6h3v4H1zM4 5h1v6H4zM5 4h1v8H5zM6 3h2v10H6zM10 6h1v4h-1zM12 4h1v8h-1zM14 2h1v12h-1z" },
	mute = { 16, "M1 6h3v4H1zM4 5h1v6H4zM5 4h1v8H5zM6 3h2v10H6zM10 5h1v1h-1zM11 6h1v1h-1zM12 7h1v2h-1zM13 6h1v1h-1zM14 5h1v1h-1zM11 9h1v1h-1zM10 10h1v1h-1zM13 9h1v1h-1zM14 10h1v1h-1z" },
	cube = { 16, "M7 1h2v1h2v1h2v1h1v8h-1v1h-2v1H9v1H7v-1H5v-1H3v-1H2V4h1V3h2V2h2zm0 2v1H5v1H4v1h1v1h2v1h2V7h2V6h1V5h-1V4H9V3zM4 8v4h1v1h2V10H6V9H4zm5 2v3h2v-1h1V8h-2v1H9z" },
	chart = { 16, "M2 9h3v5H2zM7 4h3v10H7zM12 7h3v7h-3z" },
	play = { 16, "M4 2h2v1h2v1h2v1h2v1h2v4h-2v1h-2v1H8v1H6v1H4z" },
	close = { 16, "M2 2h2v2H2zM4 4h2v2H4zM6 6h4v4H6zM10 4h2v2h-2zM12 2h2v2h-2zM4 10h2v2H4zM2 12h2v2H2zM10 10h2v2h-2zM12 12h2v2h-2z" },
	gear = { 16, "M7 1h2v2h2V2h1v1h1v1h-1v2h2v2h-2v2h1v1h-1v1h-1v-1H9v2H7v-2H5v1H4v-1H3v-1h1V8H2V6h2V4H3V3h1V2h1v1h2zm0 4v1H6v3h1v1h2V9h1V6H9V5z" },
	help = { 16, "M5 2h6v1h1v4h-1v1H9v2H7V7h1V6h2V4H6v2H4V3h1zM7 12h2v2H7z" },
	restart = { 16, "M6 1h5v1h2v1h1v2h1v6h-1v2h-1v1h-2v1H6v-1H4v-1H3v-2H2V9h2v2h1v1h1v1h5v-1h1v-1h1V5h-1V4h-1V3H6v1H5v1h2v2H1V1h2v2h1V2h2z" },
	home = { 16, "M7 1h2v1h1v1h1v1h1v1h1v1h1v2h-1v7H9v-4H7v4H3V8H2V6h1V5h1V4h1V3h1V2h1z" },
}
local iconCache = {}
-- rasterize an SVG path made of straight segments into a 16x16 boolean grid (even-odd fill)
local function iconGrid(name)
	if iconCache[name] then return iconCache[name] end
	local spec = ICONS[name]
	local d = spec[2]
	local polys, cur, x, y, sx, sy = {}, nil, 0, 0, 0, 0
	for cmd, args in d:gmatch("([MmHhVvLlZz])([^MmHhVvLlZz]*)") do
		local nums = {}
		for n in args:gmatch("-?[%d%.]+") do table.insert(nums, tonumber(n)) end
		if cmd == "M" or cmd == "m" then
			if cmd == "m" then x, y = x + nums[1], y + nums[2] else x, y = nums[1], nums[2] end
			cur = { { x, y } }; table.insert(polys, cur); sx, sy = x, y
			for i = 3, #nums, 2 do
				if cmd == "m" then x, y = x + nums[i], y + nums[i + 1] else x, y = nums[i], nums[i + 1] end
				table.insert(cur, { x, y })
			end
		elseif cmd == "h" then for _, n in nums do x += n; table.insert(cur, { x, y }) end
		elseif cmd == "H" then for _, n in nums do x = n; table.insert(cur, { x, y }) end
		elseif cmd == "v" then for _, n in nums do y += n; table.insert(cur, { x, y }) end
		elseif cmd == "V" then for _, n in nums do y = n; table.insert(cur, { x, y }) end
		elseif cmd == "z" or cmd == "Z" then x, y = sx, sy end
	end
	local g = {}
	for py = 0, spec[1] - 1 do
		for px = 0, spec[1] - 1 do
			local cx, cy = px + 0.5, py + 0.5
			local inside = false
			for _, P in polys do
				local n = #P
				local j = n
				for i = 1, n do
					local xi, yi, xj, yj = P[i][1], P[i][2], P[j][1], P[j][2]
					if (yi > cy) ~= (yj > cy) and cx < (xj - xi) * (cy - yi) / (yj - yi) + xi then inside = not inside end
					j = i
				end
			end
			if inside then g[py * spec[1] + px + 1] = true end
		end
	end
	iconCache[name] = { n = spec[1], g = g }
	return iconCache[name]
end
function Kit.icon(parent, name, x, y, size, color, alpha)
	local ic = iconGrid(name)
	local holder = Kit.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = Kit.UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	holder.Size = Kit.UDim2.fromOffset(size, size)
	holder.Parent = parent
	local u = size / ic.n
	for py = 0, ic.n - 1 do
		local x0 = nil
		for px = 0, ic.n do
			local on = px < ic.n and ic.g[py * ic.n + px + 1]
			if on and not x0 then x0 = px end
			if not on and x0 then frame(holder, x0 * u, py * u, (px - x0) * u, u, color, alpha); x0 = nil end
		end
	end
	return holder
end

---------------------------------------------------------------- CRT scanlines (repeating 2px clear / 1px 7% black)
function Kit.scanlines(parent, W, H, z)
	local holder = Kit.new("Frame")
	holder.Name = "Scanlines"
	holder.BackgroundTransparency = 1
	holder.Size = Kit.UDim2.fromScale(1, 1)
	holder.ZIndex = z or 50
	holder.Parent = parent
	for y = 2, H, 3 do frame(holder, 0, y, W, 1, rgb(0, 0, 0), 0.07, z or 50) end
	return holder
end

---------------------------------------------------------------- pixel sprites at any size (image-rendering: pixelated)
-- Nearest-neighbour like Chrome: target pixel i samples source pixel floor((i + 0.5) * srcW / w).
local spriteCache = {}
-- tint: nil, "#rrggbb" (flat colour) or "~#rrggbb" (shade-preserving, same rule as ocean.js sprite())
local function spriteGrid(name, tint)
	local key = name .. (tint or "")
	local c = spriteCache[key]
	if c then return c end
	local Sprites = require(script and script.Parent and script.Parent:FindFirstChild("Sprites") or "./Sprites")
	local s = Sprites[name]
	local pal = {}
	for i, ph in s.pal do
		local o = Kit.hex(ph)
		if tint and tint:sub(1, 1) == "~" then
			local t = Kit.hex(tint:sub(2))
			local lum = 0.3 * o.R + 0.59 * o.G + 0.11 * o.B
			if lum < 0.16 then pal[i] = Kit.hex("#0a1222")
			else
				local k = 0.5 + 0.7 * lum
				pal[i] = rgb(math.min(255, math.floor(t.R * 255 * k)), math.min(255, math.floor(t.G * 255 * k)), math.min(255, math.floor(t.B * 255 * k)))
			end
		elseif tint then pal[i] = Kit.hex(tint)
		else pal[i] = o end
	end
	local px = {}
	local r = s.runs
	for i = 1, #r, 4 do
		local col = pal[r[i + 3]]
		for k = 0, r[i + 2] - 1 do px[r[i + 1] * s.w + r[i] + k + 1] = col end
	end
	c = { w = s.w, h = s.h, px = px }
	spriteCache[key] = c
	return c
end
Kit.spriteGrid = spriteGrid
-- returns the holder frame; w/h in px (may be fractional: the box is snapped like the browser's)
function Kit.sprite(parent, name, x, y, w, h, alpha, solid)
	local g = spriteGrid(name, type(solid) == "string" and solid or nil)
	if type(solid) == "string" then solid = nil end
	alpha = alpha or 1
	local X0, Y0 = math.floor(x + 0.5), math.floor(y + 0.5)
	local PW, PH = math.floor(x + w + 0.5) - X0, math.floor(y + h + 0.5) - Y0
	local holder = Kit.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = Kit.UDim2.fromOffset(X0, Y0)
	holder.Size = Kit.UDim2.fromOffset(PW, PH)
	holder.Parent = parent
	if PW <= 0 or PH <= 0 then return holder end
	if Kit.makeImage then
		local buf = buffer.create(PW * PH * 4)
		for py = 0, PH - 1 do
			local sy = math.min(g.h - 1, math.floor((py + 0.5) * g.h / PH))
			for pxx = 0, PW - 1 do
				local sx = math.min(g.w - 1, math.floor((pxx + 0.5) * g.w / PW))
				local c = g.px[sy * g.w + sx + 1]
				if c and solid then c = solid end
				if c then
					buffer.writeu32(buf, (py * PW + pxx) * 4, math.floor(c.R * 255 + 0.5) + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5) * 65536 + math.floor(alpha * 255 + 0.5) * 16777216)
				end
			end
		end
		local img = Kit.makeImage(PW, PH)
		img:write(buf)
		local lbl = img:label()
		lbl.Size = Kit.UDim2.fromOffset(PW, PH)
		lbl.Parent = holder
	else
		for py = 0, PH - 1 do
			local sy = math.min(g.h - 1, math.floor((py + 0.5) * g.h / PH))
			local x0, cur = nil, nil
			for pxx = 0, PW do
				local c = pxx < PW and g.px[sy * g.w + math.min(g.w - 1, math.floor((pxx + 0.5) * g.w / PW)) + 1] or nil
				if c and solid then c = solid end
				if c ~= cur then
					if cur then frame(holder, x0, py, pxx - x0, 1, cur, alpha) end
					x0, cur = pxx, c
				end
			end
		end
	end
	return holder
end

---------------------------------------------------------------- dashed 1px rule (CSS border-top: 1px dashed)
-- Chrome draws 3px dashes with ~2px gaps, stretched so the rule starts and ends on a dash.
function Kit.dashH(parent, x, y, w, color, alpha)
	local x0, x1 = math.ceil(x - 0.01), math.floor(x + w + 0.01)
	local len = x1 - x0
	if len < 3 then return end
	local n = math.max(1, math.floor((len + 2) / 5))
	local gap = n > 1 and (len - 3 * n) / (n - 1) or 0
	for i = 0, n - 1 do frame(parent, x0 + i * (3 + gap), math.floor(y), 3, 1, color, alpha) end
end

---------------------------------------------------------------- inline rich text (spans of different colour/size)
-- segs = { {text, style, ml = margin-left px}, ... }; strut = the block's own style (its font sets the minimum line box).
-- Wraps like CSS (greedy at spaces), lines sized by the tallest inline box (line-height: normal).
-- Returns total height and the list of lines ({y, h, w}).
function Kit.richLayout(segs, width, strut)
	local toks = {}
	for si, sg in segs do
		local st = sg.style
		local first = true
		local text = st.upper and sg[1]:upper() or sg[1]
		for word, sp in text:gmatch("(%S*)(%s*)") do
			if word == "" and sp == "" then continue end
			local ww = word ~= "" and Kit.measure(word, { family = st.family, weight = st.weight, size = st.size, spacing = st.spacing }) or 0
			local spw = sp ~= "" and Kit.measure(" ", { family = st.family, weight = st.weight, size = st.size, spacing = st.spacing }) or 0
			table.insert(toks, { seg = si, word = word, sp = sp ~= "", ww = ww, spw = spw, ml = first and (sg.ml or 0) or 0 })
			first = false
		end
	end
	local lines, cur, x = {}, {}, 0
	for _, t in toks do
		local start = x + t.ml
		if width and #cur > 0 and t.word ~= "" and start + t.ww > width + 0.01 then
			table.insert(lines, cur); cur = {}; x = 0; start = 0
		end
		t.x = start
		table.insert(cur, t)
		x = start + t.ww + (t.sp and t.spw or 0)
	end
	table.insert(lines, cur)
	local out, y = {}, 0
	for _, ln in lines do
		local sa = strut and math.floor(1.025 * strut.size + 0.5) or 0
		local sd = strut and math.floor(0.275 * strut.size + 0.5) or 0
		local w = 0
		for _, t in ln do
			local st = segs[t.seg].style
			sa = math.max(sa, math.floor(1.025 * st.size + 0.5)); sd = math.max(sd, math.floor(0.275 * st.size + 0.5))
			w = math.max(w, t.x + t.ww)
		end
		table.insert(out, { y = y, h = sa + sd, asc = sa, w = w, toks = ln })
		y += sa + sd
	end
	return out, y
end
function Kit.rich(parent, x, y, width, segs, strut, align)
	local lines, h = Kit.richLayout(segs, width, strut)
	for _, ln in lines do
		local off = 0
		if align == "center" and width then off = (width - ln.w) / 2 elseif align == "right" and width then off = width - ln.w end
		-- draw runs of tokens from the same segment as one text
		local i = 1
		while i <= #ln.toks do
			local t = ln.toks[i]
			local j, s = i, t.word
			while j + 1 <= #ln.toks and ln.toks[j + 1].seg == t.seg do
				s ..= (ln.toks[j].sp and " " or "") .. ln.toks[j + 1].word
				j += 1
			end
			if s ~= "" then
				local st = table.clone(segs[t.seg].style)
				st.width, st.align, st.lineHeight, st.upper = nil, nil, nil, nil
				Kit.text(parent, x + off + t.x, y + ln.y + ln.asc - math.floor(1.025 * st.size + 0.5), s, st)
			end
			i = j + 1
		end
	end
	return h, lines
end

return Kit
