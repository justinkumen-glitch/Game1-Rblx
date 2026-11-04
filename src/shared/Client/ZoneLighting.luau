--!strict
-- Game1: per-biome lighting on the client (only this player's view changes) + "Entering <zone>" banner.
-- LihFolk: Zone and Biome Art Direction s5 (profiles are data, swapped client-side),
-- Zone Detection (hysteresis), Snow/Sandstorm/Ash recipes (air first, particles second).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage:WaitForChild("Game1"):WaitForChild("Config"):WaitForChild("World"))

type Profile = {
	ambient: Color3,
	outdoor: Color3,
	brightness: number,
	density: number,
	haze: number,
	glare: number,
	airColor: Color3,
	decay: Color3,
	tint: Color3,
	saturation: number,
	contrast: number,
}

local P: { [string]: Profile } = {
	Vale = { ambient = Color3.fromRGB(110, 110, 100), outdoor = Color3.fromRGB(150, 150, 135), brightness = 2.6, density = 0.28, haze = 1.2, glare = 0.4,
		airColor = Color3.fromRGB(220, 230, 240), decay = Color3.fromRGB(150, 175, 205), tint = Color3.fromRGB(255, 250, 238), saturation = 0.18, contrast = 0.06 },
	Fields = { ambient = Color3.fromRGB(120, 110, 95), outdoor = Color3.fromRGB(160, 150, 125), brightness = 2.8, density = 0.25, haze = 1.4, glare = 0.6,
		airColor = Color3.fromRGB(250, 230, 200), decay = Color3.fromRGB(200, 170, 130), tint = Color3.fromRGB(255, 244, 222), saturation = 0.2, contrast = 0.05 },
	Woods = { ambient = Color3.fromRGB(90, 80, 110), outdoor = Color3.fromRGB(110, 110, 140), brightness = 1.9, density = 0.42, haze = 2.4, glare = 0,
		airColor = Color3.fromRGB(200, 180, 230), decay = Color3.fromRGB(110, 90, 150), tint = Color3.fromRGB(240, 232, 255), saturation = 0.22, contrast = 0.08 },
	Desert = { ambient = Color3.fromRGB(140, 115, 90), outdoor = Color3.fromRGB(175, 150, 115), brightness = 3.1, density = 0.33, haze = 2.2, glare = 1.2,
		airColor = Color3.fromRGB(255, 220, 170), decay = Color3.fromRGB(230, 170, 110), tint = Color3.fromRGB(255, 238, 210), saturation = 0.12, contrast = 0.08 },
	Frost = { ambient = Color3.fromRGB(120, 135, 160), outdoor = Color3.fromRGB(150, 170, 200), brightness = 2.6, density = 0.4, haze = 2.0, glare = 0.3,
		airColor = Color3.fromRGB(225, 240, 255), decay = Color3.fromRGB(170, 200, 235), tint = Color3.fromRGB(235, 245, 255), saturation = 0.0, contrast = 0.06 },
	Kingdom = { ambient = Color3.fromRGB(115, 112, 110), outdoor = Color3.fromRGB(155, 150, 145), brightness = 2.7, density = 0.26, haze = 1.0, glare = 0.8,
		airColor = Color3.fromRGB(235, 225, 210), decay = Color3.fromRGB(190, 170, 150), tint = Color3.fromRGB(255, 246, 230), saturation = 0.15, contrast = 0.07 },
	Ashen = { ambient = Color3.fromRGB(95, 60, 65), outdoor = Color3.fromRGB(120, 80, 85), brightness = 1.8, density = 0.45, haze = 2.6, glare = 0.2,
		airColor = Color3.fromRGB(150, 90, 95), decay = Color3.fromRGB(110, 40, 50), tint = Color3.fromRGB(255, 225, 225), saturation = -0.05, contrast = 0.14 },
}

local ZoneLighting = {}

local function ensure(className: string, name: string): any
	local inst = Lighting:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

function ZoneLighting.Start(onEnter: ((string) -> ())?)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or ensure("Atmosphere", "Atmosphere")
	local grade = ensure("ColorCorrectionEffect", "ZoneGrade")
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local current: string? = nil
	local pending: string? = nil
	local player = Players.LocalPlayer

	local function apply(id: string)
		local p = P[id]
		if not p then
			return
		end
		TweenService:Create(Lighting, info, { Ambient = p.ambient, OutdoorAmbient = p.outdoor, Brightness = p.brightness }):Play()
		TweenService:Create(atmosphere, info, { Density = p.density, Haze = p.haze, Glare = p.glare, Color = p.airColor, Decay = p.decay }):Play()
		TweenService:Create(grade, info, { TintColor = p.tint, Saturation = p.saturation, Contrast = p.contrast }):Play()
	end

	task.spawn(function()
		while true do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local b = World.BiomeAt(root.Position.X, root.Position.Z)
				if b.id ~= current then
					-- hysteresis: the same new zone on two checks in a row
					if pending == b.id then
						current = b.id
						pending = nil
						apply(b.id)
						if onEnter then
							onEnter(b.name)
						end
					else
						pending = b.id
					end
				else
					pending = nil
				end
			end
			task.wait(0.5)
		end
	end)
end

ZoneLighting.Profiles = P
return ZoneLighting
