class_name AircraftDetailView
extends Control
## The plane screen: the aircraft outside on the apron, and its cabin below as
## a side-view cross-section built from the curated interior art.
##
## Top half: the hero aircraft in good weather. Bottom half: THE CABIN STRIP —
## a slice through the fuselage with a luggage hold at the tail, a row of real
## passenger seats, oval portholes in the wall and a galley trolley up front.
## Loading is visible furniture: each passenger fills a seat, each cargo unit
## drops a bag in the hold. A full plane looks busy; an empty one looks like an
## empty cabin, not a form with zeroes in it.
##
##     here is my plane -> here are the jobs -> these fit -> where to -> fly

signal closed()
signal dispatched(flight_id: String)
signal customize_requested(aircraft_id: String)
signal upgrade_requested(aircraft_id: String)
## A payload sprite finished its hop into the cabin. A sound layer can sit on
## this without the view knowing it exists.
signal payload_boarded(is_seat: bool)

const HERO_SCALE := 2
const APRON_Y := 164.0            ## wheel line the hero stands on
const APRON_BOTTOM := 212.0
const STRIP_TOP := 212.0          ## fuselage cross-section band
const STRIP_BOTTOM := 352.0
const WALL_TOP := 220.0           ## interior wall inside the skin
const FLOOR_TOP := 340.0
const SEAT_Y := 246.0             ## seat sprite top (98 tall, feet in carpet)
const SEAT_W := 57.0
const SEAT_PITCH := 60.0
const SEAT_ZONE_X := 222.0        ## first seat, after the hold + bulkhead door
const SEAT_POSITIONS := 6         ## four base seats + two from Cabin Plus
const HOLD_X := 8.0
const HOLD_W := 138.0
const PANEL_W := 170.0
const TRAVEL_SECONDS := 0.42

## Hold luggage: art and top-left position per cargo slot, floor-first so a
## filling hold stacks upward like someone actually loaded it.
const HOLD_SLOTS: Array = [
    ["cabin/bag_duffel_navy.png", Vector2(14.0, 291.0)],
    ["cabin/bag_duffel_grey.png", Vector2(78.0, 290.0)],
    ["cabin/bag_case_blue.png", Vector2(18.0, 222.0)],
    ["cabin/bag_backpack.png", Vector2(80.0, 222.0)],
    ["cabin/bag_duffel_black.png", Vector2(42.0, 178.0)],
    ["cabin/bag_case_blue.png", Vector2(96.0, 153.0)],
]
const PASSENGER_VARIANTS := 6

var sim: Simulation
var aircraft_id := ""

var _anchors: Dictionary = {}
var _sprites: Dictionary = {}
var _font: Font
var _hero_origin := Vector2.ZERO

var _title: Label
var _subtitle: Label
var _notice: Label
var _fly_button: Button
var _job_panel: PanelContainer
var _job_list: VBoxContainer
var _route_panel: PanelContainer
var _route_list: VBoxContainer
var _details_panel: PanelContainer
var _details_row: HBoxContainer
var _details_button: Button

var _mode := ""                    ## "" | "load" | "route"
var _details_open := false
var _selected_destination := ""
## Payload sprites currently flying from the job list into the aircraft.
var _in_transit: Array[Dictionary] = []
var _clock := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size
    get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _font = load(AssetPaths.resolve_file("ui/font5x7.fnt"))
    _build_chrome()
    set_process(true)

func bind(simulation: Simulation, id: String) -> void:
    sim = simulation
    aircraft_id = id
    _load_anchors()
    refresh()

## The hero sprite's baseline comes from the art pipeline's anchor metadata, so
## the aircraft stands on its wheels regardless of canvas margins.
func _load_anchors() -> void:
    _anchors = {}
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    var key: String = plane.family_id.replace("ac_", "")
    var path: String = AssetPaths.resolve_file("aircraft/%s/%s_side.json" % [key, key])
    if not FileAccess.file_exists(path):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) == TYPE_DICTIONARY:
        _anchors = parsed

func _plane() -> AircraftInstance:
    if sim == null:
        return null
    return sim.state.aircraft.get(aircraft_id, null)

func _family() -> Dictionary:
    # Effective stats: purchased upgrades included.
    return {} if _plane() == null else sim.family_of(_plane())

func _texture(logical: String) -> Texture2D:
    if not _sprites.has(logical):
        _sprites[logical] = AssetPaths.load_texture(logical)
    return _sprites[logical]

