--!strict
-- Game1: Map v2 terrain builder. Run in Studio Edit mode (MCP or command bar):
--   require(<this module>).Run({ region = nil })          -- whole map, runs in the background
--   require(<this module>).Run({ region = {x0, z0, x1, z1} }) -- one area (studs), e.g. to fix a corner
-- Progress: workspace.Terrain:GetAttribute("GenProgress") (0..1), "GenStatus".
-- LihFolk: Terrain Tools and Terrain API (chunked writes, snapshot first), Terrain Deep Dive (water, materials),
-- Terrain Materials and Painting (slope rules, 3-5 materials per view), Noise Functions (blending).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = {}

local MAT = Enum.Material

-- Stylised colours (bright, readable, like the stylised-town reference). Global per material,
-- so each biome owns different materials instead of recolouring shared ones.
local COLOURS: { [Enum.Material]: Color3 } = {
	[MAT.Grass] = Color3.fromRGB(96, 178, 66),
	[MAT.LeafyGrass] = Color3.fromRGB(58, 132, 58),
	[MAT.Ground] = Color3.fromRGB(150, 116, 78),
	[MAT.Mud] = Color3.fromRGB(96, 74, 56),
	[MAT.Rock] = Color3.fromRGB(128, 124, 122),
	[MAT.Sand] = Color3.fromRGB(236, 206, 146),
	[MAT.Sandstone] = Color3.fromRGB(212, 146, 96),
	[MAT.Snow] = Color3.fromRGB(240, 246, 255),
	[MAT.Glacier] = Color3.fromRGB(160, 212, 240),
	[MAT.Ice] = Color3.fromRGB(176, 222, 250),
	[MAT.Basalt] = Color3.fromRGB(46, 40, 50),
	[MAT.Slate] = Color3.fromRGB(72, 64, 78),
	[MAT.CrackedLava] = Color3.fromRGB(255, 58, 44),
	[MAT.Cobblestone] = Color3.fromRGB(132, 136, 156),
	[MAT.Limestone] = Color3.fromRGB(222, 216, 200),
}

local UNDER: { [string]: Enum.Material } = {
	Ashen = MAT.Basalt, Vale = MAT.Rock, Fields = MAT.Ground, Woods = MAT.Rock,
	Desert = MAT.Sandstone, Frost = MAT.Rock, Kingdom = MAT.Limestone,
}

local function floor4(v: number): number
	return math.floor(v / 4) * 4
end
local function ceil4(v: number): number
	return math.ceil(v / 4) * 4
end

local function bboxHits(pts: { Vector2 }, x0: number, z0: number, x1: number, z1: number, pad: number): boolean
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, p in pts do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Y), math.max(maxZ, p.Y)
	end
	return not (maxX + pad < x0 or minX - pad > x1 or maxZ + pad < z0 or minZ - pad > z1)
end

function Builder.Setup()
	local terrain = workspace.Terrain
	for m, c in COLOURS do
		terrain:SetMaterialColor(m, c)
	end
	terrain.WaterColor = Color3.fromRGB(38, 150, 178)
	terrain.WaterTransparency = 0.45
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	terrain.Decoration = true
end

