--!strict
-- Game1: the player's realm. Species, settlement states, World Control %,
-- tribute (online ticks + capped offline), titles. Owns the "Game1" profile slice.
-- LihFolk notes: Economies and Currencies; Retention and Return Hooks; Character Select and Class Systems.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))
local PlayerData = require(ServerScriptService:WaitForChild("LihFolk"):WaitForChild("PlayerData"))
local Currency = require(ServerScriptService:WaitForChild("LihFolk"):WaitForChild("Currency"))

local ConfigFolder = ReplicatedStorage:WaitForChild("Game1"):WaitForChild("Config")
local Species = require(ConfigFolder:WaitForChild("Species"))
local Settlements = require(ConfigFolder:WaitForChild("Settlements"))
local EconomyConfig = require(ConfigFolder:WaitForChild("Economy"))

local Economy = require(script.Parent:WaitForChild("Economy"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))

local T = Net.T

local Realm = {}

local pushState: any = nil
local pushToast: any = nil
local tributeCarry: { [Player]: number } = {}
local tributeUnlogged: { [Player]: number } = {}

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function Realm.GetData(player: Player): { [string]: any }?
	local profile = PlayerData.Get(player)
	if not profile then
		return nil
	end
	return profile.Data.Game1
end

function Realm.MarkDirty(player: Player)
	local profile = PlayerData.Get(player)
	if profile then
		PlayerData.MarkDirty(profile)
	end
end

function Realm.IsRegionUnlocked(data: { [string]: any }, region: string): boolean
	local def = Settlements.Regions[region]
	return def ~= nil and (def.unlocked or data.Regions[region] == true)
end

function Realm.ControlPercent(data: { [string]: any }): number
	local held = 0
	for id, state in data.Settlements do
		local def = Settlements.List[id]
		if def then
			local weight = Settlements.Tiers[def.tier].weight
			if state == "Subjugated" then
				held += weight
			elseif state == "Eliminated" then
				held += weight * Settlements.EliminatedWeightShare
			end
		end
	end
	return held / Settlements.TotalWeight * 100
end

local function titleFor(percent: number): string
	local title = EconomyConfig.Titles[1].title
	for _, entry in EconomyConfig.Titles do
		if percent >= entry.at then
			title = entry.title
		end
	end
	return title
end

-- Net gold per minute from subjugated settlements, after species modifiers.
function Realm.NetTributePerMinute(data: { [string]: any }): number
	local species = Species.Defs[data.Species]
	local tributeMult = if species then species.tributeMult else 1
	local upkeepMult = if species then species.upkeepMult else 1
	local net = 0
	for id, state in data.Settlements do
		if state == "Subjugated" then
			local def = Settlements.List[id]
			if def then
				local tier = Settlements.Tiers[def.tier]
				net += tier.tribute * tributeMult - tier.upkeep * upkeepMult
			end
		end
	end
	return net
end

---------------------------------------------------------------------------
-- Changes and publishing
---------------------------------------------------------------------------

function Realm.Toast(player: Player, text: string)
	if pushToast then
		pushToast:Fire(player, text)
	end
end

function Realm.Publish(player: Player)
	local data = Realm.GetData(player)
	if not data then
		return
	end
	local percent = Realm.ControlPercent(data)
	player:SetAttribute("Species", data.Species)
	player:SetAttribute("WorldControl", math.floor(percent * 10 + 0.5) / 10)
	player:SetAttribute("Title", titleFor(percent))
	player:SetAttribute("TributePerMin", math.floor(Realm.NetTributePerMinute(data) * 10 + 0.5) / 10)
	player:SetAttribute("WoundedUntil", data.WoundedUntil or 0)
	pushState:Fire(player, table.clone(data.Settlements), table.clone(data.Regions))
end

local MILESTONES = { 5, 10, 25, 50, 75, 100 }

function Realm.SetSettlement(player: Player, id: string, state: string): boolean
	local data = Realm.GetData(player)
	if not data or not Settlements.List[id] then
		return false
	end
	local before = Realm.ControlPercent(data)
	data.Settlements[id] = state
	Realm.MarkDirty(player)
	local after = Realm.ControlPercent(data)
	for _, milestone in MILESTONES do
		if before < milestone and after >= milestone then
			Analytics.Custom(player, "ControlMilestone", milestone)
			Realm.Toast(player, `World Control {milestone}%! New title: {titleFor(after)}`)
		end
	end
	Realm.Publish(player)
	return true
