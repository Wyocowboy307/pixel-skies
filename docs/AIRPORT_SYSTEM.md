# Airport System

## Philosophy

Airports are not full construction sandboxes in the first release. They are **living modular scenes** with meaningful upgrade slots. Spending money should visibly change the airport rather than merely increasing a number.

## Ownership language

The player does not literally buy Denver International Airport.

The airline opens a **station** at a city, can upgrade a station into a **base**, and can later designate limited **hubs**. Remote/private fields may later support stronger ownership fantasy.

## Airport gameplay stats

Primary:
- runway capability
- passenger capacity
- cargo capacity
- stands
- service level

Secondary:
- maintenance capability
- weather equipment
- turnaround speed

## Visual modules

- runway
- taxiway
- apron/stands
- terminal
- cargo shed
- hangar
- fuel/service area
- tower/ops building
- fire/service vehicles
- lights
- deicing/weather equipment later

## Upgrade path example

### Station 1
- 1–2 stands
- small terminal
- basic cargo storage
- basic fuel

### Station 2
- more stands
- larger terminal
- cargo shed
- faster turnaround

### Base
- dedicated hangar
- maintenance
- larger layover/storage
- aircraft can be based here

### Hub
- major terminal/apron
- connection bonus
- high job generation
- airline identity visible

## Runway compatibility

Instead of arbitrary airport classes, use a readable runway capability band:
- Short
- Regional
- Mainline
- Heavy

Aircraft data includes minimum runway band. The UI can still show a 1–4 icon for instant comprehension.

## Layout architecture

Each airport uses a data-defined `AirportLayout` with anchor positions, runway path, taxi paths, stand positions, building slots and decoration zones.

The first three airports should be authored as stylized templates:
- BZN: mountain regional field
- BIL: plains regional field
- DEN: large hub preview

They do not need to reproduce real airport taxiway geometry.

## Ground movement

Aircraft follow authored curves/path nodes:
- stand -> taxiway -> runway hold -> takeoff
- runway exit -> taxiway -> stand

No full ATC simulation. Simple reservations prevent two planes occupying the same stand/path segment.

## Ground service loop

At a stand:
1. engines/props stop
2. door/cargo door opens
3. unloading
4. loading
5. fuel/service
6. ready
7. push/start

Vehicles can be decorative/state-driven at first.

## Airport click behavior

World map click:
- first click selects and shows compact airport card
- second click / zoom command focuses
- high zoom transitions into airport scene

Airport scene:
- click plane -> aircraft detail
- click stand/building -> facility info
- click upgrade ghost -> upgrade panel

## Airport growth satisfaction

Every purchased upgrade must have at least one visible consequence: a larger building, new stand, new vehicle, new light/equipment or denser activity.

No invisible `+5 slots` as the only reward.
