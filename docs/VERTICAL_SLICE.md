# Vertical Slice — Montana to Denver

## Purpose

Prove the whole fantasy before scaling content.

## Airports

### BZN — Bozeman
Starter home station. Small regional airport, mountain flavor.

### BIL — Billings
Short feeder route. Plains flavor.

### DEN — Denver
First aspirational large destination/hub.

## Aircraft

- Trailhopper 4
- Twinwing 8
- Highline 19

## Required playable loop

### Gate 0 — boot
- project opens in Godot 4.7
- no parser/runtime errors
- data validators pass

### Gate 1 — map
- flat world/regional map
- BZN/BIL/DEN correctly positioned relative to each other
- pan/zoom
- airport markers
- click/focus airport
- clean LOD behavior

### Gate 2 — jobs/load
- jobs generated at BZN
- passenger and cargo types
- load/unload
- visible aircraft capacity
- invalid reason text

### Gate 3 — dispatch
- route selection
- range/runway compatibility
- time/cost/revenue preview
- dispatch creates persistent flight

### Gate 4 — airport life
- parked top-view aircraft
- loading state
- taxi out
- takeoff
- arrival/taxi in
- no teleport between stand and runway

### Gate 5 — live world flight
- same aircraft moves along route according to timestamps
- follow camera
- offline/resume works
- click plane during flight

### Gate 6 — aircraft side view
- side-profile aircraft
- passengers/cargo visibly represented
- route/ETA/load/condition
- return to exact map context

### Gate 7 — economy
- delivery settles once
- money increases
- operating cost deducted
- buy second aircraft OR visible airport upgrade

### Gate 8 — polish
- first flight tutorial
- coherent pixel art
- departure/arrival sound/VFX placeholders
- screenshot harness
- no confusing debug UI

## Slice acceptance test

A new player with no explanation should be able to complete BZN -> BIL or BZN -> DEN and understand what the job is, what the plane can carry, where it can fly, how long it takes, what they earn and how to improve the airline next.

## Explicitly out of slice

- multiplayer
- global competitor simulation
- manual flight sim
- hundreds of airports
- 30+ aircraft
- complicated ticket pricing
- crew scheduling
- maintenance parts inventory
- live real-world weather API
