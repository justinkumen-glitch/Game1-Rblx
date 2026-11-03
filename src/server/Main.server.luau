--!strict
-- Game1: the only server Script. Order matters (LihFolk Systems Library):
--   1. PlayerData.Configure  2. services Init (slices + remotes)  3. PlayerData.Start
-- LihFolk modules live in ServerScriptService/LihFolk and ReplicatedStorage/LihFolk
-- (installed in the place only; their licence forbids posting them publicly).

local ServerScriptService = game:GetService("ServerScriptService")

local LihFolk = ServerScriptService:WaitForChild("LihFolk")
local PlayerData = require(LihFolk:WaitForChild("PlayerData"))
local Currency = require(LihFolk:WaitForChild("Currency"))

local Realm = require(script.Parent:WaitForChild("Realm"))
local Raid = require(script.Parent:WaitForChild("Raid"))

-- 1. Data layer. Never rename the store after launch.
PlayerData.Configure({
	storeName = "Game1Data_v1",
	schemaVersion = 1,
})

-- 2. Services. Gold and Mana will be sold in packs, so both are marked paid.
Currency.Init({
	currencies = {
		Gold = { start = 0, paid = true, leaderstat = true },
		Mana = { start = 0, paid = true },
	},
})
Realm.Init()
Raid.Init()

-- 3. Load players last.
PlayerData.Start()
