--!strict
-- Game1: Map v2 nature scatter. Run in Studio Edit mode AFTER BuildTerrain:
--   require(<this module>).Run()
-- Stylised part-built trees and props (chunky, flat colours, like the references). Templates live in
-- ServerStorage.Game1Nature so they can be swapped for Blender meshes later and the scatter re-run.
-- LihFolk: Foliage Props and Scatter (jittered spacing, long-tail scale, clumps with gaps, ground-only rays,
-- canopies non-colliding, pivot at trunk base), World Composition (clear paths and pads), Art Budgets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Nature = {}

local SMOOTH = Enum.Material.SmoothPlastic

local function part(model: Model, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, collide: boolean, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.Parent = model
	return p
end

local function wedgePyramid(model: Model, base: number, height: number, y: number, color: Color3)
	-- square pyramid from four CornerWedges (chunky pine tier)
	local h = base / 2
	for i = 0, 3 do
		local w = Instance.new("CornerWedgePart")
		w.Anchored = true
		w.Size = Vector3.new(h, height, h)
		w.Color = color
		w.Material = SMOOTH
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		local rot = CFrame.Angles(0, math.rad(90 * i), 0)
		w.CFrame = rot * CFrame.new(h / 2, y + height / 2, -h / 2)
		w.Parent = model
	end
end

local function trunk(model: Model, r: number, h: number, color: Color3, lean: number?): Part
	local cf = CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(lean or 0)) * CFrame.Angles(0, 0, math.rad(90))
	return part(model, Enum.PartType.Cylinder, Vector3.new(h, r * 2, r * 2), cf, color, true, Enum.Material.Wood)
end

