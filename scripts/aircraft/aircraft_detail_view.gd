class_name AircraftDetailView
extends Control
## The plane detail screen: one aircraft, large, with its load visible.
##
## Panels are attached to physical zones rather than stacked as a form — route
## above the aircraft, load beneath the cabin, range on the left, condition on
## the right (docs/UI_UX.md, "Side-profile aircraft screen"). The aircraft is
## never covered by paragraphs.
##
## The load is drawn as the actual passengers and crates aboard, grouped by
## destination. A row of identical pips tells the player how full the aircraft
## is; this tells them who is on it and where they are going.

signal closed()
signal load_requested()
signal route_requested()
signal depart_requested()

## Layout, in screen pixels at 640x360. The aircraft sits on a hangar floor at
## GROUND_Y with the gauges flanking it, and the load bays sit directly beneath
## the cabin — panels attached to physical zones rather than stacked as a form.
const ROUTE_Y := 24.0
const GROUND_Y := 212.0
const BAY_TOP := 236.0
const COLUMN_WIDTH := 70.0
const SLOT := Vector2(16.0, 21.0)
const CARGO_SLOT := Vector2(19.0, 19.0)
const TRAVELLERS := [
    "traveller_teal", "traveller_orange", "traveller_green",
    "traveller_red", "traveller_grey",
]

var sim: Simulation
var aircraft_id := ""

var _title: Label
var _subtitle: Label
var _refit_panel: PanelContainer
var _refit_list: VBoxContainer
var _depart_button: Button
var _notice: Label
var _font: Font
var _sprites: Dictionary = {}
var _prop_phase := 0.0

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
    refresh()

func _process(delta: float) -> void:
    _prop_phase = fposmod(_prop_phase + delta, 1.0)
    queue_redraw()

func _texture(path: String) -> Texture2D:
    if not _sprites.has(path):
        _sprites[path] = load(path) if ResourceLoader.exists(path) else null
    return _sprites[path]

func _plane() -> AircraftInstance:
    if sim == null:
        return null
    return sim.state.aircraft.get(aircraft_id, null)

func _family() -> Dictionary:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return {}
    return sim.db.aircraft.get(plane.family_id, {})

# ---------------------------------------------------------------------------
# Chrome
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
    var title_row := HBoxContainer.new()
    title_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
    title_row.offset_left = 8.0
    title_row.offset_right = -8.0
    title_row.offset_top = 5.0
    title_row.add_theme_constant_override("separation", 6)
    add_child(title_row)

    _title = UiTheme.label("", "accent_orange")
    title_row.add_child(_title)
    _subtitle = UiTheme.label("", "text_dim")
    title_row.add_child(_subtitle)
    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_row.add_child(gap)
    var close := UiTheme.button("BACK")
    close.pressed.connect(func() -> void: closed.emit())
    title_row.add_child(close)

    var actions := HBoxContainer.new()
    actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    actions.offset_left = 8.0
    actions.offset_right = -8.0
    actions.offset_top = -22.0
    actions.offset_bottom = -6.0
    actions.add_theme_constant_override("separation", 5)
    add_child(actions)

    var load_button := UiTheme.button("LOAD")
    load_button.pressed.connect(func() -> void: load_requested.emit())
    actions.add_child(load_button)
    var route_button := UiTheme.button("ROUTE")
    route_button.pressed.connect(func() -> void: route_requested.emit())
    actions.add_child(route_button)
    _depart_button = UiTheme.button("DEPART")
    _depart_button.pressed.connect(func() -> void: depart_requested.emit())
    actions.add_child(_depart_button)
    var refit := UiTheme.button("REFIT")
    refit.pressed.connect(_toggle_refit)
    actions.add_child(refit)

    _notice = UiTheme.label("", "accent_red")
    actions.add_child(_notice)

    _refit_panel = PanelContainer.new()
    _refit_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    _refit_panel.offset_left = -132.0
    _refit_panel.offset_right = -8.0
    _refit_panel.offset_top = -104.0
    _refit_panel.offset_bottom = -26.0
    _refit_panel.visible = false
    add_child(_refit_panel)
    _refit_list = VBoxContainer.new()
    _refit_list.add_theme_constant_override("separation", 1)
    _refit_panel.add_child(_refit_list)

