--!strict
-- Game1: raids. Start from a settlement's banner prompt, fight its defenders
-- (strike + species spell), then choose Subjugate or Eliminate.
-- Server-authoritative: the client only asks to strike, cast at a point, or conquer.
-- LihFolk notes: Onboarding by Genre (weak first enemy), Gore Policy (no blood),
-- Threat Modeling (server owns damage, ranges and cooldowns).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("LihFolk"):WaitForChild("PlayerData"))

local ConfigFolder = ReplicatedStorage:WaitForChild("Game1"):WaitForChild("Config")
local Species = require(ConfigFolder:WaitForChild("Species"))
local Settlements = require(ConfigFolder:WaitForChild("Settlements"))
local Spells = require(ConfigFolder:WaitForChild("Spells"))
local EconomyConfig = require(ConfigFolder:WaitForChild("Economy"))

local Economy = require(script.Parent:WaitForChild("Economy"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))
local Realm = require(script.Parent:WaitForChild("Realm"))

local T = Net.T

type Defender = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	lastHit: number,
}

type ActiveRaid = {
	player: Player,
	id: string,
	tier: Settlements.Tier,
	center: Vector3,
	defenders: { Defender },
	alive: number,
	folder: Folder,
	finished: boolean,
	connections: { RBXScriptConnection },
}

local Raid = {}

local raids: { [Player]: ActiveRaid } = {}
local pending: { [Player]: { id: string, loot: number } } = {}
local lastStrike: { [Player]: number } = {}
local lastSpell: { [Player]: number } = {}
local pushRaid: any = nil
local raidsFolder: Folder? = nil
local defenderTemplate: Model? = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function liveRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return root, humanoid
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function buildTemplate(): Model
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(205, 160, 120)
		desc.HeadColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.TorsoColor = Color3.fromRGB(95, 115, 70)
		desc.LeftLegColor = Color3.fromRGB(85, 65, 45)
		desc.RightLegColor = Color3.fromRGB(85, 65, 45)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		model.Name = "Defender"
		return model
	end
	warn(`[Raid] falling back to block defenders: {model}`)
	local fallback = Instance.new("Model")
	fallback.Name = "Defender"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 3, 1)
	root.Color = Color3.fromRGB(95, 115, 70)
	root.Parent = fallback
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = Color3.fromRGB(205, 160, 120)
	head.CFrame = root.CFrame * CFrame.new(0, 2.1, 0)
	head.Parent = fallback
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 1.5
	humanoid.Parent = fallback
	fallback.PrimaryPart = root
	return fallback
end

