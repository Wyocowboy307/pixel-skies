class_name AircraftDetailView
extends Control
## The plane screen: one aircraft, large, with its actual load visible inside it.
##
## This is the management screen, not a status readout. Everything the player
## needs for the core loop is here and in that order:
##
##     here is my plane -> here are the jobs -> these fit -> where to -> fly
##
## Secondary numbers (range, condition, runway, logbook) live in a strip that
## stays shut unless asked for. A screen that leads with them is a maintenance
## dashboard, which is what this replaces.

signal closed()
signal dispatched(flight_id: String)
signal customize_requested(aircraft_id: String)
signal upgrade_requested(aircraft_id: String)

const HERO_SCALE := 2
const HERO_TOP := 40.0
const GROUND_Y := 236.0
const PANEL_W := 170.0
const TRAVEL_SECONDS := 0.42

var sim: Simulation
var aircraft_id := ""

var _anchors: Dictionary = {}
var _sprites: Dictionary = {}
var _font: Font
var _hero_origin := Vector2.ZERO

var _title: Label
var _subtitle: Label
var _fullness: Label
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

## Seat and cargo positions come from the sprite's own metadata, emitted by the
## art pipeline. Where a passenger sits is a property of the drawing, so it is
## shipped with the drawing rather than guessed here.
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

    # The three actions the loop is made of, given equal prominence.
    var actions := HBoxContainer.new()
    actions.set_anchors_preset(Control.PRESET_CENTER_TOP)
    actions.offset_top = 252.0
    actions.offset_left = -160.0
    actions.offset_right = 160.0
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

    var secondary := HBoxContainer.new()
    secondary.set_anchors_preset(Control.PRESET_CENTER_TOP)
    secondary.offset_top = 284.0
    secondary.offset_left = -120.0
    secondary.offset_right = 120.0
    secondary.alignment = BoxContainer.ALIGNMENT_CENTER
    secondary.add_theme_constant_override("separation", 5)
    add_child(secondary)
    var customize := UiTheme.button("CUSTOMIZE")
    customize.pressed.connect(func() -> void: customize_requested.emit(aircraft_id))
    secondary.add_child(customize)
    var upgrade := UiTheme.button("UPGRADE")
    upgrade.pressed.connect(func() -> void: upgrade_requested.emit(aircraft_id))
    secondary.add_child(upgrade)

    _notice = UiTheme.label("", "accent_red")
    _notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _notice.offset_top = 278.0
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
    panel.offset_bottom = -66.0
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

    var limits: Dictionary = Rules.capacity(family, plane.configuration)
    var loaded: Array[Job] = sim.state.loaded_jobs(plane.id)
    var used: Dictionary = Rules.load_used(loaded)

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

## Loading is a physical act: the passenger leaves the list and travels to the
## seat it will occupy. Without that the manifest just silently changes.
func _on_load_job(job: Job, from_control: Control) -> void:
    var plane: AircraftInstance = _plane()
    var before: int = sim.state.loaded_jobs(plane.id).size()
    var result: Dictionary = sim.load_job(aircraft_id, job.id)
    if not bool(result["ok"]):
        _notice.text = String(result["reason"])
        return
    _notice.text = ""
    var slot_index: int = _next_free_slot(job.seats > 0, before)
    # The hop starts where the passenger's face (or the crate) sits on the card.
    var origin: Vector2 = from_control.global_position + Vector2(19.0, from_control.size.y * 0.5)
    var target: Vector2 = _slot_screen_position(job.seats > 0, slot_index)
    var count: int = job.seats if job.seats > 0 else job.cargo_units
    for i in range(count):
        _in_transit.append({
            "t": -0.12 * float(i),          # staggered, so a group boards in file
            "from": origin,
            "to": _slot_screen_position(job.seats > 0, slot_index + i),
            "seat": job.seats > 0,
            "variant": (slot_index + i) % 5,
            "kind": job.presentation,
        })
    refresh()

func _next_free_slot(is_seat: bool, _before: int) -> int:
    var plane: AircraftInstance = _plane()
    var used := 0
    for other: Job in sim.state.loaded_jobs(plane.id):
        used += other.seats if is_seat else other.cargo_units
    var count: int = 0
    for other: Job in sim.state.loaded_jobs(plane.id):
        count += other.seats if is_seat else other.cargo_units
    return maxi(0, count - _slot_count_of_last(is_seat))

func _slot_count_of_last(is_seat: bool) -> int:
    var plane: AircraftInstance = _plane()
    var loaded: Array[Job] = sim.state.loaded_jobs(plane.id)
    if loaded.is_empty():
        return 0
    var last: Job = loaded[loaded.size() - 1]
    return last.seats if is_seat else last.cargo_units

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