func _colour(key: String) -> Color:
    return PixelPalette.get_colour(key)

func _process(delta: float) -> void:
    _clock += delta
    var still: Array[Dictionary] = []
    for item: Dictionary in _in_transit:
        item["t"] = float(item["t"]) + delta / TRAVEL_SECONDS
        if float(item["t"]) < 1.0:
            still.append(item)
        else:
            payload_boarded.emit(bool(item["seat"]))
    _in_transit = still
    queue_redraw()

# ---------------------------------------------------------------------------
# Chrome
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
    var header := HBoxContainer.new()
    header.set_anchors_preset(Control.PRESET_TOP_WIDE)
    header.offset_left = 6.0
    header.offset_right = -6.0
    header.offset_top = 5.0
    header.add_theme_constant_override("separation", 5)
    add_child(header)
    _title = UiTheme.label("", "panel_light")
    header.add_child(_title)
    _subtitle = UiTheme.label("", "sky_light")
    header.add_child(_subtitle)
    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(gap)
    var back := UiTheme.button("BACK")
    back.pressed.connect(func() -> void: closed.emit())
    header.add_child(back)

    # One row on the tarmac between the aircraft and its cabin: the three verbs
    # of the loop at full size, the two workshop doors small beside them.
    var actions := HBoxContainer.new()
    actions.set_anchors_preset(Control.PRESET_CENTER_TOP)
    actions.offset_top = 170.0
    actions.offset_left = -210.0
    actions.offset_right = 210.0
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 8)
    add_child(actions)

    var load_button := UiTheme.big_button("LOAD", "green")
    load_button.pressed.connect(func() -> void: _set_mode("load"))
    actions.add_child(load_button)
    var route_button := UiTheme.big_button("ROUTE", "blue")
    route_button.pressed.connect(func() -> void: _set_mode("route"))
    actions.add_child(route_button)
    _fly_button = UiTheme.big_button("FLY", "orange")
    _fly_button.pressed.connect(_on_fly)
    actions.add_child(_fly_button)
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(6.0, 0.0)
    actions.add_child(spacer)
    var customize := UiTheme.button("CUSTOMIZE")
    customize.pressed.connect(func() -> void: customize_requested.emit(aircraft_id))
    actions.add_child(customize)
    var upgrade := UiTheme.button("UPGRADE")
    upgrade.pressed.connect(func() -> void: upgrade_requested.emit(aircraft_id))
    actions.add_child(upgrade)

    _notice = UiTheme.label("", "accent_orange_light")
    _notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _notice.offset_top = 203.0
    _notice.offset_left = -150.0
    _notice.offset_right = 150.0
    _notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_notice)

    _job_panel = _side_panel(true)
    _job_list = _panel_list(_job_panel, "JOBS HERE")
    _route_panel = _side_panel(false)
    _route_list = _panel_list(_route_panel, "WHERE TO?")

    _build_details()

func _side_panel(on_left: bool) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_LEFT_WIDE if on_left else Control.PRESET_RIGHT_WIDE)
    if on_left:
        panel.offset_left = 6.0
        panel.offset_right = 6.0 + PANEL_W
    else:
        panel.offset_left = -6.0 - PANEL_W
        panel.offset_right = -6.0
    panel.offset_top = 40.0
    panel.offset_bottom = -30.0
    panel.visible = false
    add_child(panel)
    return panel

func _panel_list(panel: PanelContainer, title: String) -> VBoxContainer:
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 2)
    panel.add_child(column)
    column.add_child(UiTheme.label(title, "panel_deep"))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)
    var list := VBoxContainer.new()
    list.add_theme_constant_override("separation", 2)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)
    return list

## Secondary stats stay shut. They are available, not in the way.
func _build_details() -> void:
    _details_button = UiTheme.button("DETAILS +")
    _details_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _details_button.offset_left = 6.0
    _details_button.offset_top = -20.0
    _details_button.offset_bottom = -6.0
    _details_button.pressed.connect(func() -> void:
        _details_open = not _details_open
        _refresh_details())
    add_child(_details_button)

    _details_panel = PanelContainer.new()
    _details_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _details_panel.offset_left = 6.0
    _details_panel.offset_right = -6.0
    _details_panel.offset_top = -46.0
    _details_panel.offset_bottom = -24.0
    _details_panel.visible = false
    add_child(_details_panel)
    _details_row = HBoxContainer.new()
    _details_row.add_theme_constant_override("separation", 10)
    _details_panel.add_child(_details_row)

