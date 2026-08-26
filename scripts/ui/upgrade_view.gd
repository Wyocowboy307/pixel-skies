class_name UpgradeView
extends Control
## The plane upgrade shop: one owned airframe on the apron and the handful of
## kits that can be bolted onto it.
##
## The plane is the centrepiece; each card states plainly what it costs and
## what it changes, and hovering a card answers the only question that matters
## before spending: "what do my numbers become?" Buying is celebrated — an
## upgrade is a milestone for a small airline, not a settings toggle.

signal closed()

const HERO_SCALE := 2
const GROUND_Y := 186.0
const STRIP_Y := 192.0
const CARDS_Y := 216.0
const CARD_SIZE := Vector2(196.0, 136.0)
const FLOAT_SECONDS := 0.62
const CONFETTI_SECONDS := 0.85

var sim: Simulation
var aircraft_id := ""

var _font: Font
var _clock := 0.0

var _name_label: Label
var _family_label: Label
var _money_label: Label
var _strip_row: HBoxContainer
var _cards_row: HBoxContainer
var _card_panels: Dictionary = {}      ## upgrade_id -> PanelContainer

var _hovered_id := ""
var _selected_id := ""
var _hero_origin := Vector2.ZERO
var _hero_size := Vector2.ZERO
## Opaque bounds of the side sprite within its canvas, so effects can wrap the
## plane itself rather than the padded canvas around it.
var _hero_bbox := Rect2()

## Celebration state — purely presentation, started after the sim has already
## committed the purchase.
var _flash_frames := 0
var _float_label: Label
var _float_y := 0.0
var _float_t := 0.0
var _confetti: Array[Dictionary] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_preset(Control.PRESET_FULL_RECT)
    # Built in code under a CanvasLayer: no layout pass arrives, so size is
    # taken from the viewport directly (see aircraft_detail_view.gd).
    size = get_viewport_rect().size
    get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _font = load(AssetPaths.resolve_file("ui/font5x7.fnt"))
    _build_chrome()
    set_process(true)

func bind(simulation: Simulation, id: String) -> void:
    sim = simulation
    aircraft_id = id
    # A direct method callable auto-disconnects when this node is freed; a
    # lambda here would dangle on the long-lived sim.
    sim.money_changed.connect(_on_money_changed)
    refresh()

func _on_money_changed(_amount: int) -> void:
    _refresh_money()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        closed.emit()

func _plane() -> AircraftInstance:
    if sim == null:
        return null
    return sim.state.aircraft.get(aircraft_id, null)

func _colour(key: String) -> Color:
    return PixelPalette.get_colour(key)

func _label(text: String, colour_key: String, size_px: int = 7) -> Label:
    var node := UiTheme.label(text, colour_key)
    if size_px != 7:
        node.add_theme_font_size_override("font_size", size_px)
    return node

func _icon(name: String, scale: int = 1) -> TextureRect:
    var node := UiTheme.icon(name)
    if scale > 1:
        node.stretch_mode = TextureRect.STRETCH_SCALE
        node.custom_minimum_size = Vector2(10.0 * float(scale), 10.0 * float(scale))
    return node

# ---------------------------------------------------------------------------
# Chrome
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
    var header := HBoxContainer.new()
    header.set_anchors_preset(Control.PRESET_TOP_WIDE)
    header.offset_left = 6.0
    header.offset_right = -6.0
    header.offset_top = 3.0
    header.offset_bottom = 21.0
    header.add_theme_constant_override("separation", 6)
    add_child(header)
    header.add_child(_icon("upgrade", 2))
    header.add_child(_label("UPGRADE SHOP", "panel_light", 14))
    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(gap)
    header.add_child(_icon("money", 2))
    _money_label = _label("", "white", 14)
    header.add_child(_money_label)
    var gap2 := Control.new()
    gap2.custom_minimum_size = Vector2(8.0, 0.0)
    header.add_child(gap2)
    var back := UiTheme.button("BACK")
    back.pressed.connect(func() -> void: closed.emit())
    header.add_child(back)

    # The plane's name, big, above the plane itself.
    _name_label = _label("", "panel_deep", 14)
    _name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _name_label.offset_top = 30.0
    _name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_name_label)
    _family_label = _label("", "sky_deep")
    _family_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _family_label.offset_top = 47.0
    _family_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_family_label)

    # CURRENT -> UPGRADED strip, sitting on the band under the apron.
    _strip_row = HBoxContainer.new()
    _strip_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _strip_row.offset_top = STRIP_Y + 2.0
    _strip_row.offset_bottom = STRIP_Y + 20.0
    _strip_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _strip_row.add_theme_constant_override("separation", 8)
    add_child(_strip_row)

    _cards_row = HBoxContainer.new()
    _cards_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _cards_row.offset_left = 6.0
    _cards_row.offset_right = -6.0
    _cards_row.offset_top = CARDS_Y
    _cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _cards_row.add_theme_constant_override("separation", 10)
    add_child(_cards_row)

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func refresh() -> void:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    var family: Dictionary = sim.family_of(plane)
    _name_label.text = plane.display_name().to_upper()
    _family_label.text = String(family.get("name", "")).to_upper()
    _refresh_money()
    _refresh_cards()
    _refresh_strip()
    queue_redraw()

