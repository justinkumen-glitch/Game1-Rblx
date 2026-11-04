--!strict
-- Game1: settlements, citadel and spawn for Map v2 (part-built, stylised). Run in Studio Edit mode
-- AFTER BuildTerrain. Rebuilds Workspace.Game1World.Settlements and .Citadel (keeps .Nature).
-- Blender meshes replace these parts once the kits are imported.
-- LihFolk: World Composition (hero landmark, clear plazas), Level of Detail and Model Streaming (Atomic models),
-- House Construction Method (modular), Zone and Biome Art Direction (tier reads from silhouette).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local Settlements = require(ReplicatedStorage.Game1.Config.Settlements)
local World = require(ReplicatedStorage.Game1.Config.World)

local root = workspace:FindFirstChild("Game1World") or Instance.new("Folder")
root.Name = "Game1World"
for _, name in { "Settlements", "Citadel", "Fog" } do
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local SMOOTH = Enum.Material.SmoothPlastic

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = SMOOTH
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function wedge(props: { [string]: any }, parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Material = SMOOTH
	for k, v in props do
		(w :: any)[k] = v
	end
	w.Parent = parent
	return w
end

local function cyl(parent: Instance, cf: CFrame, height: number, radius: number, color: Color3, mat: Enum.Material?): Part
	return part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = mat or SMOOTH }, parent)
end

-- Biome house palettes: walls, trim, roof
local PALETTE = {
	Ashen = { Color3.fromRGB(70, 60, 70), Color3.fromRGB(40, 34, 42), Color3.fromRGB(110, 30, 40) },
	Vale = { Color3.fromRGB(236, 214, 170), Color3.fromRGB(250, 248, 240), Color3.fromRGB(200, 90, 60) },
	Fields = { Color3.fromRGB(240, 222, 180), Color3.fromRGB(250, 248, 240), Color3.fromRGB(210, 120, 60) },
	Woods = { Color3.fromRGB(140, 100, 80), Color3.fromRGB(230, 220, 200), Color3.fromRGB(150, 60, 160) },
	Desert = { Color3.fromRGB(232, 196, 140), Color3.fromRGB(250, 240, 220), Color3.fromRGB(40, 170, 170) },
	Frost = { Color3.fromRGB(120, 140, 170), Color3.fromRGB(245, 250, 255), Color3.fromRGB(70, 110, 170) },
	Kingdom = { Color3.fromRGB(240, 236, 226), Color3.fromRGB(205, 175, 90), Color3.fromRGB(60, 100, 200) },
}

-- One chunky stylised house (ref: stylised town). cf = ground centre, facing -Z (door side).
local function house(parent: Instance, cf: CFrame, w: number, d: number, storeys: number, pal: { Color3 }, seed: number)
	local m = Instance.new("Model")
	m.Name = "House"
	local wallH = 8 * storeys
	part({ Name = "Base", Size = Vector3.new(w + 1, 1.2, d + 1), CFrame = cf * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(120, 116, 112), Material = Enum.Material.Slate }, m)
	for s = 0, storeys - 1 do
		local y = 0.9 + s * 8
		part({ Name = "Walls", Size = Vector3.new(w - s * 0.0, 7.2, d), CFrame = cf * CFrame.new(0, y + 3.6, 0), Color = pal[1] }, m)
		part({ Name = "Trim", Size = Vector3.new(w + 0.8, 0.9, d + 0.8), CFrame = cf * CFrame.new(0, y + 7.6, 0), Color = pal[2] }, m)
		for k = -1, 1, 2 do -- windows front
			part({ Name = "Window", Size = Vector3.new(2, 2.6, 0.3), CFrame = cf * CFrame.new(k * w * 0.27, y + 4.2, -d / 2 - 0.05), Color = Color3.fromRGB(255, 200, 110), Material = Enum.Material.Neon }, m)
			part({ Name = "Frame", Size = Vector3.new(2.6, 3.2, 0.25), CFrame = cf * CFrame.new(k * w * 0.27, y + 4.2, -d / 2 + 0.02), Color = pal[2] }, m)
		end
	end
	part({ Name = "Door", Size = Vector3.new(2.8, 5, 0.4), CFrame = cf * CFrame.new(0, 3.4, -d / 2 - 0.1), Color = Color3.fromRGB(110, 70, 45), Material = Enum.Material.Wood }, m)
	-- roof: two wedges, overhang
	local rh = math.max(4, w * 0.42)
	local top = 0.9 + wallH + 0.4
	wedge({ Name = "Roof", Size = Vector3.new(d + 2, rh, w / 2 + 1), CFrame = cf * CFrame.new(w / 4 + 0.5, top + rh / 2, 0) * CFrame.Angles(0, math.rad(-90), 0), Color = pal[3] }, m)
	wedge({ Name = "Roof", Size = Vector3.new(d + 2, rh, w / 2 + 1), CFrame = cf * CFrame.new(-w / 4 - 0.5, top + rh / 2, 0) * CFrame.Angles(0, math.rad(90), 0), Color = pal[3] }, m)
	if seed % 3 == 0 then
		part({ Name = "Chimney", Size = Vector3.new(1.8, 5, 1.8), CFrame = cf * CFrame.new(w * 0.25, top + rh * 0.6, d * 0.2), Color = Color3.fromRGB(130, 120, 115), Material = Enum.Material.Brick }, m)
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
end

