# Reference Research — What to borrow, what not to copy

This file records design lessons, not content to clone.

## Pocket Planes — borrow the loop

Useful observed mechanics:
- world map as the main navigation layer
- airports/cities unlocked over time
- passenger and cargo jobs
- aircraft range and city/aircraft compatibility
- route review with time/profit
- layovers / transfer cargo
- a bonus for filling a plane toward the same destination
- real-time flight progression

Pixel Skies should preserve the clarity of that loop while replacing the abstract presentation with a living visible world.

Do not copy names, UI, aircraft designs, exact economy formulas or art.

Reference:
- https://nimblebit.com/PocketPlanesHelp.html
- https://nimblebit.com/

## Fly Corp — borrow map readability, avoid overload

Useful lesson: a world-scale route network is understandable when zoom/pan and airport capacity are readable.

Avoid its “thousands of cities” direction for Pixel Skies launch. Pixel Skies should be curated so every active airport feels meaningful.

Reference:
- https://store.steampowered.com/app/1372530/Fly_Corp/

## Natural Earth — world base data

Natural Earth provides public-domain vector/raster map data at multiple scales. It is suitable as geographic source data for coastlines/country shapes before stylizing them into Pixel Skies' art direction.

Use geographic data as source geometry, then preprocess/simplify it into game-specific LOD assets. Do not ship a giant GIS runtime.

Reference:
- https://www.naturalearthdata.com/about/terms-of-use/
- https://www.naturalearthdata.com/downloads/

## Godot 4.7 — technical constraints

Camera2D supports panning/zooming, but a single multi-million-pixel world scene is the wrong architecture.

Godot's own docs note that large-world coordinates are rarely useful in 2D and that 2D rendering does not gain precision from enabling them. TileMapLayer coordinates also have practical serialized limits.

Therefore:
- keep geographic coordinates separate from render coordinates;
- use LOD map layers;
- use local airport scenes centered near origin;
- transition/crossfade at high zoom instead of making the airport literally exist at Earth-map scale.

References:
- https://docs.godotengine.org/en/4.7/
- https://docs.godotengine.org/en/latest/tutorials/physics/large_world_coordinates.html
- https://docs.godotengine.org/en/latest/tutorials/2d/using_tilemaps.html

## Product lesson

The winning combination is:
**Pocket Planes clarity + a curated Fly Corp-like world + living airport/aircraft simulation + collectible pixel aircraft.**
