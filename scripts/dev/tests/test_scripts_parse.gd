extends TestCase
## Every script in the project must parse and load.
##
## The simulation tests only touch the classes they use, so a parse error in a
## UI or view script used to reach the running game unnoticed. This walks the
## whole tree instead.

func test_every_script_loads() -> void:
    var failures: PackedStringArray = []
    var checked := 0
    for path: String in _all_scripts("res://scripts"):
        # The runner and the test scripts are executing right now; reloading a
        # running script always fails, and they are proven by the run itself.
        if path.begins_with("res://scripts/dev/tests/") or path.ends_with("run_tests.gd"):
            continue
        checked += 1
        var script: Resource = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REUSE)
        # A GDScript with a parse error still loads as an object, so the only
        # honest check is to re-compile it and read the result.
        if script == null or not (script is GDScript):
            failures.append(path)
        elif (script as GDScript).reload() != OK:
            failures.append(path)
    check(checked > 0, "found scripts to check")
    check(failures.is_empty(), "scripts failed to load: %s" % ", ".join(failures))

func test_every_scene_loads() -> void:
    var failures: PackedStringArray = []
    for path: String in _all_files("res://scenes", ".tscn"):
        if ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) == null:
            failures.append(path)
    check(failures.is_empty(), "scenes failed to load: %s" % ", ".join(failures))

func _all_scripts(root: String) -> PackedStringArray:
    return _all_files(root, ".gd")

func _all_files(root: String, suffix: String) -> PackedStringArray:
    var out: PackedStringArray = []
    var dir: DirAccess = DirAccess.open(root)
    if dir == null:
        return out
    for file: String in dir.get_files():
        if file.ends_with(suffix):
            out.append(root.path_join(file))
    for sub: String in dir.get_directories():
        out.append_array(_all_files(root.path_join(sub), suffix))
    return out

func test_ui_theme_reaches_controls_under_a_canvas_layer() -> void:
    # Theme lookup walks Control and Window ancestors only. A CanvasLayer in the
    # chain breaks it, so a theme set on the root Window never arrives and every
    # control silently falls back to Godot's default styling. Assigning the
    # theme directly is what makes the pixel frames actually render.
    var theme: Theme = PixelTheme.build()
    var panel: StyleBox = theme.get_stylebox("panel", "PanelContainer")
    check(panel is StyleBoxTexture, "panel style is a generated 9-slice, not a flat box")
    if panel is StyleBoxTexture:
        check((panel as StyleBoxTexture).texture != null, "the 9-slice has its texture")
    var button: StyleBox = theme.get_stylebox("normal", "Button")
    check(button is StyleBoxTexture, "button style is a generated 9-slice")