## Refitting the cabin is the aircraft upgrade the slice actually implements:
## trading seats for hold space is a real decision, not a stat ladder
## (docs/AIRCRAFT_SYSTEM.md, "Upgrade philosophy").
func _toggle_refit() -> void:
    _refit_panel.visible = not _refit_panel.visible
    if _refit_panel.visible:
        _rebuild_refit()

func _rebuild_refit() -> void:
    for child: Node in _refit_list.get_children():
        child.queue_free()
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    _refit_list.add_child(UiTheme.label("CABIN LAYOUT", "accent_orange"))
    var loaded: bool = not sim.state.loaded_jobs(plane.id).is_empty()
    for entry: Variant in _family().get("configurations", []):
        var config: Dictionary = entry
        var id: String = String(config.get("id", ""))
        var mark: String = ">" if id == plane.configuration else " "
        var button := UiTheme.button("%s%s %dP %dC" % [mark,
            String(config.get("name", id)).to_upper().substr(0, 4),
            int(config.get("seats", 0)), int(config.get("cargo_units", 0))])
        button.disabled = loaded
        button.pressed.connect(func() -> void:
            plane.configuration = id
            _rebuild_refit()
            refresh())
        _refit_list.add_child(button)
    if loaded:
        _refit_list.add_child(UiTheme.label("UNLOAD FIRST", "accent_red"))

func refresh() -> void:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    var family: Dictionary = _family()
    _title.text = plane.display_name().to_upper()
    _subtitle.text = "%s · %s" % [String(family.get("name", "")).to_upper(), plane.registration]
    var flying: bool = plane.state == AircraftInstance.State.IN_FLIGHT
    _depart_button.disabled = flying or sim.state.loaded_jobs(plane.id).is_empty()
    _notice.text = "IN FLIGHT" if flying else ""
    queue_redraw()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _colour(key: String) -> Color:
    return PixelPalette.get_colour(key)

## Right-aligned text, measured rather than guessed — a fixed offset clips as
## soon as the string changes length.
func _text_right(right_edge: float, y: float, value: String, colour_key: String = "text") -> void:
    var width: float = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
    _text(Vector2(right_edge - width, y), value, colour_key)

func _text(at: Vector2, value: String, colour_key: String = "text") -> void:
    var origin: Vector2 = at.round()
    draw_string(_font, origin + Vector2.ONE, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
        _colour("outline"))
    draw_string(_font, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, _colour(colour_key))

func _draw() -> void:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    _draw_backdrop(sim.flight_for_aircraft(plane.id) != null)
    _draw_route_strip(plane)
    _draw_stage(plane)
    _draw_gauges(plane)
    _draw_bays(plane)

