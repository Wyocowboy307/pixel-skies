extends TestCase
## Data integrity: the JSON must describe a coherent, playable world.

func _db() -> GameDB:
    var db := GameDB.new()
    db.load_all()
    return db

func test_data_validates_clean() -> void:
    var errors: PackedStringArray = DataValidator.validate(_db())
    check(errors.is_empty(), "data validation errors: %s" % ", ".join(errors))

func test_slice_content_present() -> void:
    var db: GameDB = _db()
    for id: String in ["apt_bzn", "apt_bil", "apt_den"]:
        check(db.airports.has(id), "missing vertical-slice airport %s" % id)
    for id: String in ["ac_trailhopper_4", "ac_twinwing_8", "ac_highline_19"]:
        check(db.aircraft.has(id), "missing vertical-slice aircraft %s" % id)

func test_starter_aircraft_can_fly_starter_routes() -> void:
    # The Trailhopper is the aircraft the player starts with; if it cannot legally
    # reach BIL the vertical slice has no opening move.
    var db: GameDB = _db()
    var trailhopper: Dictionary = db.aircraft["ac_trailhopper_4"]
    var bzn: Dictionary = db.airports["apt_bzn"]
    var bil: Dictionary = db.airports["apt_bil"]
    var distance: float = WorldProjection.great_circle_nm(
        float(bzn["lat"]), float(bzn["lon"]), float(bil["lat"]), float(bil["lon"]))
    check(distance < float(trailhopper["range_nm"]), "BZN->BIL is beyond Trailhopper range")
    check(int(bil["runway_band"]) >= int(trailhopper["runway_band_required"]),
        "BIL runway cannot accept the Trailhopper")