local function newModel(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function finish(m: Model): Model
	local base = Instance.new("Part")
	base.Name = "Pivot"
	base.Anchored = true
	base.Transparency = 1
	base.Size = Vector3.new(1, 1, 1)
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	base.CFrame = CFrame.new(0, 0, 0)
	base.Parent = m
	m.PrimaryPart = base
	return m
end

-- Templates ---------------------------------------------------------------------------------
local T: { [string]: () -> Model } = {}

T.Broadleaf = function()
	local m = newModel("Broadleaf")
	trunk(m, 1.1, 10, Color3.fromRGB(110, 70, 45))
	local g = { Color3.fromRGB(78, 160, 62), Color3.fromRGB(96, 178, 70), Color3.fromRGB(66, 145, 58) }
	part(m, Enum.PartType.Ball, Vector3.one * 13, CFrame.new(0, 14, 0), g[1], false)
	part(m, Enum.PartType.Ball, Vector3.one * 9, CFrame.new(4, 11.5, 2), g[2], false)
	part(m, Enum.PartType.Ball, Vector3.one * 9, CFrame.new(-3.5, 12, -2.5), g[3], false)
	return finish(m)
end

T.Autumn = function()
	local m = newModel("Autumn")
	trunk(m, 1.0, 9, Color3.fromRGB(105, 66, 44))
	local c = { Color3.fromRGB(246, 168, 66), Color3.fromRGB(240, 140, 50), Color3.fromRGB(252, 190, 90) }
	part(m, Enum.PartType.Ball, Vector3.new(14, 9, 14), CFrame.new(0, 12, 0), c[1], false)
	part(m, Enum.PartType.Ball, Vector3.new(10, 7, 10), CFrame.new(3, 15.5, 1), c[3], false)
	part(m, Enum.PartType.Ball, Vector3.new(9, 6, 9), CFrame.new(-3, 15, -2), c[2], false)
	return finish(m)
end

T.Pine = function()
	local m = newModel("Pine")
	trunk(m, 0.9, 6, Color3.fromRGB(96, 62, 42))
	wedgePyramid(m, 12, 8, 4, Color3.fromRGB(46, 128, 72))
	wedgePyramid(m, 9, 7, 9.5, Color3.fromRGB(56, 146, 80))
	wedgePyramid(m, 6, 6, 14.5, Color3.fromRGB(66, 160, 88))
	return finish(m)
end

T.SnowPine = function()
	local m = newModel("SnowPine")
	trunk(m, 0.9, 6, Color3.fromRGB(90, 62, 46))
	wedgePyramid(m, 12, 8, 4, Color3.fromRGB(40, 100, 80))
	wedgePyramid(m, 9, 7, 9.5, Color3.fromRGB(226, 238, 248))
	wedgePyramid(m, 6, 6, 14.5, Color3.fromRGB(244, 250, 255))
	return finish(m)
end

T.DeadTree = function()
	local m = newModel("DeadTree")
	local c = Color3.fromRGB(42, 34, 40)
	trunk(m, 0.9, 12, c, 6)
	part(m, Enum.PartType.Block, Vector3.new(0.9, 7, 0.9), CFrame.new(1.8, 10, 0) * CFrame.Angles(0, 0, math.rad(-40)), c, false)
	part(m, Enum.PartType.Block, Vector3.new(0.8, 5, 0.8), CFrame.new(-1.4, 8, 0.6) * CFrame.Angles(math.rad(10), 0, math.rad(45)), c, false)
	part(m, Enum.PartType.Block, Vector3.new(0.6, 4, 0.6), CFrame.new(0.4, 13, -1) * CFrame.Angles(math.rad(-35), 0, 0), c, false)
	return finish(m)
end

T.Cactus = function()
	local m = newModel("Cactus")
	local g = Color3.fromRGB(70, 150, 80)
	part(m, Enum.PartType.Cylinder, Vector3.new(9, 2.4, 2.4), CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)), g, true)
	part(m, Enum.PartType.Ball, Vector3.one * 2.4, CFrame.new(0, 9, 0), g, false)
	part(m, Enum.PartType.Cylinder, Vector3.new(3, 1.6, 1.6), CFrame.new(1.7, 5, 0), g, false)
	part(m, Enum.PartType.Cylinder, Vector3.new(3, 1.6, 1.6), CFrame.new(3, 6.4, 0) * CFrame.Angles(0, 0, math.rad(90)), g, false)
	part(m, Enum.PartType.Cylinder, Vector3.new(2.4, 1.4, 1.4), CFrame.new(-1.6, 3.6, 0), g, false)
	part(m, Enum.PartType.Cylinder, Vector3.new(2.6, 1.4, 1.4), CFrame.new(-2.7, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), g, false)
	return finish(m)
end

T.Palm = function()
	local m = newModel("Palm")
	local bark = Color3.fromRGB(150, 110, 70)
	for i = 0, 4 do
		part(m, Enum.PartType.Cylinder, Vector3.new(3.2, 1.6 - i * 0.12, 1.6 - i * 0.12),
			CFrame.new(i * 0.5, 1.6 + i * 3, 0) * CFrame.Angles(0, 0, math.rad(90 - i * 4)), bark, i == 0, Enum.Material.Wood)
	end
	local leaf = Color3.fromRGB(70, 170, 70)
	for i = 0, 5 do
		local a = math.rad(i * 60)
		part(m, Enum.PartType.Block, Vector3.new(8, 0.5, 2.2), CFrame.new(2.5, 16, 0) * CFrame.Angles(0, a, 0) * CFrame.new(4, -0.8, 0) * CFrame.Angles(0, 0, math.rad(-18)), leaf, false)
	end
	return finish(m)
end

T.GiantMushroom = function()
	local m = newModel("GiantMushroom")
	part(m, Enum.PartType.Cylinder, Vector3.new(10, 2.6, 2.6), CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(236, 226, 210), true)
	local cap = part(m, Enum.PartType.Ball, Vector3.new(14, 7, 14), CFrame.new(0, 11, 0), Color3.fromRGB(214, 70, 210), false)
	cap.Material = Enum.Material.SmoothPlastic
	for i = 0, 4 do
		local a = math.rad(i * 72 + 20)
		part(m, Enum.PartType.Ball, Vector3.one * 1.6, CFrame.new(math.cos(a) * 4.2, 13.4, math.sin(a) * 4.2), Color3.fromRGB(255, 200, 255), false, Enum.Material.Neon)
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(240, 110, 255)
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = cap
	return finish(m)
