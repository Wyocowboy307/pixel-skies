# CLAUDE / FABLE HANDOFF — PIXEL SKIES ASSET RESET

The user supplied a 278-pack pixel-art bundle. It has been fully extracted and audited. Stop procedurally inventing production art where this curated library already has usable assets.

## Required source packs
- `01_AIRPORT_CORE/airport`: use for airport terminal, gates, security, baggage, runway/taxiway, apron, ground vehicles, service equipment, signage and airport props.
- `02_AIRCRAFT_AND_CABIN/flight`: use as the visual construction kit/reference for airplane exterior + cabin. It contains side/top passenger aircraft pieces, wings, engines, wheels, seats, windows, cargo/luggage and interior fixtures.
- `03_AIRCRAFT_REFERENCE_ONLY/air force`: top-down plane silhouettes/headings and airport support references only. Do not ship military aircraft unchanged.
- `04_WORLD_BASE/overworld`: use as the main regional/world pixel vocabulary.
- Remaining folders: selectively use for road/city/forest/desert/snow/coast/industrial/cargo detail.

## Non-negotiable rules
1. Production art must come from approved bundle assets or a deliberately approved custom aircraft asset. No beige rectangles or code-drawn fake final art.
2. Do not mix every pack. Match palette, scale and outline language. Recolor/retouch selected pieces where necessary.
3. Trailhopper is the hero asset. Build one excellent consistent Trailhopper before adding more aircraft.
4. Side profile and top-down must clearly be the SAME airplane.
5. The plane-detail screen must visibly show passengers and cargo using the cabin vocabulary from `flight`.
6. Airport scenes should be composed from actual airport assets, not generic rectangles.
7. Use `overworld` as the starting point for regional world tiles, then layer forest/desert/snow/coast packs.
8. Keep placeholder assets in a separate placeholder folder so they cannot accidentally become final.

## First implementation target
Rebuild only BZN -> BIL using this library: BZN airport scene, Trailhopper load screen with visible seats/cargo, taxi/takeoff, regional follow mode over real terrain, BIL arrival/unload. Do not expand fleet/world until this loop looks commercially coherent.
