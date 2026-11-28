#!/usr/bin/env node
// Renders a Roblox UI screen headlessly (luau CLI + mock Instances) on top of the ported scene, writes a PNG
// next to the matching Chrome screenshot, and prints element rects for layout checks.
// Usage: node tools/roblox-ui-render.js <outdir> <screen> <W> <H> [chromePng]
const path = require('path'), fs = require('fs'), { execFileSync } = require('child_process');
const { createCanvas, loadImage } = require('canvas');
const root = path.join(__dirname, '..');
const [out, screen, W, H, chromePng] = [process.argv[2], process.argv[3] || 'title', +(process.argv[4] || 1440), +(process.argv[5] || 900), process.argv[6]];
// results: RESULTS_FIXTURE=<json> gives the page data; SCROLL=<px> renders the viewport scrolled that far
const fixture = process.env.RESULTS_FIXTURE ? fs.readFileSync(process.env.RESULTS_FIXTURE, 'utf8') : JSON.stringify({ modeLabel: '5-PROMPT FLUSH COMPLETE', score: 130, depth: 830, zone: 'Reached the Pipes', n: 5, stats: { played: 1, avg: 130, best: 130 },
  results: [{ score: 30, q: 'Name a part of a song', answer: 'Outro' }, { score: 30, q: 'Name a job a horse can do', answer: 'Herding cattle' }, { score: 30, q: 'Name a US city that starts with H (100,000+ people)', answer: 'Henderson' }, { score: 10, q: 'Name a structure or object made of concrete', answer: 'Bridge' }, { score: 30, q: 'Name a song by Usher (lead or featured)', answer: 'U Got It Bad' }] });
