# Pixel Skies — Claude Code Instructions

This repository is **Pixel Skies**.

## HARD REPOSITORY BOUNDARY

Pixel Skies is completely separate from:
- `pixel-ranch`
- `pocket-arcana`

**Never read, edit, import, move, commit, or reuse files from either project unless Thomas explicitly supplies a specific asset for reuse.** Do not “helpfully” touch another repository.

When Thomas says **go build**, implement. Do not restart product discovery.

## Read order

1. `docs/GAME_BIBLE.md`
2. `docs/VERTICAL_SLICE.md`
3. `docs/WORLD_MAP_AND_ZOOM.md`
4. `docs/TECH_ARCHITECTURE.md`
5. `docs/FLIGHT_SYSTEM.md`
6. `docs/AIRPORT_SYSTEM.md`
7. `docs/AIRCRAFT_SYSTEM.md`
8. `docs/JOBS_ECONOMY_PROGRESSION.md`
9. `docs/UI_UX.md`
10. `docs/ART_BIBLE.md`
11. `docs/ART_PIPELINE.md`
12. `docs/TESTING.md`

Reference research lives in `docs/REFERENCE_RESEARCH.md`.

## Product sentence

**A simple airline manager on top of a living pixel aviation world.**

The player should understand the loop without an aviation degree:
**pick jobs -> load plane -> choose route -> depart -> arrive -> earn -> expand.**

## Non-negotiable experience

- A flat-lay pixel world map is the main home screen.
- The player can zoom from a broad world view toward individual airports.
- Aircraft are visible from above while parked, taxiing and flying.
- Clicking an aircraft opens a side-profile aircraft view with its passengers/cargo visibly represented.
- Airports are curated, not every real-world airport.
- Airport upgrades must visibly change the airport.
- Flights may take real time and continue offline.
- The player never needs to manually fly every leg.
- No arbitrary “pay an absurd fee for one more plane slot” progression wall. Capacity should come from visible facilities, fleet economics and company progression.

## Engineering rules

- Godot 4.7.x.
- Simulation state is data-driven and independent from presentation.
- Store geographic positions as latitude/longitude; project them for rendering.
- Do not build one physically gigantic 2D scene measured in millions of pixels.
- Use zoom LOD + scene handoff for world -> airport detail.
- Real-time flight progress is derived from timestamps, never from “the game stayed open for N frames.”
- Save enough state to reconstruct flights after restart/offline time.
- UI asks models for availability/reasons; UI does not decide economy rules.
- Animation reflects committed state and does not decide outcomes.
- No hardcoded aircraft/city logic when data can express it.
- Add deterministic test clocks/seeds for simulation.
- Commit stable milestones.

## Visual-production rule

Do **not** mass-generate aircraft or airport art before a master look is approved in the running game.

First art gate:
- Trailhopper 4 top view
- Trailhopper 4 side view
- Twinwing 8 top view
- BZN runway/terminal sample
- one service truck
- one passenger character
- one world-map coastline sample
- one cloud/weather sample

Generate with the approved AI pixel-art tools available on the machine (SpriteCook, PixelLab, or another approved generator). Use the same references/style clauses for every later asset.

No generic AI painting. Pixel density, silhouette, light direction, outline and scale must remain consistent.

## First implementation target

Build the vertical slice before expanding the world.

The slice is not done because menus exist. It is done when Thomas can:
1. open BZN,
2. load real generated jobs,
3. dispatch a plane,
4. watch push/taxi/takeoff,
5. zoom to the world map and see that exact plane moving,
6. click it and inspect its side-view load,
7. watch/trigger its DEN or BIL arrival sequence,
8. get paid,
9. reinvest in a plane or visible airport upgrade.

Judge every milestone by:
- **Can a new player tell what to do next?**
- **Is watching the airline operate satisfying?**