## A hangar when parked, open sky when airborne. Showing an aircraft standing on
## a hangar floor while it is halfway to Denver is the sort of small lie that
## makes a screen feel like a form rather than a window.
func _draw_backdrop(airborne: bool) -> void:
    draw_rect(Rect2(Vector2.ZERO, size), _colour("ui_bg"))
    var bar_top: float = size.y - 26.0
    draw_rect(Rect2(Vector2(0.0, bar_top), Vector2(size.x, 26.0)), _colour("ui_bg_light"))
    draw_rect(Rect2(Vector2(0.0, bar_top), Vector2(size.x, 1.0)), _colour("ui_border"))
    var back: String = "water_shelf" if airborne else "ui_bg_light"
    draw_rect(Rect2(Vector2(0.0, ROUTE_Y + 18.0), Vector2(size.x, GROUND_Y - ROUTE_Y - 18.0)),
        _colour(back))
    if airborne:
        _draw_clouds()
        # A cloud deck instead of a floor.
        draw_rect(Rect2(Vector2(0.0, GROUND_Y), Vector2(size.x, 16.0)), _colour("ice"))
        for x in range(0, int(size.x), 7):
            var bump: float = 2.0 if (x / 7) % 2 == 0 else 4.0
            draw_rect(Rect2(Vector2(float(x), GROUND_Y - bump), Vector2(7.0, bump)), _colour("ice"))
            draw_rect(Rect2(Vector2(float(x), GROUND_Y - bump), Vector2(5.0, 1.0)), _colour("ice_light"))
        return
    # Roof trusses, drawn sparsely so they suggest depth without competing.
    for x in range(24, int(size.x), 64):
        draw_rect(Rect2(Vector2(float(x), ROUTE_Y + 18.0), Vector2(1.0, 22.0)),
            _colour("ui_bg"))
    draw_rect(Rect2(Vector2(0.0, GROUND_Y), Vector2(size.x, 16.0)), _colour("concrete"))
    draw_rect(Rect2(Vector2(0.0, GROUND_Y), Vector2(size.x, 1.0)), _colour("concrete_light"))
    for x in range(0, int(size.x), 40):
        draw_rect(Rect2(Vector2(float(x), GROUND_Y + 1.0), Vector2(1.0, 10.0)), _colour("taxiway"))

## Chunky pixel clouds drifting behind the aircraft, seeded off the animation
## phase so they move slowly rather than flicker.
func _draw_clouds() -> void:
    var drift: float = _prop_phase * 40.0
    var seeds: Array[Vector2] = [
        Vector2(60.0, 70.0), Vector2(240.0, 54.0), Vector2(430.0, 88.0),
        Vector2(560.0, 62.0), Vector2(150.0, 160.0), Vector2(500.0, 168.0),
    ]
    for index in range(seeds.size()):
        var seed: Vector2 = seeds[index]
        var x: float = fposmod(seed.x - drift, size.x + 90.0) - 45.0
        var scale: float = 1.0 + float(index % 3) * 0.45
        for block in range(3):
            var w: float = (14.0 + float(block) * 8.0) * scale
            var h: float = (5.0 + float(block % 2) * 3.0) * scale
            draw_rect(Rect2(Vector2(roundf(x + float(block) * 9.0 * scale),
                roundf(seed.y + float(block % 2) * 4.0)), Vector2(roundf(w), roundf(h))),
                _colour("ice_light" if block == 1 else "ice"))

## Route strip sits above the aircraft: where it is, where it is going, when it
## gets there.
func _draw_route_strip(plane: AircraftInstance) -> void:
    draw_rect(Rect2(Vector2(0.0, ROUTE_Y), Vector2(size.x, 17.0)), _colour("ui_bg_light"))
    draw_rect(Rect2(Vector2(0.0, ROUTE_Y), Vector2(size.x, 1.0)), _colour("ui_border"))
    draw_rect(Rect2(Vector2(0.0, ROUTE_Y + 16.0), Vector2(size.x, 1.0)), _colour("ui_border"))

    var leg: FlightLeg = sim.flight_for_aircraft(plane.id)
    var text_y: float = ROUTE_Y + 12.0
    if leg != null:
        var origin: Dictionary = sim.db.airports.get(leg.origin_id, {})
        var destination: Dictionary = sim.db.airports.get(leg.destination_id, {})
        var now: float = sim.now()
        _text(Vector2(10.0, text_y), String(origin.get("code", "")), "text_dim")
        var bar := Rect2(Vector2(40.0, ROUTE_Y + 7.0), Vector2(size.x - 210.0, 3.0))
        draw_rect(bar, _colour("ui_bg"))
        var done: float = leg.progress(now)
        draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * done), bar.size.y)),
            _colour("accent_orange"))
        # The aircraft's own position on its route.
        var marker_x: float = roundf(bar.position.x + bar.size.x * done)
        draw_rect(Rect2(Vector2(marker_x - 1.0, bar.position.y - 3.0), Vector2(3.0, 9.0)),
            _colour("white"))
        _text(Vector2(bar.end.x + 6.0, text_y), String(destination.get("code", "")), "accent_orange")
        _text_right(size.x - 8.0, text_y,
            "%s · %s" % [leg.phase_name(now).to_upper(), UiTheme.duration(leg.seconds_remaining(now))],
            "text")
    else:
        var where: Dictionary = sim.db.airports.get(plane.location_id, {})
        _text(Vector2(10.0, text_y), "AT %s · %s" % [String(where.get("code", "?")),
            String(where.get("city", "")).to_upper()], "text")
        var ready: bool = not sim.state.loaded_jobs(plane.id).is_empty()
        _text_right(size.x - 8.0, text_y,
            "LOADED · PICK A ROUTE" if ready else "EMPTY · READY TO LOAD",
            "accent_green" if ready else "text_dim")

