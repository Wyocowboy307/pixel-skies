class_name CustomizeView
extends Control
## The paint shop: one aircraft, huge, parked on the workshop floor with a
## tool cart and cones beside it. Paint chips live in a compact dock along the
## bottom; pick one and the plane repaints on the spot with a little hop.
##
## This screen is about attachment, not numbers: the plane fills the screen,
## the registration is paperwork tucked in a corner card, and the nickname the
## player types floats above the aircraft in big letters. No stats anywhere.

signal closed()

const HERO_SCALE := 3
const GROUND_Y := 262.0
const DOCK_SIZE := Vector2(168.0, 82.0)
const IDENTITY_SIZE := Vector2(140.0, 106.0)
## Whole-pixel hop the plane does when a chip lands, indexed by elapsed frame.
const BOUNCE: Array[int] = [-1, -2, -3, -3, -2, -1, 0, -1, -1, 0, 0, 0]

var sim: Simulation
var aircraft_id := ""

var _font: Font
var _anchors: Dictionary = {}
var _clock := 0.0
var _bounce_frames := 0

var _rows: Dictionary = {}         ## field -> SwatchRow
var _reg_value: Label
var _nickname_edit: LineEdit
var _paint_card: PanelContainer
var _identity_card: PanelContainer
var _title_bar: PanelContainer
var _cart_tex: Texture2D
var _cone_tex: Texture2D
var _cones_small_tex: Texture2D

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size
    get_viewport().size_changed.connect(func() -> void:
        size = get_viewport_rect().size
        _layout())
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _font = load(AssetPaths.resolve_file("ui/font5x7.fnt"))
    _cart_tex = AssetPaths.load_texture("shop/tool_cart.png")
    _cone_tex = AssetPaths.load_texture("shop/cone.png")
    _cones_small_tex = AssetPaths.load_texture("shop/cones_small.png")
    _build_chrome()
    _layout()
    set_process(true)

func bind(simulation: Simulation, id: String) -> void:
    sim = simulation
    aircraft_id = id
    _load_anchors()
    refresh()

func _process(delta: float) -> void:
    _clock += delta
    if _bounce_frames > 0:
        _bounce_frames -= 1
    queue_redraw()

func _plane() -> AircraftInstance:
    if sim == null:
        return null
    return sim.state.aircraft.get(aircraft_id, null)

func _colour(key: String) -> Color:
    return PixelPalette.get_colour(key)

## Baseline comes from the sprite's own metadata so the wheels sit on the floor.
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

# ---------------------------------------------------------------------------
# Chrome
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
    _title_bar = PanelContainer.new()
    _title_bar.theme_type_variation = "HudBar"
    add_child(_title_bar)
    var title_center := CenterContainer.new()
    _title_bar.add_child(title_center)
    var title_row := HBoxContainer.new()
    title_row.add_theme_constant_override("separation", 6)
    title_center.add_child(title_row)
    title_row.add_child(_title_icon(false))
    title_row.add_child(UiTheme.heading("PAINT SHOP", "white"))
    title_row.add_child(_title_icon(true))

    # Compact chip dock: one slim row of small square chips per paint field.
    _paint_card = PanelContainer.new()
    _paint_card.theme_type_variation = "CardRaised"
    add_child(_paint_card)
    var paint_box := VBoxContainer.new()
    paint_box.add_theme_constant_override("separation", 2)
    _paint_card.add_child(paint_box)
    _add_swatch_row(paint_box, "BODY", "livery_body", LiverySprites.BODY_SETS)
    _add_swatch_row(paint_box, "ACCENT", "livery_accent", LiverySprites.ACCENT_SETS)
    _add_swatch_row(paint_box, "TAIL", "livery_tail", LiverySprites.BODY_SETS)

    # Slim corner card: the paperwork, out of the plane's way.
    _identity_card = PanelContainer.new()
    _identity_card.theme_type_variation = "CardRaised"
    add_child(_identity_card)
    var id_box := VBoxContainer.new()
    id_box.add_theme_constant_override("separation", 3)
    _identity_card.add_child(id_box)

    id_box.add_child(UiTheme.label("REGISTRATION", "hud_blue"))
    _reg_value = UiTheme.heading("", "navy")
    id_box.add_child(_reg_value)
    id_box.add_child(UiTheme.label("NICKNAME", "hud_blue"))
    _nickname_edit = LineEdit.new()
    _nickname_edit.max_length = 14
    _nickname_edit.custom_minimum_size = Vector2(0.0, 18.0)
    _nickname_edit.text_submitted.connect(func(text: String) -> void:
        _apply_nickname(text))
    _nickname_edit.focus_exited.connect(func() -> void:
        _apply_nickname(_nickname_edit.text))
    id_box.add_child(_nickname_edit)

    var done := UiTheme.big_button("DONE", "green")
    done.size_flags_horizontal = Control.SIZE_FILL
    done.pressed.connect(func() -> void: closed.emit())
    id_box.add_child(done)

