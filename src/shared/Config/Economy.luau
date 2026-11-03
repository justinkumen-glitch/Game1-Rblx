--!strict
-- Game1: economy rules and timers. See vault: Games/Game1/Economy.md

return {
	TributeTickSeconds = 10,
	OfflineRate = 0.5, -- offline tribute pays 50% of net
	OfflineCapSeconds = 8 * 60 * 60, -- 8 hours
	WoundedSeconds = 180, -- personal death penalty (pending Justin's final call)
	RaidLeashStuds = 200, -- leave this far from the settlement and the raid is abandoned
	StartRaidDistance = 40,
	FirstGarrisonFree = true, -- tutorial: first subjugation costs nothing
	Titles = {
		{ at = 0, title = "Nameless Warlord" },
		{ at = 5, title = "Warlord" },
		{ at = 10, title = "Conqueror" },
		{ at = 25, title = "Tyrant" },
		{ at = 50, title = "Dread Sovereign" },
		{ at = 75, title = "World-Eater" },
		{ at = 100, title = "Absolute Ruler" },
	},
}