func _slot_screen_position(is_seat: bool, index: int) -> Vector2:
    var list: Array = _anchors.get("seats" if is_seat else "cargo", [])
    if list.is_empty():
        return _hero_origin
    var entry: Array = list[clampi(index, 0, list.size() - 1)]
    var slot: float = float(_anchors.get("seat_slot" if is_seat else "cargo_slot", 11))
    return _hero_origin + (Vector2(float(entry[0]), float(entry[1]))
        + Vector2(slot, slot) * 0.5) * float(HERO_SCALE)

func _text(at: Vector2, value: String, colour_key: String = "ink") -> void:
    draw_string(_font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, _colour(colour_key))

func _draw() -> void:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    _draw_scene()
    _draw_hero(plane)
    _draw_route_strip(plane)
    _draw_fullness(plane)
    _draw_in_transit()

## Good weather on the apron, not a dark instrument bay.
func _draw_scene() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), _colour("sky"))
    draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(size.x, 22.0)), _colour("panel_deep"))
    _draw_clouds()
    draw_rect(Rect2(Vector2(0.0, GROUND_Y), Vector2(size.x, size.y - GROUND_Y)),
        _colour("grass"))
    draw_rect(Rect2(Vector2(0.0, GROUND_Y), Vector2(size.x, 2.0)), _colour("grass_light"))
    # Scattered grass tufts, seeded off position so they never crawl.
    for i in range(26):
        var gx: float = float((i * 97) % int(size.x))
        var gy: float = GROUND_Y + 6.0 + float((i * 37) % 40)
        if gy < size.y - 2.0:
            draw_rect(Rect2(Vector2(gx, gy), Vector2(2.0, 1.0)), _colour("grass_dark"))
    # Apron strip the aircraft actually stands on.
    draw_rect(Rect2(Vector2(0.0, GROUND_Y - 10.0), Vector2(size.x, 10.0)), _colour("concrete"))
    draw_rect(Rect2(Vector2(0.0, GROUND_Y - 10.0), Vector2(size.x, 1.0)), _colour("concrete_light"))
    for x in range(0, int(size.x), 48):
        draw_rect(Rect2(Vector2(float(x), GROUND_Y - 9.0), Vector2(1.0, 9.0)), _colour("taxiway"))