-- Build one chunk of CH x CH columns whose minimum corner is (cx, cz) in studs.
local CH = 32
local V = 4
function Builder.Chunk(World: any, cx: number, cz: number)
	local terrain = workspace.Terrain
	local x0, z0 = cx, cz
	local x1, z1 = cx + CH * V, cz + CH * V
	-- only the roads/rivers near this chunk
	local roads = {}
	for _, r in World.Roads do
		if bboxHits(r, x0, z0, x1, z1, World.RoadWidth + 8) then
			table.insert(roads, r)
		end
	end
	local rivers = {}
	for _, r in World.Rivers do
		if bboxHits(r.points, x0, z0, x1, z1, r.width + 16) then
			table.insert(rivers, r)
		end
	end

	-- column samples with a 1-column margin for slopes (index 0..CH+1)
	local H, B, W, K = {}, {}, {}, {}
	local minH, maxTop = math.huge, -math.huge
	for i = 0, CH + 1 do
		H[i], B[i], W[i], K[i] = {}, {}, {}, {}
		for j = 0, CH + 1 do
			local x = x0 + (i - 0.5) * V
			local z = z0 + (j - 0.5) * V
			local h, bi, wt, kind = World.Ground(x, z, roads, rivers)
			H[i][j], B[i][j], W[i][j], K[i][j] = h, bi, wt, kind
			if i >= 1 and i <= CH and j >= 1 and j <= CH then
				minH = math.min(minH, h)
				maxTop = math.max(maxTop, h, wt or -math.huge)
			end
		end
	end

	local yLo = math.max(World.Floor, floor4(minH) - 12)
	local yHi = ceil4(maxTop) + 4
	local ny = (yHi - yLo) // V

	-- solid rock below the band in one cheap fill
	if yLo > World.Floor then
		local size = Vector3.new(CH * V, yLo - World.Floor, CH * V)
		terrain:FillBlock(CFrame.new(x0 + size.X / 2, World.Floor + size.Y / 2, z0 + size.Z / 2), size, MAT.Rock)
	end

	local mats, occs = table.create(CH), table.create(CH)
	for i = 1, CH do
		local mi, oi = table.create(ny), table.create(ny)
		mats[i], occs[i] = mi, oi
		for k = 1, ny do
			mi[k], oi[k] = table.create(CH), table.create(CH)
		end
		for j = 1, CH do
			local h, bi, wt, kind = H[i][j], B[i][j], W[i][j], K[i][j]
			local biome = World.Biomes[bi]
			local x = x0 + (i - 0.5) * V
			local z = z0 + (j - 0.5) * V
			local slope = math.max(math.abs(H[i + 1][j] - H[i - 1][j]), math.abs(H[i][j + 1] - H[i][j - 1])) / (2 * V)

			local surf: Enum.Material
			if kind == "road" or kind == "pad" then
				surf = biome.road
			elseif kind == "river" then
				surf = if biome.id == "Frost" then MAT.Ice else MAT.Mud
			elseif h < World.SeaLevel - 1 then
				surf = if biome.id == "Ashen" then MAT.Slate elseif biome.id == "Frost" then MAT.Rock else MAT.Sand
			elseif h < World.SeaLevel + 3 and biome.id ~= "Ashen" then
				surf = if biome.id == "Frost" then MAT.Snow else MAT.Sand
			elseif slope > 0.85 then
				surf = biome.slope
			else
				local n = math.noise(x / 95, z / 95, bi * 1.31)
				local threshold = if biome.id == "Ashen" then 0.36 else 0.22
				-- dither patches near biome borders using a hash so edges read as scattered, not straight
				if biome.patch and n > threshold then
					surf = biome.patch
				else
					surf = biome.top
				end
				if biome.id == "Frost" and h > 240 then
					surf = MAT.Glacier
				end
			end
			local under = UNDER[biome.id] or MAT.Rock

			for k = 1, ny do
				local bottom = yLo + (k - 1) * V
				local occ = math.clamp((h - bottom) / V, 0, 1)
				local m: Enum.Material = MAT.Air
				if occ > 0.02 then
					m = if h - bottom > 12 then under else surf
				elseif wt and bottom < wt then
					m = MAT.Water
					occ = math.clamp((wt - bottom) / V, 0.05, 1)
				else
					occ = 0
				end
				mats[i][k][j] = m
				occs[i][k][j] = occ
			end
		end
	end

	local region = Region3.new(Vector3.new(x0, yLo, z0), Vector3.new(x1, yHi, z1)):ExpandToGrid(V)
	terrain:WriteVoxels(region, V, mats, occs)
end

-- Ocean beyond the generated square so the edge is never visible.
function Builder.OuterSea(World: any)
	local terrain = workspace.Terrain
	local half = World.Half
	local margin = 768
	local depth = World.SeaLevel - World.Floor
	local function slab(cx: number, cz: number, sx: number, sz: number)
		terrain:FillBlock(CFrame.new(cx, World.Floor + 6, cz), Vector3.new(sx, 12, sz), MAT.Sand)
		terrain:FillBlock(CFrame.new(cx, World.Floor + 12 + (depth - 12) / 2, cz), Vector3.new(sx, depth - 12, sz), MAT.Water)
	end
	local full = World.Size + margin * 2
	slab(0, -half - margin / 2, full, margin)
	slab(0, half + margin / 2, full, margin)
	slab(-half - margin / 2, 0, margin, World.Size)
	slab(half + margin / 2, 0, margin, World.Size)
end

function Builder.Run(opts: { region: { number }?, clear: boolean? }?)
	local o = opts or {}
	local cfg = ReplicatedStorage.Game1.Config
	require(cfg.Settlements) -- sets World pads and roads
	local World = require(cfg.World)
	local terrain = workspace.Terrain
	Builder.Setup()
	if o.clear then
		terrain:Clear()
	end
	local r = o.region or { -World.Half, -World.Half, World.Half, World.Half }
	local cx0 = math.floor((r[1] + World.Half) / (CH * V)) * CH * V - World.Half
	local cz0 = math.floor((r[2] + World.Half) / (CH * V)) * CH * V - World.Half
	local list = {}
	local cx = cx0
	while cx < r[3] do
		local cz = cz0
		while cz < r[4] do
			table.insert(list, Vector2.new(cx, cz))
			cz += CH * V
		end
		cx += CH * V
	end
	terrain:SetAttribute("GenProgress", 0)
	terrain:SetAttribute("GenStatus", "running")
	local t0 = os.clock()
	local ok, err = pcall(function()
		for n, c in list do
			Builder.Chunk(World, c.X, c.Y)
			terrain:SetAttribute("GenProgress", n / #list)
			task.wait()
		end
		if not o.region then
			Builder.OuterSea(World)
		end
	end)
	terrain:SetAttribute("GenStatus", if ok then string.format("done %d chunks in %.0fs", #list, os.clock() - t0) else "error: " .. tostring(err))
end

return Builder
