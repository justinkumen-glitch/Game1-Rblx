--!strict
-- Game1: every gold and mana change goes through here, so each one is logged
-- as an analytics economy event (LihFolk: Economies and Currencies; Analytics and Funnels).

local ServerScriptService = game:GetService("ServerScriptService")

local Currency = require(ServerScriptService:WaitForChild("LihFolk"):WaitForChild("Currency"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))

local Economy = {}

function Economy.Gain(player: Player, currency: string, amount: number, txType: string, sku: string?): boolean
	local whole = math.floor(amount)
	if whole < 1 then
		return false
	end
	if not Currency.Add(player, currency, whole, txType) then
		return false
	end
	Analytics.Economy(player, true, currency, whole, Currency.Get(player, currency) or 0, txType, sku)
	return true
end

function Economy.Spend(player: Player, currency: string, amount: number, txType: string, sku: string?): boolean
	local whole = math.floor(amount)
	if whole < 1 then
		return true -- nothing to pay
	end
	if not Currency.Spend(player, currency, whole, txType) then
		return false
	end
	Analytics.Economy(player, false, currency, whole, Currency.Get(player, currency) or 0, txType, sku)
	return true
end

function Economy.Get(player: Player, currency: string): number
	return Currency.Get(player, currency) or 0
end

return Economy
