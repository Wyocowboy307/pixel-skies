extends Control
## Dev-only review sheet: every aircraft family drawn large, and again at the
## sizes they actually appear in game. An asset is not approved in isolation —
## it has to read at gameplay size (docs/ART_PIPELINE.md, "Review captures").

const BACKGROUND := Color("#4c6349")
const PANEL := Color("#0d1c26", 0.9)
const TEXT := Color("#e8f1f4")
const DIM := Color("#8fa8b4")

var db: GameDB
var _phase := 0.0

func _ready() -> void:
    # A Control parented to a CanvasLayer gets no layout pass, so its rect has
    # to be set explicitly or everything draws into a zero-width column.
    size = get_viewport_rect().size
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    set_process(true)

func _process(delta: float) -> void:
    _phase = fposmod(_phase + delta * 22.0, TAU)
    queue_redraw()

func _draw() -> void:
    if db == null:
        return
    draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
    var font: Font = ThemeDB.fallback_font
    var families: Array = db.aircraft.values()
    var column_width: float = size.x / float(maxi(1, families.size()))

    for index in range(families.size()):
        var family: Dictionary = families[index]
        var centre_x: float = column_width * (float(index) + 0.5)
        var livery: Color = AircraftArt.livery_color("house")

        draw_string(font, Vector2(centre_x - 90.0, 40.0), String(family.get("name", "")),
            HORIZONTAL_ALIGNMENT_LEFT, 180, 18, TEXT)

        # Large: judge the silhouette itself.
        AircraftArt.draw_top(self, Vector2(centre_x, 180.0), -PI * 0.5, family, 3.0, livery, -1.0)
        draw_string(font, Vector2(centre_x - 90.0, 290.0), "3x · parked",
            HORIZONTAL_ALIGNMENT_CENTER, 180, 12, DIM)

        # Running, so the prop treatment can be compared side by side.
        AircraftArt.draw_top(self, Vector2(centre_x, 400.0), -PI * 0.5, family, 2.0, livery, _phase)
        draw_string(font, Vector2(centre_x - 90.0, 470.0), "2x · engines running",
            HORIZONTAL_ALIGNMENT_CENTER, 180, 12, DIM)

        # Gameplay sizes: airport stand, then world map marker.
        AircraftArt.draw_top(self, Vector2(centre_x - 60.0, 560.0), -PI * 0.5, family, 0.62, livery, -1.0)
        AircraftArt.draw_top(self, Vector2(centre_x + 40.0, 560.0), -PI * 0.5, family, 0.3, livery, -1.0)
        draw_string(font, Vector2(centre_x - 90.0, 620.0), "airport 0.62x · map 0.3x",
            HORIZONTAL_ALIGNMENT_CENTER, 180, 12, DIM)
