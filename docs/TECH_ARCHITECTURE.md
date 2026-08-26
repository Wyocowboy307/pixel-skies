# Technical Architecture

## Engine

Godot 4.7.x, GDScript.

## High-level layers

```text
App
├── Simulation
│   ├── GameClock
│   ├── AirlineState
│   ├── FlightService
│   ├── JobService
│   ├── EconomyService
│   └── SaveService
├── Data
│   ├── cities
│   ├── aircraft
│   ├── upgrades
│   └── jobs
└── Presentation
    ├── WorldMap
    ├── AirportScene
    ├── AircraftDetail
    └── UI
```

Simulation must run without scenes.

## Canonical IDs

Use stable string IDs such as `apt_bzn`, `ac_trailhopper_4`, and generated job IDs. Never use display names as keys.

## Game clock

Create a clock abstraction.

Production clock: wall time. Tests: fake clock.

All flight duration and job expiry code uses the clock service.

## Save model

Persist:
- company money/reputation
- unlocked stations
- airport upgrades
- owned aircraft
- aircraft configurations
- jobs/layovers
- active flights with timestamps
- tutorial state
- camera preference

Version the save schema.

## World simulation vs rendering

All active flights exist in simulation. WorldMap renders only objects visible in the current camera bounds/LOD. AirportScene is loaded only for the selected airport.

## Scene transitions

Main keeps shared simulation state alive.

Views:
- `WorldMapView`
- `AirportView`
- `AircraftDetailView`

Use a transition controller rather than destroying/recreating simulation.

## Map data

Preprocess source geometry offline into simplified JSON/packed resources for each LOD. Do not parse shapefiles at runtime.

## Airport movement

Author local taxi paths as Curve2D/Path2D or lightweight waypoint graphs.

Ground traffic follows visual reservations. It does not alter flight economics except turnaround completion.

## Events

Simulation emits committed domain events such as `job_loaded`, `flight_dispatched`, `flight_phase_changed`, `flight_arrived`, `job_delivered`, `aircraft_purchased`, and `airport_upgraded`.

Presentation listens and animates. Do not make an animation callback the authority for a payout.

## Data validation

At startup/dev validate duplicate IDs, bad airport refs, negative stats, range/runway enum validity, aircraft visual paths, upgrade dependencies and job template rules.

## Pixel rendering

UI in CanvasLayer. World/airport rendering nearest where appropriate. Camera can interpolate zoom but should settle at pixel-friendly levels.

## First code structure

```text
project.godot
scenes/
  main.tscn
  world/world_map.tscn
  airport/airport_view.tscn
  aircraft/aircraft_detail.tscn
scripts/
  app/
  data/
  sim/
  world/
  airport/
  aircraft/
  ui/
  dev/
data/
assets/
docs/
```