func _set_mode(mode: String) -> void:
    _mode = "" if _mode == mode else mode
    _notice.text = ""
    refresh()

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func refresh() -> void:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    var family: Dictionary = _family()
    _title.text = plane.display_name().to_upper()
    _subtitle.text = String(family.get("name", "")).to_upper()

    var loaded: Array[Job] = sim.state.loaded_jobs(plane.id)

    var flying: bool = plane.state == AircraftInstance.State.IN_FLIGHT
    _fly_button.disabled = flying or loaded.is_empty() or _selected_destination.is_empty()
    # A disabled FLY says what unlocks it, so the biggest verb in the game is
    # never a mystery.
    if _notice.text.is_empty():
        if flying:
            _notice.text = ""
        elif loaded.is_empty():
            _notice.text = "LOAD SOMETHING FIRST"
        elif _selected_destination.is_empty():
            _notice.text = "PICK A ROUTE"

    _job_panel.visible = _mode == "load" and not flying
    _route_panel.visible = _mode == "route" and not flying
    if _job_panel.visible:
        _refresh_jobs()
    if _route_panel.visible:
        _refresh_routes()
    _refresh_details()
    queue_redraw()

func _refresh_jobs() -> void:
    for child: Node in _job_list.get_children():
        child.queue_free()
    var plane: AircraftInstance = _plane()
    var board: Array[Job] = sim.state.jobs_at(plane.location_id)
    board.sort_custom(func(a: Job, b: Job) -> bool: return a.reward > b.reward)
    for job: Job in board:
        _job_list.add_child(_job_card(job))

## A job card, not a table row: a face or a crate, the destination big, plain
## language for the load, the payout in green and a clear FITS / NO SPACE call.
func _job_card(job: Job) -> Control:
    var plane: AircraftInstance = _plane()
    var verdict: Dictionary = Rules.can_load(plane, _family(), job,
        sim.state.loaded_jobs(plane.id))
    var allowed: bool = bool(verdict["ok"])
    var destination: Dictionary = sim.db.airports.get(job.destination_id, {})

    var card := VisualCard.new()
    card.font = _font
    card.face = _job_face(job)
    card.title = String(destination.get("code", "?"))
    card.subtitle = UiTheme.job_summary(job)
    card.value = UiTheme.money(job.reward)
    card.value_icon = _texture("ui/icons/money.png")
    card.badge_ok = allowed
    card.badge_text = "FITS" if allowed else "NO SPACE"
    if not allowed:
        card.reason = _short_reason(String(verdict["reason"]))
    card.pressed.connect(func() -> void: _on_load_job(job, card))
    return card

## The rules explain at sentence length; a 40 px card gets the plain kernel.
## The full sentence still appears in the notice line if the player insists.
func _short_reason(reason: String) -> String:
    var text: String = reason.to_lower()
    if text.contains("needed,"):
        # "2 seats needed, 1 free" -> "1 FREE"
        return text.get_slice("needed,", 1).strip_edges().to_upper()
    if text.begins_with("no seats"):
        return "NO SEATS"
    if text.contains("hold full"):
        return "HOLD FULL"
    if text.contains("out of range"):
        return "TOO FAR"
    if text.contains("runway"):
        return "SHORT RUNWAY"
    if text.contains("already"):
        return "IN FLIGHT"
    if text.contains("not open"):
        return "LOCKED"
    if text.begins_with("load at least"):
        return "LOAD JOBS FIRST"
    return reason.to_upper()

## Who or what is asking to fly: a portrait for people, the crate for cargo.
func _job_face(job: Job) -> Texture2D:
    if job.kind == "passenger":
        return _texture("people/portrait_%d.png" % (absi(hash(job.id)) % 5))
    var kind := "box"
    if job.presentation.contains("mail"):
        kind = "mail"
    elif job.presentation.contains("medical"):
        kind = "medical"
    elif job.presentation.contains("livestock"):
        kind = "livestock"
    return _texture("cargo/crate_%s.png" % kind)

