# UI / UX

## Prime directive

**The airplane should stay visible whenever possible.**

Do not turn Pixel Skies into a stack of management spreadsheets.

## World screen

Permanent minimal HUD:
- money
- company level/reputation
- fleet active/total
- alerts
- search
- zoom/home

Contextual:
- selected airport card
- selected aircraft card
- route planner
- weather alert

## Airport selection

Selected airport compact card:
- city / code
- available jobs
- parked aircraft
- station level
- quick buttons: Jobs / Station / Zoom In

## Plane selection

Selected plane compact card:
- name/type
- current phase
- route
- ETA
- load
- click again: open side-profile detail

## Side-profile aircraft screen

Large plane centered.

Panels should feel attached to physical zones:
- passenger/cargo load below/inside cabin
- route strip above
- fuel/range left
- condition/service right

Do not cover the plane with paragraphs.

## Job loading interaction

Airport job list shows passenger/cargo icon, destination, size and reward.

When a job is hovered/selected:
- matching destination flashes on map/mini-map;
- compatible load slot highlights on aircraft;
- incompatible reason is one sentence.

Examples:
- `2 seats needed`
- `Cargo hold full`
- `Destination out of range`
- `Runway at destination too short`

## Depart interaction

1. Load.
2. Press Route.
3. Reachable airports brighten.
4. Payload destinations pulse.
5. Click destination(s).
6. Preview time / cost / revenue.
7. Dispatch.

No hidden validation after the player presses Dispatch.

## Zoom UX

- wheel/pinch centered on pointer
- airport labels declutter by LOD
- double-click/tap zooms to target
- Escape/back reverses one detail level
- world camera remembers prior position after airport detail

## Tutorial

Never dump a manual.

First flight coach:
1. “These are jobs.”
2. load one passenger/cargo
3. “This is what your plane can carry.”
4. choose highlighted destination
5. dispatch
6. watch departure
7. follow aircraft
8. collect arrival payout
9. buy first visible upgrade

Tutorial ends with an actual completed flight.

## Alerts

Use icons + short text for plane ready, arrived, maintenance, airport nearing capacity and contract expiring. Avoid constant red badges.