end

T.Rock = function()
	local m = newModel("Rock")
	local c = Color3.fromRGB(140, 138, 146)
	part(m, Enum.PartType.Block, Vector3.new(7, 5, 6), CFrame.new(0, 1.8, 0) * CFrame.Angles(math.rad(8), math.rad(20), math.rad(-6)), c, true, Enum.Material.Slate)
	part(m, Enum.PartType.Block, Vector3.new(4, 3.5, 4), CFrame.new(3.2, 1.2, 2) * CFrame.Angles(math.rad(-10), math.rad(45), math.rad(12)), Color3.fromRGB(122, 120, 130), true, Enum.Material.Slate)
	return finish(m)
end

T.RedMushrooms = function()
	local m = newModel("RedMushrooms")
	for i, s in { { 0, 0, 1.0 }, { 2.2, 1, 0.7 }, { -1.6, 1.8, 0.55 } } do
		local k = s[3]
		part(m, Enum.PartType.Cylinder, Vector3.new(2.4 * k, 1.0 * k, 1.0 * k), CFrame.new(s[1], 1.2 * k, s[2]) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 232, 214), false)
		part(m, Enum.PartType.Ball, Vector3.new(3.4 * k, 2 * k, 3.4 * k), CFrame.new(s[1], 2.6 * k, s[2]), Color3.fromRGB(222, 48, 60), false)
		part(m, Enum.PartType.Ball, Vector3.one * 0.6 * k, CFrame.new(s[1] + 0.8 * k, 3.3 * k, s[2]), Color3.new(1, 1, 1), false)
	end
	return finish(m)
end

