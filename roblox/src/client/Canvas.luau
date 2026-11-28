--!native
-- A tiny 2D canvas in pure Luau: an RGBA pixel buffer with the subset of the HTML canvas API that the website's
-- renderer (js/ocean.js) uses. Same rules as the browser: fillRect covers partial pixels at fractional edges,
-- globalAlpha, rectangular clip with save/restore, nearest-neighbour drawImage (with translate/rotate),
-- and filled paths (triangles). The buffer is shown on screen through an EditableImage (see Ocean.luau).
local Canvas = {}
Canvas.__index = Canvas

---------------------------------------------------------------- colours
local colorCache = {}
-- parse a CSS colour string -> r, g, b (0-255), a (0-1)
local function parseColor(s)
	local c = colorCache[s]
	if c then return c[1], c[2], c[3], c[4] end
	local r, g, b, a = 0, 0, 0, 1
	if s:sub(1, 1) == "#" then
		local h = s:sub(2)
		if #h == 3 then h = h:sub(1, 1):rep(2) .. h:sub(2, 2):rep(2) .. h:sub(3, 3):rep(2) end
		r, g, b = tonumber(h:sub(1, 2), 16) or 0, tonumber(h:sub(3, 4), 16) or 0, tonumber(h:sub(5, 6), 16) or 0
	else
		local inner = s:match("%((.-)%)")
		if inner then
			local parts = {}
			for p in inner:gmatch("[^,%s]+") do table.insert(parts, tonumber(p) or 0) end
			r, g, b = parts[1] or 0, parts[2] or 0, parts[3] or 0
			a = parts[4] or 1
		end
	end
	r, g, b = math.clamp(math.floor(r + 0.5), 0, 255), math.clamp(math.floor(g + 0.5), 0, 255), math.clamp(math.floor(b + 0.5), 0, 255)
	colorCache[s] = { r, g, b, a }
	return r, g, b, a
end
Canvas.parseColor = parseColor

---------------------------------------------------------------- construction
function Canvas.new(w, h)
	local self = setmetatable({}, Canvas)
	self.W, self.H = w, h
	self.buf = buffer.create(w * h * 4)
	self.globalAlpha = 1
	self.fr, self.fg, self.fb, self.fa = 0, 0, 0, 1
	self.fillStyle = "#000"
	-- clip rect (float, device space) and transform (a, b, c, d, e, f) like the canvas matrix
	self.cx0, self.cy0, self.cx1, self.cy1 = 0, 0, w, h
	self.m = { 1, 0, 0, 1, 0, 0 }
	self.stack = {}
	self.path = {}
	return self
end

-- numeric fill (no string parsing): r, g, b 0-255, a 0-1
function Canvas:setRGBA(r, g, b, a)
	self.fillStyle = false
	self.fr, self.fg, self.fb, self.fa = r, g, b, a or 1
end

function Canvas:setFill(s)
	if s ~= self.fillStyle then
		self.fillStyle = s
		self.fr, self.fg, self.fb, self.fa = parseColor(s)
	end
end

function Canvas:clear()
	buffer.fill(self.buf, 0, 0)
end

function Canvas:save()
	table.insert(self.stack, { self.cx0, self.cy0, self.cx1, self.cy1, table.clone(self.m), self.globalAlpha, self.fillStyle, self.fr, self.fg, self.fb, self.fa })
end
function Canvas:restore()
	local s = table.remove(self.stack)
	if not s then return end
	self.cx0, self.cy0, self.cx1, self.cy1, self.m, self.globalAlpha = s[1], s[2], s[3], s[4], s[5], s[6]
	self.fillStyle, self.fr, self.fg, self.fb, self.fa = s[7], s[8], s[9], s[10], s[11]
end
function Canvas:setTransform(a, b, c, d, e, f)
	self.m = { a, b, c, d, e, f }
end
function Canvas:translate(x, y)
	local m = self.m
	m[5] += m[1] * x + m[3] * y
	m[6] += m[2] * x + m[4] * y
