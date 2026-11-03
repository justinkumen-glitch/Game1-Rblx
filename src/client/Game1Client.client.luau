--!strict
-- Game1 client: PLACEHOLDER greybox UI so the loop can be playtested.
-- It will be replaced by the Claude Design screens (Stage 2) once approved.
-- The client only displays state and sends requests; the server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))
local ConfigFolder = ReplicatedStorage:WaitForChild("Game1"):WaitForChild("Config")
local Species = require(ConfigFolder:WaitForChild("Species"))
local Spells = require(ConfigFolder:WaitForChild("Spells"))
local Settlements = require(ConfigFolder:WaitForChild("Settlements"))

local C = {
	panel = Color3.fromRGB(30, 24, 20),
	panelLight = Color3.fromRGB(52, 42, 34),
	text = Color3.fromRGB(240, 228, 205),
	muted = Color3.fromRGB(180, 165, 140),
	gold = Color3.fromRGB(240, 190, 70),
	mana = Color3.fromRGB(120, 170, 255),
	accent = Color3.fromRGB(190, 55, 45),
	good = Color3.fromRGB(110, 190, 110),
}

---------------------------------------------------------------------------
-- Tiny UI helpers
---------------------------------------------------------------------------

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return new("TextLabel", defaults)
end

local function button(text: string, color: Color3, props: { [string]: any }): TextButton
	local defaults = {
		Text = text,
		BackgroundColor3 = color,
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	local b = new("TextButton", defaults, { corner(10), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })
	return b
end

local gui = new("ScreenGui", { Name = "Game1HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

---------------------------------------------------------------------------
-- HUD: currencies, World Control bar, title
---------------------------------------------------------------------------

local currencyPanel = new("Frame", { BackgroundColor3 = C.panel, BackgroundTransparency = 0.15, Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 210, 0, 92), Parent = gui }, { corner(12) })
local goldLabel = label({ Text = "Gold 0", TextColor3 = C.gold, Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Parent = currencyPanel })
local manaLabel = label({ Text = "Mana 0", TextColor3 = C.mana, Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Parent = currencyPanel })
local tributeLabel = label({ Text = "+0 gold/min", TextColor3 = C.muted, Font = Enum.Font.Gotham, Position = UDim2.new(0, 12, 0, 62), Size = UDim2.new(1, -24, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = currencyPanel })

local controlPanel = new("Frame", { BackgroundColor3 = C.panel, BackgroundTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.new(0.42, 0, 0, 64), Parent = gui }, { corner(12), new("UISizeConstraint", { MaxSize = Vector2.new(520, 64), MinSize = Vector2.new(260, 64) }) })
local titleLabel = label({ Text = "Nameless Warlord", Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(1, -24, 0, 24), Parent = controlPanel })
local barBack = new("Frame", { BackgroundColor3 = C.panelLight, Position = UDim2.new(0, 12, 0, 32), Size = UDim2.new(1, -24, 0, 22), Parent = controlPanel }, { corner(8) })
local barFill = new("Frame", { BackgroundColor3 = C.accent, Size = UDim2.new(0, 0, 1, 0), Parent = barBack }, { corner(8) })
local barText = label({ Text = "World Control 0%", Size = UDim2.new(1, 0, 1, 0), ZIndex = 2, Parent = barBack })

local function refreshHud()
	goldLabel.Text = `Gold {player:GetAttribute("Gold") or 0}`
	manaLabel.Text = `Mana {player:GetAttribute("Mana") or 0}`
	tributeLabel.Text = `+{player:GetAttribute("TributePerMin") or 0} gold/min`
	local control = (player:GetAttribute("WorldControl") or 0) :: number
	titleLabel.Text = (player:GetAttribute("Title") or "Nameless Warlord") :: string
	barText.Text = `World Control {control}%`
	TweenService:Create(barFill, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = UDim2.new(math.clamp(control / 100, 0, 1), 0, 1, 0) }):Play()
end
for _, attr in { "Gold", "Mana", "TributePerMin", "WorldControl", "Title" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshHud)
end
refreshHud()

---------------------------------------------------------------------------
-- Toasts
---------------------------------------------------------------------------

local toastLabel = label({ Text = "", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.new(0.6, 0, 0, 40), BackgroundColor3 = C.panel, BackgroundTransparency = 1, TextTransparency = 1, Parent = gui })
corner(10).Parent = toastLabel
local toastToken = 0
local function toast(text: string)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.2
	task.delay(4, function()
		if token == toastToken then
			TweenService:Create(toastLabel, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end
Net.On("Toast", toast)

---------------------------------------------------------------------------
-- Species select (first join)
---------------------------------------------------------------------------

local speciesOverlay = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 10, Parent = gui })
label({ Text = "Choose your species", Position = UDim2.new(0.1, 0, 0.06, 0), Size = UDim2.new(0.8, 0, 0.08, 0), ZIndex = 11, Parent = speciesOverlay })
local cardRow = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.9, 0.7), ZIndex = 11, Parent = speciesOverlay }, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.02, 0) }),
})

