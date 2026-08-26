# Art Production Pipeline

## Goal

Use AI generation to accelerate production while preventing style drift.

Approved tools may include SpriteCook, PixelLab and another approved pixel generator available to Claude. Provider is less important than the locked references and review process.

## Phase A — master look only

Generate and integrate only:
1. Trailhopper 4 — top
2. Trailhopper 4 — side
3. Twinwing 8 — top
4. BZN airport sample — runway/stand/terminal area
5. service tug/truck
6. passenger character
7. coastline/map sample
8. cloud/weather sample

Review them **inside the actual game**. Do not continue if they look like different games.

## Phase B — vertical-slice complete assets

Aircraft:
- Trailhopper top + side
- Twinwing top + side
- Highline top + side
- basic liveries

BZN/BIL/DEN:
- runway/taxi/apron tiles
- terminal variants
- hangar
- cargo shed
- fuel/service props
- stands/markings
- vehicles
- airport regional decoration

World:
- map LOD styles
- airport markers
- route line styles
- weather

People/cargo:
- 6–10 passenger archetypes
- generic boxes
- mail
- luggage
- one special cargo

## Phase C — animation

Prefer reusable Godot animation where it preserves crisp art:
- transform-based taxi
- prop rotation frames
- light blinking
- touchdown particles
- door open frame
- vehicle movement

Do not demand 30-frame sprite sheets for everything.

## Asset naming

```text
assets/art/aircraft/<family>/<family>_top.png
assets/art/aircraft/<family>/<family>_side.png
assets/art/airports/tiles/...
assets/art/airports/bzn/...
assets/art/world/...
assets/art/weather/...
assets/art/people/...
assets/art/cargo/...
```

## Prompt construction

Prompts must include exact canvas target, transparent background requirement where applicable, perspective, light direction, outline, pixel density, silhouette description and explicit negative clauses.

Keep style-guide reference asset IDs/paths in a generation ledger.

## Technical import

- lossless
- nearest filter
- no mipmaps for native pixel sprites
- no alpha-border processing that softens outline

World LOD atlases may use separate import settings if needed for zoom stability.

## Review captures

Automate screenshots for whole world, regional route, BZN parked plane, taxi/takeoff, Trailhopper side detail loaded, BIL arrival and DEN with multiple aircraft.

A generation is not approved in isolation. It must look good at actual gameplay size.
