# World Map and Zoom Architecture

## User-facing promise

The player experiences Pixel Skies as **one flat-lay pixel world**.

They can zoom out until the whole world is visible, zoom into a region and see routes/aircraft, zoom toward an airport until that airport becomes a detailed operating scene, and click any owned aircraft to open its side-profile detail view.

The experience should feel continuous even though the engine uses multiple LOD layers/scenes.

## Do not build one gigantic literal map

A literal Earth-sized tilemap scaled all the way down to individual taxiways creates texture/memory waste, precision problems, impossible art requirements, bad culling and brittle coordinates.

Instead use a **logical world + visual LOD** architecture.

## Logical coordinate system

Canonical location is latitude/longitude. Never save aircraft world progress as only a Sprite2D pixel position.

## Projection

Initial map projection: equirectangular.

For a render canvas `W × H`:

```text
x = ((lon + 180) / 360) * W
y = ((90 - lat) / 180) * H
```

This is visually familiar, cheap and easy to map from geographic data.

Long routes should interpolate on a sphere/great-circle path, then project sample points into 2D. Handle International Date Line wrapping by selecting the visually shorter wrapped segment.

## Recommended visual LOD

### LOD 0 — world
Approx. reference canvas: 2048×1024.
- simplified continents
- oceans
- region labels
- unlocked airport clusters
- route lines
- aircraft icons

### LOD 1 — continental/regional
Approx. 4096×2048 logical reference.
- richer coastline
- state/province/country hints
- terrain color bands
- weather
- airport labels
- individual aircraft

### LOD 2 — airport approach
- airport badge expands
- city label becomes airport identity
- world routes fade
- local airport ground preview appears

### LOD 3 — airport scene
Handoff to a local `AirportScene` centered near `(0,0)` with runway, taxiways, stands, buildings, ground vehicles and aircraft.

The camera transition must preserve the selected airport's screen position and continue zooming through a short crossfade so the user perceives a seamless zoom.

## Camera feel

- mouse wheel / pinch zoom
- drag / WASD pan
- double-click airport: focus and zoom
- click aircraft: track/follow toggle
- home button: zoom to network
- smooth movement but settle on pixel-friendly zoom stops
- UI lives in CanvasLayer and does not scale with world zoom

Suggested camera zoom stops: `0.125, 0.25, 0.5, 1, 2, 4, 8`.

Allow temporary interpolation between stops, then settle/snap to reduce pixel shimmer.

## Map art source

Use public-domain Natural Earth geometry as a source for coastline/country masks, preprocess offline, then stylize into game-specific pixel LOD assets. The game should not depend on a GIS library at runtime.

## Aircraft rendering by zoom

Far: 1–3 pixel directional marker / airline color.

Mid: simplified top-view aircraft silhouette.

Near: full top-view sprite with navigation lights / prop blur / contrail if appropriate.

Airport view: full aircraft top sprite, landing gear state, prop/engine animation, shadow and ground-service state.

## Performance

Do not instantiate every city/plane label as heavyweight Control nodes.

Use pooled markers, culling by visible geographic bounds, batched route drawing, LOD label density, airport scenes loaded on demand, and simulation for all flights while rendering only visible flights.

## Seamless airport zoom test

A transition passes when the airport stays under the cursor/center, there is no hard teleport, the detailed runway resolves naturally, returning to world view restores the prior camera position, and the active aircraft remains the same object in simulation state.
