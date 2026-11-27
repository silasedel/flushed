-- Loads every prompt from the Questions folder (JSON chunks made by tools/roblox-export.js).
local HttpService = game:GetService("HttpService")

local Bank = { all = {}, byId = {}, casual = {} }

local chunks = script.Parent:WaitForChild("Questions"):GetChildren()
table.sort(chunks, function(a, b) return a.Name < b.Name end)
for _, mod in chunks do
	if mod:IsA("ModuleScript") then
		local list = HttpService:JSONDecode(require(mod))
		for _, q in list do
			q.brainrot = q.flags:find("b", 1, true) ~= nil
			q.vague = q.flags:find("v", 1, true) ~= nil
			q.famous = q.flags:find("f", 1, true) ~= nil
			q.fandom = q.flags:find("d", 1, true) ~= nil
			table.insert(Bank.all, q)
			Bank.byId[q.id] = q
			-- random games use prompts ~90% of players can answer, and nothing that needs you to have seen a show
			if q.diff == "easy" and not q.fandom then table.insert(Bank.casual, q) end
		end
	end
end
print(string.format("[FLUSHED] loaded %d prompts (%d in the random-game pool)", #Bank.all, #Bank.casual))

return Bank
