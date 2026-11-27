#!/usr/bin/env node
// Renders the Roblox scene (roblox/src/client/Scene.luau) to PNGs without Roblox: runs it in the luau CLI with
// mock GUI objects, dumps every visible Frame as a rectangle, and rasterizes them here.
// Usage: node tools/roblox-render.js <outdir> [width height]
const fs = require('fs'), path = require('path'), zlib = require('zlib'), { execFileSync } = require('child_process');
const R = path.join(__dirname, '..', 'roblox');
const out = process.argv[2] || '.'; const W = +(process.argv[3] || 1280), H = +(process.argv[4] || 720);
const sprites = fs.readFileSync(path.join(R, 'src/client/Sprites.luau'), 'utf8');
const scene = fs.readFileSync(path.join(R, 'src/client/Scene.luau'), 'utf8');
const lua = `--!nocheck
local VW, VH = ${W}, ${H}
local Color3 = {}
Color3.__index = Color3
function Color3.new(r, g, b) return setmetatable({ R = r, G = g, B = b }, Color3) end
function Color3.fromRGB(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
function Color3.fromHex(h) h = h:gsub("#", ""); return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)) end
function Color3:Lerp(o, t) return Color3.new(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t) end
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
local UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
local Vector2 = { new = function(x, y) return { X = x, Y = y } end, zero = { X = 0, Y = 0 } }
local Inst = {}
local function newInst(class)
  local o = { ClassName = class, _kids = {}, Visible = true, BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 0, 0, 0), AnchorPoint = Vector2.zero, ZIndex = 1, Rotation = 0, BackgroundColor3 = Color3.new(1, 1, 1), Name = class, _attr = {} }
  return setmetatable(o, Inst)
end
Inst.__index = function(self, k)
  if k == "Parent" then return rawget(self, "_parent") end
  local m = rawget(Inst, k); if m then return m end
  for _, c in rawget(self, "_kids") do if c.Name == k then return c end end
  return nil
end
Inst.__newindex = function(self, k, v)
  if k == "Parent" then
    local old = rawget(self, "_parent")
    if old then for i, c in old._kids do if c == self then table.remove(old._kids, i) break end end end
    rawset(self, "_parent", v); if v then table.insert(v._kids, self) end
  else rawset(self, k, v) end
end
function Inst:GetChildren() return table.clone(self._kids) end
function Inst:FindFirstChild(n) for _, c in self._kids do if c.Name == n then return c end end return nil end
function Inst:Destroy() self.Parent = nil end
function Inst:SetAttribute(k, v) self._attr[k] = v end
function Inst:GetAttribute(k) return self._attr[k] end
function Inst:Clone()
  local c = newInst(self.ClassName)
  for k, v in self do if k ~= "_kids" and k ~= "_parent" and k ~= "_attr" then rawset(c, k, v) end end
  for _, kid in self._kids do kid:Clone().Parent = c end
  return c
end
function Inst:GetPropertyChangedSignal() return { Connect = function() end } end
local Instance = { new = function(c, parent) local o = newInst(c); if parent then o.Parent = parent end; return o end }
local stepFn
local RunService = { RenderStepped = { Connect = function(_, f) stepFn = f end } }
local game = { GetService = function(_, n) return RunService end }
local workspace = { CurrentCamera = { ViewportSize = Vector2.new(VW, VH), GetPropertyChangedSignal = function() return { Connect = function() end } end } }
local task = { spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end }
local fakeClock = 0
local os = setmetatable({ clock = function() return fakeClock end }, { __index = os })
math.randomseed(7)
local Sprites = (function() ${sprites.replace(/^--.*\n/gm, '')} end)()
local script = { Parent = { Sprites = "SPRITES" } }
local require = function(x) return Sprites end
local Scene = (function() ${scene.replace(/^--!.*\n/, '')} end)()

local rootGui = newInst("ScreenGui")
Scene.init(rootGui)
local function dump(tag)
  print("SNAP " .. tag)
  local function walk(o, px, py, pw, ph, vis)
    if not o.Visible then return end
    local ax, ay = o.AnchorPoint.X, o.AnchorPoint.Y
    local w = o.Size.X.Scale * pw + o.Size.X.Offset
    local h = o.Size.Y.Scale * ph + o.Size.Y.Offset
    local uis = o:FindFirstChild("UIScale")
    local sc = uis and uis.Scale or 1
    local x = px + o.Position.X.Scale * pw + o.Position.X.Offset - ax * w * sc
    local y = py + o.Position.Y.Scale * ph + o.Position.Y.Offset - ay * h * sc
    if o.ClassName == "Frame" and o.BackgroundTransparency < 1 then
      local c = o.BackgroundColor3
      print(string.format("R %d %d %d %d %d %d %d %d", math.floor(x), math.floor(y), math.ceil(w * sc), math.ceil(h * sc), math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), math.floor((1 - o.BackgroundTransparency) * 255)))
    end
    for _, k in o._kids do
      if k.ClassName == "Frame" then
        if sc ~= 1 then
          -- children of a scaled frame: approximate by scaling their offsets
          local kk = setmetatable({}, { __index = k })
          walk(k, x, y, w * sc, h * sc, vis)
        else walk(k, x, y, w, h, vis) end
      end
    end
  end
  walk(rootGui._kids[1], 0, 0, VW, VH)
end
local function run(sec) local n = math.floor(sec * 30); for _ = 1, n do fakeClock += 1 / 30; stepFn(1 / 30) end end
run(1); dump("title")
Scene.setSkin({ duck = "duck-gold", toilet = "toilet-gold", trail = "trail-rainbow" }, {
  { id = "duck-gold", type = "duck", color = "#ffcc33" }, { id = "toilet-gold", type = "toilet", sprite = "goldtoilet" }, { id = "trail-rainbow", type = "trail", trail = "rainbow" } })
run(0.5); dump("title-gold")
Scene.setSkin({}, {})
local done = false
Scene.flush(function() done = true end)
run(0.95); dump("flush-backflip")
run(1.0); dump("flush-down")
run(1.4); dump("dive-start")
for _, sc in { 30, 60, 30, 85, 100, 60 } do Scene.sink(sc) end
run(6); dump("dive-pipes-sewer")
Scene.sink(85)
run(6); dump("dive-rat-kingdom")
Scene.sink(100)
run(6); dump("dive-core")
for _, sc in { 100, 100 } do Scene.sink(sc) end
Scene.setSkin({ duck = "duck-million", trail = "trail-fire" }, { { id = "duck-million", type = "duck", color = "#ffd23f", fx = "million" }, { id = "trail-fire", type = "trail", trail = "fire" } })
Scene.sink(30)
run(0.6); dump("dive-rainbow")
print("DEPTH " .. Scene.depth())
`;
const f = path.join(R, 'tests', '.render.luau'); fs.writeFileSync(f, lua);
let txt;
try { txt = execFileSync('luau', [f], { maxBuffer: 1 << 28 }).toString(); } finally { fs.rmSync(f, { force: true }); }
const crc = (() => { const t = new Int32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c; } return b => { let c = -1; for (const x of b) c = t[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; }; })();
const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
const png = (px) => { const raw = Buffer.alloc((W * 3 + 1) * H); for (let y = 0; y < H; y++) { raw[y * (W * 3 + 1)] = 0; px.copy(raw, y * (W * 3 + 1) + 1, y * W * 3, (y + 1) * W * 3); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]); };
let cur = null, buf = null; const files = [];
const flush = () => { if (cur) { const p = path.join(out, `scene-${cur}.png`); fs.writeFileSync(p, png(buf)); files.push(p); } };
for (const line of txt.split('\n')) {
  if (line.startsWith('SNAP ')) { flush(); cur = line.slice(5); buf = Buffer.alloc(W * H * 3); }
  else if (line.startsWith('R ') && buf) {
    const [x, y, w, h, r, g, b, a] = line.slice(2).split(' ').map(Number); const al = a / 255;
    for (let j = Math.max(0, y); j < Math.min(H, y + h); j++) for (let i = Math.max(0, x); i < Math.min(W, x + w); i++) {
      const o = (j * W + i) * 3; buf[o] = buf[o] * (1 - al) + r * al; buf[o + 1] = buf[o + 1] * (1 - al) + g * al; buf[o + 2] = buf[o + 2] * (1 - al) + b * al; }
  } else if (line.trim()) console.log(line);
}
flush(); console.log(files.join('\n'));
