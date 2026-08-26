# Aircraft System

## Aircraft are the collection game

The fleet should be one of Pixel Skies' strongest long-term rewards.

Use fictional families inspired by aviation categories unless/until licensing for real manufacturers is intentionally pursued.

## Primary stats

- passenger capacity
- cargo capacity / payload
- range
- cruise speed
- runway band

Secondary:
- operating cost
- reliability
- turnaround speed
- condition

## Configurations

Aircraft may support Passenger, Cargo and Mixed configurations. Do not create three separate near-identical aircraft records when configuration can be data.

## Visual representations

Every production aircraft needs:

### Map/airport top view
Shows wing planform, engines/props, airline livery, nose/tail orientation and gear state where readable.

### Side-profile detail view
Shows complete aircraft silhouette, windows/doors, livery and cabin/cargo zones.

## Plane detail / cutaway

Clicking a plane opens a side-view scene.

Small aircraft:
- show individual seats/passenger icons;
- show individual cargo slots/crates.

Large aircraft later:
- group seats into cabin blocks;
- show passenger count + representative characters;
- cargo as containers/pallet groups.

The goal is to understand the load visually without rendering 180 unique passenger sprites.

## Personal attachment

Each owned aircraft has:
- registration
- optional nickname
- livery
- home base
- hours/legs
- lifetime revenue
- condition

Cosmetic history makes old aircraft worth keeping.

## Upgrade philosophy

Avoid fantasy `+50% engine` ladders.

Upgrades should be believable abstractions:
- weight reduction package
- auxiliary tanks/range kit
- cargo conversion
- cabin refresh
- reliability package
- faster turnaround equipment

Meaningful tradeoffs are better than infinite stat ladders.

## Vertical-slice aircraft

### Trailhopper 4
Role: bush/feeder. Cheap, slow, short runway, small load, useful forever at remote airports.

### Twinwing 8
Role: regional utility. Better payload and speed, moderate cost.

### Highline 19
Role: commuter turboprop. High regional capacity, longer runway, faster and more expensive.

Numbers live in `data/aircraft.json`.

## Future roster categories

- bush/STOL
- floatplane
- light twin
- commuter turboprop
- regional jet
- narrowbody
- widebody
- cargo freighter
- heavy/oversize
- firefighting/special mission
- helicopter later

## Balance rule

A new aircraft should unlock a new **decision**, not simply invalidate the previous one.