local function fountain(parent: Instance, at: Vector3, tint: Color3)
	local m = Instance.new("Model")
	m.Name = "Fountain"
	cyl(m, CFrame.new(at), 1.6, 9, Color3.fromRGB(200, 205, 215), Enum.Material.Limestone)
	cyl(m, CFrame.new(at + Vector3.new(0, 1.0, 0)), 0.8, 7.8, Color3.fromRGB(60, 170, 220), Enum.Material.Glass).Transparency = 0.25
	cyl(m, CFrame.new(at), 6, 1.4, Color3.fromRGB(200, 205, 215), Enum.Material.Limestone)
	cyl(m, CFrame.new(at + Vector3.new(0, 6, 0)), 0.8, 3.6, Color3.fromRGB(200, 205, 215), Enum.Material.Limestone)
	local orb = part({ Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6, CFrame = CFrame.new(at + Vector3.new(0, 8.6, 0)), Color = tint, Material = Enum.Material.Neon }, m)
	local light = Instance.new("PointLight")
	light.Color = tint
	light.Range = 20
	light.Parent = orb
	m.Parent = parent
end

-- Magic rings over cities (cyan / violet / gold); spun on the client by the "SpinRing" tag later.
local function magicRings(parent: Instance, at: Vector3, radius: number, dark: boolean)
	local m = Instance.new("Model")
	m.Name = if dark then "DarkMagic" else "CityMagic"
	local cols = if dark then { Color3.fromRGB(255, 30, 50), Color3.fromRGB(90, 255, 130) } else { Color3.fromRGB(90, 225, 255), Color3.fromRGB(180, 120, 255) }
	for ring = 1, 2 do
		local r = if ring == 1 then radius else radius * 0.65
		local y = if ring == 1 then 0 else radius * 1.1
		local n = math.floor(r * 1.4)
		local holder = Instance.new("Model")
		holder.Name = "Ring" .. ring
		for i = 0, n - 1 do
			if dark and ring == 1 and (i % 9) < 2 then
				continue -- broken ring for the sinister version
			end
			local a = (i / n) * math.pi * 2
			local seg = 2 * math.pi * r / n * 1.05
			part({ Name = "Seg", Size = Vector3.new(0.8, 0.8, seg), CFrame = CFrame.new(at + Vector3.new(math.cos(a) * r, y + math.sin(a * 3) * (if dark then 1.5 else 0), math.sin(a) * r)) * CFrame.Angles(0, -a, 0),
				Color = cols[ring], Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }, holder)
			if i % 4 == 0 then
				part({ Name = "Rune", Size = Vector3.new(0.4, if dark then 3.5 else 2.6, 1.8), CFrame = CFrame.new(at + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)) * CFrame.Angles(0, -a, if dark then math.rad(25) else 0),
					Color = cols[ring], Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }, holder)
			end
		end
		holder:SetAttribute("SpinSpeed", if ring == 1 then (if dark then -0.12 else 0.15) else (if dark then 0.2 else -0.25))
		holder:SetAttribute("SpinCentre", at)
		holder.Parent = m
	end
	m.Parent = parent
end

local function tower(parent: Instance, at: Vector3, height: number, radius: number, stone: Color3, roof: Color3)
	local m = Instance.new("Model")
	m.Name = "Tower"
	cyl(m, CFrame.new(at), height, radius, stone, Enum.Material.Limestone)
	cyl(m, CFrame.new(at + Vector3.new(0, height, 0)), 1.5, radius + 1, stone, Enum.Material.Limestone)
	-- stepped "cone" roof
	for i = 0, 5 do
		local r = (radius + 0.8) * (1 - i / 6)
		cyl(m, CFrame.new(at + Vector3.new(0, height + 1.5 + i * 2.6, 0)), 2.6, math.max(r, 0.4), roof)
	end
	for k = 0, 3 do
		local a = k * math.pi / 2
		part({ Name = "Window", Size = Vector3.new(1.2, 3, 0.4), CFrame = CFrame.new(at + Vector3.new(math.cos(a) * radius, height * 0.7, math.sin(a) * radius)) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = Color3.fromRGB(255, 210, 120), Material = Enum.Material.Neon }, m)
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