## The aircraft at 1:1, standing on the hangar floor.
func _draw_stage(plane: AircraftInstance) -> void:
    var sprite: Texture2D = AircraftSprites.side_sprite(plane.family_id)
    if sprite == null:
        return
    var drawn: Vector2 = sprite.get_size()
    var at := Vector2(roundf((size.x - drawn.x) * 0.5), roundf(GROUND_Y + 2.0 - drawn.y))
    if sim.flight_for_aircraft(plane.id) == null:
        # Contact shadow, so a parked aircraft sits on the floor rather than hovering.
        draw_rect(Rect2(Vector2(at.x + 18.0, GROUND_Y + 1.0), Vector2(drawn.x - 36.0, 2.0)),
            _colour("shadow"))
    draw_texture(sprite, at)
    # Slow beacon on the fin: a parked aircraft that still feels alive.
    if _prop_phase < 0.45:
        draw_rect(Rect2(at + Vector2(22.0, 8.0), Vector2(2.0, 2.0)), _colour("accent_red"))

func _column_backing(at: Vector2, height: float) -> void:
    var rect := Rect2(at - Vector2(3.0, 3.0), Vector2(COLUMN_WIDTH + 6.0, height))
    draw_rect(rect, _colour("ui_bg"))
    draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), _colour("ui_border"))
    draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 1.0), Vector2(rect.size.x, 1.0)),
        _colour("ui_border"))

func _column(at: Vector2, title: String) -> void:
    draw_rect(Rect2(at, Vector2(COLUMN_WIDTH, 1.0)), _colour("ui_border"))
    _text(at + Vector2(2.0, 10.0), title, "text_dim")