## The 10px plane icon at a crisp 2x, one on each side of the title.
func _title_icon(mirrored: bool) -> TextureRect:
    var node := TextureRect.new()
    node.texture = AssetPaths.load_texture("ui/icons/plane.png")
    node.custom_minimum_size = Vector2(20.0, 20.0)
    node.stretch_mode = TextureRect.STRETCH_SCALE
    node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    node.flip_h = mirrored
    return node

func _add_swatch_row(into: VBoxContainer, title: String, field: String,
        sets: Dictionary) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    into.add_child(row)

    var label := UiTheme.label(title, "navy")
    label.custom_minimum_size = Vector2(40.0, 0.0)
    label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(label)

    var swatches := SwatchRow.new(sets.keys(), sets,
        func(scheme: String) -> void: _pick(field, scheme))
    row.add_child(swatches)
    _rows[field] = swatches

## Free children of a CanvasLayer Control get no layout pass, so the cards are
## placed by hand and re-placed when the viewport changes.
func _layout() -> void:
    _title_bar.position = Vector2.ZERO
    _title_bar.size = Vector2(size.x, 24.0)
    _paint_card.position = Vector2(roundf((size.x - DOCK_SIZE.x) * 0.5),
        size.y - DOCK_SIZE.y - 4.0)
    _paint_card.size = DOCK_SIZE
    _identity_card.position = Vector2(size.x - IDENTITY_SIZE.x - 8.0, 30.0)
    _identity_card.size = IDENTITY_SIZE

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _pick(field: String, scheme: String) -> void:
    var changes: Dictionary = {}
    changes[field] = scheme
    sim.customize_aircraft(aircraft_id, changes)
    refresh()
    # Repaint response: the chip rings out and the plane does a little hop.
    var row: SwatchRow = _rows[field]
    row.flash(scheme)
    _bounce_frames = BOUNCE.size()

func _apply_nickname(text: String) -> void:
    if sim == null:
        return
    sim.customize_aircraft(aircraft_id, {"nickname": text})
    refresh()

func refresh() -> void:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    var body: String = plane.livery_body if not plane.livery_body.is_empty() else "cream"
    var accent: String = plane.livery_accent if not plane.livery_accent.is_empty() else "orange"
    var tail: String = plane.livery_tail if not plane.livery_tail.is_empty() else body
    _set_row("livery_body", body)
    _set_row("livery_accent", accent)
    _set_row("livery_tail", tail)
    _reg_value.text = plane.registration
    if not _nickname_edit.has_focus():
        _nickname_edit.text = plane.nickname
    queue_redraw()

func _set_row(field: String, scheme: String) -> void:
    var row: SwatchRow = _rows[field]
    row.selected = scheme
    row.queue_redraw()

# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), _colour("sky"))
    _draw_clouds()
    _draw_garland()
    _draw_floor()
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    _draw_hero(plane)
    _draw_props()
    _draw_nickname(plane)

## The workshop floor: full-width concrete with expansion joints, a painted
## hangar guide line, and a stencilled hint where the chips are.
func _draw_floor() -> void:
    draw_rect(Rect2(Vector2(0.0, GROUND_Y), Vector2(size.x, size.y - GROUND_Y)),
        _colour("concrete"))
    draw_rect(Rect2(Vector2(0.0, GROUND_Y), Vector2(size.x, 2.0)), _colour("concrete_light"))
    for x in range(40, int(size.x), 96):
        draw_rect(Rect2(Vector2(float(x), GROUND_Y + 2.0),
            Vector2(1.0, size.y - GROUND_Y - 2.0)), _colour("taxiway"))
    # The painted hangar floor line the plane parks on.
    draw_rect(Rect2(Vector2(0.0, GROUND_Y + 14.0), Vector2(size.x, 2.0)),
        _colour("accent_yellow"))
    draw_rect(Rect2(Vector2(0.0, GROUND_Y + 16.0), Vector2(size.x, 1.0)), _colour("sand"))
    # A few worn patches so the slab reads as worked-on, not flat fill.
    for i in range(14):
        var px: float = float((i * 131) % int(size.x))
        var py: float = GROUND_Y + 22.0 + float((i * 53) % int(size.y - GROUND_Y - 26.0))
        draw_rect(Rect2(Vector2(px, py), Vector2(3.0, 1.0)), _colour("taxiway"))
    # Stencilled hint, painted on the slab like ramp lettering.
    _stencil(Vector2(30.0, GROUND_Y + 46.0), "CLICK A CHIP")
    _stencil(Vector2(30.0, GROUND_Y + 58.0), "TO REPAINT")
    _draw_splats()

