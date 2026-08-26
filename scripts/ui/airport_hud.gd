class_name AirportHud
extends Control
## The management layer over an airport scene: job board, aircraft load view and
## route/dispatch.
##
## Panels are docked to the edges so the airfield stays visible between them.
## Every legality question is answered by the simulation, and refusals are shown
## before the player commits, never after (docs/UI_UX.md, "Depart interaction").

signal destination_hovered(airport_id: String)
signal dispatch_completed(flight_id: String)

const PANEL_WIDTH := 300.0
const DOCK_WIDTH := 620.0

var sim: Simulation
var airport_id := ""
var selected_aircraft_id := ""
var routing := false
var selected_destination := ""

var _job_list: VBoxContainer
var _job_header: Label
var _dock: PanelContainer
var _dock_title: Label
var _dock_subtitle: Label
var _config_button: Button
var _seat_row: HBoxContainer
var _hold_row: HBoxContainer
var _manifest: VBoxContainer
var _notice: Label
var _route_button: Button
var _route_panel: PanelContainer
var _route_list: VBoxContainer
var _preview: Label
var _dispatch_button: Button

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # A Control created in code under a CanvasLayer gets no layout pass, so its
    # rect stays zero and every anchored child collapses into the corner. The
    # size has to be taken from the viewport and kept in step with it.
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _track_viewport_size()
    _build_job_panel()
    _build_dock()
    _build_route_panel()

func _track_viewport_size() -> void:
    size = get_viewport_rect().size
    var viewport: Viewport = get_viewport()
    if not viewport.size_changed.is_connected(_on_viewport_resized):
        viewport.size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
    size = get_viewport_rect().size

func bind(simulation: Simulation, at_airport: String) -> void:
    sim = simulation
    airport_id = at_airport
    sim.jobs_changed.connect(_on_jobs_changed)
    sim.flight_dispatched.connect(_on_flight_dispatched)
    sim.flight_arrived.connect(func(_settlement: Dictionary) -> void: refresh())
    var parked: Array[AircraftInstance] = sim.state.aircraft_at(airport_id)
    if not parked.is_empty():
        selected_aircraft_id = parked[0].id
    refresh()

func select_aircraft(aircraft_id: String) -> void:
    selected_aircraft_id = aircraft_id
    routing = false
    selected_destination = ""
    refresh()

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build_job_panel() -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiTheme.panel())
    panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
    panel.offset_left = 16.0
    panel.offset_right = 16.0 + PANEL_WIDTH
    panel.offset_top = 68.0
    panel.offset_bottom = -250.0
    add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 6)
    panel.add_child(column)

    _job_header = UiTheme.label("Jobs", 16, UiTheme.TEXT)
    column.add_child(_job_header)
    column.add_child(UiTheme.label("Click a job to load it", 11, UiTheme.TEXT_DIM))

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)

    _job_list = VBoxContainer.new()
    _job_list.add_theme_constant_override("separation", 4)
    _job_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_job_list)

func _build_dock() -> void:
    _dock = PanelContainer.new()
    _dock.add_theme_stylebox_override("panel", UiTheme.panel())
    _dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _dock.offset_left = -DOCK_WIDTH * 0.5
    _dock.offset_right = DOCK_WIDTH * 0.5
    _dock.offset_top = -232.0
    _dock.offset_bottom = -16.0
    add_child(_dock)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 5)
    _dock.add_child(column)

    _dock_title = UiTheme.label("", 17, UiTheme.ACCENT)
    column.add_child(_dock_title)
    var identity := HBoxContainer.new()
    identity.add_theme_constant_override("separation", 10)
    column.add_child(identity)
    _dock_subtitle = UiTheme.label("", 12, UiTheme.TEXT_DIM)
    identity.add_child(_dock_subtitle)
    var identity_spacer := Control.new()
    identity_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    identity.add_child(identity_spacer)
    _config_button = UiTheme.button("Layout")
    _config_button.tooltip_text = "Trade seats for hold space"
    _config_button.pressed.connect(_on_configuration_pressed)
    identity.add_child(_config_button)

    var seats := HBoxContainer.new()
    seats.add_theme_constant_override("separation", 8)
    column.add_child(seats)
    seats.add_child(UiTheme.label("Seats", 12, UiTheme.TEXT_DIM))
    _seat_row = HBoxContainer.new()
    _seat_row.add_theme_constant_override("separation", 3)
    seats.add_child(_seat_row)

    var hold := HBoxContainer.new()
    hold.add_theme_constant_override("separation", 8)
    column.add_child(hold)
    hold.add_child(UiTheme.label("Hold", 12, UiTheme.TEXT_DIM))
    _hold_row = HBoxContainer.new()
    _hold_row.add_theme_constant_override("separation", 3)
    hold.add_child(_hold_row)

    _manifest = VBoxContainer.new()
    _manifest.add_theme_constant_override("separation", 3)
    column.add_child(_manifest)

    _notice = UiTheme.label("", 12, UiTheme.BAD)
    column.add_child(_notice)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 8)
    column.add_child(actions)

    _route_button = UiTheme.button("Choose destination")
    _route_button.pressed.connect(_on_route_pressed)
    actions.add_child(_route_button)

    _preview = UiTheme.label("", 12, UiTheme.TEXT)
    actions.add_child(_preview)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(spacer)

    _dispatch_button = UiTheme.button("Depart")
    _dispatch_button.disabled = true
    _dispatch_button.pressed.connect(_on_dispatch_pressed)
    actions.add_child(_dispatch_button)