local choosing = false
for index, key in Species.Order do
	local def = Species.Defs[key]
	local card = new("Frame", { BackgroundColor3 = C.panel, Size = UDim2.fromScale(0.3, 1), LayoutOrder = index, ZIndex = 11, Parent = cardRow }, { corner(14), new("UIStroke", { Color = def.bodyColor, Thickness = 3 }) })
	new("Frame", { BackgroundColor3 = def.bodyColor, Position = UDim2.fromScale(0.3, 0.05), Size = UDim2.fromScale(0.4, 0.22), ZIndex = 12, Parent = card }, { corner(60), new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	label({ Text = def.name, Position = UDim2.fromScale(0.05, 0.3), Size = UDim2.fromScale(0.9, 0.1), ZIndex = 12, Parent = card })
	label({ Text = def.blurb, Font = Enum.Font.GothamMedium, TextColor3 = C.muted, Position = UDim2.fromScale(0.05, 0.41), Size = UDim2.fromScale(0.9, 0.08), ZIndex = 12, Parent = card })
	label({ Text = "+ " .. def.strength, Font = Enum.Font.Gotham, TextColor3 = C.good, Position = UDim2.fromScale(0.05, 0.52), Size = UDim2.fromScale(0.9, 0.1), ZIndex = 12, Parent = card })
	label({ Text = "- " .. def.weakness, Font = Enum.Font.Gotham, TextColor3 = C.accent, Position = UDim2.fromScale(0.05, 0.63), Size = UDim2.fromScale(0.9, 0.1), ZIndex = 12, Parent = card })
	label({ Text = "Spell: " .. Spells.Defs[def.spell].name, Font = Enum.Font.Gotham, TextColor3 = C.mana, Position = UDim2.fromScale(0.05, 0.74), Size = UDim2.fromScale(0.9, 0.07), ZIndex = 12, Parent = card })
	local choose = button("Choose", C.accent, { Position = UDim2.fromScale(0.15, 0.84), Size = UDim2.fromScale(0.7, 0.11), ZIndex = 12, Parent = card })
	choose.Activated:Connect(function()
		if choosing then
			return
		end
		choosing = true
		local result = Net.Request("ChooseSpecies", key)
		choosing = false
		if result.ok then
			speciesOverlay.Visible = false
		else
			toast(`Could not choose species ({result.code}). Try again.`)
		end
	end)
end

local function refreshSpeciesOverlay()
	local ready = player:GetAttribute("DataReady") == true
	local species = player:GetAttribute("Species")
	speciesOverlay.Visible = ready and (species == nil or species == "")
end
player:GetAttributeChangedSignal("DataReady"):Connect(refreshSpeciesOverlay)
player:GetAttributeChangedSignal("Species"):Connect(refreshSpeciesOverlay)
refreshSpeciesOverlay()

---------------------------------------------------------------------------
-- Raid HUD: strike (F / button) and spell (Q / button)
---------------------------------------------------------------------------

local raidPanel = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.new(0, 260, 0, 170), Visible = false, Parent = gui })
local raidStatus = label({ Text = "", Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.panel, BackgroundTransparency = 0.2, Parent = raidPanel })
corner(8).Parent = raidStatus
local strikeButton = button("Strike [F]", C.panelLight, { Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(0.48, 0, 0, 120), Parent = raidPanel })
local spellButton = button("Spell [Q]", C.accent, { Position = UDim2.new(0.52, 0, 0, 40), Size = UDim2.new(0.48, 0, 0, 120), Parent = raidPanel })
local spellCooldownCover = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), ZIndex = 3, Parent = spellButton }, { corner(10) })

local inRaid = false
local spellReadyAt = 0

local function spellTarget(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return root.Position + root.CFrame.LookVector * 18
	end
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return if hit then hit.Position else root.Position + root.CFrame.LookVector * 18
end

local function strike()
	if inRaid then
		Net.Send("Attack")
	end
end

local function castSpell()
	if not inRaid or os.clock() < spellReadyAt then
		return
	end
	local target = spellTarget()
	if target then
		Net.Send("CastSpell", target)
	end
end

strikeButton.Activated:Connect(strike)
spellButton.Activated:Connect(castSpell)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
		strike()
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY then
		castSpell()
	end
end)

---------------------------------------------------------------------------
-- Victory card: Subjugate or Eliminate
---------------------------------------------------------------------------

