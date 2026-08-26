# Pixel Skies — Game Bible

## High concept

Pixel Skies takes the easy-to-read airline loop that makes small airline games addictive and adds the part that is usually missing: **a visible living world**.

The player does not manage dots that secretly represent airplanes. The airplanes exist. They taxi, queue, take off, move across the map, encounter weather, arrive, park, unload and get serviced.

The game should feel cozy, mechanical and collectible rather than like enterprise software.

## Player fantasy

“I started with one little plane in Montana. Now I can zoom out and see my airline crossing the world — and every plane down there is mine.”

## Core loop

1. Open an airport.
2. Browse passengers/cargo/contracts.
3. Load jobs onto a compatible aircraft.
4. Choose one or more stops within range.
5. Review time, cost, delivery value and compatibility.
6. Dispatch.
7. Watch departure or return to management.
8. Track aircraft in real time on the world.
9. Watch arrival/unload.
10. Collect revenue/reputation.
11. Reinvest in aircraft, facilities, routes and new stations.

## Three simulation scales

### Strategic scale — world
- whole-world flat-lay map
- routes, weather, cities, demand
- live aircraft movement
- expansion decisions

### Operational scale — airport
- runway/taxiways/stands
- aircraft parking and ground service
- arrivals/departures
- visible airport upgrades
- light queueing, no ATC spreadsheet

### Attachment scale — aircraft
- large side-profile plane
- passengers/cargo/crew/load blocks
- fuel/range/condition
- livery, registration, name
- route and ETA
- upgrade/configuration actions

## Complexity budget

The player should not need to understand real dispatch paperwork.

Each aircraft exposes five primary gameplay facts:
- capacity
- cargo capability
- range
- speed
- runway requirement

Secondary facts such as fuel burn, reliability and condition exist but are presented only when relevant.

Each airport exposes:
- runway capability
- passenger capacity
- cargo capacity
- service level
- station/hub level

## World scope

The visual world is global from the beginning, but commercial access is curated.

Launch target: roughly 40–60 meaningful cities after the vertical slice, expanding later through updates/content. The player sees the rest of Earth as geography, not as thousands of clickable airport dots.

Cities should create distinct route roles:
- small feeder
- regional destination
- tourist
- cargo/industrial
- major hub
- remote/STOL
- special-event location

## Progression

### Early
- tiny props
- short western routes
- simple passenger/cargo jobs
- small stations

### Mid
- turboprops / regional aircraft
- hub-and-spoke routing
- cargo specialization
- weather planning
- multiple bases
- first AI competitors

### Late
- narrowbody / widebody / heavy cargo families
- intercontinental network
- major hubs
- premium and specialist contracts
- complex fleet composition

Small aircraft must never become obsolete. They retain value through short runways, thin demand, remote airports, feeder economics and special contracts.

## Time philosophy

Flights are real-time persistent activities. Short hops should often be minutes; regional flights can be tens of minutes to roughly an hour; long-haul can take hours.

The player is never trapped watching. They can manage another airport, plan routes, inspect aircraft, or leave the game. Offline progress resolves from timestamps.

Do not use manipulative wait walls. Time creates fleet planning, not punishment.

## Competition

Not vertical-slice scope.

Later AI airlines:
- open competing stations/routes
- take a share of demand
- have recognizable colors/fleet preferences
- react to profitable markets
- never cheat with hidden capacity

Competition should create stories, not turn the game into fare-management accounting.

## Special jobs

Examples:
- medical supplies
- ranch livestock
- touring band
- sports charter
- wildfire supplies
- oversized machine part
- holiday rush
- stranded travelers
- remote mail
- VIP charter

Special jobs should change the sprite/load presentation where possible.

## Design guardrails

Avoid hundreds of airport dots at launch, dozens of aircraft stats, mandatory manual flight, microscopic airport-building placement, slot inflation as the main economy sink, menus that hide the airplanes, and fake complexity that does not create a decision.

Prefer visible cause/effect, strong silhouettes, simple compatibility checks, satisfying motion, route stories, collecting aircraft and world growth the player can see.
