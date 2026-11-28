--!native
-- Crisp text in the website's fonts (IBM Plex Mono, VT323) for Roblox, which can't load those fonts.
-- Glyph outlines (FontData.luau) are filled without anti-aliasing (pixel-centre sampling, non-zero winding),
-- the way the website's text renders on a Mac (-webkit-font-smoothing: none). Layout follows CSS: monospace
-- advance + letter-spacing after every character, word wrapping, line-height boxes with half-leading.
-- Pure Luau: rasterizes to horizontal spans, which TextView turns into pixels (EditableImage) or Frames.
local FontData = require(script and script.Parent and script.Parent:FindFirstChild("FontData") or "./FontData")

local TextRaster = {}
-- calibrated against Chrome (tools/roblox-text-diff.js): exact advances, glyph origins floored, baseline rounded
TextRaster.originMode, TextRaster.baselineMode, TextRaster.advMode = "floor", "round", "q64s"

-- weight -> font key ("800" etc. fall back like the browser does: Plex Mono tops out at 700)
function TextRaster.fontKey(family, weight)
	if family == "vt323" then return "vt323" end
	weight = tonumber(weight) or 400
	if weight >= 650 then return "plex700" elseif weight >= 550 then return "plex600" elseif weight >= 450 then return "plex500" end
	return "plex400"
end

-- characters the fonts don't have (the browser borrows them from a system font): simple shapes in em units
local SHAPES = {
	[0x25BC] = { 0.6, { { 0.0, 0.66, 0.6, 0.66, 0.3, 0.12 } } }, -- ▼
	[0x25B2] = { 0.6, { { 0.08, 0.2, 0.3, 0.62, 0.52, 0.2 } } }, -- ▲
	[0x25B8] = { 0.6, { { 0.14, 0.58, 0.46, 0.4, 0.14, 0.22 } } }, -- ▸
	[0x25C2] = { 0.6, { { 0.46, 0.58, 0.46, 0.22, 0.14, 0.4 } } }, -- ◂
}

local function glyphOf(font, cp)
	local g = font.glyphs[cp]
	if g then return g[1], g[2], 1 end
	local s = SHAPES[cp]
	if s then return s[1] * font.upm, s[2], font.upm end -- em-unit polygons, scaled by upm
	g = font.glyphs[63] -- "?"
	return g[1], g[2], 1
end

