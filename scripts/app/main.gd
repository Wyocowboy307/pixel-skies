extends Node2D
## Application root. Owns shared state and switches between world and airport
## views without ever tearing down simulation state
## (docs/TECH_ARCHITECTURE.md, "Scene transitions").

const WORLD_ZOOM_STOP := 0
const AIRPORT_APPROACH_STOP := 5
const AIRPORT_CAMERA_ZOOM := 1.0

@onready var _world: Node2D = $World
@onready var _map: WorldMapView = $World/WorldMap
@onready var _camera: WorldCamera = $WorldCamera
@onready var _overlay: WorldOverlay = $UI/WorldOverlay
@onready var _hud: Hud = $UI/Hud

var db := GameDB.new()
var sim: Simulation

enum View { WORLD, AIRPORT, AIRCRAFT }

var _view: View = View.WORLD
var _transition: ViewTransition
var _airport_view: AirportView
var _airport_camera: AirportCamera
var _airport_hud: AirportHud
var _detail_view: AircraftDetailView
## The view to return to when the aircraft detail screen closes.
var _detail_return: View = View.WORLD
var _busy := false
## Where the world camera was before diving into an airport, so backing out
## restores the exact view the player left.
var _world_return_position := Vector2.ZERO
var _world_return_stop := 2
var _followed_aircraft_id := ""
## Built once and assigned to every top-level Control we own.
var _ui_theme: Theme

func _ready() -> void:
    # Theme lookup walks up through Control and Window nodes only. These views
    # hang off a CanvasLayer under a Node2D, which breaks that chain, so a theme
    # set on the root Window never reaches them and every control silently falls
    # back to Godot's default vector styling. It has to be assigned to each
    # top-level Control we own.
    _ui_theme = PixelTheme.build()
    get_tree().root.theme = _ui_theme
    db.load_all()
    _report_data_problems()

    sim = Simulation.new(db)
    if not sim.load_game():
        sim.new_game()
    sim.money_changed.connect(_on_money_changed)
    # The fleet readout tracks flights, not money, so it has to refresh when a
    # flight starts or ends rather than only when the balance moves.
    sim.flight_dispatched.connect(func(_leg: FlightLeg) -> void: _refresh_hud_counts())
    sim.flight_arrived.connect(func(_settlement: Dictionary) -> void: _refresh_hud_counts())

    _transition = ViewTransition.new()
    add_child(_transition)

    _hud.theme = _ui_theme
    _overlay.theme = _ui_theme
    _map.bind_camera(_camera)
    _hud.bind_sim(sim)
    _overlay.bind(db, _camera, sim)
    _hud.bind(db)

    _overlay.airport_clicked.connect(_on_airport_clicked)
    _overlay.airport_activated.connect(_on_airport_activated)
    _overlay.background_clicked.connect(_on_background_clicked)
    _overlay.aircraft_clicked.connect(_on_aircraft_clicked)
    _overlay.aircraft_activated.connect(open_aircraft_detail)
    _hud.focus_requested.connect(_on_airport_activated)
    _hud.home_requested.connect(_on_home_requested)
    _camera.view_changed.connect(_update_zoom_readout)

    # Open on the airline's home station rather than an arbitrary patch of
    # ocean, so a new player starts looking at their own operation.
    _camera.focus_on(_airport_world_position("apt_bzn"), 2)
    _update_zoom_readout()
    _on_money_changed(sim.state.money)
    print("Pixel Skies ready — %d airports, %d aircraft families." % [db.airports.size(), db.aircraft.size()])

func _process(_delta: float) -> void:
    # Timestamps do the work; this only notices when a boundary has been passed.
    sim.tick()
    _follow_aircraft()

func _follow_aircraft() -> void:
    if _followed_aircraft_id.is_empty() or _view != View.WORLD:
        return
    var leg: FlightLeg = sim.flight_for_aircraft(_followed_aircraft_id)
    if leg == null:
        _followed_aircraft_id = ""
        return
    _camera.follow(_overlay.aircraft_world_position(_followed_aircraft_id))

func _on_money_changed(amount: int) -> void:
    _hud.set_money(amount)

func _refresh_hud_counts() -> void:
    _hud.set_money(sim.state.money)

func _report_data_problems() -> void:
    if not OS.is_debug_build():
        return
    for problem: String in DataValidator.validate(db):
        push_warning("Data: %s" % problem)

func _airport_world_position(airport_id: String) -> Vector2:
    var airport: Dictionary = db.airports[airport_id]
    return WorldProjection.to_world(float(airport["lat"]), float(airport["lon"]))

# ---------------------------------------------------------------------------
# World view interaction
# ---------------------------------------------------------------------------

func _on_airport_clicked(airport_id: String) -> void:
    _hud.show_airport(airport_id)

## Second click / Zoom In: dive toward the airport and hand off to its scene.
func _on_airport_activated(airport_id: String) -> void:
    if _busy or _view == View.AIRPORT:
        return
    _hud.show_airport(airport_id)
    _overlay.selected_airport_id = airport_id
    enter_airport(airport_id)

## Selecting a flying aircraft locks the camera to it. Watching is optional and
## observational — it never becomes manual flying (docs/FLIGHT_SYSTEM.md).
func _on_aircraft_clicked(aircraft_id: String) -> void:
    _followed_aircraft_id = aircraft_id
    _hud.clear_airport()

func _on_background_clicked() -> void:
    _followed_aircraft_id = ""
    _hud.clear_airport()

func _on_home_requested() -> void:
    if _view == View.AIRPORT:
        exit_airport()
        return
    _camera.focus_on(_airport_world_position("apt_bzn"), WORLD_ZOOM_STOP)