## Loading is a physical act: the passenger leaves the list, hops across the
## screen and lands in the seat they will occupy. Without that the manifest
## just silently changes.
func _on_load_job(job: Job, from_control: Control) -> void:
    var plane: AircraftInstance = _plane()
    var used_before: Dictionary = Rules.load_used(sim.state.loaded_jobs(plane.id))
    var result: Dictionary = sim.load_job(aircraft_id, job.id)
    if not bool(result["ok"]):
        _notice.text = String(result["reason"])
        return
    _notice.text = ""
    var is_seat: bool = job.seats > 0
    var first_index: int = int(used_before["seats"]) if is_seat \
        else int(used_before["cargo_units"])
    # The hop starts where the passenger's face (or the crate) sits on the card.
    var origin: Vector2 = from_control.global_position \
        + Vector2(from_control.size.x + 14.0, from_control.size.y * 0.5)
    var count: int = job.seats if is_seat else job.cargo_units
    for i in range(count):
        _in_transit.append({
            "t": -0.12 * float(i),          # staggered, so a group boards in file
            "from": origin,
            "to": _slot_screen_position(is_seat, first_index + i),
            "seat": is_seat,
            "index": first_index + i,
            "variant": (first_index + i) % PASSENGER_VARIANTS,
        })
    refresh()

func _refresh_routes() -> void:
    for child: Node in _route_list.get_children():
        child.queue_free()
    for candidate: String in sim.state.unlocked_airport_ids:
        if candidate == _plane().location_id:
            continue
        _route_list.add_child(_route_card(candidate))

## Route cards get the same visual treatment as jobs: destination big, the
## flight in plain terms, expected profit, and whether the plane can make it.
func _route_card(destination_id: String) -> Control:
    var verdict: Dictionary = sim.dispatch_check(aircraft_id, destination_id)
    var preview: Dictionary = sim.dispatch_preview(aircraft_id, destination_id)
    var allowed: bool = bool(verdict["ok"])
    var destination: Dictionary = sim.db.airports.get(destination_id, {})

    var card := VisualCard.new()
    card.font = _font
    card.face = _texture("ui/icons/route.png")
    card.title = String(destination.get("code", ""))
    card.subtitle = "%s · %s" % [String(destination.get("city", "")).to_upper(),
        UiTheme.duration(float(preview.get("duration_seconds", 0.0)))]
    if allowed:
        var profit: int = int(preview.get("profit", 0))
        card.value = UiTheme.money(profit)
        card.value_bad = profit < 0
        card.value_icon = _texture("ui/icons/money.png")
    card.badge_ok = allowed
    card.badge_text = "READY" if allowed else "NO GO"
    if not allowed:
        card.reason = _short_reason(String(verdict["reason"]))
    card.highlighted = destination_id == _selected_destination
    card.pressed.connect(func() -> void:
        _selected_destination = destination_id
        _mode = ""
        refresh())
    return card

func _refresh_details() -> void:
    _details_button.text = "DETAILS -" if _details_open else "DETAILS +"
    _details_panel.visible = _details_open
    if not _details_open:
        return
    for child: Node in _details_row.get_children():
        child.queue_free()
    var plane: AircraftInstance = _plane()
    var family: Dictionary = _family()
    var entries: Array = [
        ["range", "%d NM" % int(family.get("range_nm", 0))],
        ["runway", Rules.band_name(int(family.get("runway_band_required", 1))).to_upper()],
        ["condition", "%d%%" % roundi(plane.condition * 100.0)],
        ["clock", "%d LEGS" % plane.legs],
        ["money", UiTheme.money(plane.lifetime_revenue)],
        ["plane", plane.registration],
    ]
    for entry: Array in entries:
        var cell := HBoxContainer.new()
        cell.add_theme_constant_override("separation", 3)
        _details_row.add_child(cell)
        cell.add_child(UiTheme.icon(String(entry[0])))
        cell.add_child(UiTheme.label(String(entry[1]), "ink"))

func _on_fly() -> void:
    var result: Dictionary = sim.dispatch(aircraft_id, _selected_destination)
    if not bool(result["ok"]):
        _notice.text = String(result["reason"])
        refresh()
        return
    dispatched.emit(String(result.get("flight_id", "")))
    closed.emit()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _seat_position(index: int) -> Vector2:
    return Vector2(SEAT_ZONE_X + float(index) * SEAT_PITCH, SEAT_Y)

## Where a payload lands, in this control's coordinates. Seats are passenger
## chest height; cargo is the centre of the bag that will appear.
func _slot_screen_position(is_seat: bool, index: int) -> Vector2:
    if is_seat:
        var seat: Vector2 = _seat_position(clampi(index, 0, SEAT_POSITIONS - 1))
        return (seat + Vector2(35.0, 34.0)).round()
    var slot: Array = HOLD_SLOTS[clampi(index, 0, HOLD_SLOTS.size() - 1)]
    var texture: Texture2D = _texture(String(slot[0]))
    var half: Vector2 = texture.get_size() * 0.5 if texture != null else Vector2(24.0, 20.0)
    return ((slot[1] as Vector2) + half).round()