---------------------------------------------------------------- layout
-- opts: family, weight, size (px), spacing (letter-spacing px), lineHeight (px or nil = normal 1.3em),
--       width (wrap width px or nil), align ("left" | "center" | "right")
-- returns { lines = { {text, width} }, w, h, lineH, ascent }
function TextRaster.layout(text, opts)
	if not opts.pre then text = text:gsub("[ \t]+", " ") end
	local font = FontData[TextRaster.fontKey(opts.family, opts.weight)]
	local size, sp = opts.size, opts.spacing or 0
	local unit = size / font.upm
	local function adv(cp)
		local a = glyphOf(font, cp)
		return a * unit + sp
	end
	-- line-height: normal = rounded ascent + rounded descent (as Chrome does)
	local ascPx, descPx = math.floor(font.asc * unit + 0.5), math.floor(font.desc * unit + 0.5)
	local lineH = opts.lineHeight or (ascPx + descPx)
	local lines = {}
	local function measure(s)
		local w = 0
		for _, cp in utf8.codes(s) do w += adv(cp) end
		return w
	end
	for para in (text .. "\n"):gmatch("(.-)\n") do
		if not opts.width then
			table.insert(lines, { para, measure(para) })
		else
			-- greedy word wrap like CSS (break at spaces; very long words break anywhere)
			local cur, curW = "", 0
			for word, gap in para:gmatch("(%S+)(%s*)") do
				local ww = measure(word)
				local spaceW = (#gap > 0) and measure(" ") or 0
				if cur ~= "" and curW + ww > opts.width + 0.01 then
					table.insert(lines, { cur, curW })
					cur, curW = "", 0
				end
				if ww > opts.width and cur == "" then -- hard break a long word
					local piece, pw = "", 0
					for _, cp in utf8.codes(word) do
						local a = adv(cp)
						if pw + a > opts.width and piece ~= "" then table.insert(lines, { piece, pw }); piece, pw = "", 0 end
						piece ..= utf8.char(cp); pw += a
					end
					cur, curW = piece, pw
				else
					cur ..= word; curW += ww
				end
				if #gap > 0 then cur ..= " "; curW += spaceW end
			end
			-- trailing spaces don't take width on a wrapped line
			local trimmed = cur:gsub("%s+$", "")
			table.insert(lines, { trimmed, measure(trimmed) })
		end
	end
	local w = 0
	for _, l in lines do w = math.max(w, l[2]) end
	local contentH = ascPx + descPx
	return { lines = lines, w = w, h = lineH * #lines, lineH = lineH, ascent = ascPx, halfLeading = (lineH - contentH) / 2, font = font, unit = unit, spacing = sp }
end

---------------------------------------------------------------- rasterizing
local spanCache = {}
local cacheCount = 0
-- spans of one glyph drawn with its origin at (0, baseline 0) after snapping: { y, x0, x1, y, x0, x1, ... }
-- fx = sub-pixel x offset of the glyph origin (0, 0.25, 0.5, 0.75): Chrome places glyphs at fractional x
local function glyphSpans(fontKey, font, cp, size, fx)
	local key = fontKey .. "|" .. cp .. "|" .. size .. "|" .. fx
	local c = spanCache[key]
	if c then return c end
	local _, contours, scaleUnits = glyphOf(font, cp)
	local s = size / font.upm * scaleUnits
	-- edges in pixel space (y down)
	local edges = {}
	local minY, maxY = math.huge, -math.huge
	for _, k in contours do
		local n = #k // 2
		for i = 1, n do
			local j = i % n + 1
			local x0, y0 = k[2 * i - 1] * s + fx, -k[2 * i] * s
			local x1, y1 = k[2 * j - 1] * s + fx, -k[2 * j] * s
			if y0 ~= y1 then
				table.insert(edges, { x0, y0, x1, y1, y1 > y0 and 1 or -1 })
				minY, maxY = math.min(minY, y0, y1), math.max(maxY, y0, y1)
			end
		end
	end
	local out = {}
	if #edges > 0 then
		for row = math.floor(minY), math.ceil(maxY) do
			local yc = row + 0.5
			local xs = {}
			for _, e in edges do
				local ya, yb = e[2], e[4]
				if (ya <= yc and yb > yc) or (yb <= yc and ya > yc) then
					table.insert(xs, { e[1] + (yc - ya) / (yb - ya) * (e[3] - e[1]), e[5] })
				end
			end
			if #xs > 1 then
				table.sort(xs, function(a, b) return a[1] < b[1] end)
				local wind = 0
				for i = 1, #xs - 1 do
					wind += xs[i][2]
					if wind ~= 0 then
						-- pixel centres strictly inside [xa, xb)
						local xa, xb = xs[i][1], xs[i + 1][1]
						local p0, p1 = math.ceil(xa - 0.5), math.ceil(xb - 0.5) - 1
						if p1 >= p0 then table.insert(out, row); table.insert(out, p0); table.insert(out, p1) end
					end
				end
			end
		end
	end
	if cacheCount > 20000 then table.clear(spanCache); cacheCount = 0 end
	spanCache[key] = out
	cacheCount += 1
	return out
end

-- Calls emit(x0, x1, y) for every horizontal run of "ink" (inclusive pixel columns), text laid out by layout().
-- ox, oy: top-left of the text box in pixels; boxW: box width for alignment.
function TextRaster.draw(text, opts, L, ox, oy, boxW, emit)
	local fontKey = TextRaster.fontKey(opts.family, opts.weight)
	local font = L.font
	local size = opts.size
	local align = opts.align or "left"
	for li, line in L.lines do
		local lx = ox
		if align == "center" then lx = ox + (boxW - line[2]) / 2
		elseif align == "right" then lx = ox + boxW - line[2] end
		local by = oy + (li - 1) * L.lineH + L.halfLeading + L.ascent
		local baseline = TextRaster.baselineMode == "floor" and math.floor(by) or (TextRaster.baselineMode == "ceil" and math.ceil(by) or math.floor(by + 0.5))
		local x = lx
		for _, cp in utf8.codes(line[1]) do
			local a = glyphOf(font, cp)
			if cp ~= 32 then
				local mode = TextRaster.originMode
				local q
				if mode == "round" then q = math.floor(x + 0.5)
				elseif mode == "floor" then q = math.floor(x)
				elseif mode == "frac64" then q = math.floor(x * 64 + 0.5) / 64
				else q = math.floor(x * 4 + 0.5) / 4 end
				local gx = math.floor(q)
				local sp = glyphSpans(fontKey, font, cp, size, q - gx)
				for i = 1, #sp, 3 do emit(gx + sp[i + 1], gx + sp[i + 2], baseline + sp[i]) end
			end
			local am = TextRaster.advMode
			if am == "round1" then x += math.floor(a * L.unit + L.spacing + 0.5)
			elseif am == "round2" then x += math.floor(a * L.unit + 0.5) + L.spacing
			elseif am == "round3" then x += math.floor(a * L.unit + 0.5) + math.floor(L.spacing + 0.5)
			elseif am == "q64" then x += math.floor((a * L.unit + L.spacing) * 64 + 0.5) / 64
			elseif am == "q64f" then x += math.floor((a * L.unit + L.spacing) * 64) / 64
			elseif am == "q64s" then x += math.floor(a * L.unit * 64 + 0.5) / 64 + math.floor(L.spacing * 64 + 0.5) / 64
			else x += a * L.unit + L.spacing end
		end
	end
end

return TextRaster
