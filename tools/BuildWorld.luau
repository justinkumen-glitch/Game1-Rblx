--!strict
-- Game1: GREYBOX world builder. Run once in Studio Edit mode (command bar or MCP).
-- Rebuilds Workspace.Game1World from Config.Settlements. Placeholder blocks only:
-- Blender models replace these in Stage 3.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Settlements = require(ReplicatedStorage.Game1.Config.Settlements)

local old = workspace:FindFirstChild("Game1World")
if old then
	old:Destroy()
end

local world = Instance.new("Folder")
world.Name = "Game1World"

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function wedge(props: { [string]: any }, parent: Instance): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	for k, v in props do
		(w :: any)[k] = v
	end
	w.Parent = parent
	return w
end

-- Citadel (your home) -------------------------------------------------------
local citadel = Instance.new("Model")
citadel.Name = "Citadel"
local stone = Color3.fromRGB(45, 40, 48)
part({ Name = "Floor", Size = Vector3.new(70, 2, 70), Position = Vector3.new(0, 1, 0), Color = stone, Material = Enum.Material.Slate }, citadel)
for _, corner in { Vector3.new(-30, 0, -30), Vector3.new(30, 0, -30), Vector3.new(-30, 0, 30), Vector3.new(30, 0, 30) } do
	part({ Name = "Tower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(26, 10, 10), CFrame = CFrame.new(corner + Vector3.new(0, 14, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = stone, Material = Enum.Material.Slate }, citadel)
	part({ Name = "TowerCap", Size = Vector3.new(11, 2, 11), Position = corner + Vector3.new(0, 28, 0), Color = Color3.fromRGB(120, 20, 30), Material = Enum.Material.SmoothPlastic }, citadel)
end
part({ Name = "Keep", Size = Vector3.new(24, 30, 18), Position = Vector3.new(0, 17, -18), Color = Color3.fromRGB(35, 30, 38), Material = Enum.Material.Slate }, citadel)
part({ Name = "KeepGlow", Size = Vector3.new(4, 8, 0.5), Position = Vector3.new(0, 22, -8.8), Color = Color3.fromRGB(150, 60, 255), Material = Enum.Material.Neon }, citadel)
citadel.Parent = world

-- Settlements ---------------------------------------------------------------
local settlementsFolder = Instance.new("Folder")
settlementsFolder.Name = "Settlements"
settlementsFolder.Parent = world

local hutsPerTier = { Hamlet = 3, Village = 5, Town = 8, City = 12, Capital = 16 }
local radiusPerTier = { Hamlet = 16, Village = 22, Town = 30, City = 40, Capital = 52 }
local wallColor = Color3.fromRGB(150, 115, 80)
local roofColor = Color3.fromRGB(120, 60, 40)

for id, def in Settlements.List do
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("SettlementId", id)
	model:SetAttribute("Tier", def.tier)
	local center = def.position
	local radius = radiusPerTier[def.tier]

	part({ Name = "Ground", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, radius * 2 + 12, radius * 2 + 12), CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(110, 120, 70), Material = Enum.Material.Grass }, model)

	local huts = hutsPerTier[def.tier]
	for i = 1, huts do
		local angle = (i / huts) * math.pi * 2
		local spot = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local facing = CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z))
		local size = if def.tier == "Hamlet" or def.tier == "Village" then Vector3.new(8, 6, 8) else Vector3.new(10, 9, 10)
		part({ Name = "HutWall", Size = size, CFrame = facing * CFrame.new(0, size.Y / 2 + 1, 0), Color = wallColor, Material = Enum.Material.WoodPlanks }, model)
		wedge({ Name = "HutRoofA", Size = Vector3.new(size.X + 1, 3, size.Z / 2 + 0.5), CFrame = facing * CFrame.new(0, size.Y + 2.5, size.Z / 4), Color = roofColor }, model)
		wedge({ Name = "HutRoofB", Size = Vector3.new(size.X + 1, 3, size.Z / 2 + 0.5), CFrame = facing * CFrame.new(0, size.Y + 2.5, -size.Z / 4) * CFrame.Angles(0, math.rad(180), 0), Color = roofColor }, model)
	end

	-- Banner: the raid starts here
	local pole = part({ Name = "BannerPole", Size = Vector3.new(0.6, 14, 0.6), Position = center + Vector3.new(0, 8, 0), Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.Wood }, model)
	part({ Name = "BannerFlag", Size = Vector3.new(0.2, 3.5, 5), Position = center + Vector3.new(0, 13, 2.6), Color = Color3.fromRGB(220, 200, 150), Material = Enum.Material.Fabric }, model)
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
	sign.Size = UDim2.fromOffset(220, 50)
	sign.StudsOffset = Vector3.new(0, 10, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 400
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(245, 230, 200)
	text.TextStrokeTransparency = 0.4
	text.Text = `{def.name} · {def.tier}`
	text.Parent = sign
	sign.Parent = pole

	-- Fog over regions you haven't scouted (placeholder fog of war)
	if not Settlements.Regions[def.region].unlocked then
		part({ Name = "Fog", Shape = Enum.PartType.Ball, Size = Vector3.one * (radius * 2 + 40), Position = center, Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.SmoothPlastic, Transparency = 0.35, CanCollide = false, CanQuery = false, CastShadow = false }, model)
	end

	model.Parent = settlementsFolder
end

-- Spawn inside the citadel, facing Ashford
local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
if spawnLocation then
	spawnLocation.CFrame = CFrame.lookAt(Vector3.new(0, 2.6, 10), Vector3.new(80, 2.6, 20))
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Neutral = true
end
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate.Color = Color3.fromRGB(95, 105, 65)
	baseplate.Material = Enum.Material.Grass
	local texture = baseplate:FindFirstChildOfClass("Texture")
	if texture then
		texture:Destroy()
	end
end
Lighting.ClockTime = 16.5

world.Parent = workspace
return "Game1World built"
