--!strict
-- Game1: settlement tiers and the realm layout. Numbers mirror the vault's Economy.md.
-- Defender counts are lower than Economy.md until the army system exists (solo raids).

export type Tier = {
	weight: number, -- World Control weight
	defenders: number,
	defenderHealth: number,
	defenderDamage: number,
	raidLoot: number,
	garrison: number, -- gold to subjugate
	tribute: number, -- gold per minute
	upkeep: number, -- gold per minute
}

export type SettlementDef = {
	name: string,
	tier: string,
	region: string,
	position: Vector3,
}

local Tiers: { [string]: Tier } = {
	Hamlet = { weight = 1, defenders = 4, defenderHealth = 60, defenderDamage = 6, raidLoot = 100, garrison = 200, tribute = 12, upkeep = 4 },
	Village = { weight = 2, defenders = 6, defenderHealth = 80, defenderDamage = 8, raidLoot = 250, garrison = 500, tribute = 28, upkeep = 9 },
	Town = { weight = 5, defenders = 10, defenderHealth = 120, defenderDamage = 11, raidLoot = 800, garrison = 1600, tribute = 85, upkeep = 30 },
	City = { weight = 12, defenders = 14, defenderHealth = 180, defenderDamage = 14, raidLoot = 2500, garrison = 5000, tribute = 240, upkeep = 90 },
	Capital = { weight = 30, defenders = 20, defenderHealth = 260, defenderDamage = 18, raidLoot = 8000, garrison = 16000, tribute = 700, upkeep = 260 },
}

local Regions: { [string]: { name: string, unlocked: boolean, scoutCost: number } } = {
	Vale = { name = "The Ashen Vale", unlocked = true, scoutCost = 0 },
	Marches = { name = "The Grey Marches", unlocked = false, scoutCost = 150 },
	Highlands = { name = "The Iron Highlands", unlocked = false, scoutCost = 270 },
	Aldermere = { name = "Kingdom of Aldermere", unlocked = false, scoutCost = 486 },
}

local List: { [string]: SettlementDef } = {
	ashford = { name = "Ashford", tier = "Hamlet", region = "Vale", position = Vector3.new(80, 0, 20) },
	millbrook = { name = "Millbrook", tier = "Village", region = "Vale", position = Vector3.new(40, 0, 130) },
	thornwick = { name = "Thornwick", tier = "Village", region = "Vale", position = Vector3.new(-110, 0, 90) },
	greyhaven = { name = "Greyhaven", tier = "Town", region = "Marches", position = Vector3.new(-40, 0, -200) },
	oakridge = { name = "Oakridge", tier = "Hamlet", region = "Marches", position = Vector3.new(150, 0, -150) },
	ironhold = { name = "Ironhold", tier = "City", region = "Highlands", position = Vector3.new(300, 0, 160) },
	aldermere = { name = "Aldermere", tier = "Capital", region = "Aldermere", position = Vector3.new(-320, 0, -80) },
}

local totalWeight = 0
for _, def in List do
	totalWeight += Tiers[def.tier].weight
end

return {
	Tiers = Tiers,
	Regions = Regions,
	List = List,
	TotalWeight = totalWeight,
	EliminateBonus = 0.5, -- eliminate pays raid loot x (1 + 0.5)
	EliminatedWeightShare = 0.5, -- ruins count half control
}