func _update_zoom_readout() -> void:
    if _view != View.WORLD:
        return
    var tier: int = WorldLod.tier_for_zoom(minf(_camera.current_zoom(), _camera.target_zoom()))
    _hud.set_zoom_readout(_camera.current_zoom(), String(WorldLod.TIERS[tier]["name"]))

# ---------------------------------------------------------------------------
# View transitions
# ---------------------------------------------------------------------------

func enter_airport(airport_id: String) -> void:
    var layout: Dictionary = db.layout_for_airport(airport_id)
    if layout.is_empty():
        push_warning("No layout for %s" % airport_id)
        return
    _busy = true
    _world_return_position = _camera.global_position
    _world_return_stop = _camera.zoom_index

    # Keep zooming the world map under the fade so the dive reads as continuous.
    var anchor: Vector2 = _overlay.airport_screen_position(airport_id)
    _camera.focus_on(_airport_world_position(airport_id), AIRPORT_APPROACH_STOP, anchor)
    await _transition.cover()

    _overlay.visible = false
    _world.visible = false
    _airport_view = AirportView.new()
    _airport_view.setup(db.airports[airport_id], layout)
    _airport_view.bind_sim(sim)
    add_child(_airport_view)

    _airport_camera = AirportCamera.new()
    _airport_view.add_child(_airport_camera)
    # Frame the apron rather than the geometric centre of the field: loading and
    # departures are what the player came here to watch.
    _airport_camera.frame(_airport_view.bounds(), _airport_view.apron_centre(), AIRPORT_CAMERA_ZOOM)
    _airport_camera.make_current()

    _airport_hud = AirportHud.new()
    _airport_hud.theme = _ui_theme
    $UI.add_child(_airport_hud)
    _airport_hud.bind(sim, airport_id)
    _airport_hud.dispatch_completed.connect(_on_dispatch_completed)
    _airport_view.aircraft_clicked.connect(_airport_hud.select_aircraft)
    _airport_view.aircraft_activated.connect(open_aircraft_detail)
    if not _airport_hud.selected_aircraft_id.is_empty():
        _airport_view.selected_aircraft_id = _airport_hud.selected_aircraft_id

    _view = View.AIRPORT
    _hud.set_zoom_readout(AIRPORT_CAMERA_ZOOM, "airport")
    _hud.clear_airport()
    await _transition.uncover()
    _busy = false

func exit_airport() -> void:
    if _busy or _view != View.AIRPORT:
        return
    _busy = true
    await _transition.cover()

    if _airport_hud != null:
        _airport_hud.queue_free()
        _airport_hud = null
    if _airport_view != null:
        _airport_view.queue_free()
        _airport_view = null
        _airport_camera = null

    _world.visible = true
    _overlay.visible = true
    _view = View.WORLD
    _camera.make_current()
    # Restore the exact world view the player dived from.
    _camera.focus_on(_world_return_position, _world_return_stop)
    _update_zoom_readout()
    await _transition.uncover()
    _busy = false

## A departure is the moment the airline does something, so the view follows it
## out to the world map rather than leaving the player staring at an empty stand.
func _on_dispatch_completed(flight_id: String) -> void:
    _airport_view.queue_redraw()
    var leg: FlightLeg = sim.state.flights.get(flight_id, null)
    if leg != null:
        _followed_aircraft_id = leg.aircraft_id
        _overlay.selected_aircraft_id = leg.aircraft_id

# ---------------------------------------------------------------------------
# Aircraft detail
# ---------------------------------------------------------------------------

## Opens the plane detail screen over whichever view the player was in, and
## returns to exactly that view on close.
func open_aircraft_detail(aircraft_id: String) -> void:
    if _busy or _view == View.AIRCRAFT:
        return
    if not sim.state.aircraft.has(aircraft_id):
        return
    _detail_return = _view
    _detail_view = AircraftDetailView.new()
    _detail_view.theme = _ui_theme
    $UI.add_child(_detail_view)
    _detail_view.bind(sim, aircraft_id)
    _detail_view.closed.connect(close_aircraft_detail)
    _detail_view.dispatched.connect(_on_detail_dispatched)
    _hud.visible = false
    if _airport_hud != null:
        _airport_hud.visible = false
    _overlay.visible = false
    _view = View.AIRCRAFT

func close_aircraft_detail() -> void:
    if _view != View.AIRCRAFT:
        return
    if _detail_view != null:
        _detail_view.queue_free()
        _detail_view = null
    _hud.visible = true
    _view = _detail_return
    if _view == View.AIRPORT and _airport_hud != null:
        _airport_hud.visible = true
        _airport_hud.refresh()
    elif _view == View.WORLD:
        _overlay.visible = true

## Dispatching from the plane screen hands the player straight to the world to
## watch the departure, which is the point of pressing Fly.
func _on_detail_dispatched(flight_id: String) -> void:
    var leg: FlightLeg = sim.state.flights.get(flight_id, null)
    if leg == null:
        return
    _followed_aircraft_id = leg.aircraft_id
    _overlay.selected_aircraft_id = leg.aircraft_id
    _detail_return = View.WORLD

func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("ui_cancel"):
        return
    get_viewport().set_input_as_handled()
    if _view == View.AIRCRAFT:
        close_aircraft_detail()
        return
    if _view == View.AIRPORT:
        exit_airport()
        return
    # Escape reverses one detail level at a time (docs/UI_UX.md, "Zoom UX").
    _hud.clear_airport()
    _overlay.selected_airport_id = ""
    _camera.step_zoom(-1)
