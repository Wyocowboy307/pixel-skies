# Testing and Verification

## Philosophy

“Implemented” is not enough.

Every milestone must prove:
1. state is correct;
2. save/resume is correct;
3. the user can understand it;
4. the visual action reads at gameplay speed.

## Automated simulation tests

At minimum:
- geographic projection round-trip tolerance
- distance calculation
- range legality
- runway legality
- payload capacity
- dispatch creates one flight
- payout occurs once
- offline completion
- job expiry
- layover persistence
- aircraft cannot be on two flights
- airport upgrade prerequisite
- save migration/version

Use a fake clock.

## UI smoke tests

- boot main scene
- select BZN
- open jobs
- load job
- route to BIL
- dispatch
- open plane detail
- return
- advance fake time
- settle arrival

## Screenshot scenarios

Automate stable screenshots:
- world_opening
- route_preview
- airport_bzn
- loading
- takeoff
- enroute
- aircraft_detail
- arrival
- upgraded_station

## Performance budget

Test with synthetic 60 airports, 100 active aircraft, 300 jobs and multiple weather overlays. Simulation may track all; rendering should cull by view/LOD.

## Visual review checklist

- Does the plane silhouette read without label?
- Can destination be identified?
- Can legal route be understood?
- Does zoom preserve context?
- Does airport look alive?
- Does side view make the payload obvious?
- Does an upgrade visibly change something?

## Regression rule

Art, VFX and camera work must never change revenue, duration, legality, job settlement, aircraft capacity or save results.
