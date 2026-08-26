class_name EconomyService
extends RefCounted
## Money: what a job pays and what a leg costs.
##
## Payouts scale with distance, size, urgency and rarity; costs scale with the
## aircraft's operating cost, distance and a simple ground fee
## (docs/JOBS_ECONOMY_PROGRESSION.md, "Revenue"). One currency only.

## Passenger jobs pay a boarding fee plus a per-mile fare.
const PASSENGER_BASE := 25.0
const PASSENGER_PER_NM := 0.85
## Cargo pays slightly less per mile but loads denser.
const CARGO_BASE := 20.0
const CARGO_PER_NM := 0.65

const URGENCY_MULTIPLIER := {"normal": 1.0, "high": 1.35}

## Ground handling charged at both ends, by airport tier.
const GROUND_FEE := {"regional": 25, "major": 60}
## A modest reward for filling a plane toward one destination. Deliberately
## small: mixed routes must stay viable (docs/JOBS_ECONOMY_PROGRESSION.md).
const SAME_DESTINATION_BONUS := 0.08

static func job_reward(kind: String, seats: int, cargo_units: int,
        distance_nm: float, template_multiplier: float, urgency: String) -> int:
    var amount := 0.0
    if seats > 0:
        amount += float(seats) * (PASSENGER_BASE + PASSENGER_PER_NM * distance_nm)
    if cargo_units > 0:
        amount += float(cargo_units) * (CARGO_BASE + CARGO_PER_NM * distance_nm)
    if kind == "contract":
        # Contracts are rarer and carry more flavour, so they pay a premium on
        # top of whatever they physically occupy.
        amount *= 1.15
    amount *= template_multiplier
    amount *= float(URGENCY_MULTIPLIER.get(urgency, 1.0))
    return maxi(1, roundi(amount))

static func ground_fee(airport: Dictionary) -> int:
    return int(GROUND_FEE.get(String(airport.get("tier", "regional")), 25))

static func flight_cost(family: Dictionary, origin: Dictionary,
        destination: Dictionary, distance_nm: float) -> int:
    var fuel_and_crew: float = float(family.get("operating_cost_per_nm", 0.0)) * distance_nm
    return maxi(1, roundi(fuel_and_crew + float(ground_fee(origin) + ground_fee(destination))))

## Total payout for a delivered load, including the same-destination bonus.
static func payload_revenue(payload: Array[Job]) -> int:
    if payload.is_empty():
        return 0
    var total := 0
    var destinations: Dictionary = {}
    for job: Job in payload:
        total += job.reward
        destinations[job.destination_id] = true
    if destinations.size() == 1 and payload.size() > 1:
        total = roundi(float(total) * (1.0 + SAME_DESTINATION_BONUS))
    return total

## Everything the dispatch preview needs, so the UI never recomputes economics.
static func preview(family: Dictionary, origin: Dictionary, destination: Dictionary,
        distance_nm: float, payload: Array[Job], duration_seconds: float) -> Dictionary:
    var delivered: Array[Job] = []
    var carried_on: Array[Job] = []
    for job: Job in payload:
        if job.destination_id == destination.get("id", ""):
            delivered.append(job)
        else:
            carried_on.append(job)
    var revenue: int = payload_revenue(delivered)
    var cost: int = flight_cost(family, origin, destination, distance_nm)
    return {
        "distance_nm": distance_nm,
        "duration_seconds": duration_seconds,
        "revenue": revenue,
        "cost": cost,
        "profit": revenue - cost,
        "delivered": delivered.size(),
        "carried_on": carried_on.size(),
        "same_destination_bonus": delivered.size() > 1,
    }
