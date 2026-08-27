# Pixel Skies curated asset library

Built from the 278-pack bundle supplied in this chat. All 278 archives were extracted successfully; this folder contains only the packs most useful for Pixel Skies.

## Use order
1. `01_AIRPORT_CORE/airport` — terminal interiors, gates, security, baggage, apron/runway/taxiway, ground vehicles, signage, service equipment. This should replace most procedural airport art.
2. `02_AIRCRAFT_AND_CABIN/flight` — passenger-aircraft parts, side/top aircraft pieces, wings, engines, wheels, seats, windows, cabin fixtures, luggage/cargo. Use as the aircraft construction/reference base.
3. `03_AIRCRAFT_REFERENCE_ONLY/air force` — lots of top-down aircraft silhouettes, hangars and support vehicles. Military; do NOT ship unchanged as the Pixel Skies fleet. Use geometry/scale/orientation reference only.
4. `04_WORLD_BASE/overworld` — strongest ready-made world/regional base in the bundle. Includes water/ground biomes, towns/cities, weather/sky icons, roads, ports and terrain.
5. Regional packs add forests, desert, snow, coast, islands, farms and city/road detail.

## Hard art rule
Do not let code procedurally draw final airports, aircraft, roads, buildings, terrain props or UI stand-ins when a usable asset exists here. Procedural art is placeholder-only.

## Plane rule
The bundle does NOT contain a perfect charming Pocket-Planes-like fleet. The final Trailhopper/Twinwing/Highline should be original Pixel Skies aircraft. Use `flight` for modular parts, cabin vocabulary and proportions; use `air force` only for top-down orientation reference. Lock one Trailhopper side + top design before creating a fleet.
