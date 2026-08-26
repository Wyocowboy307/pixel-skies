class_name AirportHud
extends Control
## The management layer over an airport scene: job board, aircraft load view and
## route/dispatch, sized for a 640x360 screen.
##
## Panels are docked to the edges so the airfield stays visible between them.
## Every legality question is answered by the simulation, and refusals are shown
## before the player commits, never after (docs/UI_UX.md, "Depart interaction").

signal destination_hovered(airport_id: String)
signal dispatch_completed(flight_id: String)

var sim: Simulation
var airport_id := ""
var selected_aircraft_id := ""
var routing := false
var _watching := false
var selected_destination := ""

var _job_panel: PanelContainer
var _job_list: VBoxContainer
var _job_header: Label
var _dock: PanelContainer
var _dock_title: Label
var _dock_subtitle: Label
var _badge_slot: HBoxContainer
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
    set_anchors_preset(Control.PRESET_FULL_RECT)
    # A Control created in code under a CanvasLayer gets no layout pass, so its
    # rect stays zero and every anchored child collapses into the corner.
    size = get_viewport_rect().size
    get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
    _build_job_panel()
    _build_dock()
    _build_route_panel()

func bind(simulation: Simulation, at_airport: String) -> void:
    sim = simulation
    airport_id = at_airport
    sim.jobs_changed.connect(func(_id: String) -> void: refresh())
    sim.flight_dispatched.connect(_on_flight_dispatched)
    sim.flight_arrived.connect(func(_settlement: Dictionary) -> void: refresh())
    var parked: Array[AircraftInstance] = sim.state.aircraft_at(airport_id)
    if not parked.is_empty():
        selected_aircraft_id = parked[0].id
    refresh()

## Collapses the management panels while an aircraft is operating, so the field
## is unobstructed during a departure or an arrival.
func set_watching(watching: bool) -> void:
    if _watching == watching:
        return
    _watching = watching
    refresh()

func select_aircraft(aircraft_id: String) -> void:
    selected_aircraft_id = aircraft_id
    routing = false
    selected_destination = ""
    refresh()

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _side_panel(on_left: bool) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_LEFT_WIDE if on_left else Control.PRESET_RIGHT_WIDE)
    if on_left:
        panel.offset_left = UiTheme.MARGIN
        panel.offset_right = UiTheme.MARGIN + UiTheme.PANEL_WIDTH
    else:
        panel.offset_left = -UiTheme.MARGIN - UiTheme.PANEL_WIDTH
        panel.offset_right = -UiTheme.MARGIN
    panel.offset_top = UiTheme.TOP_BAR_HEIGHT + 5.0
    panel.offset_bottom = -UiTheme.DOCK_HEIGHT - 8.0
    add_child(panel)
    return panel

func _build_job_panel() -> void:
    _job_panel = _side_panel(true)
    var panel: PanelContainer = _job_panel
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 2)
    panel.add_child(column)

    _job_header = UiTheme.label("", "accent_orange")
    column.add_child(_job_header)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    column.add_child(scroll)

    _job_list = VBoxContainer.new()
    _job_list.add_theme_constant_override("separation", 1)
    _job_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_job_list)

func _build_dock() -> void:
    _dock = PanelContainer.new()
    _dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _dock.offset_left = UiTheme.MARGIN
    _dock.offset_right = -UiTheme.MARGIN
    _dock.offset_top = -UiTheme.DOCK_HEIGHT
    _dock.offset_bottom = -UiTheme.MARGIN
    add_child(_dock)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 1)
    _dock.add_child(column)

    var identity := HBoxContainer.new()
    identity.add_theme_constant_override("separation", 5)
    column.add_child(identity)
    _badge_slot = HBoxContainer.new()
    _badge_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    identity.add_child(_badge_slot)
    _dock_title = UiTheme.label("", "accent_orange")
    identity.add_child(_dock_title)
    _dock_subtitle = UiTheme.label("", "text_dim")
    identity.add_child(_dock_subtitle)
    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    identity.add_child(gap)
    _config_button = UiTheme.button("LAYOUT")
    _config_button.tooltip_text = "Trade seats for hold space"
    _config_button.pressed.connect(_on_configuration_pressed)
    identity.add_child(_config_button)

    var capacity := HBoxContainer.new()
    capacity.add_theme_constant_override("separation", 6)
    column.add_child(capacity)
    capacity.add_child(UiTheme.icon("passenger"))
    _seat_row = HBoxContainer.new()
    _seat_row.add_theme_constant_override("separation", 2)
    capacity.add_child(_seat_row)
    capacity.add_child(UiTheme.icon("cargo"))
    _hold_row = HBoxContainer.new()
    _hold_row.add_theme_constant_override("separation", 2)
    capacity.add_child(_hold_row)

    var lower := HBoxContainer.new()
    lower.add_theme_constant_override("separation", 6)
    lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(lower)

    _manifest = VBoxContainer.new()
    _manifest.add_theme_constant_override("separation", 0)
    _manifest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lower.add_child(_manifest)

    var actions := VBoxContainer.new()
    actions.add_theme_constant_override("separation", 1)
    lower.add_child(actions)
    _notice = UiTheme.label("", "accent_red")
    actions.add_child(_notice)
    _preview = UiTheme.label("", "text")
    actions.add_child(_preview)

    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 3)
    actions.add_child(buttons)
    _route_button = UiTheme.button("ROUTE")
    _route_button.pressed.connect(_on_route_pressed)
    buttons.add_child(_route_button)
    _dispatch_button = UiTheme.button("DEPART")
    _dispatch_button.disabled = true
    _dispatch_button.pressed.connect(_on_dispatch_pressed)
    buttons.add_child(_dispatch_button)