local function fadeAndRemove(model: Model)
	-- Kid-friendly defeat: no blood, the body fades away like a spirit.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			TweenService:Create(part, TweenInfo.new(1), { Transparency = 1 }):Play()
		elseif part:IsA("Decal") then
			TweenService:Create(part, TweenInfo.new(1), { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(model, 1.2)
end

local function burst(position: Vector3, radius: number, color: Color3)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CastShadow = false
	ball.Transparency = 0.2
	ball.Size = Vector3.one * 2
	ball.Position = position
	ball.Parent = raidsFolder or workspace
	TweenService:Create(ball, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, 0.6)
end

---------------------------------------------------------------------------
-- Raid lifecycle
---------------------------------------------------------------------------

local function endRaid(raid: ActiveRaid)
	if raid.finished then
		return
	end
	raid.finished = true
	for _, connection in raid.connections do
		connection:Disconnect()
	end
	if raids[raid.player] == raid then
		raids[raid.player] = nil
	end
	task.delay(1.5, function()
		raid.folder:Destroy()
	end)
end

local function failRaid(raid: ActiveRaid, reason: string)
	if raid.finished then
		return
	end
	local player = raid.player
	local def = Settlements.List[raid.id]
	if reason == "Fell" then
		local profile = PlayerData.Get(player)
		local firstRaid = profile ~= nil and profile.Data.Game1.Raids == 0
		Analytics.Custom(player, "PersonalDeath", 1, raid.id)
		if profile and not firstRaid then
			profile.Data.Game1.WoundedUntil = os.time() + EconomyConfig.WoundedSeconds
			PlayerData.MarkDirty(profile)
			Realm.Toast(player, `You fell at {def.name}. Wounded: rest {EconomyConfig.WoundedSeconds // 60} minutes before fighting again.`)
		else
			-- Tutorial grace: no wound before the first victory (LihFolk: first death explained, never unfair).
			Realm.Toast(player, `You fell at {def.name}! Try again: strike with F and blast them with your spell (Q).`)
		end
	else
		Realm.Toast(player, `You left {def.name}. The raid is over.`)
	end
	pushRaid:Fire(player, "Failed", { id = raid.id, reason = reason })
	endRaid(raid)
	Realm.Publish(player)
end

local function victory(raid: ActiveRaid)
	if raid.finished then
		return
	end
	local player = raid.player
	local data = Realm.GetData(player)
	if not data then
		endRaid(raid)
		return
	end
	local def = Settlements.List[raid.id]
	local tier = raid.tier
	local species = Species.Defs[data.Species]
	local loot = math.floor(tier.raidLoot * (if species then species.raidLootMult else 1))
	Economy.Gain(player, "Gold", loot, "Raid", raid.id)
	data.Raids += 1
	Realm.MarkDirty(player)

	local free = EconomyConfig.FirstGarrisonFree and next(data.Settlements) == nil
	local tributeMult = if species then species.tributeMult else 1
	local upkeepMult = if species then species.upkeepMult else 1
	pending[player] = { id = raid.id, loot = loot }
	pushRaid:Fire(player, "Victory", {
		id = raid.id,
		name = def.name,
		loot = loot,
		eliminateGold = math.floor(loot * Settlements.EliminateBonus),
		garrison = if free then 0 else tier.garrison,
		tributeNet = math.floor((tier.tribute * tributeMult - tier.upkeep * upkeepMult) * 10 + 0.5) / 10,
	})
	endRaid(raid)
end

local function onDefenderDied(raid: ActiveRaid, defender: Defender)
	raid.alive -= 1
	fadeAndRemove(defender.model)
	if not raid.finished then
		pushRaid:Fire(raid.player, "Progress", { alive = raid.alive, total = #raid.defenders })
		if raid.alive <= 0 then
			victory(raid)
		end
	end
end

function Raid.Start(player: Player, id: string)
	local def = Settlements.List[id]
	local data = Realm.GetData(player)
	if not def or not data then
		return
	end
	if data.Species == "" then
		Realm.Toast(player, "Choose your species first.")
		return
	end
	if not Realm.IsRegionUnlocked(data, def.region) then
		Realm.Toast(player, `{def.name} lies in unexplored land. Scouting arrives in the next update.`)
		return
	end
	if data.Settlements[id] then
		Realm.Toast(player, `{def.name} is already yours.`)
		return
	end
	if raids[player] then
		Realm.Toast(player, "You are already raiding.")
		return
	end
	if pending[player] then
		Realm.Toast(player, "Decide the fate of your last conquest first.")
		return
	end
	local woundedFor = (data.WoundedUntil or 0) - os.time()
	if woundedFor > 0 then
		Realm.Toast(player, `You are wounded. Rest {woundedFor} more seconds before fighting.`)
		return
	end
	local root, humanoid = liveRoot(player)
	if not root or not humanoid or (flat(root.Position) - flat(def.position)).Magnitude > EconomyConfig.StartRaidDistance + 20 then
		return
	end

	local tier = Settlements.Tiers[def.tier]
	local folder = Instance.new("Folder")
	folder.Name = `Raid_{player.UserId}`
	folder.Parent = raidsFolder

	local raid: ActiveRaid = {
		player = player,
		id = id,
		tier = tier,
		center = def.position,
		defenders = {},
		alive = 0,
		folder = folder,
		finished = false,
		connections = {},
	}
	raids[player] = raid

	local template = defenderTemplate :: Model
	for i = 1, tier.defenders do
		local model = template:Clone()
		local dHumanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		local dRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart
		dHumanoid.MaxHealth = tier.defenderHealth
		dHumanoid.Health = tier.defenderHealth
		dHumanoid.WalkSpeed = 12
		dHumanoid.BreakJointsOnDeath = false
		dHumanoid.DisplayName = `{def.name} Guard`
		dHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
		local angle = (i / tier.defenders) * math.pi * 2
		model:PivotTo(CFrame.new(def.position + Vector3.new(math.cos(angle) * 14, 4, math.sin(angle) * 14)))
		model.Parent = folder
		pcall(function()
			dRoot:SetNetworkOwner(nil) -- server owns enemy physics
		end)
		local defender: Defender = { model = model, humanoid = dHumanoid, root = dRoot, lastHit = 0 }
		table.insert(raid.defenders, defender)
		raid.alive += 1
		dHumanoid.Died:Connect(function()
			onDefenderDied(raid, defender)
		end)
	end

	table.insert(raid.connections, humanoid.Died:Connect(function()
		failRaid(raid, "Fell")
	end))

	Analytics.Onboarding(player, data, "TutorialRaidStarted")
	Realm.MarkDirty(player)
	pushRaid:Fire(player, "Started", { id = id, name = def.name, total = tier.defenders })
end

---------------------------------------------------------------------------
-- Combat requests
---------------------------------------------------------------------------

local function onAttack(player: Player)
	local raid = raids[player]
	if not raid or raid.finished then
		return
	end
	local now = os.clock()
	if now - (lastStrike[player] or 0) < Spells.Strike.cooldown then
		return
	end
	lastStrike[player] = now
	local root = liveRoot(player)
	if not root then
		return
	end
	local best: Defender? = nil
	local bestDistance = Spells.Strike.range + 2 -- small latency allowance
	for _, defender in raid.defenders do
		if defender.humanoid.Health > 0 and defender.root.Parent then
			local distance = (defender.root.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = defender, distance
			end
		end
	end
	if best then
		best.humanoid:TakeDamage(Spells.Strike.damage)
	end
end

local function onCast(player: Player, target: Vector3)
	local raid = raids[player]
	local data = Realm.GetData(player)
	if not raid or raid.finished or not data then
		return
	end
	local species = Species.Defs[data.Species]
	if not species then
		return
	end
	local spell = Spells.Defs[species.spell]
	local now = os.clock()
	if now - (lastSpell[player] or -math.huge) < spell.cooldown then
		return
	end
	local root = liveRoot(player)
	if not root then
		return
	end
	lastSpell[player] = now
	local offset = target - root.Position
	if offset.Magnitude > spell.range then
		target = root.Position + offset.Unit * spell.range -- clamp, never trust the client's reach
	end
	burst(target, spell.radius, spell.color)
	for _, defender in raid.defenders do
		if defender.humanoid.Health > 0 and defender.root.Parent then
			if (flat(defender.root.Position) - flat(target)).Magnitude <= spell.radius then
				defender.humanoid:TakeDamage(spell.damage)
			end
		end
	end
	pushRaid:Fire(player, "SpellCast", { cooldown = spell.cooldown })
end

local function onConquer(player: Player, id: string, choice: string)
	local pend = pending[player]
	if not pend or pend.id ~= id then
		return Net.fail("NoConquest")
	end
	local data = Realm.GetData(player)
	if not data then
		return Net.fail("NotReady")
	end
	local def = Settlements.List[id]
	local tier = Settlements.Tiers[def.tier]
	if choice == "Subjugate" then
		local free = EconomyConfig.FirstGarrisonFree and next(data.Settlements) == nil
		if not free and not Economy.Spend(player, "Gold", tier.garrison, "Garrison", id) then
			return Net.fail("NeedGold", { need = tier.garrison })
		end
		pending[player] = nil
		Realm.SetSettlement(player, id, "Subjugated")
		Realm.Toast(player, `{def.name} now kneels. Its tribute flows to you.`)
	else
		pending[player] = nil
		Economy.Gain(player, "Gold", math.floor(pend.loot * Settlements.EliminateBonus), "Eliminate", id)
		Realm.SetSettlement(player, id, "Eliminated")
		Realm.Toast(player, `{def.name} lies in ruins. Its spoils are yours.`)
	end
	Analytics.Onboarding(player, data, "FirstConquest")
	Analytics.Custom(player, "Conquest", 1, choice)
	Realm.MarkDirty(player)
	return Net.ok({ state = data.Settlements[id] })
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function Raid.Init()
	local existing = workspace:FindFirstChild("Game1Raids")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Game1Raids"
	folder.Parent = workspace
	raidsFolder = folder

	defenderTemplate = buildTemplate()
	pushRaid = Net.Push("RaidEvent")

	Net.Listen("Attack", {
		rate = { burst = 6, perSecond = 4 },
		args = {},
		handler = onAttack,
	})
	Net.Listen("CastSpell", {
		rate = { burst = 3, perSecond = 1 },
		args = { T.vector3(10000) },
		handler = onCast,
	})
	Net.Handle("Conquer", {
		rate = { burst = 3, perSecond = 1 },
		args = { T.key(Settlements.List), T.oneOf({ "Subjugate", "Eliminate" }) },
		handler = onConquer,
	})

	-- Banner prompts placed in the world at edit time (tools/BuildWorld.luau).
	local world = workspace:WaitForChild("Game1World", 10)
	local settlementsFolder = world and world:FindFirstChild("Settlements")
	for id in Settlements.List do
		local settlement = settlementsFolder and settlementsFolder:FindFirstChild(id)
		local prompt = settlement and settlement:FindFirstChild("RaidPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player: Player)
				Raid.Start(player, id)
			end)
		else
			warn(`[Raid] no RaidPrompt for settlement '{id}'`)
		end
	end

	-- One AI loop for every raid: defenders chase and hit the raider.
	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()
			for player, raid in raids do
				if not raid.finished then
					local root, humanoid = liveRoot(player)
					if root and humanoid then
						if (flat(root.Position) - flat(raid.center)).Magnitude > EconomyConfig.RaidLeashStuds then
							failRaid(raid, "Left")
						else
							for _, defender in raid.defenders do
								if defender.humanoid.Health > 0 and defender.root.Parent then
									defender.humanoid:MoveTo(root.Position)
									if (defender.root.Position - root.Position).Magnitude < 5 and now - defender.lastHit > 1.4 then
										defender.lastHit = now
										humanoid:TakeDamage(raid.tier.defenderDamage)
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local raid = raids[player]
		if raid then
			endRaid(raid)
		end
		pending[player] = nil
		lastStrike[player] = nil
		lastSpell[player] = nil
	end)
end

return Raid
