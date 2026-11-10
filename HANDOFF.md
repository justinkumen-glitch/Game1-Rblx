# Handoff: where Game1 is (read this first in a new Claude Code session)

Last updated 2026-11-10 by the cloud session. Working branch: **`map-v2`** (not merged; nothing on it has run in Studio yet).

## Done and live in Studio (main)
- v0.1 loop: choose species → raid → subjugate/eliminate → tribute → World Control %. Server-authoritative, DataStore via LihFolk PlayerData.
- LihFolk modules (Net, PlayerData, Currency, RateLimit, Signal) exist **only in the Studio place**, never in this public repo.

## Written on `map-v2`, not yet run
| File | What it does |
|---|---|
| `src/shared/Config/World.luau` | 4,096-stud map rules: 7 biomes (centres, accent, materials), heights, coast, rivers, oasis, pads, roads. Deterministic. |
| `src/shared/Config/Settlements.luau` | 18 settlements by tier per biome (old ids kept for saves), citadel on the Ashen Coast, road links. Y comes from World. |
| `src/shared/Client/ZoneLighting.luau` | Per-biome lighting + "Entering <zone>" banner (required by Game1Client). |
| `src/client/Game1Client.client.luau` | + zone banner, re-applies raid prompts when settlements stream in, spins magic rings. |
| `tools/BuildTerrain.luau` | Chunked terrain writer (`Run({clear=true})`, progress on `Terrain` attrs `GenProgress` / `GenStatus`). |
| `tools/BuildWorld.luau` | Settlements (houses, fountains, walls, mage tower, magic rings), citadel with dark magic, spawn, lighting, streaming. Run after terrain. |
| `tools/BuildNature.luau` | Seeded clumped scatter of trees/props per biome; uses Blender meshes from `ServerStorage.Game1Meshes` if imported, else part templates. Run last. |
| `assets/models/blender/game1_nature1.py` | Nature Kit 1 (20 models). Output GLB is in the vault: `Games/Game1/Assets/Models/Nature1_v1/Nature1_All.glb`. |

## Next steps
1. Open Game1 (dev) in Studio. Sync `map-v2` into the place (Rojo / Script Sync; `tools/` scripts run as temporary ModuleScripts in ServerStorage, then removed).
2. Run BuildTerrain (`clear=true`) → check a top-down capture → BuildWorld → BuildNature.
3. Playtest: spawn in citadel, raid Cinderhollow/Ashford, zone banner shows, prompts work after streaming.
4. Justin imports `Nature1_All.glb` (File → Import 3D) → move into `ServerStorage.Game1Meshes` → re-run BuildNature.
5. Commit one feature per commit, merge `map-v2`, update the vault (Status, Decisions, Script Map, Assets).

Design source of truth: vault `Games/Game1/World and Stealth Design.md` (biomes, city districts, weakpoints, cloak vs detection, spell list).

## Running Blender locally (Mac)
`/Applications/Blender.app/Contents/MacOS/Blender -b --python assets/models/blender/<script>.py -- <out_dir>`
Scripts need the LihFolk Blender toolkit (`lihfolk_bpy`, `lihfolk_house`, `lihfolk_curves`) on the path: in the vault's `45 Procedural Blender Assets/scripts` / LihFolk download. Notes: the scripts read `sys.argv[1]` (written for a bpy Python module); under the Blender binary read the args after `--` instead. Justin's Blender is 5.4 Alpha; scripts were written against 5.2.
