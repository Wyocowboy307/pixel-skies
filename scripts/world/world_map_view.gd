class_name WorldMapView
extends Node2D
## Draws the stylized world map as a single LOD texture in world space.
##
## Textures come from tools/build_world_geometry.py. Nothing here parses
## geographic data at runtime. The map repeats horizontally so panning across
## the International Date Line is continuous.

const OCEAN_VOID := Color("#0f2435")

var _camera: WorldCamera
var _textures: Dictionary = {}
var _tier := -1

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = -100

func bind_camera(camera: WorldCamera) -> void:
    _camera = camera
    _camera.view_changed.connect(_on_view_changed)
    _refresh_tier()

func _on_view_changed() -> void:
    _refresh_tier()
    queue_redraw()

func _refresh_tier() -> void:
    if _camera == null:
        return
    # Selecting on the lower of current/target zoom keeps a coarser (larger
    # world_scale) texture on screen mid-animation, so the map is never
    # downsampled while a zoom is still interpolating.
    var zoom_for_tier: float = minf(_camera.current_zoom(), _camera.target_zoom())
    var tier: int = WorldLod.tier_for_zoom(zoom_for_tier)
    if tier != _tier:
        _tier = tier
        _ensure_texture(tier)

func _ensure_texture(tier: int) -> void:
    if _textures.has(tier):
        return
    var path: String = WorldLod.texture_path(tier)
    if not ResourceLoader.exists(path):
        push_error("World map texture missing: %s — run tools/build_world_geometry.py" % path)
        return
    _textures[tier] = load(path)

func _draw() -> void:
    if _camera == null or not _textures.has(_tier):
        return
    var texture: Texture2D = _textures[_tier]
    var size: Vector2 = WorldProjection.WORLD_SIZE

    # Fill beyond the poles so panning never reveals the clear colour.
    var view: Rect2 = _visible_world_rect()
    draw_rect(Rect2(view.position - Vector2(64, 64), view.size + Vector2(128, 128)), OCEAN_VOID)

    # Draw the copies of the world that intersect the view, giving seamless
    # horizontal wrap without duplicating any state.
    var first: int = int(floor((view.position.x) / size.x))
    var last: int = int(floor((view.position.x + view.size.x) / size.x))
    for copy in range(first, last + 1):
        draw_texture_rect(texture, Rect2(Vector2(copy * size.x, 0.0), size), false)

func _visible_world_rect() -> Rect2:
    var viewport_size: Vector2 = get_viewport_rect().size
    var top_left: Vector2 = _camera.screen_to_world(Vector2.ZERO)
    var bottom_right: Vector2 = _camera.screen_to_world(viewport_size)
    return Rect2(top_left, bottom_right - top_left)
