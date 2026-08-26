class_name DataValidator
extends RefCounted
## Startup/dev validation for the JSON game data.
##
## Returns every problem found rather than asserting on the first one, so a data
## edit shows its full damage in one run. Presentation never calls this; it is a
## boot-time and test-time guard.

const RUNWAY_BAND_MIN := 1
const RUNWAY_BAND_MAX := 4

static func validate(db: GameDB) -> PackedStringArray:
    var errors: PackedStringArray = []
    _validate_airports(db, errors)
    _validate_aircraft(db, errors)
    _validate_upgrades(db, errors)
    _validate_job_templates(db, errors)
    _validate_layouts(db, errors)
    return errors

static func _validate_airports(db: GameDB, errors: PackedStringArray) -> void:
    if db.airports.is_empty():
        errors.append("cities.json: no airports loaded")
    var seen_codes: Dictionary = {}
    for id: String in db.airports:
        var a: Dictionary = db.airports[id]
        var where: String = "cities.json[%s]" % id
        if not id.begins_with("apt_"):
            errors.append("%s: airport id must start with 'apt_'" % where)
        var code: String = String(a.get("code", ""))
        if code.length() != 3:
            errors.append("%s: code '%s' should be a 3-letter identifier" % [where, code])
        if seen_codes.has(code):
            errors.append("%s: duplicate airport code '%s'" % [where, code])
        seen_codes[code] = true
        var lat: float = float(a.get("lat", 999.0))
        var lon: float = float(a.get("lon", 999.0))
        if lat < -90.0 or lat > 90.0:
            errors.append("%s: lat %f out of range" % [where, lat])
        if lon < -180.0 or lon > 180.0:
            errors.append("%s: lon %f out of range" % [where, lon])
        _require_band(a.get("runway_band", 0), where, "runway_band", errors)
        for weight_key: String in ["passenger_demand", "cargo_demand", "tourism"]:
            var w: float = float(a.get(weight_key, -1.0))
            if w < 0.0 or w > 2.0:
                errors.append("%s: %s %f should be within 0..2" % [where, weight_key, w])

static func _validate_aircraft(db: GameDB, errors: PackedStringArray) -> void:
    if db.aircraft.is_empty():
        errors.append("aircraft.json: no aircraft loaded")
    for id: String in db.aircraft:
        var ac: Dictionary = db.aircraft[id]
        var where: String = "aircraft.json[%s]" % id
        if not id.begins_with("ac_"):
            errors.append("%s: aircraft id must start with 'ac_'" % where)
        for stat_key: String in [
            "passenger_capacity", "cargo_units", "range_nm", "cruise_kts",
            "operating_cost_per_nm", "purchase_cost", "turnaround_seconds_game",
        ]:
            if not ac.has(stat_key):
                errors.append("%s: missing '%s'" % [where, stat_key])
            elif float(ac[stat_key]) <= 0.0:
                errors.append("%s: %s must be positive" % [where, stat_key])
        _require_band(ac.get("runway_band_required", 0), where, "runway_band_required", errors)
        # Art may legitimately not exist yet, but the path must be declared so the
        # art pipeline has a stable destination to generate into.
        for art_key: String in ["art_top", "art_side"]:
            if String(ac.get(art_key, "")).is_empty():
                errors.append("%s: missing '%s' path" % [where, art_key])

static func _validate_upgrades(db: GameDB, errors: PackedStringArray) -> void:
    for id: String in db.airport_upgrades:
        var up: Dictionary = db.airport_upgrades[id]
        var where: String = "airport_upgrades.json[%s]" % id
        if float(up.get("cost", -1.0)) < 0.0:
            errors.append("%s: cost must not be negative" % where)
        if String(up.get("visual_change", "")).is_empty():
            errors.append("%s: every upgrade needs a visual_change" % where)
        var effects: Dictionary = up.get("effects", {})
        if effects.is_empty():
            errors.append("%s: upgrade has no effects" % where)
        for required: Variant in up.get("requires", []):
            var req: String = String(required)
            if not db.airport_upgrades.has(req):
                errors.append("%s: requires unknown upgrade '%s'" % [where, req])
            elif req == id:
                errors.append("%s: upgrade requires itself" % where)

static func _validate_job_templates(db: GameDB, errors: PackedStringArray) -> void:
    var kinds: Array[String] = ["passenger", "cargo", "contract"]
    for id: String in db.job_templates:
        var t: Dictionary = db.job_templates[id]
        var where: String = "job_templates.json[%s]" % id
        var kind: String = String(t.get("kind", ""))
        if not kinds.has(kind):
            errors.append("%s: unknown kind '%s'" % [where, kind])
        if int(t.get("weight", 0)) <= 0:
            errors.append("%s: weight must be positive" % where)
        if float(t.get("reward_multiplier", 0.0)) <= 0.0:
            errors.append("%s: reward_multiplier must be positive" % where)
        if kind == "passenger":
            var lo: int = int(t.get("party_size_min", 0))
            var hi: int = int(t.get("party_size_max", 0))
            if lo <= 0 or hi < lo:
                errors.append("%s: party_size_min/max invalid (%d..%d)" % [where, lo, hi])
        elif kind == "cargo":
            var ulo: int = int(t.get("units_min", 0))
            var uhi: int = int(t.get("units_max", 0))
            if ulo <= 0 or uhi < ulo:
                errors.append("%s: units_min/max invalid (%d..%d)" % [where, ulo, uhi])

static func _validate_layouts(db: GameDB, errors: PackedStringArray) -> void:
    # Every airport the player can open needs a layout, or zooming in lands on
    # an empty scene.
    for airport_id: String in db.airports:
        if db.layout_for_airport(airport_id).is_empty():
            errors.append("cities.json[%s]: no layout matches layout_id" % airport_id)
    for id: String in db.airport_layouts:
        var layout: Dictionary = db.airport_layouts[id]
        var where: String = "airport_layouts.json[%s]" % id
        var airport_id: String = String(layout.get("airport_id", ""))
        if not db.airports.has(airport_id):
            errors.append("%s: unknown airport_id '%s'" % [where, airport_id])
        var runway: Dictionary = layout.get("runway", {})
        if runway.is_empty():
            errors.append("%s: layout has no runway" % where)
        elif float(runway.get("width", 0.0)) <= 0.0:
            errors.append("%s: runway width must be positive" % where)
        var stands: Array = layout.get("stands", [])
        if stands.is_empty():
            errors.append("%s: layout has no stands, nothing could park" % where)
        var stand_ids: Dictionary = {}
        for stand: Variant in stands:
            var stand_id: String = String((stand as Dictionary).get("id", ""))
            if stand_id.is_empty():
                errors.append("%s: a stand is missing its id" % where)
            elif stand_ids.has(stand_id):
                errors.append("%s: duplicate stand id '%s'" % [where, stand_id])
            stand_ids[stand_id] = true

static func _require_band(value: Variant, where: String, key: String, errors: PackedStringArray) -> void:
    var band: int = int(value)
    if band < RUNWAY_BAND_MIN or band > RUNWAY_BAND_MAX:
        errors.append("%s: %s %d must be %d..%d" % [where, key, band, RUNWAY_BAND_MIN, RUNWAY_BAND_MAX])