func _build_route_panel() -> void:
    _route_panel = _side_panel(false)
    _route_panel.visible = false
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 2)
    _route_panel.add_child(column)
    column.add_child(UiTheme.label("WHERE TO?", "accent_orange"))
    _route_list = VBoxContainer.new()
    _route_list.add_theme_constant_override("separation", 1)
    column.add_child(_route_list)

# ---------------------------------------------------------------------------
# Rows
# ---------------------------------------------------------------------------

## A clickable row: an icon, two lines of text and a value on the right.
func _row(height: float) -> Dictionary:
    var button := Button.new()
    button.custom_minimum_size = Vector2(0.0, height)
    button.clip_contents = true
    var row := HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.set_anchors_preset(Control.PRESET_FULL_RECT)
    row.add_theme_constant_override("separation", 3)
    button.add_child(row)
    return {"button": button, "row": row}

func _on_flight_dispatched(leg: FlightLeg) -> void:
    routing = false
    selected_destination = ""
    dispatch_completed.emit(leg.id)
    refresh()

func refresh() -> void:
    if sim == null:
        return
    if _watching:
        # Nothing to manage while an aircraft is taxiing or taking off; the
        # field should be unobstructed.
        _job_panel.visible = false
        _route_panel.visible = false
        _dock.visible = false
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
    _job_header.text = "%s JOBS · %d" % [String(airport.get("code", "")), board.size()]
    for job: Job in board:
        _job_list.add_child(_job_row(job))

func _job_row(job: Job) -> Control:
    var verdict: Dictionary = _load_verdict(job)
    var allowed: bool = bool(verdict["ok"])
    var parts: Dictionary = _row(UiTheme.ROW_HEIGHT)
    var button: Button = parts["button"]
    var row: HBoxContainer = parts["row"]
    button.tooltip_text = String(verdict["reason"])
    button.pressed.connect(func() -> void: _on_job_pressed(job))
    button.mouse_entered.connect(func() -> void: destination_hovered.emit(job.destination_id))

    row.add_child(UiTheme.icon(UiTheme.kind_icon(job.kind)))

    var middle := VBoxContainer.new()
    middle.add_theme_constant_override("separation", 0)
    middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(middle)

    var destination: Dictionary = sim.db.airports.get(job.destination_id, {})
    var headline := HBoxContainer.new()
    headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
    headline.add_theme_constant_override("separation", 3)
    middle.add_child(headline)
    headline.add_child(UiTheme.label(UiTheme.job_summary(job), "text" if allowed else "text_dim"))
    headline.add_child(UiTheme.label("TO", "text_dim"))
    headline.add_child(UiTheme.label(String(destination.get("code", "?")),
        "accent_orange" if allowed else "text_dim"))

    var footer := HBoxContainer.new()
    footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    footer.add_theme_constant_override("separation", 3)
    middle.add_child(footer)
    # A refused job explains itself in place rather than failing silently.
    if allowed:
        footer.add_child(UiTheme.icon("money"))
        footer.add_child(UiTheme.label(UiTheme.money(job.reward), "accent_green"))
        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        footer.add_child(spacer)
        footer.add_child(UiTheme.label(UiTheme.duration(job.seconds_remaining(sim.now())), "text_dim"))
    else:
        footer.add_child(UiTheme.label(String(verdict["reason"]), "accent_red"))
    return button

func _load_verdict(job: Job) -> Dictionary:
    var plane: AircraftInstance = sim.state.aircraft.get(selected_aircraft_id, null)
    if plane == null:
        return Rules.no("Pick an aircraft")
    return Rules.can_load(plane, sim.family_of(plane), job,
        sim.state.loaded_jobs(plane.id))

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
    for child: Node in _badge_slot.get_children():
        child.queue_free()
    _badge_slot.add_child(UiTheme.aircraft_badge(plane.family_id))
    _dock_title.text = plane.display_name().to_upper()
    _dock_subtitle.text = "%s · FLIES UP TO %d NM" % [
        String(family.get("name", "")).to_upper(), int(family.get("range_nm", 0))]
    _config_button.text = _configuration_name(family, plane.configuration).to_upper()

    var limits: Dictionary = Rules.capacity(family, plane.configuration)
    var loaded: Array[Job] = sim.state.loaded_jobs(plane.id)
    var used: Dictionary = Rules.load_used(loaded)
    _fill_slots(_seat_row, int(used["seats"]), int(limits["seats"]), "accent_teal")
    _fill_slots(_hold_row, int(used["cargo_units"]), int(limits["cargo_units"]), "accent_yellow")

    for child: Node in _manifest.get_children():
        child.queue_free()
    if loaded.is_empty():
        _manifest.add_child(UiTheme.label("NOTHING ABOARD YET", "text_dim"))
        _manifest.add_child(UiTheme.label("PICK A JOB ON THE LEFT →", "accent_teal"))
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
        _notice.text = "Unload before changing layout"
        return
    var options: Array = (sim.db.aircraft.get(plane.family_id, {}) as Dictionary).get("configurations", [])
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

