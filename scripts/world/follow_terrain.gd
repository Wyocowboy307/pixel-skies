class_name FollowTerrain
extends Control
## The follow-mode terrain strip: while the camera is locked to an aircraft in
## cruise, the abstract world map gives way to a close pixel world scrolling
## beneath it — plains, a farm, a river, forest, a town, foothills and the
## mountains near the destination (assets/art/production/world/corridor_*.png,
## composed offline by tools/compose_corridor.py).
##
## Pure presentation: it reads the flight's timestamps and draws; it never
## writes simulation state. The scroll offset comes straight from
## FlightLeg.enroute_progress, so what the player sees under the aircraft is
## exactly how far along the leg actually is.

const STRIP_PATH := "world/corridor_bzn_bil.png"
## Wall-clock speeds. The scroll itself is progress-driven; only the clouds and
## the 1px vertical drift breathe on wall time so a paused clock still feels
## alive.
const DRIFT_PERIOD_SECONDS := 11.0
const CLOUD_SCALE := 2

## Screen lane, wind speed (px/s) and parallax factor per cloud. Factors above
## one make clouds cross faster than the terrain: they are nearer the camera.
const CLOUD_LANES := [
    {"y": 52.0, "speed": 5.0, "factor": 1.35, "kind": 0},
    {"y": 168.0, "speed": 8.0, "factor": 1.6, "kind": 2},
    {"y": 286.0, "speed": 3.5, "factor": 1.2, "kind": 1},
]
## Shadow offset from the aircraft: the sun sits top-left, so the shadow falls
## below-right, and its distance sells the cruise altitude.
const SHADOW_OFFSET := Vector2(18.0, 26.0)

var sim: Simulation
## The overlay is told when the strip is on screen so it can swap to its
## centred follow drawing and drop the map furniture.
var overlay: WorldOverlay

var _strip: Texture2D
var _clouds: Array[Texture2D] = []
var _followed_id := ""
var _active := false
var _clock := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    # Controls under a CanvasLayer do not inherit a size from anchors alone.
    size = get_viewport_rect().size
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _strip = AssetPaths.load_texture(STRIP_PATH)
    for index in range(3):
        var cloud: Texture2D = AssetPaths.load_texture("world/cloud_%d.png" % index)
        if cloud != null:
            _clouds.append(cloud)
    visible = false

func bind(simulation: Simulation, world_overlay: WorldOverlay) -> void:
    sim = simulation
    overlay = world_overlay

## Called by main every frame with the aircraft the world view is following,
## or "" when the view is elsewhere.
func set_followed(aircraft_id: String) -> void:
    _followed_id = aircraft_id

func _process(delta: float) -> void:
    _clock += delta
    var active: bool = _leg_in_cruise() != null and _strip != null
    if active != _active:
        _active = active
        visible = active
        if overlay != null:
            overlay.set_terrain_follow(_followed_id if active else "")
            overlay.queue_redraw()
    elif active and overlay != null:
        # Keep the overlay pointed at the right aircraft if follow switches.
        overlay.set_terrain_follow(_followed_id)
    if active:
        queue_redraw()

## The followed aircraft's leg, but only while it is actually crossing country:
## climb-out through approach. On the ground the airfield scene owns the view.
func _leg_in_cruise() -> FlightLeg:
    if sim == null or _followed_id.is_empty():
        return null
    var leg: FlightLeg = sim.flight_for_aircraft(_followed_id)
    if leg == null:
        return null
    var phase: FlightLeg.Phase = leg.phase_at(sim.now())
    if phase < FlightLeg.Phase.CLIMB or phase > FlightLeg.Phase.APPROACH:
        return null
    return leg

func _draw() -> void:
    var leg: FlightLeg = _leg_in_cruise()
    if leg == null:
        return
    var offset: float = _scroll_offset(leg)
    _draw_strip(offset)
    _draw_shadow()
    _draw_clouds(offset)

func _scroll_offset(leg: FlightLeg) -> float:
    var span: float = maxf(0.0, _strip.get_size().x - size.x)
    return roundf(leg.enroute_progress(sim.now()) * span)

## The strip scrolls horizontally with flight progress and breathes one pixel
## vertically on wall time. The vertical shift wraps through the source
## texture (grass at both edges), so no background ever peeks through.
func _draw_strip(offset: float) -> void:
    var strip_size: Vector2 = _strip.get_size()
    var drift: float = roundf(sin(_clock * TAU / DRIFT_PERIOD_SECONDS))
    var src_y: float = fposmod(-drift, strip_size.y)
    var first: float = minf(strip_size.y - src_y, size.y)
    draw_texture_rect_region(_strip,
        Rect2(Vector2.ZERO, Vector2(size.x, first)),
        Rect2(Vector2(offset, src_y), Vector2(size.x, first)))
    if first < size.y:
        draw_texture_rect_region(_strip,
            Rect2(Vector2(0.0, first), Vector2(size.x, size.y - first)),
            Rect2(Vector2(offset, 0.0), Vector2(size.x, size.y - first)))

## The aircraft's shadow on the terrain: a small dark ellipse below-right of
## centre. The overlay draws the aircraft itself, centred, above this layer.
func _draw_shadow() -> void:
    var at: Vector2 = (size * 0.5 + SHADOW_OFFSET).round()
    var colour: Color = Color(PixelPalette.get_colour("shadow"), 0.5)
    var half_widths: Array[float] = [5.0, 8.0, 10.0, 11.0, 10.0, 8.0, 5.0]
    for row in range(half_widths.size()):
        var half: float = half_widths[row]
        draw_rect(Rect2(at + Vector2(-half, float(row - 3)), Vector2(half * 2.0, 1.0)), colour)

## Two or three clouds crossing over the terrain at different speeds. Faster
## lanes carry a parallax factor above one — nearer the camera than the ground
## — plus a wall-clock wind so they keep moving even under a fixed test clock.
func _draw_clouds(offset: float) -> void:
    if _clouds.is_empty():
        return
    for lane_index in range(CLOUD_LANES.size()):
        var lane: Dictionary = CLOUD_LANES[lane_index]
        var texture: Texture2D = _clouds[int(lane["kind"]) % _clouds.size()]
        var drawn: Vector2 = texture.get_size() * float(CLOUD_SCALE)
        var period: float = size.x + drawn.x + 160.0
        var travelled: float = offset * float(lane["factor"]) + _clock * float(lane["speed"]) \
            + float(lane_index) * 260.0
        var x: float = size.x - fposmod(travelled, period)
        var at := Vector2(roundf(x), roundf(float(lane["y"])))
        draw_texture_rect(texture, Rect2(at, drawn), false)
