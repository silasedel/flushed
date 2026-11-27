-- Checks the Luau economy matches the website: prices 29/41/58, payouts, boosts, percentiles.
-- Run from the roblox/ folder:  luau tests/economy.luau
local E = require("../src/shared/Economy")
local function eq(a, b, what) if a ~= b then error(string.format("%s: got %s, want %s", what, tostring(a), tostring(b))) end end
eq(E.par(5), 145, "par 5"); eq(E.par(7), 205, "par 7"); eq(E.par(10), 290, "par 10")
eq(E.price(5), 29, "price 5"); eq(E.price(7), 41, "price 7"); eq(E.price(10), 58, "price 10"); eq(E.price(0), 58, "price endless")
eq(E.payout(205, 7, 1), 41, "payout at par"); eq(E.payout(305, 7, 1), 45, "payout above par"); eq(E.payout(100, 7, 1.3), 26, "boosted")
eq(E.boost({ runs = 0 }).why, "NEW PLAYER", "welcome"); eq(E.boost({ runs = 5, lose = 3 }).x, 1.3, "comeback"); eq(E.boost({ runs = 5, lose = 1 }).x, 1, "none")
eq(E.percentile(7, 385), 91, "385 in 7 prompts")
print("economy ok: prices 29/41/58, profit at " .. E.profitAt(7, 1) .. "+ in 7 prompts")