func _text(at: Vector2, value: String, colour_key: String = "ink") -> void:
    draw_string(_font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, _colour(colour_key))

func _draw() -> void:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    _draw_scene()
    _draw_hero(plane)
    _draw_cabin(plane)
    _draw_route_strip(plane)
    _draw_in_transit()

## Good weather on the apron above, the cabin cross-section below.
func _draw_scene() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), _colour("sky"))
    draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(size.x, 22.0)), _colour("panel_deep"))
    _draw_clouds()
    # A line of distant grass, then the concrete the aircraft stands on.
    draw_rect(Rect2(Vector2(0.0, APRON_Y - 8.0), Vector2(size.x, 4.0)), _colour("grass"))
    draw_rect(Rect2(Vector2(0.0, APRON_Y - 4.0), Vector2(size.x, 2.0)), _colour("grass_dark"))
    draw_rect(Rect2(Vector2(0.0, APRON_Y - 2.0), Vector2(size.x, APRON_BOTTOM - APRON_Y + 2.0)),
        _colour("concrete"))
    draw_rect(Rect2(Vector2(0.0, APRON_Y - 2.0), Vector2(size.x, 1.0)), _colour("concrete_light"))
    for x in range(24, int(size.x), 48):
        draw_rect(Rect2(Vector2(float(x), APRON_Y + 4.0), Vector2(1.0, 6.0)), _colour("taxiway"))
    for x in range(8, int(size.x), 34):
        draw_rect(Rect2(Vector2(float(x), APRON_Y + 20.0), Vector2(18.0, 2.0)),
            _colour("accent_yellow"))

## Chunky drifting clouds. Full-width bands read as a barcode, not as weather.
func _draw_clouds() -> void:
    var drift: float = fposmod(_clock * 5.0, size.x + 140.0)
    var seeds: Array[Vector2] = [
        Vector2(40.0, 38.0), Vector2(210.0, 62.0), Vector2(390.0, 34.0),
        Vector2(520.0, 70.0), Vector2(120.0, 96.0), Vector2(460.0, 104.0),
    ]
    for index in range(seeds.size()):
        var seed: Vector2 = seeds[index]
        var x: float = fposmod(seed.x - drift, size.x + 140.0) - 70.0
        var scale: float = 1.0 + float(index % 3) * 0.5
        for block in range(4):
            var w: float = roundf((18.0 + float(block % 3) * 12.0) * scale)
            var h: float = roundf((6.0 + float(block % 2) * 4.0) * scale)
            var bx: float = roundf(x + float(block) * 11.0 * scale)
            var by: float = roundf(seed.y + float(block % 2) * 5.0)
            draw_rect(Rect2(Vector2(bx, by), Vector2(w, h)),
                _colour("sky_light" if block % 2 == 0 else "white"))

## The aircraft at a whole-number scale, seated on its own baseline so the
## wheels touch the concrete no matter what margin the canvas carries.
func _draw_hero(plane: AircraftInstance) -> void:
    var sprite: Texture2D = LiverySprites.side_texture(plane)
    if sprite == null:
        return
    var drawn: Vector2 = sprite.get_size() * float(HERO_SCALE)
    var baseline: float = float(_anchors.get("baseline", sprite.get_size().y - 1))
    var wheels_at: float = (baseline + 1.0) * float(HERO_SCALE)
    _hero_origin = Vector2(roundf((size.x - drawn.x) * 0.5), roundf(APRON_Y - wheels_at))
    # Contact shadow first, so the aircraft sits on the concrete instead of
    # hovering over it.
    draw_rect(Rect2(Vector2(roundf(_hero_origin.x + drawn.x * 0.14), APRON_Y + 1.0),
        Vector2(roundf(drawn.x * 0.68), 3.0)), _colour("shadow"))
    draw_texture_rect(sprite, Rect2(_hero_origin, drawn), false)

# ---------------------------------------------------------------------------
# The cabin strip
# ---------------------------------------------------------------------------