const scroll = +(process.env.SCROLL || 0);
const toLua = v => Array.isArray(v) ? '{' + v.map(toLua).join(',') + '}' : v && typeof v === 'object' ? '{' + Object.entries(v).map(([k, x]) => `[${JSON.stringify(k)}]=${toLua(x)}`).join(',') + '}' : typeof v === 'string' ? JSON.stringify(v) : String(v);
const lua = `--!nocheck
local W, H = ${W}, ${H}
local Color3 = {} Color3.__index = Color3
function Color3.new(r, g, b) return setmetatable({ R = r, G = g, B = b }, Color3) end
function Color3.fromRGB(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
function Color3:Lerp(o, t) return Color3.new(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t) end
function Color3.fromHex(h) h = h:gsub("#", ""); return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)) end
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
local Inst = {} Inst.__index = Inst
local function new(class) return setmetatable({ ClassName = class, _kids = {}, Visible = true, BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1, Name = class,
	Activated = { Connect = function() end } }, Inst) end
function Inst:SetAttribute(k, v) rawset(self, "_attr_" .. k, v) end
function Inst:GetAttribute(k) return rawget(self, "_attr_" .. k) end
function Inst:IsA(c) return self.ClassName == c or (c == "GuiObject") end
function Inst:GetChildren() return table.clone(self._kids) end
function Inst:Destroy() local p = rawget(self, "_parent"); if p then for i, c in p._kids do if c == self then table.remove(p._kids, i) break end end end; rawset(self, "_parent", nil) end
function Inst:FindFirstChild(n) for _, c in self._kids do if c.Name == n then return c end end return nil end
setmetatable(Inst, { __index = function(t, k) return nil end })
local mt = { __index = function(self, k) local v = rawget(Inst, k); if v then return v end; for _, c in rawget(self, "_kids") do if c.Name == k then return c end end; return nil end,
	__newindex = function(self, k, v) if k == "Parent" then if v then table.insert(v._kids, self) end; rawset(self, "_parent", v) else rawset(self, k, v) end end }
local function mk(class) local o = new(class); return setmetatable(o, mt) end
local Kit = require("./src/client/Kit")
Kit.new = mk
Kit.Color3 = Color3
Kit.UDim2 = UDim2
Kit.makeImage = function(w, h) local img = { w = w, h = h }
	function img:write(buf) self.buf = buf end
	function img:label() local l = mk("ImageLabel"); l.BackgroundTransparency = 1; l._img = self; return l end
	return img end
Kit.Css.set(W, H); Kit.minTextSize = tonumber("${process.env.MIN_TEXT || 0}")
local Ocean = require("./src/client/Ocean")
Ocean.init(W, H)
local now = 1000
Ocean.setView("${screen === 'game' ? 'game' : screen === 'results' ? 'results' : 'title'}", true)
for _ = 1, 90 do now += 16.67; Ocean.frame(now) end
local scene = Ocean.state.ctx
local function hex(buf) return (buffer.tostring(buf):gsub(".", function(c) return string.format("%02x", string.byte(c)) end)) end
print("SCENE " .. scene.W .. " " .. scene.H .. " " .. hex(scene.buf))
local guiRoot = mk("Frame"); guiRoot.Size = UDim2.new(0, W, 0, H); guiRoot.BackgroundTransparency = 1
local rules = "Ranked: entry is spent when the run starts and is non-refundable once you answer. Same price for everyone. Payout = 1 coin per 5 points up to the typical score, then 1 coin per 25 points above it, rounded down. About half of runs come out ahead; overall the house keeps a small cut. Boosts: your first 3 ranked runs pay ×1.3/×1.2/×1.1, and after 3 losses in a row your next run pays ×1.3. Coins are earned in-game only and can't be bought. Shop items are cosmetic, final sale."
local rects
if "${screen}" == "title" then
	local Title = require("./src/client/TitleScreen")
	_, rects = Title.build(guiRoot, { coins = 0, len = 10, price = 58, boost = { x = 1.3, why = "NEW PLAYER" }, rules = rules }, {})
elseif ({ menu = 1, stats = 1, shop = 1, packs = 1, help = 1, settings = 1, again = 1 })["${screen}"] then
	local Title = require("./src/client/TitleScreen")
	Title.build(guiRoot, { coins = 0, len = 10, price = 58, boost = { x = 1.3, why = "NEW PLAYER" }, rules = rules }, {})
	local P = require("./src/client/Panels")
	local s = "${screen}"
	if s == "menu" then
		_, rects = P.menu(guiRoot, { { label = "HOME", icon = "home", act = "home" }, { label = "PLAY", icon = "play", act = "unlimited" }, { label = "THEMED PACKS", icon = "cube", act = "packs" },
			{ label = "SHOP", icon = "cube", act = "shop" }, { label = "STATISTICS", icon = "chart", act = "stats" }, { label = "SETTINGS", icon = "gear", act = "settings" }, { label = "HOW TO PLAY", icon = "help", act = "help" } },
			"home", "3,776 prompts in the deep · Daily #88", function() end, function() end)
	elseif s == "stats" then
		rects = {}; local _; _, rects = P.stats(guiRoot, { games = 0, best = 0, avg = 0, avgPer = 0, deepest = 0, answeredPct = 0 }, {})
	elseif s == "shop" then
		local Cfg = require("./src/shared/Config")
		local items = {}
		for _, it in Cfg.SHOP do local d = table.clone(it); d.robux = it.type ~= "boost"; d.preview = it.type == "toilet" and (it.sprite or "toilet") or "duck0"; d.ph = it.type == "toilet" and 15 or 13; d.tint = it.fx == "rainbow" and "~#ff7ad9" or it.tint; table.insert(items, d) end
		_, rects = P.shop(guiRoot, { coins = 0, items = items, boosts = 0 }, {})
	elseif s == "packs" then
		_, rects = P.packs(guiRoot, { { key = "geography", name = "Geography", blurb = "Countries, capitals, rivers, peaks and every corner of the map.", count = 355 },
			{ key = "movies", name = "Movies & TV", blurb = "Directors, franchises, characters and the small screen.", count = 306 }, { key = "sports", name = "Sports", blurb = "Teams, tournaments, legends and the rules of the game.", count = 219 },
			{ key = "gaming", name = "Gaming", blurb = "Pokémon, Minecraft, Nintendo, consoles and classics.", count = 237 }, { key = "science", name = "Science & Nature", blurb = "Elements, planets, the human body and the animal kingdom.", count = 782 },
			{ key = "music", name = "Music", blurb = "Instruments, bands, albums, composers and musicals.", count = 154 }, { key = "language", name = "Language & Lit", blurb = "Words, alphabets, languages and literature.", count = 262 },
			{ key = "pop", name = "Pop Culture", blurb = "Celebrities, internet, apps, snacks and everything trending.", count = 311 }, { key = "fun", name = "Fun & Random", blurb = "Things that use suction, junk-drawer finds, Minecraft blocks and more.", count = 433 } }, { focus = 1 })
	elseif s == "help" then P.help(guiRoot, {}); rects = {}
	elseif s == "settings" then P.settings(guiRoot, { sound = true, prompts = 3776, answers = 412000 }, {}); rects = {}
	else P.playAgain(guiRoot, { len = 10, price = 58, coins = 0, boost = { x = 1.3, why = "NEW PLAYER" } }, {}); rects = {} end
elseif "${screen}" == "results" then
	local Results = require("./src/client/ResultsScreen")
	local root
	root, rects = Results.build(guiRoot, ${toLua(JSON.parse(fixture))}, {})
	root.Page.Position = UDim2.new(0, 0, 0, -${scroll})
else
	local Game = require("./src/client/GameScreen")
	local g = Game.new(guiRoot, {})
	g:setHud(0, 0)
	g:setProgress({ { state = "cur" }, { state = "todo" }, { state = "todo" }, { state = "todo" }, { state = "todo" } }, "PROMPT 1 OF 5")
	g:setPrompt("Name something you might spot on a national park trip.", "PROMPT 1 OF 5")
	g:setTimer(23, 25)
	g:setFeedback([["qwzz" isn't on our list]], "bad")
	g:update(Ocean, false)
	rects = g.rects
end
for name, r in rects do print(string.format("RECT %s %.1f %.1f %.1f %.1f", name, r[1], r[2], r[3], r[4])) end
local function walk(o, px, py, pw, ph)
	if o.Visible == false then return end
	local w = o.Size.X.Scale * pw + o.Size.X.Offset
	local h = o.Size.Y.Scale * ph + o.Size.Y.Offset
	local x = px + o.Position.X.Scale * pw + o.Position.X.Offset
	local y = py + o.Position.Y.Scale * ph + o.Position.Y.Offset
	if o.ClassName == "ImageLabel" and o._img and o._img.buf then
		print(string.format("I %d %d %d %d %d %d %s", x, y, w, h, o._img.w, o._img.h, hex(o._img.buf)))
	elseif (o.ClassName == "Frame" or o.ClassName == "ScrollingFrame") and (o.BackgroundTransparency or 0) < 1 then
		local c = o.BackgroundColor3
		print(string.format("R %d %d %d %d %d %d %d %d", x, y, w, h, math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), math.floor((1 - o.BackgroundTransparency) * 255 + 0.5)))
	end
	if o.ClassName == "ScrollingFrame" then print(string.format("CLIP %d %d %d %d", x, y, w, h)) end
	for _, k in o._kids do walk(k, x, y, w, h) end
	if o.ClassName == "ScrollingFrame" then print("UNCLIP") end
end
walk(guiRoot, 0, 0, W, H)
`;
const tmp = path.join(root, 'roblox/.ui_tmp.luau'); fs.writeFileSync(tmp, lua);
let txt; try { txt = execFileSync('luau', [tmp], { cwd: path.join(root, 'roblox'), maxBuffer: 1 << 30 }).toString(); } finally { fs.rmSync(tmp, { force: true }); }
(async () => {
  const cv = createCanvas(W, H); const c = cv.getContext('2d'); c.imageSmoothingEnabled = false;
  const rects = {};
  for (const line of txt.split('\n')) {
    const p = line.split(' ');
    if (p[0] === 'SCENE') { const sw = +p[1], sh = +p[2]; const sc = createCanvas(sw, sh); const id = sc.getContext('2d').createImageData(sw, sh); id.data.set(Buffer.from(p[3], 'hex')); sc.getContext('2d').putImageData(id, 0, 0); c.drawImage(sc, 0, 0, W, H); }
    else if (p[0] === 'R') { const [x, y, w, h, r, g, b, a] = p.slice(1).map(Number); c.fillStyle = `rgba(${r},${g},${b},${a / 255})`; c.fillRect(x, y, w, h); }
    else if (p[0] === 'I') { const [x, y, w, h, iw, ih] = p.slice(1, 7).map(Number); const ic = createCanvas(iw, ih); const id = ic.getContext('2d').createImageData(iw, ih); id.data.set(Buffer.from(p[7], 'hex')); ic.getContext('2d').putImageData(id, 0, 0); c.drawImage(ic, x, y, w, h); }
    else if (p[0] === 'CLIP') { const [x, y, w, h] = p.slice(1).map(Number); c.save(); c.beginPath(); c.rect(x, y, w, h); c.clip(); }
    else if (p[0] === 'UNCLIP') c.restore();
    else if (p[0] === 'RECT') rects[p[1]] = p.slice(2).map(Number);
  }
  c.fillStyle = 'rgba(0,0,0,0.07)'; for (let y = 2; y < H; y += 3) c.fillRect(0, y, W, 1);
  fs.writeFileSync(path.join(out, `rbx-${screen}-${W}x${H}.png`), cv.toBuffer('image/png'));
  if (chromePng) {
    const ref = await loadImage(chromePng); const sbs = createCanvas(W * 2 + 8, H); const s = sbs.getContext('2d'); s.fillStyle = '#f0f'; s.fillRect(0, 0, sbs.width, H);
    s.drawImage(ref, 0, 0); s.drawImage(cv, W + 8, 0); fs.writeFileSync(path.join(out, `sbs-${screen}-${W}x${H}.png`), sbs.toBuffer('image/png'));
  }
  console.log(JSON.stringify(rects));
})();