end
function Canvas:rotate(t)
	local m = self.m
	local cs, sn = math.cos(t), math.sin(t)
	local a, b, c, d = m[1], m[2], m[3], m[4]
	m[1], m[2] = a * cs + c * sn, b * cs + d * sn
	m[3], m[4] = -a * sn + c * cs, -b * sn + d * cs
end
-- ctx.beginPath(); ctx.rect(x, y, w, h); ctx.clip()  (axis-aligned, no rotation in use)
function Canvas:clipRect(x, y, w, h)
	local m = self.m
	x, y = x + m[5], y + m[6]
	self.cx0, self.cy0 = math.max(self.cx0, x), math.max(self.cy0, y)
	self.cx1, self.cy1 = math.min(self.cx1, x + w), math.min(self.cy1, y + h)
end

---------------------------------------------------------------- pixel blending
local readu8, writeu8, writeu32 = buffer.readu8, buffer.writeu8, buffer.writeu32
local function blend(buf, o, r, g, b, a)
	if a >= 0.999 then
		writeu32(buf, o, r + g * 256 + b * 65536 + 4278190080)
		return
	end
	if a <= 0.001 then return end
	local da8 = readu8(buf, o + 3)
	if da8 == 255 then -- opaque destination (almost everything): plain source-over
		local ia = 1 - a
		local ra, ga, ba = r * a + 0.5, g * a + 0.5, b * a + 0.5
		writeu8(buf, o, ra + readu8(buf, o) * ia)
		writeu8(buf, o + 1, ga + readu8(buf, o + 1) * ia)
		writeu8(buf, o + 2, ba + readu8(buf, o + 2) * ia)
		return
	end
	local da = da8 / 255
	local oa = a + da * (1 - a)
	if oa <= 0 then return end
	local k = da * (1 - a)
	writeu8(buf, o, math.floor((r * a + readu8(buf, o) * k) / oa + 0.5))
	writeu8(buf, o + 1, math.floor((g * a + readu8(buf, o + 1) * k) / oa + 0.5))
	writeu8(buf, o + 2, math.floor((b * a + readu8(buf, o + 2) * k) / oa + 0.5))
	writeu8(buf, o + 3, math.floor(oa * 255 + 0.5))
end
Canvas.blend = blend

-- coverage of pixel [p, p+1) by span [a, b)
local function cover(p, a, b)
	local lo, hi = math.max(p, a), math.min(p + 1, b)
	return hi > lo and hi - lo or 0
end

---------------------------------------------------------------- fills
function Canvas:fillRect(x, y, w, h)
	if w < 0 then x, w = x + w, -w end
	if h < 0 then y, h = y + h, -h end
	local m = self.m
	x, y = x + m[5], y + m[6] -- fills are only ever translated, never rotated, in the renderer
	local x0, y0 = math.max(x, self.cx0, 0), math.max(y, self.cy0, 0)
	local x1, y1 = math.min(x + w, self.cx1, self.W), math.min(y + h, self.cy1, self.H)
	if x1 <= x0 or y1 <= y0 then return end
	local r, g, b = self.fr, self.fg, self.fb
	local a = self.fa * self.globalAlpha
	if a <= 0.001 then return end
	local buf, W = self.buf, self.W
	local ix0, iy0, ix1, iy1 = math.floor(x0), math.floor(y0), math.ceil(x1) - 1, math.ceil(y1) - 1
	local exactX = x0 == ix0 and x1 == ix1 + 1
	local exactY = y0 == iy0 and y1 == iy1 + 1
	if exactX and exactY and a >= 0.999 then
		-- solid, pixel-aligned: write the first row, then copy it down
		local col = r + g * 256 + b * 65536 + 4278190080
		local rowStart = (iy0 * W + ix0) * 4
		local n = ix1 - ix0 + 1
		for i = 0, n - 1 do writeu32(buf, rowStart + i * 4, col) end
		for yy = iy0 + 1, iy1 do buffer.copy(buf, (yy * W + ix0) * 4, buf, rowStart, n * 4) end
		return
	end
	if exactX and exactY then -- translucent, pixel-aligned
		local ia = 1 - a
		local ra, ga, ba = r * a + 0.5, g * a + 0.5, b * a + 0.5
		for yy = iy0, iy1 do
			local o = (yy * W + ix0) * 4
			for _ = ix0, ix1 do
				if readu8(buf, o + 3) == 255 then
					writeu8(buf, o, ra + readu8(buf, o) * ia)
					writeu8(buf, o + 1, ga + readu8(buf, o + 1) * ia)
					writeu8(buf, o + 2, ba + readu8(buf, o + 2) * ia)
				else
					blend(buf, o, r, g, b, a)
				end
				o += 4
			end
		end
		return
	end
	for yy = iy0, iy1 do
		local cy = exactY and 1 or cover(yy, y0, y1)
		if cy > 0 then
			local base = yy * W * 4
			for xx = ix0, ix1 do
				local cx = exactX and 1 or cover(xx, x0, x1)
				if cx > 0 then blend(buf, base + xx * 4, r, g, b, a * cx * cy) end
			end
		end
	end