func _draw_cabin(plane: AircraftInstance) -> void:
    var limits: Dictionary = Rules.capacity(_family(), plane.configuration)
    var loaded: Array[Job] = sim.state.loaded_jobs(plane.id)
    var used: Dictionary = Rules.load_used(loaded)
    var seats_used: int = mini(int(used["seats"]), SEAT_POSITIONS)
    var cargo_used: int = mini(int(used["cargo_units"]), HOLD_SLOTS.size())
    var seat_limit: int = mini(int(limits["seats"]), SEAT_POSITIONS)
    var cargo_limit: int = int(limits["cargo_units"])

    _draw_fuselage_band()
    _draw_hold(cargo_used, cargo_limit)
    _draw_portholes(seat_limit)
    _draw_dressing()
    _draw_seat_row(seats_used, seat_limit)
    _draw_capacity_line(seats_used, seat_limit, cargo_used, cargo_limit)

## The cross-section shell: cream skin, interior wall, carpet, cut ends.
func _draw_fuselage_band() -> void:
    # Outer skin above and below the interior.
    draw_rect(Rect2(Vector2(0.0, STRIP_TOP), Vector2(size.x, size.y - STRIP_TOP)),
        _colour("panel_light"))
    draw_rect(Rect2(Vector2(0.0, STRIP_TOP), Vector2(size.x, 1.0)), _colour("white"))
    draw_rect(Rect2(Vector2(0.0, STRIP_TOP + 1.0), Vector2(size.x, 2.0)), _colour("card_hi"))
    draw_rect(Rect2(Vector2(0.0, WALL_TOP - 1.0), Vector2(size.x, 1.0)), _colour("panel_shade"))
    # Interior wall.
    draw_rect(Rect2(Vector2(0.0, WALL_TOP), Vector2(size.x, FLOOR_TOP - WALL_TOP)),
        _colour("card"))
    draw_rect(Rect2(Vector2(0.0, WALL_TOP), Vector2(size.x, 1.0)), _colour("card_hi"))
    # Carpet, tiled from the curated slice.
    var carpet: Texture2D = _texture("cabin/floor_carpet.png")
    if carpet != null:
        var cw: float = carpet.get_size().x
        var x := 0.0
        while x < size.x:
            draw_texture(carpet, Vector2(x, FLOOR_TOP).round())
            x += cw
    draw_rect(Rect2(Vector2(0.0, FLOOR_TOP), Vector2(size.x, 1.0)), _colour("panel_shade"))
    # Belly skin under the carpet.
    draw_rect(Rect2(Vector2(0.0, STRIP_BOTTOM), Vector2(size.x, size.y - STRIP_BOTTOM)),
        _colour("panel_shade"))
    draw_rect(Rect2(Vector2(0.0, STRIP_BOTTOM), Vector2(size.x, 1.0)), _colour("panel_edge"))

## The tail hold: a darker bay with ribs, one real bag per loaded cargo unit,
## netted down once the stack gets serious.
func _draw_hold(cargo_used: int, _cargo_limit: int) -> void:
    draw_rect(Rect2(Vector2(HOLD_X, WALL_TOP), Vector2(HOLD_W, FLOOR_TOP - WALL_TOP)),
        _colour("panel_shade"))
    draw_rect(Rect2(Vector2(HOLD_X, WALL_TOP), Vector2(HOLD_W, 2.0)), _colour("panel_deep"))
    draw_rect(Rect2(Vector2(HOLD_X, WALL_TOP), Vector2(2.0, FLOOR_TOP - WALL_TOP)),
        _colour("panel_deep"))
    draw_rect(Rect2(Vector2(HOLD_X + HOLD_W - 2.0, WALL_TOP),
        Vector2(2.0, FLOOR_TOP - WALL_TOP)), _colour("panel_deep"))
    for rib in range(3):
        var rx: float = HOLD_X + 34.0 + float(rib) * 36.0
        draw_rect(Rect2(Vector2(rx, WALL_TOP + 2.0), Vector2(2.0, FLOOR_TOP - WALL_TOP - 2.0)),
            _colour("panel"))
    # The net hangs against the wall whether or not anything is under it yet;
    # bags load in front of it so the manifest stays readable.
    var net: Texture2D = _texture("cabin/cargo_net.png")
    if net != null:
        draw_texture(net, Vector2(26.0, 268.0))
    for index in range(cargo_used):
        var slot: Array = HOLD_SLOTS[index]
        var texture: Texture2D = _texture(String(slot[0]))
        if texture != null:
            draw_texture(texture, (slot[1] as Vector2).round())

