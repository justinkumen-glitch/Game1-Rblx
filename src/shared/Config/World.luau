--!strict
-- Game1: Map v2 world rules. Shared by the terrain builder (tools/BuildTerrain.luau),
-- Settlements (ground heights) and the client zone lighting.
-- Deterministic: same inputs -> same heights on server, client and in Studio.
-- LihFolk notes: Noise Functions and Terrain Generation (blended biomes, designer curves),
-- Zone and Biome Art Direction (one accent per zone), Terrain Materials and Painting (3-5 materials per view).

local World = {}

World.Size = 4096 -- studs, square, centred on the origin
World.Half = World.Size / 2
World.SeaLevel = 20
World.Floor = -40
World.Voxel = 4

export type Biome = {
	id: string,
	name: string,
	centre: Vector2,
	accent: Color3,
	top: Enum.Material,
	slope: Enum.Material,
	patch: Enum.Material?, -- noise patches on flat ground
	road: Enum.Material,
}

-- Biome centres are placed by hand (designed, not random); noise only warps the borders.
World.Biomes = {
	{ id = "Ashen", name = "The Ashen Coast", centre = Vector2.new(-1350, 1250), accent = Color3.fromRGB(255, 40, 60),
		top = Enum.Material.Basalt, slope = Enum.Material.Slate, patch = Enum.Material.CrackedLava, road = Enum.Material.Slate },
	{ id = "Vale", name = "Verdant Vale", centre = Vector2.new(-550, 850), accent = Color3.fromRGB(255, 200, 80),
		top = Enum.Material.Grass, slope = Enum.Material.Rock, patch = Enum.Material.LeafyGrass, road = Enum.Material.Cobblestone },
	{ id = "Fields", name = "The Golden Fields", centre = Vector2.new(350, 550), accent = Color3.fromRGB(240, 170, 60),
		top = Enum.Material.Grass, slope = Enum.Material.Ground, patch = Enum.Material.Ground, road = Enum.Material.Cobblestone },
	{ id = "Woods", name = "Glimmerwood", centre = Vector2.new(-1350, -50), accent = Color3.fromRGB(230, 70, 220),
		top = Enum.Material.LeafyGrass, slope = Enum.Material.Rock, patch = Enum.Material.Mud, road = Enum.Material.Ground },
	{ id = "Desert", name = "The Sunscar", centre = Vector2.new(1350, 900), accent = Color3.fromRGB(40, 210, 200),
		top = Enum.Material.Sand, slope = Enum.Material.Sandstone, patch = Enum.Material.Sandstone, road = Enum.Material.Sandstone },
	{ id = "Frost", name = "Frostpeak", centre = Vector2.new(-450, -1250), accent = Color3.fromRGB(120, 200, 255),
		top = Enum.Material.Snow, slope = Enum.Material.Glacier, patch = Enum.Material.Ice, road = Enum.Material.Rock },
	{ id = "Kingdom", name = "Highland Kingdom", centre = Vector2.new(1150, -950), accent = Color3.fromRGB(70, 120, 255),
		top = Enum.Material.Grass, slope = Enum.Material.Limestone, patch = Enum.Material.LeafyGrass, road = Enum.Material.Cobblestone },
}
World.BiomeIndex = {} :: { [string]: number }
for i, b in World.Biomes do
	World.BiomeIndex[b.id] = i
end

-- Rivers: polylines from the mountains to the sea / the oasis. Width in studs.
World.Rivers = {
	{ width = 22, depth = 9, points = { Vector2.new(-420, -1000), Vector2.new(-300, -550), Vector2.new(-120, -100),
		Vector2.new(-260, 350), Vector2.new(-150, 900), Vector2.new(-60, 1450), Vector2.new(-20, 2100) } },
	{ width = 18, depth = 8, points = { Vector2.new(250, -1150), Vector2.new(520, -650), Vector2.new(640, -150),
		Vector2.new(900, 300), Vector2.new(1180, 650), Vector2.new(1300, 860) } },
}
World.Oasis = { centre = Vector2.new(1330, 880), radius = 70 }

-- Roads are filled in by Settlements (they connect settlements). Kept here for the builder.
World.RoadWidth = 12

------------------------------------------------------------------------------------------------
-- Noise helpers
------------------------------------------------------------------------------------------------
local noise = math.noise