end

-- paths: only triangles/convex polygons filled once (disco beams)
function Canvas:beginPath() table.clear(self.path) end
function Canvas:moveTo(x, y) table.insert(self.path, { x + self.m[5], y + self.m[6] }) end
function Canvas:lineTo(x, y) table.insert(self.path, { x + self.m[5], y + self.m[6] }) end
function Canvas:fill()
	local P = self.path
	if #P < 3 then return end
	local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
	for _, p in P do
		minx, miny, maxx, maxy = math.min(minx, p[1]), math.min(miny, p[2]), math.max(maxx, p[1]), math.max(maxy, p[2])
	end
	local x0, y0 = math.max(math.floor(minx), math.floor(self.cx0), 0), math.max(math.floor(miny), math.floor(self.cy0), 0)
	local x1, y1 = math.min(math.ceil(maxx), math.ceil(self.cx1), self.W) - 1, math.min(math.ceil(maxy), math.ceil(self.cy1), self.H) - 1
	local n = #P
	local a = self.fa * self.globalAlpha
	local buf, W = self.buf, self.W
	local SUB = 4
	local cov = {}
	for yy = y0, y1 do
		table.clear(cov)
		for sy = 0, SUB - 1 do
			local py = yy + (sy + 0.5) / SUB
			-- x crossings of this sub-scanline (even-odd)
			local xs = {}
			local j = n
			for i = 1, n do
				local xi, yi, xj, yj = P[i][1], P[i][2], P[j][1], P[j][2]
				if (yi > py) ~= (yj > py) then table.insert(xs, (xj - xi) * (py - yi) / (yj - yi) + xi) end
				j = i
			end
			table.sort(xs)
			for k = 1, #xs - 1, 2 do
				local xa, xb = math.max(xs[k], x0), math.min(xs[k + 1], x1 + 1)
				if xb > xa then
					for xx = math.floor(xa), math.ceil(xb) - 1 do
						local c = cover(xx, xa, xb)
						if c > 0 then cov[xx] = (cov[xx] or 0) + c / SUB end
					end
				end
			end
		end
		for xx, c in cov do
			if xx >= x0 and xx <= x1 and c > 0 then blend(buf, (yy * W + xx) * 4, self.fr, self.fg, self.fb, a * math.min(1, c)) end
		end
	end
end