## Portholes in the wall between the headrests: one per seat position, plus a
## spare aft of the galley so the wall never dead-ends.
func _draw_portholes(_seat_limit: int) -> void:
    var porthole: Texture2D = _texture("cabin/porthole.png")
    if porthole == null:
        return
    for index in range(SEAT_POSITIONS):
        var at := Vector2(SEAT_ZONE_X + float(index) * SEAT_PITCH + 38.0, 224.0)
        draw_texture(porthole, at.round())

## Bulkhead door aft, galley trolley forward: the strip reads as one aircraft,
## not a row of seats floating in cream.
func _draw_dressing() -> void:
    var door: Texture2D = _texture("cabin/door_exit.png")
    if door != null:
        # Between the hold and the cabin.
        draw_texture(door, Vector2(HOLD_X + HOLD_W + 2.0, FLOOR_TOP - 96.0).round())
    var cart: Texture2D = _texture("cabin/galley_cart.png")
    if cart != null:
        draw_texture(cart, Vector2(586.0, FLOOR_TOP - 98.0).round())

## Seats up to capacity, greyed sockets beyond it, passengers in the occupied
## ones. Passenger first, seat over it: the sprite peeks over the backrest and
## rests a hand on the armrest, which reads as sitting IN the seat.
func _draw_seat_row(seats_used: int, seat_limit: int) -> void:
    var seat: Texture2D = _texture("cabin/seat_tan.png")
    if seat == null:
        return
    var pending: Dictionary = {}
    for item: Dictionary in _in_transit:
        if bool(item["seat"]):
            pending[int(item.get("index", -1))] = true
    for index in range(SEAT_POSITIONS):
        var at: Vector2 = _seat_position(index)
        if index >= seat_limit:
            # Not installed in this configuration: a grey socket, so spare
            # airframe capacity is something you can see and buy into.
            draw_texture_rect(seat, Rect2(at.round(), seat.get_size()), false,
                Color(0.56, 0.58, 0.64))
            continue
        var boarded: bool = index < seats_used and not pending.has(index)
        if boarded:
            var passenger: Texture2D = _texture(
                "people/cabin_passenger_%d.png" % (index % PASSENGER_VARIANTS))
            if passenger != null:
                draw_texture(passenger, (at + Vector2(12.0, 4.0)).round())
        draw_texture(seat, at.round())

## One quiet line on the skin band saying the same thing the furniture shows.
func _draw_capacity_line(seats_used: int, seat_limit: int,
        cargo_used: int, cargo_limit: int) -> void:
    var text: String = "%d/%d SEATS   %d/%d HOLD" % [
        seats_used, seat_limit, cargo_used, cargo_limit]
    var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
    _text(Vector2(size.x - width - 8.0, STRIP_TOP + 8.0), text, "panel_deep")

func _draw_route_strip(plane: AircraftInstance) -> void:
    var leg: FlightLeg = sim.flight_for_aircraft(plane.id)
    var y := 26.0
    var text := ""
    var colour := "sky_light"
    if leg != null:
        var destination: Dictionary = sim.db.airports.get(leg.destination_id, {})
        text = "%s  %s  %s" % [leg.phase_name(sim.now()).to_upper(),
            String(destination.get("code", "")),
            UiTheme.duration(leg.seconds_remaining(sim.now()))]
        colour = "accent_orange_light"
    elif not _selected_destination.is_empty():
        var chosen: Dictionary = sim.db.airports.get(_selected_destination, {})
        var preview: Dictionary = sim.dispatch_preview(aircraft_id, _selected_destination)
        text = "TO %s  %s  %s" % [String(chosen.get("code", "")),
            UiTheme.duration(float(preview.get("duration_seconds", 0.0))),
            UiTheme.money(int(preview.get("profit", 0)))]
        colour = "accent_green"
    else:
        var here: Dictionary = sim.db.airports.get(plane.location_id, {})
        text = "AT %s · %s" % [String(here.get("code", "?")),
            String(here.get("city", "")).to_upper()]
    var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
    var box := Rect2(Vector2(roundf((size.x - width) * 0.5) - 6.0, y - 9.0),
        Vector2(width + 12.0, 13.0))
    draw_rect(box, _colour("panel_deep"))
    draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), _colour("panel_edge"))
    _text(Vector2(roundf((size.x - width) * 0.5), y), text, colour)