local function fbm(x: number, z: number, freq: number, octaves: number, seed: number): number
	-- returns roughly -1..1
	local sum, amp, norm = 0, 1, 0
	local f = freq
	for o = 1, octaves do
		sum += noise(x * f + seed * 13.37, z * f - seed * 7.11, seed * 3.3 + o * 1.7) * amp
		norm += amp
		amp *= 0.5
		f *= 2.03
	end
	return sum / norm * 2 -- math.noise is ~ -0.5..0.5 in practice; scale up
end

local function ridged(x: number, z: number, freq: number, octaves: number, seed: number): number
	-- 0..1, sharp ridges
	local sum, amp, norm = 0, 1, 0
	local f = freq
	for o = 1, octaves do
		local n = 1 - math.abs(noise(x * f + seed * 5.1, z * f + seed * 2.9, o * 0.71) * 2)
		sum += n * n * amp
		norm += amp
		amp *= 0.5
		f *= 2.1
	end
	return sum / norm
end

local function smoothstep(a: number, b: number, t: number): number
	local x = math.clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end
World.smoothstep = smoothstep

local function hash01(x: number, z: number, s: number): number
	local n = math.sin(x * 12.9898 + z * 78.233 + s * 37.719) * 43758.5453
	return n - math.floor(n)
end
World.hash01 = hash01

------------------------------------------------------------------------------------------------
-- Biome weights (warped inverse-distance; smooth borders, Voronoi-like cores)
------------------------------------------------------------------------------------------------
local WARP = 260
local SHARP = 6 -- higher = crisper borders