func _build_route_panel() -> void:
    _route_panel = PanelContainer.new()
    _route_panel.add_theme_stylebox_override("panel", UiTheme.panel())
    _route_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
    _route_panel.offset_left = -16.0 - PANEL_WIDTH
    _route_panel.offset_right = -16.0
    _route_panel.offset_top = 68.0
    _route_panel.offset_bottom = -250.0
    _route_panel.visible = false
    add_child(_route_panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 6)
    _route_panel.add_child(column)
    column.add_child(UiTheme.label("Where to?", 16, UiTheme.TEXT))
    column.add_child(UiTheme.label("Time, cost and profit before you commit", 11, UiTheme.TEXT_DIM))

    _route_list = VBoxContainer.new()
    _route_list.add_theme_constant_override("separation", 4)
    column.add_child(_route_list)

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _on_jobs_changed(_airport_id: String) -> void:
    refresh()

func _on_flight_dispatched(leg: FlightLeg) -> void:
    routing = false
    selected_destination = ""
    dispatch_completed.emit(leg.id)
    refresh()

func refresh() -> void:
    if sim == null:
        return
    _refresh_jobs()
    _refresh_dock()
    _refresh_route()

func _refresh_jobs() -> void:
    for child: Node in _job_list.get_children():
        child.queue_free()
    var board: Array[Job] = sim.state.jobs_at(airport_id)
    board.sort_custom(func(a: Job, b: Job) -> bool: return a.reward > b.reward)
    var airport: Dictionary = sim.db.airports.get(airport_id, {})
    _job_header.text = "Jobs at %s · %d waiting" % [String(airport.get("code", "")), board.size()]
    for job: Job in board:
        _job_list.add_child(_job_row(job))

func _job_row(job: Job) -> Control:
    var verdict: Dictionary = _load_verdict(job)
    var allowed: bool = bool(verdict["ok"])

    var button := Button.new()
    button.custom_minimum_size = Vector2(0.0, 44.0)
    button.add_theme_stylebox_override("normal", UiTheme.row_style(UiTheme.ROW))
    button.add_theme_stylebox_override("hover", UiTheme.row_style(UiTheme.ROW_HOVER))
    button.add_theme_stylebox_override("pressed", UiTheme.row_style(UiTheme.ROW_HOVER))
    button.tooltip_text = String(verdict["reason"])
    button.pressed.connect(func() -> void: _on_job_pressed(job))
    button.mouse_entered.connect(func() -> void: destination_hovered.emit(job.destination_id))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.set_anchors_preset(Control.PRESET_FULL_RECT)
    button.add_child(row)

    var tag := UiTheme.label(UiTheme.kind_glyph(job.kind), 11, UiTheme.kind_color(job.kind))
    tag.custom_minimum_size = Vector2(30.0, 0.0)
    row.add_child(tag)

    var middle := VBoxContainer.new()
    middle.add_theme_constant_override("separation", 0)
    middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(middle)

    var destination: Dictionary = sim.db.airports.get(job.destination_id, {})
    var headline: String = "%s  %s" % [String(destination.get("code", "?")), job.describe()]
    middle.add_child(UiTheme.label(headline, 13, UiTheme.TEXT if allowed else UiTheme.TEXT_DIM))
    # A refused job explains itself in place rather than failing silently on click.
    var detail: String = String(verdict["reason"]) if not allowed else String(destination.get("city", ""))
    middle.add_child(UiTheme.label(detail, 10, UiTheme.BAD if not allowed else UiTheme.TEXT_DIM))

    var money_column := VBoxContainer.new()
    money_column.add_theme_constant_override("separation", 0)
    money_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(money_column)
    money_column.add_child(UiTheme.label(UiTheme.money(job.reward), 13,
        UiTheme.GOOD if allowed else UiTheme.TEXT_DIM))
    var remaining: float = job.seconds_remaining(sim.now())
    var urgent: bool = remaining < 600.0
    var patience := UiTheme.label(UiTheme.duration(remaining) + " left", 10,
        UiTheme.BAD if urgent else UiTheme.TEXT_DIM)
    patience.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    money_column.add_child(patience)
    return button

