# Game1-Rblx

Roblox game code, built with Claude.

| Folder | Goes into Studio as | Holds |
| --- | --- | --- |
| `src/server` | ServerScriptService/Game1 | server scripts and modules |
| `src/client` | StarterPlayerScripts/Game1Client | client UI (placeholder until Claude Design screens) |
| `src/shared` | ReplicatedStorage/Game1 | config shared by server and client |
| `assets/models` | (imported by hand) | Blender exports + the scripts that made them |

`CLAUDE.md` holds the Master Prompt, so every Claude Code session follows the same rules.
Game notes, decisions and analytics: Obsidian vault `Roblox Builder/Games/`.

| `tools/BuildWorld.luau` | run once in Studio | rebuilds the greybox world |

**Not in this repo:** the LihFolk Systems modules (PlayerData, Currency, Net, RateLimit, Signal). They are installed in the Studio place under `ServerScriptService/LihFolk` and `ReplicatedStorage/LihFolk`; their licence allows shipping them in the game but not posting them publicly.
