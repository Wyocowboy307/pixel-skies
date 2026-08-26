# Pixel Skies

**Pixel Skies** is a living pixel-art airline management game built in Godot 4.7.

The fantasy is simple: start with a tiny airline, carry passengers and cargo, watch every aircraft physically operate, grow airports and hubs, and eventually cover a flat-lay pixel world with your fleet.

This repository is completely separate from **Pixel Ranch** and **Pocket Arcana**.

## Core pillars

1. **One zoomable living world** — whole-world flat map -> region -> airport -> aircraft.
2. **Planes are visible machines, not timers** — taxi, take off, fly, land, unload, refuel.
3. **Pocket-sized management** — jobs, routes, fleet and airports are easy to understand.
4. **Airports visibly grow** — upgrades change the actual airport scene.
5. **Aircraft collection matters** — small planes stay useful because runway, demand and range differ.
6. **Real-time flights, active play optional** — flights continue while the player manages other things or is offline.
7. **Visual attachment** — top-down aircraft on the map, side-profile cutaway when selected.

## Vertical slice

The first slice is **Bozeman (BZN) -> Billings (BIL) -> Denver (DEN)** with three fictional aircraft families:
- Trailhopper 4 — single-engine bush plane
- Twinwing 8 — light twin/turboprop
- Highline 19 — commuter turboprop

The slice is not complete until the player can accept jobs, load a plane, watch it leave an airport, see it travel on the map, watch it arrive, get paid, inspect the aircraft in side view, and buy/upgrade something meaningful.

See `CLAUDE.md` and `docs/VERTICAL_SLICE.md`.
