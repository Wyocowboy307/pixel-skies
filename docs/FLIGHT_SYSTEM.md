# Flight System

## Principle

A flight is a persistent simulation record, not a moving sprite. The sprite is only one presentation of that state.

Core record:

```text
FlightLeg:
  id
  aircraft_id
  origin_airport_id
  destination_airport_id
  route_points
  departure_timestamp
  arrival_timestamp
  phase
  payload_ids
  operating_cost
```

## Phases

1. parked
2. boarding/loading
3. push/start
4. taxi_out
5. takeoff_roll
6. climb_transition
7. enroute
8. approach_transition
9. landing_roll
10. taxi_in
11. unloading
12. complete

The world-map timeline represents the `enroute` portion. Airport animation represents the ground/transition phases.

## Duration

Distance is based on geographic coordinates.

Initial tuning:
- compute great-circle distance;
- convert by aircraft cruise speed;
- apply a game time scale;
- add small fixed ground time.

Target experience, not strict realism:
- very short hop: ~5–20 min
- regional: ~20–60 min
- longer domestic: ~1–3 h
- intercontinental later: multiple hours

Exact tuning belongs in data.

## Offline progression

On load/resume:
- compare saved/current time;
- recompute every active flight phase from timestamps;
- settle completed legs once;
- generate arrival-ready state;
- never require the game to have been open.

Protect against duplicate payout with an idempotent settlement flag.

## Route planning

Player selects aircraft and one or more reachable stops.

Planner shows:
- distance
- estimated time
- payload destination matches
- operating cost
- expected revenue
- estimated profit
- runway/airport compatibility

Unavailable city should explain one reason at a time: out of range, runway too short, airport locked, or aircraft already assigned.

## Multi-stop routes

Vertical slice may start with one destination.

Later:
- allow chained legs;
- auto-drop matching payload at each stop;
- layover cargo/passengers can remain stored;
- route line previews each leg.

## Visual flight

On the world map:
- interpolate along sampled great-circle path;
- orient sprite to local path tangent;
- animate props/engines where visible;
- weather overlay may alter route warning later.

## Watch mode

Selecting a flying aircraft may lock the map camera to it.

Watch mode is observational, not mandatory manual flying. A future optional mission mode can be arcade flight, but it must not block normal airline management.

## Arrival/departure presentation

If the airport scene is open, play the live sequence.

If not, simulation proceeds normally. The player can later open the airport and see the current ground phase, or an optional short arrival recap.

## Failure philosophy

Do not introduce random catastrophic crashes.

Operational problems later can be delay, maintenance warning, weather reroute, gate unavailable or missed connection. They should create decisions, not wipe hours of progress.
