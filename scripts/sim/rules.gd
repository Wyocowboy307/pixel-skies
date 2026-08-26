class_name Rules
extends RefCounted
## Compatibility rules. The UI asks these questions and prints the answer; it
## never decides legality itself (docs/TECH_ARCHITECTURE.md).
##
## Every check returns `{ok: bool, reason: String}` and reports exactly one
## reason, because a player who is told four things at once learns nothing
## (docs/UI_UX.md, "Job loading interaction").

const RUNWAY_BAND_NAMES := ["", "Short", "Regional", "Mainline", "Heavy"]

static func ok() -> Dictionary:
    return {"ok": true, "reason": ""}

static func no(reason: String) -> Dictionary:
    return {"ok": false, "reason": reason}

## The family record with a specific airframe's purchased upgrades applied:
## range added to range_nm, extra seats and hold units added to every
## configuration. Callers that hold an owned aircraft should use this (via
## Simulation.family_of) so capacity and range reflect what was bought.
static func effective_family(family: Dictionary, upgrade_ids: Array) -> Dictionary:
    if upgrade_ids.is_empty():
        return family
    var out: Dictionary = family.duplicate(true)
    var extra_seats := 0
    var extra_cargo := 0
    var extra_range := 0.0
    for entry: Variant in family.get("upgrades", []):
        var upgrade: Dictionary = entry
        if not upgrade_ids.has(String(upgrade.get("id", ""))):
            continue
        var effects: Dictionary = upgrade.get("effects", {})
        extra_seats += int(effects.get("seats", 0))
        extra_cargo += int(effects.get("cargo_units", 0))
        extra_range += float(effects.get("range_nm", 0.0))
    out["range_nm"] = float(family.get("range_nm", 0.0)) + extra_range
    var configs: Array = []
    for entry: Variant in out.get("configurations", []):
        var config: Dictionary = (entry as Dictionary).duplicate()
        if int(config.get("seats", 0)) > 0 or extra_cargo == 0:
            config["seats"] = int(config.get("seats", 0)) + (extra_seats if int(config.get("seats", 0)) > 0 else 0)
        config["cargo_units"] = int(config.get("cargo_units", 0)) + extra_cargo
        configs.append(config)
    out["configurations"] = configs
    out["passenger_capacity"] = int(family.get("passenger_capacity", 0)) + extra_seats
    out["cargo_units"] = int(family.get("cargo_units", 0)) + extra_cargo
    return out

## Seats and hold units available in an aircraft's current configuration.
static func capacity(family: Dictionary, configuration: String) -> Dictionary:
    for entry: Variant in family.get("configurations", []):
        var config: Dictionary = entry
        if String(config.get("id", "")) == configuration:
            return {"seats": int(config.get("seats", 0)),
                    "cargo_units": int(config.get("cargo_units", 0))}
    # An aircraft with no configuration table falls back to its headline stats.
    return {"seats": int(family.get("passenger_capacity", 0)),
            "cargo_units": int(family.get("cargo_units", 0))}

static func load_used(jobs: Array[Job]) -> Dictionary:
    var seats := 0
    var units := 0
    for job: Job in jobs:
        seats += job.seats
        units += job.cargo_units
    return {"seats": seats, "cargo_units": units}

## Can this job go on this aircraft right now?
static func can_load(aircraft: AircraftInstance, family: Dictionary,
        job: Job, loaded: Array[Job]) -> Dictionary:
    if aircraft.state == AircraftInstance.State.IN_FLIGHT:
        return no("%s is already flying" % aircraft.display_name())
    if not job.is_available():
        return no("That job is no longer available")
    if job.origin_id != aircraft.location_id:
        return no("Job is waiting at a different airport")

    var limits: Dictionary = capacity(family, aircraft.configuration)
    var used: Dictionary = load_used(loaded)
    if job.seats > 0:
        var free_seats: int = int(limits["seats"]) - int(used["seats"])
        if free_seats <= 0:
            return no("No seats free")
        if job.seats > free_seats:
            return no("%d seat%s needed, %d free" % [
                job.seats, "" if job.seats == 1 else "s", free_seats])
    if job.cargo_units > 0:
        var free_units: int = int(limits["cargo_units"]) - int(used["cargo_units"])
        if free_units <= 0:
            return no("Cargo hold full")
        if job.cargo_units > free_units:
            return no("%d hold unit%s needed, %d free" % [
                job.cargo_units, "" if job.cargo_units == 1 else "s", free_units])
    return ok()

## Can this aircraft fly this leg? Range and runway are the two facts a player
## must understand, so they are reported separately and plainly.
static func can_fly(family: Dictionary, origin: Dictionary, destination: Dictionary,
        distance_nm: float) -> Dictionary:
    if origin.get("id", "") == destination.get("id", ""):
        return no("Already at that airport")
    if not bool(destination.get("starter_unlocked", false)):
        return no("%s is not open to your airline yet" % String(destination.get("code", "")))
    var range_nm: float = float(family.get("range_nm", 0.0))
    if distance_nm > range_nm:
        return no("Out of range — %d nm needed, %d nm available" % [
            roundi(distance_nm), roundi(range_nm)])
    var required: int = int(family.get("runway_band_required", 1))
    if int(destination.get("runway_band", 0)) < required:
        return no("Runway at %s is too short — needs %s" % [
            String(destination.get("code", "")), band_name(required)])
    return ok()

## The whole dispatch check in one call, so the dispatch button and the route
## planner can never disagree about what is legal.
static func can_dispatch(aircraft: AircraftInstance, family: Dictionary,
        origin: Dictionary, destination: Dictionary, distance_nm: float,
        payload: Array[Job]) -> Dictionary:
    if not aircraft.is_available():
        return no("%s is already assigned to a flight" % aircraft.display_name())
    if payload.is_empty():
        return no("Load at least one job before departing")
    var flyable: Dictionary = can_fly(family, origin, destination, distance_nm)
    if not bool(flyable["ok"]):
        return flyable
    return ok()

static func band_name(band: int) -> String:
    if band < 1 or band >= RUNWAY_BAND_NAMES.size():
        return "Unknown"
    return RUNWAY_BAND_NAMES[band]