func _load_verdict(job: Job) -> Dictionary:
    var plane: AircraftInstance = sim.state.aircraft.get(selected_aircraft_id, null)
    if plane == null:
        return Rules.no("Select an aircraft first")
    var family: Dictionary = sim.db.aircraft.get(plane.family_id, {})
    return Rules.can_load(plane, family, job, sim.state.loaded_jobs(plane.id))

func _on_job_pressed(job: Job) -> void:
    var result: Dictionary = sim.load_job(selected_aircraft_id, job.id)
    _notice.text = "" if bool(result["ok"]) else String(result["reason"])
    refresh()

func _refresh_dock() -> void:
    var plane: AircraftInstance = sim.state.aircraft.get(selected_aircraft_id, null)
    if plane == null:
        _dock.visible = false
        return
    _dock.visible = true
    var family: Dictionary = sim.db.aircraft.get(plane.family_id, {})
    _dock_title.text = "%s · %s" % [plane.display_name(), String(family.get("name", ""))]
    _dock_subtitle.text = "%s · %s · range %d nm · needs %s runway" % [
        plane.registration, _configuration_name(family, plane.configuration),
        int(family.get("range_nm", 0)),
        Rules.band_name(int(family.get("runway_band_required", 1)))]

    _config_button.text = "Layout: %s" % _configuration_name(family, plane.configuration)
    var limits: Dictionary = Rules.capacity(family, plane.configuration)
    var loaded: Array[Job] = sim.state.loaded_jobs(plane.id)
    var used: Dictionary = Rules.load_used(loaded)
    _fill_slots(_seat_row, int(used["seats"]), int(limits["seats"]), UiTheme.PASSENGER)
    _fill_slots(_hold_row, int(used["cargo_units"]), int(limits["cargo_units"]), UiTheme.CARGO)

    for child: Node in _manifest.get_children():
        child.queue_free()
    if loaded.is_empty():
        _manifest.add_child(UiTheme.label("Empty — load a job from the left", 11, UiTheme.TEXT_DIM))
    else:
        for job: Job in loaded:
            _manifest.add_child(_manifest_row(job))

## Cycles Passenger / Freighter / Combi. Refused while anything is aboard,
## because silently dumping a loaded payload would be worse than saying no.
func _on_configuration_pressed() -> void:
    var plane: AircraftInstance = sim.state.aircraft.get(selected_aircraft_id, null)
    if plane == null:
        return
    if not sim.state.loaded_jobs(plane.id).is_empty():
        _notice.text = "Unload before changing the cabin layout"
        return
    var family: Dictionary = sim.db.aircraft.get(plane.family_id, {})
    var options: Array = family.get("configurations", [])
    if options.size() < 2:
        return
    var current := 0
    for index in range(options.size()):
        if String((options[index] as Dictionary).get("id", "")) == plane.configuration:
            current = index
    plane.configuration = String((options[(current + 1) % options.size()] as Dictionary).get("id", ""))
    _notice.text = ""
    refresh()

func _configuration_name(family: Dictionary, configuration: String) -> String:
    for entry: Variant in family.get("configurations", []):
        var config: Dictionary = entry
        if String(config.get("id", "")) == configuration:
            return String(config.get("name", configuration))
    return configuration

## Capacity as discrete pips: how full the aircraft is has to be readable at a
## glance, not a fraction to be parsed.
func _fill_slots(row: HBoxContainer, used: int, total: int, color: Color) -> void:
    for child: Node in row.get_children():
        child.queue_free()
    if total <= 0:
        row.add_child(UiTheme.label("none", 11, UiTheme.TEXT_DIM))
        return
    for i in range(total):
        var pip := ColorRect.new()
        pip.custom_minimum_size = Vector2(14.0, 14.0)
        pip.color = color if i < used else UiTheme.SLOT_EMPTY
        row.add_child(pip)
    row.add_child(UiTheme.label("%d/%d" % [used, total], 11, UiTheme.TEXT_DIM))