func _refresh_money() -> void:
    if sim != null:
        _money_label.text = UiTheme.money(sim.state.money)

func _upgrades() -> Array:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return []
    return (sim.db.aircraft.get(plane.family_id, {}) as Dictionary).get("upgrades", [])

func _refresh_cards() -> void:
    for child: Node in _cards_row.get_children():
        child.queue_free()
    _card_panels = {}
    for entry: Variant in _upgrades():
        var upgrade: Dictionary = entry
        var card: PanelContainer = _build_card(upgrade)
        _cards_row.add_child(card)
        _card_panels[String(upgrade.get("id", ""))] = card

func _build_card(upgrade: Dictionary) -> PanelContainer:
    var plane: AircraftInstance = _plane()
    var upgrade_id: String = String(upgrade.get("id", ""))
    var owned: bool = plane.upgrade_ids.has(upgrade_id)
    var verdict: Dictionary = sim.aircraft_upgrade_check(aircraft_id, upgrade_id)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = CARD_SIZE
    panel.mouse_entered.connect(func() -> void: _set_hovered(upgrade_id))
    panel.mouse_exited.connect(func() -> void: _set_hovered(""))
    panel.gui_input.connect(func(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed \
                and event.button_index == MOUSE_BUTTON_LEFT:
            select_upgrade(upgrade_id))

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    panel.add_child(column)

    column.add_child(_label(String(upgrade.get("name", "")).to_upper(), "ink", 14))
    var blurb := _label(String(upgrade.get("blurb", "")), "ink_soft")
    blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_child(blurb)

    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(spacer)

    if owned:
        var done := HBoxContainer.new()
        done.alignment = BoxContainer.ALIGNMENT_CENTER
        done.add_theme_constant_override("separation", 6)
        column.add_child(done)
        done.add_child(_icon("upgrade", 2))
        done.add_child(_label("OWNED", "accent_green", 14))
        return panel

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    column.add_child(row)
    row.add_child(_icon("money", 2))
    row.add_child(_label(UiTheme.money(int(upgrade.get("cost", 0))), "ink", 14))
    var push := Control.new()
    push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    push.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(push)
    var buy := UiTheme.action("BUY")
    buy.disabled = not bool(verdict["ok"])
    buy.mouse_entered.connect(func() -> void: _set_hovered(upgrade_id))
    buy.pressed.connect(func() -> void: _on_buy(upgrade_id))
    row.add_child(buy)

    if not bool(verdict["ok"]):
        column.add_child(_label(String(verdict["reason"]), "accent_red"))
    return panel

func _set_hovered(upgrade_id: String) -> void:
    if _hovered_id == upgrade_id:
        return
    _hovered_id = upgrade_id
    _refresh_strip()
    queue_redraw()

## Programmatic selection — also the hook the capture scenario drives.
func select_upgrade(upgrade_id: String) -> void:
    _selected_id = "" if _selected_id == upgrade_id else upgrade_id
    _refresh_strip()
    queue_redraw()

# ---------------------------------------------------------------------------
# CURRENT -> UPGRADED strip
# ---------------------------------------------------------------------------

## The stat comparison for one candidate upgrade, config-aware: what the plane
## does now versus what it would do with the kit fitted.
func _stat_changes(candidate_id: String) -> Array[Dictionary]:
    var plane: AircraftInstance = _plane()
    var raw: Dictionary = sim.db.aircraft.get(plane.family_id, {})
    var current: Dictionary = sim.family_of(plane)
    var next_ids: Array[String] = plane.upgrade_ids.duplicate()
    next_ids.append(candidate_id)
    var upgraded: Dictionary = Rules.effective_family(raw, next_ids)
    var now_cap: Dictionary = Rules.capacity(current, plane.configuration)
    var next_cap: Dictionary = Rules.capacity(upgraded, plane.configuration)
    var out: Array[Dictionary] = []
    if int(now_cap["seats"]) != int(next_cap["seats"]):
        out.append({"unit": "SEATS", "from": int(now_cap["seats"]), "to": int(next_cap["seats"])})
    if int(now_cap["cargo_units"]) != int(next_cap["cargo_units"]):
        out.append({"unit": "HOLD", "from": int(now_cap["cargo_units"]),
            "to": int(next_cap["cargo_units"])})
    var now_range: int = roundi(float(current.get("range_nm", 0.0)))
    var next_range: int = roundi(float(upgraded.get("range_nm", 0.0)))
    if now_range != next_range:
        out.append({"unit": "NM", "from": now_range, "to": next_range})
    return out

func _refresh_strip() -> void:
    for child: Node in _strip_row.get_children():
        child.queue_free()
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    var focus: String = _hovered_id if not _hovered_id.is_empty() else _selected_id
    if focus.is_empty():
        # Nothing picked: state the plane as it is today.
        var family: Dictionary = sim.family_of(plane)
        var limits: Dictionary = Rules.capacity(family, plane.configuration)
        _strip_row.add_child(_icon("passenger"))
        _strip_row.add_child(_label("%d SEATS" % int(limits["seats"]), "white", 14))
        _strip_row.add_child(_label("·", "sky_light", 14))
        _strip_row.add_child(_icon("cargo"))
        _strip_row.add_child(_label("%d HOLD" % int(limits["cargo_units"]), "white", 14))
        _strip_row.add_child(_label("·", "sky_light", 14))
        _strip_row.add_child(_icon("range"))
        _strip_row.add_child(_label("%d NM" % roundi(float(family.get("range_nm", 0.0))),
            "white", 14))
        return
    if plane.upgrade_ids.has(focus):
        var upgrade: Dictionary = sim.aircraft_upgrade(plane.family_id, focus)
        _strip_row.add_child(_icon("upgrade", 2))
        _strip_row.add_child(_label("%s IS FITTED" % String(upgrade.get("name", "")).to_upper(),
            "accent_green", 14))
        return
    var changes: Array[Dictionary] = _stat_changes(focus)
    var first := true
    for change: Dictionary in changes:
        if not first:
            _strip_row.add_child(_label("·", "sky_light", 14))
        first = false
        var unit: String = String(change["unit"])
        _strip_row.add_child(_label("%d %s" % [int(change["from"]), unit], "white", 14))
        _strip_row.add_child(_label("→", "accent_yellow", 14))
        _strip_row.add_child(_label("%d %s" % [int(change["to"]), unit], "accent_green", 14))

# ---------------------------------------------------------------------------
# Buying
# ---------------------------------------------------------------------------

func _on_buy(upgrade_id: String) -> void:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    var upgrade: Dictionary = sim.aircraft_upgrade(plane.family_id, upgrade_id)
    var result: Dictionary = sim.purchase_aircraft_upgrade(aircraft_id, upgrade_id)
    if not bool(result["ok"]):
        refresh()
        return
    _celebrate(upgrade)
    refresh()

## Earning something should look like earning something: the plane flashes,
## the gained stat floats up off it, and a little confetti burst goes off.
## All of it is presentation; the sim has already settled the purchase.
func _celebrate(upgrade: Dictionary) -> void:
    _flash_frames = 9
    var effects: Dictionary = upgrade.get("effects", {})
    var gains: PackedStringArray = []
    if int(effects.get("seats", 0)) != 0:
        gains.append("+%d SEATS" % int(effects.get("seats", 0)))
    if int(effects.get("cargo_units", 0)) != 0:
        gains.append("+%d HOLD" % int(effects.get("cargo_units", 0)))
    if int(effects.get("range_nm", 0)) != 0:
        gains.append("+%d NM" % int(effects.get("range_nm", 0)))
    _start_float(" ".join(gains))
    _spawn_confetti()

func _start_float(text: String) -> void:
    if _float_label != null:
        _float_label.queue_free()
    _float_label = _label(text, "accent_green", 14)
    var chip := StyleBoxFlat.new()
    chip.bg_color = _colour("panel_deep")
    chip.content_margin_left = 6.0
    chip.content_margin_right = 6.0
    chip.content_margin_top = 3.0
    chip.content_margin_bottom = 3.0
    _float_label.add_theme_stylebox_override("normal", chip)
    add_child(_float_label)
    var width: float = _font.get_string_size(_float_label.text,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 12.0
    _float_y = _hero_origin.y + _hero_size.y * 0.35
    _float_t = 0.0
    _float_label.position = Vector2(roundf((size.x - width) * 0.5), roundf(_float_y))

func _spawn_confetti() -> void:
    _confetti = []
    var keys: Array[String] = ["accent_orange", "accent_teal", "accent_yellow",
        "accent_green", "accent_red", "white"]
    var centre := Vector2(size.x * 0.5, GROUND_Y - 56.0)
    for i in range(22):
        var angle: float = TAU * float(i) / 22.0
        _confetti.append({
            "at": centre + Vector2(cos(angle), sin(angle)) * 10.0,
            "velocity": Vector2(cos(angle), sin(angle) - 1.2) * (90.0 + float(i % 5) * 30.0),
            "colour": keys[i % keys.size()],
            "age": 0.0,
            "grain": 3.0 + float(i % 2),
        })

func _process(delta: float) -> void:
    _clock += delta
    if _flash_frames > 0:
        _flash_frames -= 1
    if _float_label != null:
        _float_t += delta
        # Whole-pixel steps, so the rising text stays on the pixel grid.
        _float_y -= delta * 46.0
        _float_label.position.y = roundf(_float_y)
        if _float_t > FLOAT_SECONDS * 0.66:
            _float_label.modulate.a = 0.66
        if _float_t > FLOAT_SECONDS * 0.85:
            _float_label.modulate.a = 0.33
        if _float_t >= FLOAT_SECONDS:
            _float_label.queue_free()
            _float_label = null
    var alive: Array[Dictionary] = []
    for grain: Dictionary in _confetti:
        grain["age"] = float(grain["age"]) + delta
        if float(grain["age"]) >= CONFETTI_SECONDS:
            continue
        var velocity: Vector2 = grain["velocity"]
        velocity.y += 260.0 * delta
        grain["velocity"] = velocity
        grain["at"] = (grain["at"] as Vector2) + velocity * delta
        alive.append(grain)
    _confetti = alive
    queue_redraw()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _text(at: Vector2, value: String, colour_key: String, size_px: int = 7) -> void:
    draw_string(_font, at.round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px,
        _colour(colour_key))

func _draw() -> void:
    _draw_scene()
    _draw_hero()
    _draw_selection_ring()
    _draw_flash()
    _draw_confetti()

## A sunny apron, same weather as the plane screen next door.
func _draw_scene() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), _colour("sky"))
    _draw_clouds()
    # Header band.
    draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 22.0)), _colour("panel_deep"))
    draw_rect(Rect2(Vector2(0.0, 22.0), Vector2(size.x, 1.0)), _colour("panel_edge"))
    # Apron the plane stands on, then grass the cards sit on.
    draw_rect(Rect2(Vector2(0.0, GROUND_Y - 10.0), Vector2(size.x, 10.0)), _colour("concrete"))
    draw_rect(Rect2(Vector2(0.0, GROUND_Y - 10.0), Vector2(size.x, 1.0)),
        _colour("concrete_light"))
    for x in range(0, int(size.x), 48):
        draw_rect(Rect2(Vector2(float(x), GROUND_Y - 9.0), Vector2(1.0, 9.0)),
            _colour("taxiway"))
    draw_rect(Rect2(Vector2(0.0, GROUND_Y), Vector2(size.x, size.y - GROUND_Y)),
        _colour("grass"))
    draw_rect(Rect2(Vector2(0.0, GROUND_Y), Vector2(size.x, 2.0)), _colour("grass_light"))
    for i in range(22):
        var gx: float = float((i * 113) % int(size.x))
        var gy: float = GROUND_Y + 8.0 + float((i * 41) % int(size.y - GROUND_Y - 12.0))
        draw_rect(Rect2(Vector2(gx, gy), Vector2(2.0, 1.0)), _colour("grass_dark"))
    # The band the CURRENT -> UPGRADED strip sits on.
    draw_rect(Rect2(Vector2(0.0, STRIP_Y), Vector2(size.x, 22.0)), _colour("panel_deep"))
    draw_rect(Rect2(Vector2(0.0, STRIP_Y + 22.0), Vector2(size.x, 1.0)), _colour("panel_edge"))