local function walls(parent: Instance, centre: Vector3, radius: number, height: number, color: Color3, gateAngle: number)
	local m = Instance.new("Model")
	m.Name = "Walls"
	local n = math.floor(radius / 5)
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local diff = math.abs(((a - gateAngle + math.pi) % (math.pi * 2)) - math.pi)
		if diff < 0.16 then
			continue -- gate gap
		end
		local seg = 2 * math.pi * radius / n + 0.6
		local pos = centre + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local cf = CFrame.lookAt(pos, Vector3.new(centre.X, pos.Y, centre.Z))
		part({ Name = "Wall", Size = Vector3.new(seg, height, 3.5), CFrame = cf * CFrame.new(0, height / 2 - 3, 0), Color = color, Material = Enum.Material.Limestone }, m)
		if i % 2 == 0 then
			part({ Name = "Merlon", Size = Vector3.new(seg * 0.45, 2, 3.7), CFrame = cf * CFrame.new(0, height - 2, 0), Color = color, Material = Enum.Material.Limestone }, m)
		end
	end
	m.Parent = parent
end

-- Settlements -------------------------------------------------------------------------------
local settlementsFolder = Instance.new("Folder")
settlementsFolder.Name = "Settlements"

local layout = {
	Hamlet = { houses = 4, ring = 26, storeys = 1 },
	Village = { houses = 7, ring = 36, storeys = 1 },
	Town = { houses = 12, ring = 52, storeys = 2 },
	City = { houses = 20, ring = 78, storeys = 2 },
	Capital = { houses = 28, ring = 104, storeys = 3 },
}

