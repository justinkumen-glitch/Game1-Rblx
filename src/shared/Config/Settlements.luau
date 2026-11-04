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
	Hamlet = { weight = 1, defenders = 3, defenderHealth = 60, defenderDamage = 3, raidLoot = 100, garrison = 200, tribute = 12, upkeep = 4 },
	Village = { weight = 2, defenders = 5, defenderHealth = 80, defenderDamage = 5, raidLoot = 250, garrison = 500, tribute = 28, upkeep = 9 },
	Town = { weight = 5, defenders = 10, defenderHealth = 120, defenderDamage = 11, raidLoot = 800, garrison = 1600, tribute = 85, upkeep = 30 },
	City = { weight = 12, defenders = 14, defenderHealth = 180, defenderDamage = 14, raidLoot = 2500, garrison = 5000, tribute = 240, upkeep = 90 },
	Capital = { weight = 30, defenders = 20, defenderHealth = 260, defenderDamage = 18, raidLoot = 8000, garrison = 16000, tribute = 700, upkeep = 260 },
}

-- Regions are the Map v2 biomes (see Config/World.luau). Ashen (your home) and Vale start unlocked.
local Regions: { [string]: { name: string, unlocked: boolean, scoutCost: number } } = {
	Ashen = { name = "The Ashen Coast", unlocked = true, scoutCost = 0 },
	Vale = { name = "Verdant Vale", unlocked = true, scoutCost = 0 },
	Fields = { name = "The Golden Fields", unlocked = false, scoutCost = 150 },
	Woods = { name = "Glimmerwood", unlocked = false, scoutCost = 220 },
	Desert = { name = "The Sunscar", unlocked = false, scoutCost = 320 },
	Frost = { name = "Frostpeak", unlocked = false, scoutCost = 400 },
	Kingdom = { name = "Highland Kingdom", unlocked = false, scoutCost = 560 },
}

local World = require(script.Parent.World)

-- x, z only: the ground height is computed from the world rules so models and guards sit on the terrain.
-- Ids from v0.1 are kept so saved progress carries over.
local Raw: { [string]: { name: string, tier: string, region: string, x: number, z: number } } = {
	cinderhollow = { name = "Cinderhollow", tier = "Hamlet", region = "Ashen", x = -1080, z = 1080 },
	ashford = { name = "Ashford", tier = "Hamlet", region = "Vale", x = -820, z = 1010 },
	brackenford = { name = "Brackenford", tier = "Hamlet", region = "Vale", x = -470, z = 1150 },
	millbrook = { name = "Millbrook", tier = "Village", region = "Vale", x = -640, z = 700 },
	thornwick = { name = "Thornwick", tier = "Village", region = "Vale", x = -380, z = 560 },
	oakridge = { name = "Oakridge", tier = "Hamlet", region = "Fields", x = 120, z = 820 },
	sunmeadow = { name = "Sunmeadow", tier = "Village", region = "Fields", x = 420, z = 760 },
	greyhaven = { name = "Greyhaven", tier = "Town", region = "Fields", x = 330, z = 330 },
	mossdeep = { name = "Mossdeep", tier = "Village", region = "Woods", x = -1180, z = 330 },
	lanternhollow = { name = "Lanternhollow", tier = "Town", region = "Woods", x = -1380, z = -260 },
	dunerest = { name = "Dunerest", tier = "Village", region = "Desert", x = 1000, z = 1180 },
	sandspire = { name = "Sandspire", tier = "Town", region = "Desert", x = 1580, z = 520 },
	solmara = { name = "Solmara", tier = "City", region = "Desert", x = 1200, z = 870 },
	rimeholt = { name = "Rimeholt", tier = "Village", region = "Frost", x = -760, z = -900 },
	ironhold = { name = "Ironhold", tier = "City", region = "Frost", x = -150, z = -1350 },
	whitecrest = { name = "Whitecrest", tier = "Town", region = "Kingdom", x = 800, z = -700 },
	highmoor = { name = "Highmoor", tier = "City", region = "Kingdom", x = 1500, z = -600 },
	aldermere = { name = "Aldermere", tier = "Capital", region = "Kingdom", x = 1150, z = -1200 },
}

-- Your citadel: on the Ashen Coast cliffs, looking out to sea.
local CITADEL_XZ = Vector2.new(-1420, 1360)

-- Flat ground radius per tier (studs) for walkable towns and cities.
local PadRadius = { Hamlet = 45, Village = 60, Town = 85, City = 120, Capital = 160 }

-- Road network: pairs of ids ("citadel" is your home).
local RoadLinks = {
	{ "citadel", "cinderhollow" }, { "cinderhollow", "ashford" }, { "ashford", "brackenford" }, { "ashford", "millbrook" },
	{ "millbrook", "thornwick" }, { "thornwick", "oakridge" }, { "oakridge", "sunmeadow" }, { "thornwick", "greyhaven" },
	{ "millbrook", "mossdeep" }, { "mossdeep", "lanternhollow" }, { "sunmeadow", "dunerest" }, { "dunerest", "solmara" },
	{ "solmara", "sandspire" }, { "greyhaven", "whitecrest" }, { "whitecrest", "aldermere" }, { "whitecrest", "highmoor" },
	{ "lanternhollow", "rimeholt" }, { "rimeholt", "ironhold" }, { "ironhold", "aldermere" },
}

local function groundY(x: number, z: number): number
	local h = World.NaturalHeight(x, z)
	return math.max(h, World.SeaLevel + 6)
end

local List: { [string]: SettlementDef } = {}
local pads = {}
for id, r in Raw do
	local y = groundY(r.x, r.z)
	List[id] = { name = r.name, tier = r.tier, region = r.region, position = Vector3.new(r.x, y, r.z) }
	table.insert(pads, { centre = Vector2.new(r.x, r.z), radius = PadRadius[r.tier], blend = 45, y = y })
end
local citadelY = groundY(CITADEL_XZ.X, CITADEL_XZ.Y) + 6
table.insert(pads, { centre = CITADEL_XZ, radius = 90, blend = 50, y = citadelY })
World.SetPads(pads)

local function xzOf(id: string): Vector2
	if id == "citadel" then
		return CITADEL_XZ
	end
	local r = Raw[id]
	return Vector2.new(r.x, r.z)
end

-- Gently curved roads: subdivide each link and push the middle points sideways with noise.
local roads = {}
for n, link in RoadLinks do
	local a, b = xzOf(link[1]), xzOf(link[2])
	local dir = b - a
	local side = Vector2.new(-dir.Y, dir.X).Unit
	local pts = {}
	local steps = math.max(4, math.floor(dir.Magnitude / 60))
	for i = 0, steps do
		local t = i / steps
		local bend = math.sin(t * math.pi) * math.noise(n * 3.7, t * 2.1, 9.9) * dir.Magnitude * 0.35
		table.insert(pts, a + dir * t + side * bend)
	end
	table.insert(roads, pts)
end
World.SetRoads(roads)

local totalWeight = 0
for _, def in List do
	totalWeight += Tiers[def.tier].weight
end

return {
	Tiers = Tiers,
	Regions = Regions,
	List = List,
	Citadel = Vector3.new(CITADEL_XZ.X, citadelY, CITADEL_XZ.Y),
	PadRadius = PadRadius,
	TotalWeight = totalWeight,
	EliminateBonus = 0.5, -- eliminate pays raid loot x (1 + 0.5)
	EliminatedWeightShare = 0.5, -- ruins count half control
}