end

local function applyLook(player: Player, character: Model)
	local data = Realm.GetData(player)
	if not data then
		return
	end
	local species = Species.Defs[data.Species]
	if not species then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = species.walkSpeed
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors") or character:WaitForChild("Body Colors", 5)
	if bodyColors and bodyColors:IsA("BodyColors") then
		local c = species.bodyColor
		bodyColors.HeadColor3 = c
		bodyColors.LeftArmColor3 = c
		bodyColors.RightArmColor3 = c
		bodyColors.LeftLegColor3 = c
		bodyColors.RightLegColor3 = c
		bodyColors.TorsoColor3 = c
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local function flushTributeLog(player: Player)
	local amount = tributeUnlogged[player] or 0
	if amount >= 1 then
		Analytics.Economy(player, true, "Gold", amount, Currency.Get(player, "Gold") or 0, "Tribute")
	end
	tributeUnlogged[player] = 0
end

local function onLoaded(player: Player, profile: PlayerData.Profile)
	local data = profile.Data.Game1
	local now = os.time()
	if data.LastTribute > 0 then
		local elapsed = math.clamp(now - data.LastTribute, 0, EconomyConfig.OfflineCapSeconds)
		local gold = math.floor(Realm.NetTributePerMinute(data) * elapsed / 60 * EconomyConfig.OfflineRate)
		if gold >= 1 then
			Economy.Gain(player, "Gold", gold, "OfflineTribute")
			task.delay(4, Realm.Toast, player, `While you were away, your lands paid {gold} gold.`)
		end
	end
	data.LastTribute = now
	Analytics.Onboarding(player, data, "Joined")
	PlayerData.MarkDirty(profile)
	Realm.Publish(player)
	if player.Character then
		task.spawn(applyLook, player, player.Character)
	end
end

local function tributeTick()
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.Get(player)
		if profile then
			local data = profile.Data.Game1
			local perTick = Realm.NetTributePerMinute(data) * EconomyConfig.TributeTickSeconds / 60
			if perTick > 0 then
				local carry = (tributeCarry[player] or 0) + perTick
				local whole = math.floor(carry)
				tributeCarry[player] = carry - whole
				-- Credited every tick, logged to analytics once a minute (rate limits).
				if whole >= 1 and Currency.Add(player, "Gold", whole, "Tribute") then
					tributeUnlogged[player] = (tributeUnlogged[player] or 0) + whole
				end
			end
			data.LastTribute = os.time()
			PlayerData.MarkDirty(profile)
		end
	end
end

function Realm.Init()
	PlayerData.RegisterSlice("Game1", function()
		return {
			Species = "",
			Settlements = {}, -- [settlementId] = "Subjugated" | "Eliminated"
			Regions = {}, -- [regionId] = true once scouted
			OnboardingStep = 0,
			LastTribute = 0,
			WoundedUntil = 0,
			Raids = 0,
		}
	end)

	pushState = Net.Push("RealmState")
	pushToast = Net.Push("Toast")

	Net.Handle("ChooseSpecies", {
		rate = { burst = 3, perSecond = 0.5 },
		args = { T.key(Species.Defs) },
		handler = function(player: Player, key: string)
			local profile = PlayerData.Get(player)
			if not profile then
				return Net.fail("NotReady")
			end
			local data = profile.Data.Game1
			if data.Species ~= "" then
				return Net.fail("AlreadyChosen")
			end
			data.Species = key
			Analytics.Onboarding(player, data, "SpeciesChosen")
			Analytics.Custom(player, "SpeciesChosen", 1, key)
			PlayerData.MarkDirty(profile)
			Realm.Publish(player)
			if player.Character then
				task.spawn(applyLook, player, player.Character)
			end
			Realm.Toast(player, "Your conquest begins. Ashford lies just past your citadel gate.")
			return Net.ok()
		end,
	})

	PlayerData.Loaded:Connect(onLoaded)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			applyLook(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		flushTributeLog(player)
		tributeCarry[player] = nil
		tributeUnlogged[player] = nil
	end)

	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(EconomyConfig.TributeTickSeconds)
			tributeTick()
			ticks += 1
			if ticks % math.max(1, math.floor(60 / EconomyConfig.TributeTickSeconds)) == 0 then
				for _, player in Players:GetPlayers() do
					flushTributeLog(player)
				end
			end
		end
	end)
end

return Realm