for id, def in Settlements.List do
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("SettlementId", id)
	model:SetAttribute("Tier", def.tier)
	local c = def.position
	local biome = World.Biomes[World.BiomeIndex[def.region]] or World.BiomeAt(c.X, c.Z)
	local pal = PALETTE[biome.id] or PALETTE.Vale
	local L = layout[def.tier]
	local rng = Random.new(#id * 97 + math.floor(c.X))

	-- houses on two rings facing the plaza; streets stay clear between them
	local placed = 0
	local rings = if L.houses > 10 then 2 else 1
	for ring = 1, rings do
		local count = if rings == 2 then (if ring == 1 then math.floor(L.houses * 0.4) else L.houses - math.floor(L.houses * 0.4)) else L.houses
		local radius = if ring == 1 then L.ring * (if rings == 2 then 0.55 else 1) else L.ring
		for i = 1, count do
			local a = (i / count) * math.pi * 2 + ring * 0.4
			if math.abs(((a + math.pi / 2 + math.pi) % (math.pi * 2)) - math.pi) < 0.35 then
				continue -- keep the main street (toward -Z) open
			end
			local spot = c + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			local cf = CFrame.lookAt(spot, Vector3.new(c.X, spot.Y, c.Z))
			local w = rng:NextInteger(10, 14)
			local d = rng:NextInteger(9, 12)
			local storeys = math.clamp(L.storeys + rng:NextInteger(-1, 0), 1, 3)
			house(model, cf, w, d, storeys, pal, i + ring * 7)
			placed += 1
		end
	end

	if def.tier ~= "Hamlet" then
		fountain(model, c + Vector3.new(0, 0, 14), biome.accent)
	end
	if def.tier == "City" or def.tier == "Capital" then
		walls(model, c, L.ring + 22, if def.tier == "Capital" then 22 else 16, PALETTE.Kingdom[1], -math.pi / 2)
		local t = tower(model, c + Vector3.new(0, 0, L.ring * 0.25 + 12), if def.tier == "Capital" then 70 else 48, if def.tier == "Capital" then 9 else 7, Color3.fromRGB(240, 236, 226), pal[3])
		t.Name = "MageTower"
		magicRings(model, c + Vector3.new(0, if def.tier == "Capital" then 52 else 36, L.ring * 0.25 + 12), if def.tier == "Capital" then 28 else 20, false)
		for k = 0, 3 do -- wall towers
			local a = k * math.pi / 2 + math.pi / 4
			tower(model, c + Vector3.new(math.cos(a) * (L.ring + 22), 0, math.sin(a) * (L.ring + 22)), 30, 5, PALETTE.Kingdom[1], Color3.fromRGB(60, 100, 200))
		end
	end

	-- Banner: the raid starts here
	local pole = part({ Name = "BannerPole", Size = Vector3.new(0.6, 14, 0.6), Position = c + Vector3.new(0, 7, 0), Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.Wood }, model)
	part({ Name = "BannerFlag", Size = Vector3.new(0.2, 3.5, 5), Position = c + Vector3.new(0, 12, 2.6), Color = Color3.fromRGB(220, 200, 150), Material = Enum.Material.Fabric }, model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RaidPrompt"
	prompt.ActionText = "Raid"
	prompt.ObjectText = `{def.name} ({def.tier})`
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = pole

	local sign = Instance.new("BillboardGui")
	sign.Name = "NameSign"
	sign.Size = UDim2.fromOffset(240, 54)
	sign.StudsOffset = Vector3.new(0, 12, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 400
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.Fantasy
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 240, 210)
	text.TextStrokeTransparency = 0.3
	text.Text = `{def.name} · {def.tier}`
	text.Parent = sign
	sign.Parent = pole

	model:SetAttribute("Houses", placed)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = settlementsFolder
end
settlementsFolder.Parent = root

-- Citadel (your home) on the Ashen Coast cliff ------------------------------------------------
local citadel = Instance.new("Model")
citadel.Name = "Citadel"
local cpos = Settlements.Citadel
local dark = Color3.fromRGB(46, 40, 50)
local trimC = Color3.fromRGB(30, 24, 32)
part({ Name = "Floor", Size = Vector3.new(110, 3, 110), CFrame = CFrame.new(cpos + Vector3.new(0, -1.2, 0)), Color = Color3.fromRGB(60, 54, 64), Material = Enum.Material.Slate }, citadel)
walls(citadel, cpos, 62, 18, dark, math.atan2(-1, 1)) -- gate faces inland (towards the Vale)
for k, spec in { { 0, -22, 78, 12 }, { 26, 8, 56, 8 }, { -24, 12, 46, 7 }, { 10, 30, 34, 6 } } do
	local at = cpos + Vector3.new(spec[1], 0, spec[2])
	local h, r = spec[3], spec[4]
	cyl(citadel, CFrame.new(at), h, r, dark, Enum.Material.Slate)
	cyl(citadel, CFrame.new(at + Vector3.new(0, h, 0)), 1.6, r + 1.2, trimC, Enum.Material.Slate)
	for i = 0, 7 do -- crooked spire: offset stacked cylinders
		local rr = (r + 0.4) * (1 - i / 8)
		cyl(citadel, CFrame.new(at + Vector3.new(i * 0.35, h + 1.6 + i * 3.6, i * 0.15)), 3.6, math.max(rr, 0.35), Color3.fromRGB(44, 34, 58), Enum.Material.Slate)
	end
	for i = 0, 5 do
		local a = i * math.pi / 3 + k
		part({ Name = "Glow", Size = Vector3.new(1.1, 3.6, 0.4), CFrame = CFrame.new(at + Vector3.new(math.cos(a) * r, h * (0.3 + 0.12 * (i % 4)), math.sin(a) * r)) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon }, citadel)
	end
end
magicRings(citadel, cpos + Vector3.new(0, 30, -22), 26, true)
citadel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
citadel.Parent = root

-- Spawn inside the citadel, facing the gate and the Vale beyond
local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
if spawnLocation then
	local p = cpos + Vector3.new(0, 1.2, 20)
	spawnLocation.CFrame = CFrame.lookAt(p, p + Vector3.new(1, 0, -1))
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Neutral = true
end

-- Old flat baseplate is stored, not deleted (reversible)
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate.Parent = ServerStorage
end

-- Global light: warm afternoon, stylised sky; zone profiles tint per biome on the client
Lighting.ClockTime = 15.2
Lighting.GeographicLatitude = 35
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.4
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atm.Density = 0.28
atm.Haze = 1.2
atm.Color = Color3.fromRGB(220, 230, 240)
atm.Decay = Color3.fromRGB(150, 175, 205)
atm.Parent = Lighting
local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 28
bloom.Threshold = 1.6
bloom.Parent = Lighting
local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
rays.Intensity = 0.06
rays.Parent = Lighting

-- Big map settings: streaming on, sensible radii (Level of Detail and Model Streaming)
workspace.StreamingEnabled = true
workspace.StreamingMinRadius = 128
workspace.StreamingTargetRadius = 768
workspace.StreamOutBehavior = Enum.StreamOutBehavior.Opportunistic

root.Parent = workspace
return "Game1World v2 built"
