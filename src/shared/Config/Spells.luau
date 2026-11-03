--!strict
-- Game1: spells and the basic strike. Tier I spells only in v0.1.

export type SpellDef = {
	name: string,
	school: string,
	tier: number,
	damage: number,
	radius: number,
	range: number,
	cooldown: number,
	color: Color3,
}

local Defs: { [string]: SpellDef } = {
	GraveBurst = { name = "Grave Burst", school = "Necrotic", tier = 1, damage = 40, radius = 12, range = 60, cooldown = 6, color = Color3.fromRGB(120, 255, 170) },
	Hellfire = { name = "Hellfire", school = "Hellfire", tier = 1, damage = 40, radius = 12, range = 60, cooldown = 6, color = Color3.fromRGB(255, 120, 40) },
	StormHowl = { name = "Storm Howl", school = "Primal", tier = 1, damage = 40, radius = 12, range = 60, cooldown = 6, color = Color3.fromRGB(120, 190, 255) },
}

return {
	Defs = Defs,
	Strike = { damage = 25, range = 9, cooldown = 0.45 },
}
