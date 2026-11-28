-- Renders a fixed scenario with the Luau port of the website's renderer and prints frames as hex.
-- Driven by tools/roblox-scene-diff.js, which renders the same scenario with the website's js/ocean.js and diffs them.
local Ocean = require("../src/client/Ocean")
local W, H = tonumber(SCENE_W or 1440), tonumber(SCENE_H or 900)
local seed = 12345
Ocean.random = function() seed = (seed * 48271) % 2147483647; return seed / 2147483647 end
Ocean.init(W, H)
local now = 1000
local snaps = {}
local function step(ms)
	local n = math.floor(ms / 16.67 + 0.5)
	for _ = 1, n do now += 16.67; Ocean.frame(now) end
end
local function snap(name)
	local ctx = Ocean.state.ctx
	local s = buffer.tostring(ctx.buf)
	local hexs = s:gsub(".", function(c) return string.format("%02x", string.byte(c)) end)
	print("SNAP " .. name .. " " .. ctx.W .. " " .. ctx.H)
	print(hexs)
end
Ocean.setView("title", true); step(1500); snap("title")
Ocean.setView("intro"); Ocean.flush(now); step(900); snap("flush-mid")
step(1700); snap("flush-drop")
Ocean.setView("game"); step(1500); snap("game-start")
for _, d in { 1200, 2700, 3900, 4900, 6200 } do Ocean.setDepth(d, now); step(4000); snap("game-depth-" .. d) end
Ocean.setView("results"); step(2500); snap("results")