func _stencil(at: Vector2, text: String) -> void:
    draw_string(_font, (at + Vector2(1.0, 1.0)).round(), text,
        HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SIZE, _colour("taxiway"))
    draw_string(_font, at.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
        UiTheme.FONT_SIZE, _colour("white"))

## Dried paint splats on the slab under the plane — this floor has seen a few
## thousand repaints. Deterministic layout, so the floor never shimmers.
func _draw_splats() -> void:
    var keys: Array[String] = [
        "accent_teal", "accent_yellow", "accent_red", "btn_green", "btn_blue",
        "accent_orange",
    ]
    for i in range(12):
        var sx: float = 150.0 + float((i * 67) % 360)
        var sy: float = GROUND_Y + 22.0 + float((i * 29) % 24)
        var colour: Color = _colour(keys[i % keys.size()])
        colour.a = 0.75
        var w: float = 2.0 + float(i % 3)
        draw_rect(Rect2(Vector2(sx, sy), Vector2(w, 2.0)), colour)
        if i % 3 == 0:
            draw_rect(Rect2(Vector2(sx + 1.0, sy + 2.0), Vector2(1.0, 1.0)), colour)

## Curated workshop dressing beside the plane: tool cart port side, cones
## starboard. Whole-pixel positions, native library scale.
func _draw_props() -> void:
    if _cart_tex != null:
        draw_texture(_cart_tex,
            Vector2(46.0, GROUND_Y + 18.0 - _cart_tex.get_size().y).round())
    if _cone_tex != null:
        draw_texture(_cone_tex,
            Vector2(size.x - 132.0, GROUND_Y + 10.0 - _cone_tex.get_size().y).round())
    if _cones_small_tex != null:
        draw_texture(_cones_small_tex,
            Vector2(size.x - 98.0, GROUND_Y + 24.0 - _cones_small_tex.get_size().y).round())

func _draw_hero(plane: AircraftInstance) -> void:
    var sprite: Texture2D = LiverySprites.side_texture(plane)
    if sprite == null:
        return
    var drawn: Vector2 = sprite.get_size() * float(HERO_SCALE)
    var baseline: float = float(_anchors.get("baseline", sprite.get_size().y - 1.0))
    var wheels_at: float = (baseline + 1.0) * float(HERO_SCALE)
    var hop := 0.0
    if _bounce_frames > 0:
        hop = float(BOUNCE[BOUNCE.size() - _bounce_frames])
    var origin := Vector2(roundf((size.x - drawn.x) * 0.5),
        roundf(GROUND_Y + 2.0 - wheels_at + hop))
    # Chunky drop shadow keeps the plane seated rather than floating.
    var shade := _colour("shadow")
    shade.a = 0.28
    draw_rect(Rect2(Vector2(origin.x + drawn.x * 0.18, GROUND_Y - 2.0).round(),
        Vector2(roundf(drawn.x * 0.64), 4.0)), shade)
    draw_texture_rect(sprite, Rect2(origin, drawn), false)

func _draw_nickname(plane: AircraftInstance) -> void:
    var shown: String = plane.display_name()
    if shown.is_empty():
        return
    var at := Vector2(0.0, 54.0)
    draw_string(_font, at + Vector2(1.0, 1.0), shown, HORIZONTAL_ALIGNMENT_CENTER,
        size.x, UiTheme.FONT_SIZE * 2, _colour("navy_deep"))
    draw_string(_font, at, shown, HORIZONTAL_ALIGNMENT_CENTER,
        size.x, UiTheme.FONT_SIZE * 2, _colour("white"))

## A string of pixel pennants under the title bar — this is a shop, not a form.
func _draw_garland() -> void:
    var flags: Array[String] = [
        "accent_yellow", "accent_teal", "accent_red", "btn_green", "accent_orange",
    ]
    var top: float = roundf(_title_bar.size.y) if _title_bar != null else 24.0
    var index := 0
    var x := 6.0
    while x < size.x - 8.0:
        var colour: Color = _colour(flags[index % flags.size()])
        var drop: float = float(index % 2)   # every other flag hangs 1px lower
        draw_rect(Rect2(Vector2(x, top + drop), Vector2(8.0, 3.0)), colour)
        draw_rect(Rect2(Vector2(x + 1.0, top + drop + 3.0), Vector2(6.0, 3.0)), colour)
        draw_rect(Rect2(Vector2(x + 3.0, top + drop + 6.0), Vector2(2.0, 2.0)), colour)
        index += 1
        x += 20.0