## Payload in flight from the job list to its place in the cabin, on a shallow
## arc. Passengers hop as the same sprite that will sit in the seat.
func _draw_in_transit() -> void:
    for item: Dictionary in _in_transit:
        var t: float = clampf(float(item["t"]), 0.0, 1.0)
        if float(item["t"]) < 0.0:
            continue
        var eased: float = t * t * (3.0 - 2.0 * t)
        var from: Vector2 = item["from"]
        var to: Vector2 = item["to"]
        var at: Vector2 = from.lerp(to, eased)
        at.y -= sin(eased * PI) * 30.0        # hop
        var texture: Texture2D = _transit_texture(item)
        if texture == null:
            continue
        draw_texture(texture, (at - texture.get_size() * 0.5).round())

func _transit_texture(item: Dictionary) -> Texture2D:
    if bool(item["seat"]):
        return _texture("people/cabin_passenger_%d.png" % int(item["variant"]))
    var index: int = int(item.get("index", item.get("variant", 0)))
    var slot: Array = HOLD_SLOTS[clampi(index, 0, HOLD_SLOTS.size() - 1)]
    return _texture(String(slot[0]))

# ---------------------------------------------------------------------------
# Visual card
# ---------------------------------------------------------------------------

## One job or route as a chunky pixel card: sprite on the left, the destination
## big in the middle, money on the right, verdict badge in the corner. Drawn by
## hand so every element lands on a whole pixel and nothing ever half-clips.
class VisualCard extends Button:
    const CARD_HEIGHT := 40.0
    const PAD := 5.0
    const ICON_BOX := 28.0
    const TITLE_SIZE := 14
    const SMALL_SIZE := 7

    var font: Font = null
    var face: Texture2D = null
    var title := ""
    var subtitle := ""
    var value := ""
    var value_bad := false
    var value_icon: Texture2D = null
    var reason := ""
    var badge_text := ""
    var badge_ok := true
    var highlighted := false

    func _init() -> void:
        custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
        clip_contents = true
        texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

    func _colour(key: String) -> Color:
        return PixelPalette.get_colour(key)

    func _draw() -> void:
        if font == null:
            return
        var width: float = size.x
        var text_x: float = PAD + ICON_BOX + 4.0

        if face != null:
            var drawn: Vector2 = face.get_size() * 2.0
            var icon_at := Vector2(PAD + roundf((ICON_BOX - drawn.x) * 0.5),
                roundf((CARD_HEIGHT - drawn.y) * 0.5))
            draw_texture_rect(face, Rect2(icon_at, drawn), false)

        # Destination, big and navy. The one word the player scans for.
        draw_string(font, Vector2(text_x, 17.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1,
            TITLE_SIZE, _colour("ui_bg"))

        var badge_width: float = font.get_string_size(
            badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x + 8.0
        var subtitle_room: float = width - PAD - badge_width - 4.0 - text_x
        draw_string(font, Vector2(text_x, 27.0), _fit(subtitle, subtitle_room),
            HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, _colour("ink_soft"))
        if not reason.is_empty():
            draw_string(font, Vector2(text_x, 36.0), _fit(reason, subtitle_room),
                HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, _colour("accent_red"))

        if not value.is_empty():
            var value_width: float = font.get_string_size(
                value, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x
            var value_x: float = width - PAD - value_width
            draw_string(font, Vector2(value_x, 14.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1,
                SMALL_SIZE, _colour("accent_red" if value_bad else "accent_green"))
            if value_icon != null:
                draw_texture(value_icon, Vector2(value_x - 12.0, 5.0).round())

        if not badge_text.is_empty():
            _draw_badge(Vector2(width - PAD - badge_width, CARD_HEIGHT - PAD - 11.0),
                Vector2(badge_width, 11.0))

        if highlighted:
            draw_rect(Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)),
                _colour("accent_orange"), false, 1.0)

    func _draw_badge(at: Vector2, badge_size: Vector2) -> void:
        at = at.round()
        draw_rect(Rect2(at - Vector2.ONE, badge_size + Vector2(2.0, 2.0)), _colour("outline"))
        draw_rect(Rect2(at, badge_size), _colour("accent_green" if badge_ok else "accent_red"))
        draw_string(font, at + Vector2(4.0, 8.0), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
            SMALL_SIZE, _colour("ink" if badge_ok else "white"))

    ## Truncate to the space available rather than letting text half-clip.
    func _fit(text: String, room: float) -> String:
        if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x <= room:
            return text
        var out: String = text
        while out.length() > 1 and font.get_string_size(
                out + "..", HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x > room:
            out = out.substr(0, out.length() - 1)
        return out + ".."
