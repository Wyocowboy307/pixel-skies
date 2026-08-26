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

const HERO_SCALE := 2
const HERO_TOP := 40.0
const GROUND_Y := 236.0
const PANEL_W := 150.0
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
    _font = load("res://assets/art/ui/font5x7.fnt")
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
    var path: String = "res://assets/art/aircraft/%s/%s_side.json" % [key, key]
    if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) == TYPE_DICTIONARY:
        _anchors = parsed

func _plane() -> AircraftInstance:
    if sim == null:
        return null
    return sim.state.aircraft.get(aircraft_id, null)

func _family() -> Dictionary:
    var plane: AircraftInstance = _plane()
    return {} if plane == null else sim.db.aircraft.get(plane.family_id, {})

func _texture(path: String) -> Texture2D:
    if not _sprites.has(path):
        _sprites[path] = load(path) if ResourceLoader.exists(path) else null
    return _sprites[path]

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

    var load_button := UiTheme.action("LOAD")
    load_button.pressed.connect(func() -> void: _set_mode("load"))
    actions.add_child(load_button)
    var route_button := UiTheme.action("ROUTE")
    route_button.pressed.connect(func() -> void: _set_mode("route"))
    actions.add_child(route_button)
    _fly_button = UiTheme.action("FLY")
    _fly_button.pressed.connect(_on_fly)
    actions.add_child(_fly_button)

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

## A job card, not a table row: icon, plain language, destination, reward.
func _job_card(job: Job) -> Control:
    var plane: AircraftInstance = _plane()
    var verdict: Dictionary = Rules.can_load(plane, _family(), job,
        sim.state.loaded_jobs(plane.id))
    var allowed: bool = bool(verdict["ok"])

    var button := Button.new()
    button.custom_minimum_size = Vector2(0.0, 26.0)
    button.clip_contents = true
    button.pressed.connect(func() -> void: _on_load_job(job, button))

    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.add_theme_constant_override("separation", 4)
    button.add_child(row)
    row.add_child(UiTheme.icon(UiTheme.kind_icon(job.kind)))

    var column := VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_theme_constant_override("separation", 0)
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(column)
    var destination: Dictionary = sim.db.airports.get(job.destination_id, {})
    column.add_child(UiTheme.label("%s TO %s" % [UiTheme.job_summary(job),
        String(destination.get("code", "?"))], "ink" if allowed else "ink_soft"))
    column.add_child(UiTheme.label(UiTheme.money(job.reward) if allowed
        else String(verdict["reason"]), "accent_green" if allowed else "accent_red"))
    return button

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
    var origin: Vector2 = from_control.global_position + from_control.size * 0.5
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

func _route_card(destination_id: String) -> Control:
    var verdict: Dictionary = sim.dispatch_check(aircraft_id, destination_id)
    var preview: Dictionary = sim.dispatch_preview(aircraft_id, destination_id)
    var allowed: bool = bool(verdict["ok"])
    var destination: Dictionary = sim.db.airports.get(destination_id, {})

    var button := Button.new()
    button.custom_minimum_size = Vector2(0.0, 26.0)
    button.clip_contents = true
    button.pressed.connect(func() -> void:
        _selected_destination = destination_id
        _mode = ""
        refresh())
    var column := VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.set_anchors_preset(Control.PRESET_FULL_RECT)
    column.add_theme_constant_override("separation", 0)
    button.add_child(column)
    column.add_child(UiTheme.label("%s %s" % [String(destination.get("code", "")),
        String(destination.get("city", ""))], "ink" if allowed else "ink_soft"))
    if allowed:
        column.add_child(UiTheme.label("%s · %s" % [
            UiTheme.duration(float(preview.get("duration_seconds", 0.0))),
            UiTheme.money(int(preview.get("profit", 0)))], "accent_green"))
    else:
        column.add_child(UiTheme.label(String(verdict["reason"]), "accent_red"))
    return button

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
    var sprite: Texture2D = AircraftSprites.side_sprite(plane.family_id)
    if sprite == null:
        return
    var drawn: Vector2 = sprite.get_size() * float(HERO_SCALE)
    _hero_origin = Vector2(roundf((size.x - drawn.x) * 0.5), roundf(GROUND_Y - drawn.y + 6.0))
    draw_texture_rect(sprite, Rect2(_hero_origin, drawn), false)

    var loaded: Array[Job] = sim.state.loaded_jobs(plane.id)
    var seat_index := 0
    var cargo_index := 0
    for job: Job in loaded:
        for i in range(job.seats):
            _draw_payload(true, seat_index, seat_index % 5, "")
            seat_index += 1
        for i in range(job.cargo_units):
            _draw_payload(false, cargo_index, 0, job.presentation)
            cargo_index += 1

func _draw_payload(is_seat: bool, index: int, variant: int, presentation: String) -> void:
    var texture: Texture2D = _payload_texture(is_seat, variant, presentation)
    if texture == null:
        return
    var centre: Vector2 = _slot_screen_position(is_seat, index)
    var drawn: Vector2 = texture.get_size() * float(HERO_SCALE)
    draw_texture_rect(texture, Rect2((centre - drawn * 0.5).round(), drawn), false)

func _payload_texture(is_seat: bool, variant: int, presentation: String) -> Texture2D:
    if is_seat:
        return _texture("res://assets/art/people/seated_%d.png" % (variant % 5))
    var kind := "box"
    if presentation.contains("mail"):
        kind = "mail"
    elif presentation.contains("medical"):
        kind = "medical"
    elif presentation.contains("livestock"):
        kind = "livestock"
    return _texture("res://assets/art/cargo/cabin_%s.png" % kind)

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