## Range on the left, condition and logbook on the right — attached to the
## aircraft rather than stacked in a table.
func _draw_gauges(plane: AircraftInstance) -> void:
    var family: Dictionary = _family()
    var left := Vector2(8.0, 52.0)
    # The columns need their own ground: over the airborne sky backdrop the
    # labels were being read against passing clouds.
    _column_backing(left, 132.0)
    _column_backing(Vector2(size.x - COLUMN_WIDTH - 8.0, 52.0), 132.0)
    _column(left, "RANGE")
    _text(left + Vector2(2.0, 22.0), "%d NM" % int(family.get("range_nm", 0)), "accent_teal")

    # With a route chosen the bar shows how much of the range it eats, which is
    # the only form of this number that helps a decision.
    var used := 0.0
    var leg: FlightLeg = sim.flight_for_aircraft(plane.id)
    if leg != null and float(family.get("range_nm", 0)) > 0.0:
        used = clampf(leg.distance_nm / float(family.get("range_nm", 1)), 0.0, 1.0)
    _bar(left + Vector2(2.0, 28.0), Vector2(COLUMN_WIDTH - 6.0, 5.0),
        used if used > 0.0 else 1.0, "accent_teal" if used < 0.85 else "accent_red")
    if used > 0.0:
        _text(left + Vector2(2.0, 46.0), "%d%% USED" % roundi(used * 100.0), "text_dim")
    else:
        _text(left + Vector2(2.0, 46.0), "FULL RANGE", "text_dim")

    _column(left + Vector2(0.0, 60.0), "RUNWAY")
    _text(left + Vector2(2.0, 82.0),
        Rules.band_name(int(family.get("runway_band_required", 1))).to_upper(), "text")
    _column(left + Vector2(0.0, 96.0), "HOME")
    var home: Dictionary = sim.db.airports.get(plane.home_base_id, {})
    _text(left + Vector2(2.0, 118.0), String(home.get("code", "—")), "text")

    var right := Vector2(size.x - COLUMN_WIDTH - 8.0, 52.0)
    _column(right, "CONDITION")
    var condition: float = plane.condition
    _bar(right + Vector2(2.0, 16.0), Vector2(COLUMN_WIDTH - 6.0, 5.0), condition,
        "accent_green" if condition > 0.6 else "accent_yellow")
    _text(right + Vector2(2.0, 34.0), "%d%%" % roundi(condition * 100.0), "text")

    # The logbook is what makes an old airframe worth keeping.
    _column(right + Vector2(0.0, 48.0), "LOGBOOK")
    _text(right + Vector2(2.0, 70.0), "%d LEGS" % plane.legs, "text")
    _text(right + Vector2(2.0, 82.0), "%.0f HRS" % plane.hours, "text_dim")
    _column(right + Vector2(0.0, 96.0), "EARNED")
    _text(right + Vector2(2.0, 118.0), UiTheme.money(plane.lifetime_revenue), "accent_orange")

func _bar(at: Vector2, bar_size: Vector2, fraction: float, colour_key: String) -> void:
    draw_rect(Rect2(at, bar_size), _colour("ui_bg"))
    draw_rect(Rect2(at, Vector2(roundf(bar_size.x * clampf(fraction, 0.0, 1.0)), bar_size.y)),
        _colour(colour_key))
    draw_rect(Rect2(at, Vector2(bar_size.x, 1.0)), _colour("ui_border"))

## Cabin and hold, drawn as the actual passengers and crates aboard, grouped by
## where they are going. A row of identical pips says how full the aircraft is;
## this says who is on it and where they are going.
func _draw_bays(plane: AircraftInstance) -> void:
    var limits: Dictionary = Rules.capacity(_family(), plane.configuration)
    var loaded: Array[Job] = sim.state.loaded_jobs(plane.id)
    var passengers: Array[Job] = []
    var freight: Array[Job] = []
    for job: Job in loaded:
        if job.seats > 0:
            passengers.append(job)
        if job.cargo_units > 0:
            freight.append(job)

    var seats: int = int(limits["seats"])
    var holds: int = int(limits["cargo_units"])
    var cabin_width: float = _bay_width(seats, passengers, SLOT, true)
    var hold_width: float = _bay_width(holds, freight, CARGO_SLOT, false)
    var total: float = cabin_width + hold_width + 28.0
    var x: float = roundf((size.x - total) * 0.5)

    # The bays get their own panel: labels sitting directly on the hangar floor
    # were unreadable against the concrete.
    var panel := Rect2(Vector2(x - 10.0, BAY_TOP - 12.0), Vector2(total + 20.0, 62.0))
    draw_rect(panel, _colour("ui_bg_light"))
    draw_rect(Rect2(panel.position, Vector2(panel.size.x, 1.0)), _colour("ui_border"))
    draw_rect(Rect2(Vector2(panel.position.x, panel.end.y - 1.0), Vector2(panel.size.x, 1.0)),
        _colour("ui_border"))
    _draw_bay(Vector2(x, BAY_TOP), "CABIN", seats, passengers, true)
    _draw_bay(Vector2(x + cabin_width + 28.0, BAY_TOP), "HOLD", holds, freight, false)