T.Flowers = function()
	local m = newModel("Flowers")
	local cols = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 140, 190), Color3.fromRGB(180, 140, 255), Color3.fromRGB(255, 255, 255) }
	for i = 1, 7 do
		local a, r = i * 2.4, 0.6 + (i % 3) * 1.1
		part(m, Enum.PartType.Ball, Vector3.one * 0.8, CFrame.new(math.cos(a) * r, 0.6, math.sin(a) * r), cols[(i % #cols) + 1], false)
	end
	return finish(m)
end

T.IceSpike = function()
	local m = newModel("IceSpike")
	local c = Color3.fromRGB(170, 220, 250)
	for i, s in { { 0, 0, 14, 0 }, { 3, 1, 9, 14 }, { -2.5, -1.5, 7, -16 } } do
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(2.6, s[3], 2.6)
		w.CFrame = CFrame.new(s[1], s[3] / 2 - 0.5, s[2]) * CFrame.Angles(0, 0, math.rad(s[4]))
		w.Color = c
		w.Material = Enum.Material.Glass
		w.Transparency = 0.15
		w.CanCollide = i == 1
		w.Parent = m
	end
	return finish(m)
end

T.Crystal = function()
	local m = newModel("Crystal")
	local c = Color3.fromRGB(230, 120, 255)
	part(m, Enum.PartType.Block, Vector3.new(1.8, 6, 1.8), CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.rad(45), math.rad(8)), c, false, Enum.Material.Neon)
	part(m, Enum.PartType.Block, Vector3.new(1.2, 3.6, 1.2), CFrame.new(1.4, 1.4, 0.4) * CFrame.Angles(0, math.rad(20), math.rad(-25)), c, false, Enum.Material.Neon)
	return finish(m)
end

T.LavaShard = function()
	local m = newModel("LavaShard")
	part(m, Enum.PartType.Block, Vector3.new(2.6, 9, 2.6), CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(12), math.rad(30), math.rad(-14)), Color3.fromRGB(28, 22, 30), true, Enum.Material.Basalt)
	part(m, Enum.PartType.Block, Vector3.new(0.6, 6, 0.6), CFrame.new(0.4, 3.6, -1.3) * CFrame.Angles(math.rad(12), math.rad(30), math.rad(-14)), Color3.fromRGB(255, 60, 40), false, Enum.Material.Neon)
	return finish(m)
end

-- Per-biome mix: { template, weight, scaleMin, scaleMax }, density per 24-stud cell, clump strength.
type Mix = { { any } }
local TREES: { [string]: { density: number, clump: number, mix: Mix } } = {
	Vale = { density = 0.20, clump = 0.8, mix = { { "Broadleaf", 70, 0.8, 1.8 }, { "Autumn", 18, 0.8, 1.6 }, { "Pine", 12, 0.8, 1.6 } } },
	Fields = { density = 0.05, clump = 0.6, mix = { { "Broadleaf", 55, 0.9, 1.9 }, { "Autumn", 45, 0.9, 1.8 } } },
	Woods = { density = 0.60, clump = 0.5, mix = { { "Pine", 45, 0.9, 2.4 }, { "Broadleaf", 30, 0.9, 2.0 }, { "GiantMushroom", 25, 0.7, 1.8 } } },
	Desert = { density = 0.035, clump = 0.4, mix = { { "Cactus", 80, 0.8, 1.5 }, { "Palm", 20, 0.9, 1.4 } } },
	Frost = { density = 0.18, clump = 0.9, mix = { { "SnowPine", 100, 0.8, 2.2 } } },
	Kingdom = { density = 0.16, clump = 0.7, mix = { { "Broadleaf", 50, 0.9, 1.9 }, { "Pine", 50, 0.9, 2.0 } } },
	Ashen = { density = 0.10, clump = 0.6, mix = { { "DeadTree", 75, 0.8, 1.6 }, { "LavaShard", 25, 0.7, 1.6 } } },
}
local SMALL: { [string]: { density: number, mix: Mix } } = {
	Vale = { density = 0.18, mix = { { "Flowers", 50, 1, 1.6 }, { "RedMushrooms", 20, 0.8, 1.4 }, { "Rock", 30, 0.5, 1.4 } } },
	Fields = { density = 0.14, mix = { { "Flowers", 70, 1, 1.8 }, { "Rock", 30, 0.5, 1.2 } } },
	Woods = { density = 0.22, mix = { { "RedMushrooms", 45, 0.8, 1.6 }, { "Crystal", 25, 0.7, 1.5 }, { "Rock", 30, 0.6, 1.4 } } },
	Desert = { density = 0.06, mix = { { "Rock", 100, 0.6, 1.8 } } },
	Frost = { density = 0.10, mix = { { "IceSpike", 60, 0.7, 1.8 }, { "Rock", 40, 0.6, 1.6 } } },
	Kingdom = { density = 0.12, mix = { { "Flowers", 50, 1, 1.6 }, { "Rock", 50, 0.5, 1.3 } } },
	Ashen = { density = 0.08, mix = { { "LavaShard", 50, 0.5, 1.2 }, { "Rock", 50, 0.6, 1.4 } } },
}

local function pick(mix: Mix, rng: Random): { any }
	local total = 0
	for _, e in mix do
		total += e[2]
	end
	local r = rng:NextNumber() * total
	for _, e in mix do
		r -= e[2]
		if r <= 0 then
			return e
		end
	end
	return mix[1]
end

local function longTail(rng: Random, a: number, b: number): number
	-- many small, few giants
	return a + (b - a) * rng:NextNumber() ^ 2.2
end

local BLOCKED = {
	[Enum.Material.Water] = true, [Enum.Material.Cobblestone] = true, [Enum.Material.Mud] = true,
	[Enum.Material.Ice] = true, [Enum.Material.CrackedLava] = true,
}

function Nature.Templates(): Folder
	local folder = ServerStorage:FindFirstChild("Game1Nature") :: Folder?
	if folder then
		folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Game1Nature"
	for name, fn in T do
		local m = fn()
		m.Name = name
		m.Parent = f
	end
	f.Parent = ServerStorage
	return f
end

function Nature.Run(opts: { seed: number? }?)
	local cfg = ReplicatedStorage.Game1.Config
	local Settlements = require(cfg.Settlements)
	local World = require(cfg.World)
	local templates = Nature.Templates()
	local seed = (opts and opts.seed) or 2026
	local rng = Random.new(seed)

	local root = workspace:FindFirstChild("Game1World") or Instance.new("Folder")
	root.Name = "Game1World"
	root.Parent = workspace
	local old = root:FindFirstChild("Nature")
	if old then
		old:Destroy()
	end
	local natureFolder = Instance.new("Folder")
	natureFolder.Name = "Nature"
	local perBiome: { [string]: Folder } = {}
	for _, b in World.Biomes do
		local f = Instance.new("Folder")
		f.Name = b.id
		f.Parent = natureFolder
		perBiome[b.id] = f
	end
	natureFolder.Parent = root

	-- keep-out circles: settlement pads and the citadel
	local keep = {}
	for _, def in Settlements.List do
		table.insert(keep, { c = Vector2.new(def.position.X, def.position.Z), r = Settlements.PadRadius[def.tier] + 18 })
	end
	table.insert(keep, { c = Vector2.new(Settlements.Citadel.X, Settlements.Citadel.Z), r = 120 })

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false

	local function nearRoad(p: Vector2): boolean
		for _, road in World.Roads do
			for i = 1, #road - 1 do
				if World.segDist(p, road[i], road[i + 1]) < World.RoadWidth * 0.5 + 5 then
					return true
				end
			end
		end
		return false
	end

	local function place(cell: number, small: boolean)
		local count = 0
		local n = World.Size // cell
		local batch = 0
		for gx = 0, n - 1 do
			for gz = 0, n - 1 do
				local x = -World.Half + (gx + rng:NextNumber(0.1, 0.9)) * cell
				local z = -World.Half + (gz + rng:NextNumber(0.1, 0.9)) * cell
				local biome = World.BiomeAt(x, z)
				local spec = if small then SMALL[biome.id] else TREES[biome.id]
				if not spec then
					continue
				end
				local density = spec.density
				if not small then
					local clumpN = math.noise(x / 170, z / 170, seed % 97 + 0.5)
					density *= math.clamp(1 + clumpN * 4 * (spec :: any).clump, 0, 2.2)
				end
				if rng:NextNumber() > density then
					continue
				end
				local p2 = Vector2.new(x, z)
				local blocked = false
				for _, k in keep do
					if (p2 - k.c).Magnitude < k.r then
						blocked = true
						break
					end
				end
				if blocked or nearRoad(p2) then
					continue
				end
				local hit = workspace:Raycast(Vector3.new(x, 700, z), Vector3.new(0, -800, 0), params)
				if not hit or BLOCKED[hit.Material] or hit.Normal.Y < 0.8 or hit.Position.Y < World.SeaLevel + 1.5 then
					continue
				end
				local e = pick(spec.mix, rng)
				local tpl = templates:FindFirstChild(e[1]) :: Model
				local m = tpl:Clone()
				local s = longTail(rng, e[3], e[4])
				m:ScaleTo(s)
				local tilt = if small then 0 else rng:NextNumber(-4, 4)
				m:PivotTo(CFrame.new(hit.Position - Vector3.new(0, 0.4 * s, 0)) * CFrame.Angles(math.rad(tilt), rng:NextNumber(0, math.pi * 2), math.rad(tilt * 0.5)))
				m.Parent = perBiome[biome.id]
				count += 1
				batch += 1
				if batch >= 150 then
					batch = 0
					task.wait()
				end
			end
		end
		return count
	end

	local t0 = os.clock()
	local trees = place(24, false)
	local small = place(30, true)
	workspace.Terrain:SetAttribute("NatureStatus", string.format("trees %d, props %d in %.0fs", trees, small, os.clock() - t0))
end

return Nature