local card = new("Frame", { BackgroundColor3 = C.panel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), Visible = false, ZIndex = 20, Parent = gui }, { corner(16), new("UISizeConstraint", { MaxSize = Vector2.new(620, 380), MinSize = Vector2.new(300, 260) }), new("UIStroke", { Color = C.gold, Thickness = 2 }) })
local cardTitle = label({ Text = "", Position = UDim2.fromScale(0.05, 0.05), Size = UDim2.fromScale(0.9, 0.14), ZIndex = 21, Parent = card })
local cardSub = label({ Text = "", Font = Enum.Font.GothamMedium, TextColor3 = C.gold, Position = UDim2.fromScale(0.05, 0.2), Size = UDim2.fromScale(0.9, 0.09), ZIndex = 21, Parent = card })
local subjugateButton = button("", C.good, { Position = UDim2.fromScale(0.05, 0.36), Size = UDim2.fromScale(0.43, 0.42), ZIndex = 21, Parent = card })
local eliminateButton = button("", C.accent, { Position = UDim2.fromScale(0.52, 0.36), Size = UDim2.fromScale(0.43, 0.42), ZIndex = 21, Parent = card })
local cardError = label({ Text = "", Font = Enum.Font.Gotham, TextColor3 = C.accent, Position = UDim2.fromScale(0.05, 0.83), Size = UDim2.fromScale(0.9, 0.1), ZIndex = 21, Parent = card })

local pendingId: string? = nil
local deciding = false

local function decide(choice: string)
	if not pendingId or deciding then
		return
	end
	deciding = true
	local result = Net.Request("Conquer", pendingId, choice)
	deciding = false
	if result.ok then
		card.Visible = false
		pendingId = nil
	elseif result.code == "NeedGold" then
		cardError.Text = `You need {result.data and result.data.need or "more"} gold to garrison it. Eliminate it, or raid elsewhere first.`
	else
		cardError.Text = `Something went wrong ({result.code}).`
	end
end
subjugateButton.Activated:Connect(function()
	decide("Subjugate")
end)
eliminateButton.Activated:Connect(function()
	decide("Eliminate")
end)

---------------------------------------------------------------------------
-- Raid events from the server
---------------------------------------------------------------------------

Net.On("RaidEvent", function(kind: string, payload: any)
	if kind == "Started" then
		inRaid = true
		raidPanel.Visible = true
		raidStatus.Text = `Raiding {payload.name}: {payload.total}/{payload.total} guards`
		toast(`Raid on {payload.name}! Strike with F, cast your spell with Q.`)
	elseif kind == "Progress" then
		raidStatus.Text = `Guards left: {payload.alive}/{payload.total}`
	elseif kind == "SpellCast" then
		spellReadyAt = os.clock() + payload.cooldown
		spellCooldownCover.Size = UDim2.fromScale(1, 1)
		TweenService:Create(spellCooldownCover, TweenInfo.new(payload.cooldown, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) }):Play()
	elseif kind == "Failed" then
		inRaid = false
		raidPanel.Visible = false
	elseif kind == "Victory" then
		inRaid = false
		raidPanel.Visible = false
		pendingId = payload.id
		cardTitle.Text = `{payload.name} has fallen!`
		cardSub.Text = `+{payload.loot} gold looted`
		local cost = if payload.garrison == 0 then "FREE" else `{payload.garrison} gold`
		subjugateButton.Text = `SUBJUGATE\nGarrison: {cost}\n+{payload.tributeNet} gold/min\nFull control`
		eliminateButton.Text = `ELIMINATE\n+{payload.eliminateGold} gold now\nNo upkeep\nHalf control`
		cardError.Text = ""
		card.Visible = true
	end
end)

---------------------------------------------------------------------------
-- Settlement prompts: hide for lands you already own, label unexplored ones
---------------------------------------------------------------------------

local world = workspace:WaitForChild("Game1World", 30)
local settlementsFolder = world and world:WaitForChild("Settlements", 10)

Net.On("RealmState", function(states: { [string]: string }, regions: { [string]: boolean })
	if not settlementsFolder then
		return
	end
	for id, def in Settlements.List do
		local settlement = settlementsFolder:FindFirstChild(id)
		local prompt = settlement and settlement:FindFirstChild("RaidPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			local owned = states[id]
			local unlocked = Settlements.Regions[def.region].unlocked or regions[def.region] == true
			prompt.Enabled = owned == nil
			prompt.ActionText = if unlocked then "Raid" else "Unexplored"
			if owned and settlement then
				local flag = settlement:FindFirstChild("BannerFlag", true)
				if flag and flag:IsA("BasePart") then
					flag.Color = if owned == "Subjugated" then C.accent else Color3.fromRGB(40, 40, 40)
				end
			end
		end
	end
end)