function World.Weights(x: number, z: number): ({ number }, number)
	local wx = x + noise(x / 700, z / 700, 11.5) * WARP * 2
	local wz = z + noise(x / 700, z / 700, 42.1) * WARP * 2
	local ws = table.create(#World.Biomes, 0)
	local total, best, bestI = 0, -1, 1
	for i, b in World.Biomes do
		local d = math.max(1, math.sqrt((wx - b.centre.X) ^ 2 + (wz - b.centre.Y) ^ 2))
		local w = (1000 / d) ^ SHARP
		ws[i] = w
		total += w
		if w > best then
			best, bestI = w, i
		end
	end
	for i = 1, #ws do
		ws[i] /= total
	end
	return ws, bestI
end

------------------------------------------------------------------------------------------------
-- Per-biome land heights (studs above World.Floor ... absolute Y)
------------------------------------------------------------------------------------------------
local function hAshen(x: number, z: number): number
	return 64 + ridged(x, z, 1 / 260, 3, 1) * 34 + fbm(x, z, 1 / 90, 2, 2) * 4
end
local function hVale(x: number, z: number): number
	return 34 + (fbm(x, z, 1 / 420, 3, 3) * 0.5 + 0.5) * 22
end
local function hFields(x: number, z: number): number
	return 31 + (fbm(x, z, 1 / 600, 2, 4) * 0.5 + 0.5) * 9
end
local function hWoods(x: number, z: number): number
	return 38 + (fbm(x, z, 1 / 300, 4, 5) * 0.5 + 0.5) * 30
end
local function hDesert(x: number, z: number): number
	-- dunes (directional ridges) plus terraced mesas
	local dune = (1 - math.abs(math.sin((x * 0.8 + z * 0.35) / 55 + fbm(x, z, 1 / 300, 2, 6) * 2.5))) ^ 2
	local h = 30 + dune * 9 + (fbm(x, z, 1 / 500, 2, 7) * 0.5 + 0.5) * 8
	local m = fbm(x, z, 1 / 260, 2, 8)
	if m > 0.32 then
		h = math.max(h, 30 + 46 * smoothstep(0.32, 0.4, m)) -- flat-topped mesa with steep sides
	end
	return h
end
local function hFrost(x: number, z: number): number
	local r = ridged(x, z, 1 / 520, 5, 9)
	return 60 + r * r * 330 + fbm(x, z, 1 / 120, 2, 10) * 6
end
local function hKingdom(x: number, z: number): number
	return 50 + (fbm(x, z, 1 / 450, 3, 11) * 0.5 + 0.5) * 34
end
local HEIGHT = { hAshen, hVale, hFields, hWoods, hDesert, hFrost, hKingdom }

-- Continent mask: 0 = sea, 1 = land. Squircle coastline with noise; the Ashen Coast ends in cliffs.
local LAND_R = 1830
local function landMask(x: number, z: number, ashenW: number): number
	local r = (math.abs(x) ^ 4 + math.abs(z) ^ 4) ^ 0.25
	local edge = LAND_R + noise(x / 500, z / 500, 77.7) * 260 + noise(x / 140, z / 140, 3.3) * 60
	local width = 230 - 200 * ashenW -- beaches elsewhere, cliffs on the Ashen Coast
	return smoothstep(edge, edge - width, r)
end

local function segDist(p: Vector2, a: Vector2, b: Vector2): (number, number)
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude, t
end
World.segDist = segDist

-- Natural ground height before settlement pads, roads and rivers. Also returns the dominant biome index.
function World.NaturalHeight(x: number, z: number): (number, number, { number })
	local ws, bi = World.Weights(x, z)
	local h = 0
	for i, w in ws do
		if w > 0.002 then
			h += HEIGHT[i](x, z) * w
		end
	end
	local land = landMask(x, z, ws[1])
	local seaFloor = World.SeaLevel - 18 + noise(x / 200, z / 200, 5.5) * 6
	h = seaFloor + (h - seaFloor) * land
	-- the oasis lake in the desert
	local od = (Vector2.new(x, z) - World.Oasis.centre).Magnitude
	if od < World.Oasis.radius + 50 then
		local k = smoothstep(World.Oasis.radius + 50, World.Oasis.radius * 0.6, od)
		h = h + ((World.SeaLevel + 6) - h) * k -- bowl bottom at SeaLevel+6, water added by the builder
	end
	return h, bi, ws
end

------------------------------------------------------------------------------------------------
-- Settlement pads (filled by Settlements.luau via World.SetPads) and roads
------------------------------------------------------------------------------------------------
export type Pad = { centre: Vector2, radius: number, blend: number, y: number }
World.Pads = {} :: { Pad }
World.Roads = {} :: { { Vector2 } }

function World.SetPads(pads: { Pad })
	World.Pads = pads
end
function World.SetRoads(roads: { { Vector2 } })
	World.Roads = roads
end

-- Final ground: natural + river channels + pads (pads win over rivers). Returns
-- height, biome index, waterTop (or nil), surface kind ("ground" | "road" | "river" | "pad").
-- roads/rivers: optional pre-filtered lists (the terrain builder passes only the ones near a chunk).
function World.Ground(x: number, z: number, roads: { { Vector2 } }?, rivers: { any }?): (number, number, number?, string)
	local h, bi = World.NaturalHeight(x, z)
	local p = Vector2.new(x, z)
	local waterTop: number? = nil
	local kind = "ground"

	if h < World.SeaLevel then
		waterTop = World.SeaLevel
	end
	local od = (p - World.Oasis.centre).Magnitude
	if od < World.Oasis.radius then
		waterTop = World.SeaLevel + 12
	end

	for _, river in (rivers or World.Rivers) do
		local pts = river.points
		local best = math.huge
		for i = 1, #pts - 1 do
			local d = segDist(p, pts[i], pts[i + 1])
			if d < best then
				best = d
			end
		end
		local half = river.width * 0.5 + 10
		if best < half then
			local k = 1 - (best / half) ^ 2
			local bank = h
			h = h - river.depth * k
			if best < river.width * 0.5 then
				waterTop = math.max(waterTop or -math.huge, bank - 2.5)
				kind = "river"
			end
		end
	end

	for _, road in (roads or World.Roads) do
		local best = math.huge
		for i = 1, #road - 1 do
			local d = segDist(p, road[i], road[i + 1])
			if d < best then
				best = d
			end
		end
		if best < World.RoadWidth * 0.5 and kind ~= "river" then
			kind = "road"
		end
	end

	for _, pad in World.Pads do
		local d = (p - pad.centre).Magnitude
		if d < pad.radius + pad.blend then
			local k = smoothstep(pad.radius + pad.blend, pad.radius, d)
			h = h + (pad.y - h) * k
			if k > 0.6 then
				kind = if d < pad.radius * 0.35 then "pad" else (if kind == "road" then "road" else "ground")
				if waterTop and waterTop < h + 1 then
					waterTop = nil
				end
			end
		end
	end
	if waterTop and waterTop <= h then
		waterTop = nil
	end
	return h, bi, waterTop, kind
end

-- Which biome is the player standing in (for zone lighting and region names).
function World.BiomeAt(x: number, z: number): Biome
	local _, bi = World.Weights(x, z)
	return World.Biomes[bi]
end

return World