func _draw_clouds() -> void:
    var drift: float = fposmod(_clock * 5.0, size.x + 140.0)
    var seeds: Array[Vector2] = [
        Vector2(60.0, 40.0), Vector2(250.0, 66.0), Vector2(430.0, 36.0),
        Vector2(540.0, 84.0), Vector2(140.0, 104.0),
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

func _draw_hero() -> void:
    var plane: AircraftInstance = _plane()
    if plane == null:
        return
    var sprite: Texture2D = AircraftSprites.side_sprite(plane.family_id)
    if sprite == null:
        return
    var drawn: Vector2 = sprite.get_size() * float(HERO_SCALE)
    var baseline: float = _hero_baseline(plane, sprite)
    var wheels_at: float = (baseline + 1.0) * float(HERO_SCALE)
    _hero_origin = Vector2(roundf((size.x - drawn.x) * 0.5), roundf(GROUND_Y - wheels_at))
    _hero_size = drawn
    if _hero_bbox.size == Vector2.ZERO:
        var image: Image = sprite.get_image()
        if image != null:
            var used: Rect2i = image.get_used_rect()
            _hero_bbox = Rect2(Vector2(used.position) * float(HERO_SCALE),
                Vector2(used.size) * float(HERO_SCALE))
    # Chunky drop shadow keeps the plane seated rather than floating.
    var shade := _colour("shadow")
    shade.a = 0.28
    draw_rect(Rect2(Vector2(_hero_origin.x + drawn.x * 0.18, GROUND_Y - 5.0).round(),
        Vector2(roundf(drawn.x * 0.64), 4.0)), shade)
    draw_texture_rect(sprite, Rect2(_hero_origin, drawn), false)

## The wheels line comes from the art pipeline's metadata; canvas height is a
## poor substitute because generated art pads under the gear.
func _hero_baseline(plane: AircraftInstance, sprite: Texture2D) -> float:
    var key: String = plane.family_id.replace("ac_", "")
    var path: String = AssetPaths.resolve_file("aircraft/%s/%s_side.json" % [key, key])
    if FileAccess.file_exists(path):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
        if typeof(parsed) == TYPE_DICTIONARY:
            return float((parsed as Dictionary).get("baseline", sprite.get_size().y - 1.0))
    return sprite.get_size().y - 1.0

## A bold ring around the card being considered, drawn outside the panel so
## the frame art stays untouched.
func _draw_selection_ring() -> void:
    var focus: String = _hovered_id if not _hovered_id.is_empty() else _selected_id
    if focus.is_empty() or not _card_panels.has(focus):
        return
    var panel: PanelContainer = _card_panels[focus]
    if not is_instance_valid(panel) or panel.size.x <= 0.0:
        return
    var rect: Rect2 = panel.get_global_rect().grow(4.0)
    rect.position = rect.position.round()
    rect.size = rect.size.round()
    var ring := _colour("accent_orange")
    draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), ring)
    draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 3.0),
        Vector2(rect.size.x, 3.0)), ring)
    draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), ring)
    draw_rect(Rect2(rect.position + Vector2(rect.size.x - 3.0, 0.0),
        Vector2(3.0, rect.size.y)), ring)

func _draw_flash() -> void:
    if _flash_frames <= 0 or _hero_bbox.size == Vector2.ZERO:
        return
    # Alternating frames read as a bright pixel flash, not a smooth fade.
    if _flash_frames % 2 == 0:
        return
    var glow := _colour("white")
    glow.a = 0.6
    draw_rect(Rect2(_hero_origin + _hero_bbox.position, _hero_bbox.size).grow(4.0), glow)

func _draw_confetti() -> void:
    var shade: Color = _colour("outline")
    for grain: Dictionary in _confetti:
        var at: Vector2 = (grain["at"] as Vector2).round()
        var side: float = float(grain.get("grain", 3.0))
        # A dark under-pixel keeps each grain visible against sky and cloud.
        draw_rect(Rect2(at + Vector2(1.0, 1.0), Vector2(side, side)), shade)
        draw_rect(Rect2(at, Vector2(side, side)), _colour(String(grain["colour"])))
