# Jobs, Economy and Progression

## Job types

### Passenger
- origin
- destination
- party size
- patience/expiry
- reward
- optional trait

### Cargo
- origin
- destination
- weight/slot size
- reward
- optional handling type

### Contract
Special multi-step or time-limited job with stronger flavor/reward.

## Job generation

Each airport has demand weights for local population/tier, business, tourism, cargo, remote access and season/event.

Generate a small readable list, not 80 rows.

Destinations are weighted toward currently unlocked stations, useful network connections and an occasional expansion tease.

## Transfer / layover

Payload can be unloaded at a non-final station and stored for another aircraft. Layover capacity comes from visible terminal/cargo facilities.

This creates hub strategy without route-schedule spreadsheets.

## Same-destination bonus

A modest load-efficiency bonus can reward filling a plane toward one destination. Do not make it so large that mixed routes are always wrong.

## Revenue

Job payout should broadly scale with distance, job size, urgency and rarity/special handling.

Flight cost scales with aircraft operating cost, distance and a simple ground fee abstraction.

The dispatch preview always shows estimated profit.

## Currency

Vertical slice: **one primary currency**. Do not start with premium currencies.

Later progression can use money plus company reputation/level as a non-spendable unlock track.

## Progression sinks

Good:
- buying/leasing aircraft
- station opening
- visible airport facilities
- maintenance
- livery/cosmetics
- route rights/region expansion

Bad:
- exponentially expensive abstract fleet slots
- paying merely to click more often

Fleet soft cap comes from hangar/base capacity, operating costs, available profitable demand and company progression.

## Company level

Earn reputation from completed jobs, profitable flights, new destinations, contracts and reliable service.

Level unlocks categories rather than raw multipliers.

## Region expansion

The entire world remains visible.

Commercial access expands deliberately by region instead of exploding into thousands of dots at once.

## AI competitors — later

Competitors affect demand share on selected routes.

Keep their model legible: airline identity, route presence, service rating and approximate share.

Do not implement a stock market or dynamic fare-management simulator in the vertical slice.