## Capacity as discrete pips: how full the aircraft is must be readable at a
## glance, not a fraction to be parsed.
func _fill_slots(row: HBoxContainer, used: int, total: int, colour_key: String) -> void:
    for child: Node in row.get_children():
        child.queue_free()
    if total <= 0:
        row.add_child(UiTheme.label("—", "text_dim"))
        return
    var is_seat: bool = colour_key == "accent_teal"
    for i in range(total):
        row.add_child(UiTheme.payload_pip(is_seat, i < used, i))

func _manifest_row(job: Job) -> Control:
    var parts: Dictionary = _row(11.0)
    var button: Button = parts["button"]
    var row: HBoxContainer = parts["row"]
    button.tooltip_text = "Click to unload"
    button.pressed.connect(func() -> void:
        sim.unload_job(selected_aircraft_id, job.id)
        refresh())
    var destination: Dictionary = sim.db.airports.get(job.destination_id, {})
    row.add_child(UiTheme.icon(UiTheme.kind_icon(job.kind)))
    row.add_child(UiTheme.label("%s %s" % [String(destination.get("code", "?")), job.describe()]))
    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(gap)
    row.add_child(UiTheme.label(UiTheme.money(job.reward), "accent_green"))
    return button

# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------

func _on_route_pressed() -> void:
    routing = not routing
    refresh()

func _refresh_route() -> void:
    _route_panel.visible = routing
    for child: Node in _route_list.get_children():
        child.queue_free()
    if not routing:
        _preview.text = ""
        _dispatch_button.disabled = true
        return
    for candidate_id: String in sim.state.unlocked_airport_ids:
        if candidate_id != airport_id:
            _route_list.add_child(_route_row(candidate_id))
    _update_preview()

func _route_row(destination_id: String) -> Control:
    var verdict: Dictionary = sim.dispatch_check(selected_aircraft_id, destination_id)
    var preview: Dictionary = sim.dispatch_preview(selected_aircraft_id, destination_id)
    var allowed: bool = bool(verdict["ok"])
    var destination: Dictionary = sim.db.airports.get(destination_id, {})

    var parts: Dictionary = _row(UiTheme.ROW_HEIGHT + 4.0)
    var button: Button = parts["button"]
    var row: HBoxContainer = parts["row"]
    button.pressed.connect(func() -> void:
        selected_destination = destination_id
        _refresh_route())
    button.mouse_entered.connect(func() -> void: destination_hovered.emit(destination_id))

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 0)
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(column)

    var chosen: String = " <" if destination_id == selected_destination else ""
    column.add_child(UiTheme.label("%s %s%s" % [String(destination.get("code", "")),
        String(destination.get("city", "")), chosen], "text" if allowed else "text_dim"))
    if allowed:
        column.add_child(UiTheme.label("%dNM · %s · %s" % [
            roundi(float(preview.get("distance_nm", 0.0))),
            UiTheme.duration(float(preview.get("duration_seconds", 0.0))),
            UiTheme.money(int(preview.get("profit", 0)))],
            "accent_green" if int(preview.get("profit", 0)) >= 0 else "accent_red"))
    else:
        column.add_child(UiTheme.label(String(verdict["reason"]), "accent_red"))
    return button

func _update_preview() -> void:
    if selected_destination.is_empty():
        _preview.text = "WHERE TO? →"
        _dispatch_button.disabled = true
        return
    var verdict: Dictionary = sim.dispatch_check(selected_aircraft_id, selected_destination)
    if not bool(verdict["ok"]):
        _preview.text = String(verdict["reason"])
        _dispatch_button.disabled = true
        return
    var preview: Dictionary = sim.dispatch_preview(selected_aircraft_id, selected_destination)
    var destination: Dictionary = sim.db.airports.get(selected_destination, {})
    _preview.text = "%s · %s · %s" % [
        String(destination.get("code", "")),
        UiTheme.duration(float(preview.get("duration_seconds", 0.0))),
        UiTheme.money(int(preview.get("profit", 0)))]
    _dispatch_button.disabled = false

func _on_dispatch_pressed() -> void:
    var result: Dictionary = sim.dispatch(selected_aircraft_id, selected_destination)
    if not bool(result["ok"]):
        _notice.text = String(result["reason"])
        refresh()