## Chunky drifting clouds. Full-width bands read as a barcode, not as weather.
func _draw_clouds() -> void:
    var drift: float = fposmod(_clock * 5.0, size.x + 140.0)
    var seeds: Array[Vector2] = [
        Vector2(40.0, 44.0), Vector2(210.0, 70.0), Vector2(390.0, 40.0),
        Vector2(520.0, 78.0), Vector2(120.0, 108.0), Vector2(460.0, 118.0),
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

## The aircraft with its actual manifest inside it, drawn at a whole-number
## scale so every pixel stays hard.
func _draw_hero(plane: AircraftInstance) -> void:
    var sprite: Texture2D = LiverySprites.side_texture(plane)
    if sprite == null:
        return
    var drawn: Vector2 = sprite.get_size() * float(HERO_SCALE)
    # Seat the aircraft on its own baseline rather than on the bottom of its
    # canvas. Generated art leaves a variable margin under the wheels, so using
    # the canvas height leaves the plane hovering above the apron.
    var baseline: float = float(_anchors.get("baseline", sprite.get_size().y - 1))
    var wheels_at: float = (baseline + 1.0) * float(HERO_SCALE)
    _hero_origin = Vector2(roundf((size.x - drawn.x) * 0.5), roundf(GROUND_Y + 2.0 - wheels_at))
    draw_texture_rect(sprite, Rect2(_hero_origin, drawn), false)

    var loaded: Array[Job] = sim.state.loaded_jobs(plane.id)
    var used: Dictionary = Rules.load_used(loaded)
    _draw_empty_slots(plane, int(used["seats"]), int(used["cargo_units"]))
    var seat_index := 0
    var cargo_index := 0
    for job: Job in loaded:
        for i in range(job.seats):
            _draw_payload(true, seat_index, seat_index % 5, "")
            seat_index += 1
        for i in range(job.cargo_units):
            _draw_payload(false, cargo_index, 0, job.presentation)
            cargo_index += 1
    # Empty seats are still seats: draw the furniture so 0/4 reads as four
    # visibly empty places, not four dark rectangles.
    var limits: Dictionary = Rules.capacity(_family(), plane.configuration)
    var seat_anchors: Array = _anchors.get("seats", [])
    var empty_seat: Texture2D = _texture(_seat_art())
    if empty_seat != null:
        for i in range(seat_index, mini(int(limits["seats"]), seat_anchors.size())):
            var centre: Vector2 = _slot_screen_position(true, i)
            var drawn_seat: Vector2 = empty_seat.get_size() * float(HERO_SCALE)
            draw_texture_rect(empty_seat, Rect2((centre - drawn_seat * 0.5).round(), drawn_seat), false)

## Unfilled seats and hold slots are dashed outlines inside the aircraft, so
## spare capacity is something you see in the plane, not just a number.
func _draw_empty_slots(plane: AircraftInstance, seats_used: int, cargo_used: int) -> void:
    var empty: Texture2D = _texture(_seat_art())
    if empty == null:
        return
    var limits: Dictionary = Rules.capacity(_family(), plane.configuration)
    var drawn: Vector2 = empty.get_size() * float(HERO_SCALE)
    var seat_slots: int = mini(int(limits["seats"]), (_anchors.get("seats", []) as Array).size())
    for index in range(seats_used, seat_slots):
        var centre: Vector2 = _slot_screen_position(true, index)
        draw_texture_rect(empty, Rect2((centre - drawn * 0.5).round(), drawn), false)
    var cargo_slots: int = mini(int(limits["cargo_units"]),
        (_anchors.get("cargo", []) as Array).size())
    for index in range(cargo_used, cargo_slots):
        var centre: Vector2 = _slot_screen_position(false, index)
        draw_texture_rect(empty, Rect2((centre - drawn * 0.5).round(), drawn), false)

func _draw_payload(is_seat: bool, index: int, variant: int, presentation: String) -> void:
    var texture: Texture2D = _payload_texture(is_seat, variant, presentation)
    if texture == null:
        return
    var centre: Vector2 = _slot_screen_position(is_seat, index)
    if is_seat:
        # The seat stays under its passenger: an occupied place reads as a
        # person sitting in a seat, not a person floating in the cabin.
        var seat: Texture2D = _texture(_seat_art())
        if seat != null:
            var seat_drawn: Vector2 = seat.get_size() * float(HERO_SCALE)
            draw_texture_rect(seat, Rect2((centre - seat_drawn * 0.5).round(), seat_drawn), false)
    var drawn: Vector2 = texture.get_size() * float(HERO_SCALE)
    var at: Vector2 = (centre - drawn * 0.5).round()
    if is_seat:
        at += Vector2(1.0, -1.0)      # perched on the cushion, not sunk in it
    draw_texture_rect(texture, Rect2(at, drawn), false)

## Tight generated cabins use the 8px seat; roomy ones the 11px.
func _seat_art() -> String:
    return "ui/seat_small.png" if int(_anchors.get("seat_slot", 10)) <= 8 else "ui/seat_empty.png"

func _payload_texture(is_seat: bool, variant: int, presentation: String) -> Texture2D:
    if is_seat:
        return _texture("people/seated_%d.png" % (variant % 5))
    var kind := "box"
    if presentation.contains("mail"):
        kind = "mail"
    elif presentation.contains("medical"):
        kind = "medical"
    elif presentation.contains("livestock"):
        kind = "livestock"
    return _texture("cargo/cabin_%s.png" % kind)

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

## One plain line: how full is it. The aircraft above already shows this; the
## line just confirms it in words.
func _draw_fullness(plane: AircraftInstance) -> void:
    var limits: Dictionary = Rules.capacity(_family(), plane.configuration)
    var used: Dictionary = Rules.load_used(sim.state.loaded_jobs(plane.id))
    var text: String = "%d/%d SEATS   %d/%d HOLD" % [
        int(used["seats"]), int(limits["seats"]),
        int(used["cargo_units"]), int(limits["cargo_units"])]
    var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
    var box := Rect2(Vector2(roundf((size.x - width) * 0.5) - 6.0, GROUND_Y + 5.0),
        Vector2(width + 12.0, 13.0))
    draw_rect(box, _colour("panel_deep"))
    _text(Vector2(roundf((size.x - width) * 0.5), GROUND_Y + 14.0), text, "panel_light")

## Payload in flight from the job list to its slot, on a shallow arc.
func _draw_in_transit() -> void:
    for item: Dictionary in _in_transit:
        var t: float = clampf(float(item["t"]), 0.0, 1.0)
        if float(item["t"]) < 0.0:
            continue
        var eased: float = t * t * (3.0 - 2.0 * t)
        var from: Vector2 = item["from"]
        var to: Vector2 = item["to"]
        var at: Vector2 = from.lerp(to, eased)
        at.y -= sin(eased * PI) * 26.0        # hop
        var texture: Texture2D = _payload_texture(
            bool(item["seat"]), int(item["variant"]), String(item["kind"]))
        if texture == null:
            continue
        var drawn: Vector2 = texture.get_size() * float(HERO_SCALE)
        draw_texture_rect(texture, Rect2((at - drawn * 0.5).round(), drawn), false)

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