---------------------------------------------------------------- images
-- img = { w, h, px = buffer (RGBA) } ; draws src rect (sx, sy, sw, sh) into dest (dx, dy, dw, dh), nearest neighbour
function Canvas:drawImage(img, a1, a2, a3, a4, a5, a6, a7, a8)
	local sx, sy, sw, sh, dx, dy, dw, dh
	if a5 then
		sx, sy, sw, sh, dx, dy, dw, dh = a1, a2, a3, a4, a5, a6, a7, a8
	else
		sx, sy, sw, sh = 0, 0, img.w, img.h
		dx, dy, dw, dh = a1, a2, a3 or img.w, a4 or img.h
	end
	if dw <= 0 or dh <= 0 or sw <= 0 or sh <= 0 then return end
	local m = self.m
	local ga = self.globalAlpha
	local buf, W, H = self.buf, self.W, self.H
	local src, iw = img.px, img.w
	if m[2] == 0 and m[3] == 0 and m[1] == 1 and m[4] == 1 then
		-- axis aligned: dest pixels whose centres fall inside the destination rect
		dx, dy = dx + m[5], dy + m[6]
		local px0 = math.max(math.ceil(dx - 0.5), math.ceil(self.cx0 - 0.5), 0)
		local py0 = math.max(math.ceil(dy - 0.5), math.ceil(self.cy0 - 0.5), 0)
		local px1 = math.min(math.ceil(dx + dw - 0.5) - 1, math.ceil(self.cx1 - 0.5) - 1, W - 1)
		local py1 = math.min(math.ceil(dy + dh - 0.5) - 1, math.ceil(self.cy1 - 0.5) - 1, H - 1)
		local kx, ky = sw / dw, sh / dh
		for py = py0, py1 do
			local syy = sy + math.floor((py + 0.5 - dy) * ky)
			if syy >= sy and syy < sy + sh then
				local srow = syy * iw
				local drow = py * W
				for px = px0, px1 do
					local sxx = sx + math.floor((px + 0.5 - dx) * kx)
					if sxx >= sx and sxx < sx + sw then
						local so = (srow + sxx) * 4
						local sa = readu8(src, so + 3)
						if sa > 0 then
							blend(buf, (drow + px) * 4, readu8(src, so), readu8(src, so + 1), readu8(src, so + 2), sa / 255 * ga)
						end
					end
				end
			end
		end
		return
	end
	-- transformed (rotation): inverse-map each destination pixel in the bounding box
	local a, b, c, d, e, f = m[1], m[2], m[3], m[4], m[5], m[6]
	local det = a * d - b * c
	if math.abs(det) < 1e-9 then return end
	local ia, ib, ic, id = d / det, -b / det, -c / det, a / det
	local corners = { { dx, dy }, { dx + dw, dy }, { dx, dy + dh }, { dx + dw, dy + dh } }
	local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
	for _, p in corners do
		local X, Y = a * p[1] + c * p[2] + e, b * p[1] + d * p[2] + f
		minx, miny, maxx, maxy = math.min(minx, X), math.min(miny, Y), math.max(maxx, X), math.max(maxy, Y)
	end
	local px0, py0 = math.max(math.floor(minx), math.floor(self.cx0), 0), math.max(math.floor(miny), math.floor(self.cy0), 0)
	local px1, py1 = math.min(math.ceil(maxx), math.ceil(self.cx1), W) - 1, math.min(math.ceil(maxy), math.ceil(self.cy1), H) - 1
	local kx, ky = sw / dw, sh / dh
	for py = py0, py1 do
		for px = px0, px1 do
			local X, Y = px + 0.5 - e, py + 0.5 - f
			local ux, uy = ia * X + ic * Y, ib * X + id * Y -- user space
			local lx, ly = ux - dx, uy - dy
			if lx >= 0 and ly >= 0 and lx < dw and ly < dh then
				local sxx, syy = sx + math.floor(lx * kx), sy + math.floor(ly * ky)
				local so = (syy * iw + sxx) * 4
				local sa = readu8(src, so + 3)
				if sa > 0 then blend(buf, (py * W + px) * 4, readu8(src, so), readu8(src, so + 1), readu8(src, so + 2), sa / 255 * ga) end
			end
		end
	end
end

-- make an image from per-pixel callback data: returns { w, h, px }
function Canvas.image(w, h)
	return { w = w, h = h, px = buffer.create(math.max(1, w * h * 4)) }
end
function Canvas.setPixel(img, x, y, r, g, b, a)
	writeu32(img.px, (y * img.w + x) * 4, r + g * 256 + b * 65536 + (a or 255) * 16777216)
end

return Canvas
