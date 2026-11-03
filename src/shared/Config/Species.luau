--!strict
-- Game1: species definitions (display-safe; the server reads its own copy).
-- Strength / weakness / spell school per species. See vault: Games/Game1/Game Design.md

export type SpeciesDef = {
	name: string,
	blurb: string,
	strength: string,
	weakness: string,
	spell: string, -- key in Spells.Defs
	bodyColor: Color3,
	tributeMult: number,
	upkeepMult: number,
	raidLootMult: number,
	walkSpeed: number,
}

local Defs: { [string]: SpeciesDef } = {
	Undead = {
		name = "Undead Legion",
		blurb = "Death is only the beginning.",
		strength = "Fallen foes rise to fight for you",
		weakness = "Subjugated lands pay 20% less tribute",
		spell = "GraveBurst",
		bodyColor = Color3.fromRGB(205, 200, 180),
		tributeMult = 0.8,
		upkeepMult = 1,
		raidLootMult = 1,
		walkSpeed = 16,
	},
	Demonkin = {
		name = "Demonkin",
		blurb = "Every pact is made to be broken.",
		strength = "+25% loot when you betray an ally",
		weakness = "Kingdoms trust you less",
		spell = "Hellfire",
		bodyColor = Color3.fromRGB(150, 35, 45),
		tributeMult = 1,
		upkeepMult = 1,
		raidLootMult = 1,
		walkSpeed = 16,
	},
	Beastkin = {
		name = "Beastkin Horde",
		blurb = "Strike fast, take everything.",
		strength = "+30% speed and +15% raid loot",
		weakness = "Higher upkeep on subjugated lands",
		spell = "StormHowl",
		bodyColor = Color3.fromRGB(150, 100, 60),
		tributeMult = 1,
		upkeepMult = 1.25,
		raidLootMult = 1.15,
		walkSpeed = 20.8,
	},
}

return {
	Defs = Defs,
	Order = { "Undead", "Demonkin", "Beastkin" },
}