func _manifest_row(job: Job) -> Control:
    var button := Button.new()
    button.add_theme_stylebox_override("normal", UiTheme.row_style(UiTheme.ROW))
    button.add_theme_stylebox_override("hover", UiTheme.row_style(UiTheme.ROW_HOVER))
    button.custom_minimum_size = Vector2(0.0, 24.0)
    button.tooltip_text = "Click to unload"
    button.pressed.connect(func() -> void:
        sim.unload_job(selected_aircraft_id, job.id)
        refresh())
    var destination: Dictionary = sim.db.airports.get(job.destination_id, {})
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.add_theme_constant_override("separation", 8)
    button.add_child(row)
    row.add_child(UiTheme.label(UiTheme.kind_glyph(job.kind), 10, UiTheme.kind_color(job.kind)))
    row.add_child(UiTheme.label("to %s · %s" % [String(destination.get("code", "?")), job.describe()],
        11, UiTheme.TEXT))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(spacer)
    row.add_child(UiTheme.label(UiTheme.money(job.reward), 11, UiTheme.GOOD))
    return button

# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------

func _on_route_pressed() -> void:
    routing = not routing
    refresh()

func _refresh_route() -> void:
    _route_panel.visible = routing
    _route_button.text = "Hide destinations" if routing else "Choose destination"
    for child: Node in _route_list.get_children():
        child.queue_free()
    if not routing:
        _preview.text = ""
        _dispatch_button.disabled = true
        return

    for candidate_id: String in sim.state.unlocked_airport_ids:
        if candidate_id == airport_id:
            continue
        _route_list.add_child(_route_row(candidate_id))
    _update_preview()

func _route_row(destination_id: String) -> Control:
    var verdict: Dictionary = sim.dispatch_check(selected_aircraft_id, destination_id)
    var preview: Dictionary = sim.dispatch_preview(selected_aircraft_id, destination_id)
    var allowed: bool = bool(verdict["ok"])
    var destination: Dictionary = sim.db.airports.get(destination_id, {})

    var button := Button.new()
    button.custom_minimum_size = Vector2(0.0, 52.0)
    var chosen: bool = destination_id == selected_destination
    button.add_theme_stylebox_override("normal",
        UiTheme.row_style(UiTheme.ROW_HOVER if chosen else UiTheme.ROW))
    button.add_theme_stylebox_override("hover", UiTheme.row_style(UiTheme.ROW_HOVER))
    button.pressed.connect(func() -> void:
        selected_destination = destination_id
        _refresh_route())
    button.mouse_entered.connect(func() -> void: destination_hovered.emit(destination_id))

    var row := VBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.add_theme_constant_override("separation", 0)
    button.add_child(row)

    var top := HBoxContainer.new()
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_theme_constant_override("separation", 8)
    row.add_child(top)
    top.add_child(UiTheme.label("%s  %s" % [String(destination.get("code", "")),
        String(destination.get("city", ""))], 13, UiTheme.TEXT if allowed else UiTheme.TEXT_DIM))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer)
    if allowed:
        var profit: int = int(preview.get("profit", 0))
        top.add_child(UiTheme.label(UiTheme.money(profit), 13,
            UiTheme.GOOD if profit >= 0 else UiTheme.BAD))

    if allowed:
        row.add_child(UiTheme.label("%d nm · %s · earns %s · costs %s" % [
            roundi(float(preview.get("distance_nm", 0.0))),
            UiTheme.duration(float(preview.get("duration_seconds", 0.0))),
            UiTheme.money(int(preview.get("revenue", 0))),
            UiTheme.money(int(preview.get("cost", 0)))], 10, UiTheme.TEXT_DIM))
    else:
        row.add_child(UiTheme.label(String(verdict["reason"]), 10, UiTheme.BAD))
    return button

func _update_preview() -> void:
    if selected_destination.is_empty():
        _preview.text = "Pick a destination on the right"
        _dispatch_button.disabled = true
        return
    var verdict: Dictionary = sim.dispatch_check(selected_aircraft_id, selected_destination)
    var preview: Dictionary = sim.dispatch_preview(selected_aircraft_id, selected_destination)
    var destination: Dictionary = sim.db.airports.get(selected_destination, {})
    if not bool(verdict["ok"]):
        _preview.text = String(verdict["reason"])
        _dispatch_button.disabled = true
        return
    _preview.text = "%s · %s · profit %s" % [
        String(destination.get("code", "")),
        UiTheme.duration(float(preview.get("duration_seconds", 0.0))),
        UiTheme.money(int(preview.get("profit", 0)))]
    _dispatch_button.disabled = false

func _on_dispatch_pressed() -> void:
    var result: Dictionary = sim.dispatch(selected_aircraft_id, selected_destination)
    if not bool(result["ok"]):
        _notice.text = String(result["reason"])
        refresh()