## Chunky drifting clouds, same language as the plane screen.
func _draw_clouds() -> void:
    var drift: float = fposmod(_clock * 5.0, size.x + 140.0)
    var seeds: Array[Vector2] = [
        Vector2(40.0, 40.0), Vector2(230.0, 62.0), Vector2(410.0, 36.0),
        Vector2(540.0, 72.0), Vector2(130.0, 96.0),
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

# ---------------------------------------------------------------------------
# Swatches
# ---------------------------------------------------------------------------

## One slim row of clickable paint chips. Drawn by hand so the chips stay
## pixel-hard: each chip is the scheme's base colour with its light and dark
## shades as bands, like a real paint sample. The selected chip wears a
## navy-and-white ring, and a freshly picked chip flashes for a few frames.
class SwatchRow extends Control:
    const CHIP := 14.0
    const GAP := 3.0
    const PAD := 4.0
    const FLASH_FRAMES := 14

    var options: Array = []
    var sets: Dictionary = {}
    var selected := ""
    var on_pick: Callable
    var _hover := -1
    var _flash_scheme := ""
    var _flash_left := 0

    func _init(option_names: Array, colour_sets: Dictionary, pick: Callable) -> void:
        options = option_names
        sets = colour_sets
        on_pick = pick
        mouse_filter = Control.MOUSE_FILTER_STOP
        custom_minimum_size = Vector2(
            PAD * 2.0 + CHIP * float(options.size()) + GAP * float(options.size() - 1),
            PAD * 2.0 + CHIP)

    ## Ring the chip that was just picked for a few frames.
    func flash(scheme: String) -> void:
        _flash_scheme = scheme
        _flash_left = FLASH_FRAMES
        set_process(true)
        queue_redraw()

    func _process(_delta: float) -> void:
        if _flash_left > 0:
            _flash_left -= 1
            queue_redraw()
        else:
            set_process(false)

    func _chip_rect(index: int) -> Rect2:
        return Rect2(Vector2(PAD + float(index) * (CHIP + GAP), PAD), Vector2(CHIP, CHIP))

    func _index_at(at: Vector2) -> int:
        for index in range(options.size()):
            if _chip_rect(index).grow(2.0).has_point(at):
                return index
        return -1

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseMotion:
            var over: int = _index_at((event as InputEventMouseMotion).position)
            if over != _hover:
                _hover = over
                queue_redraw()
        if event is InputEventMouseButton:
            var click := event as InputEventMouseButton
            if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
                var picked: int = _index_at(click.position)
                if picked >= 0:
                    accept_event()
                    on_pick.call(String(options[picked]))

    func _notification(what: int) -> void:
        if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
            _hover = -1
            queue_redraw()

    func _draw() -> void:
        for index in range(options.size()):
            var scheme: String = String(options[index])
            var keys: Array = sets.get(scheme, [])
            if keys.size() < 3:
                continue
            var chip: Rect2 = _chip_rect(index)
            if scheme == _flash_scheme and _flash_left > 0:
                # Alternating bright ring: the repaint response.
                var ring_key: String = "white" if (_flash_left / 2) % 2 == 0 \
                    else "accent_yellow"
                draw_rect(chip.grow(3.0), PixelPalette.get_colour(ring_key), true)
            elif scheme == selected:
                draw_rect(chip.grow(3.0), PixelPalette.get_colour("navy"), true)
                draw_rect(chip.grow(1.0), PixelPalette.get_colour("white"), true)
            elif index == _hover:
                draw_rect(chip.grow(1.0), PixelPalette.get_colour("hud_blue"), true)
            draw_rect(chip, PixelPalette.get_colour(String(keys[1])), true)
            draw_rect(Rect2(chip.position, Vector2(CHIP, 4.0)),
                PixelPalette.get_colour(String(keys[0])), true)
            draw_rect(Rect2(chip.position + Vector2(0.0, CHIP - 4.0), Vector2(CHIP, 4.0)),
                PixelPalette.get_colour(String(keys[2])), true)
            _outline(chip, PixelPalette.get_colour("navy"))

    func _outline(rect: Rect2, colour: Color) -> void:
        draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), colour, true)
        draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 1.0),
            Vector2(rect.size.x, 1.0)), colour, true)
        draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), colour, true)
        draw_rect(Rect2(rect.position + Vector2(rect.size.x - 1.0, 0.0),
            Vector2(1.0, rect.size.y)), colour, true)