func _bay_width(capacity: int, jobs: Array[Job], slot: Vector2, is_cabin: bool) -> float:
    var used := 0
    for job: Job in jobs:
        used += job.seats if is_cabin else job.cargo_units
    var groups: int = jobs.size()
    return float(capacity) * (slot.x + 1.0) + float(groups) * 5.0 + 4.0

func _draw_bay(at: Vector2, title: String, capacity: int, jobs: Array[Job],
        is_cabin: bool) -> void:
    var slot: Vector2 = SLOT if is_cabin else CARGO_SLOT
    var used := 0
    for job: Job in jobs:
        used += job.seats if is_cabin else job.cargo_units
    _text(at, title, "text_dim")
    _text(at + Vector2(38.0, 0.0), "%d/%d" % [used, capacity],
        "accent_green" if used > 0 else "text_dim")

    var cursor: Vector2 = at + Vector2(0.0, 6.0)
    var index := 0
    var colour_index := 0
    for job: Job in jobs:
        var count: int = job.seats if is_cabin else job.cargo_units
        var group_start: Vector2 = cursor
        for i in range(count):
            _draw_slot(cursor, slot, job, is_cabin, colour_index)
            cursor.x += slot.x + 1.0
            index += 1
        # Destination under the group: this is what makes the load legible.
        var destination: Dictionary = sim.db.airports.get(job.destination_id, {})
        var width: float = cursor.x - group_start.x - 1.0
        draw_rect(Rect2(Vector2(group_start.x, group_start.y + slot.y + 2.0), Vector2(width, 1.0)),
            _colour("accent_orange"))
        _text(Vector2(group_start.x + 1.0, group_start.y + slot.y + 12.0),
            String(destination.get("code", "")), "accent_orange")
        cursor.x += 5.0
        colour_index += 1

    for i in range(capacity - index):
        _draw_slot(cursor, slot, null, is_cabin, 0)
        cursor.x += slot.x + 1.0

func _draw_slot(at: Vector2, slot: Vector2, job: Job, is_cabin: bool, colour_index: int) -> void:
    var filled: bool = job != null
    draw_rect(Rect2(at, slot), _colour("ui_bg_light" if filled else "ui_bg"))
    draw_rect(Rect2(at, Vector2(slot.x, 1.0)), _colour("ui_border" if filled else "ui_bg_light"))
    draw_rect(Rect2(at + Vector2(0.0, slot.y - 1.0), Vector2(slot.x, 1.0)),
        _colour("ui_border" if filled else "ui_bg_light"))
    if not filled:
        # An empty slot still reads as a seat or a pallet space waiting to be
        # filled, rather than as blank background.
        var mark: Color = _colour("ui_border")
        draw_rect(Rect2(at, slot), _colour("ui_bg"))
        for edge_x in [at.x, at.x + slot.x - 1.0]:
            draw_rect(Rect2(Vector2(edge_x, at.y + 2.0), Vector2(1.0, slot.y - 4.0)), mark)
        draw_rect(Rect2(at + Vector2(4.0, roundf(slot.y * 0.55)), Vector2(slot.x - 8.0, 1.0)), mark)
        return
    var path := ""
    if is_cabin:
        path = "res://assets/art/people/%s.png" % TRAVELLERS[colour_index % TRAVELLERS.size()]
    else:
        var kind: String = "box"
        if job.presentation.contains("mail"):
            kind = "mail"
        elif job.presentation.contains("medical"):
            kind = "medical"
        elif job.presentation.contains("livestock"):
            kind = "livestock"
        path = "res://assets/art/cargo/crate_%s.png" % kind
    var texture: Texture2D = _texture(path)
    if texture == null:
        return
    var offset: Vector2 = ((slot - texture.get_size()) * 0.5).round()
    draw_texture(texture, (at + offset).round())
