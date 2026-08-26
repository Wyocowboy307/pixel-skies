extends Node
## Dev screenshot harness.
##
## Screen recording is unavailable on this machine, so visual review happens by
## rendering the real game windowed and saving viewport captures from inside the
## engine. Runs only when the game is launched with capture arguments:
##
##   Godot --path . -- --scenario world_opening
##   Godot --path . -- --shot boot --frames 90
##
## Scenarios live in scripts/dev/scenarios/<name>.gd and expose
## `func run(cap) -> void`, calling `await cap.shot("step_name")` where a frame
## is worth reviewing.

const OUT_DIR := "res://.captures"
const CAPTURE_FPS := 60
const SCENARIO_DIR := "res://scripts/dev/scenarios/%s.gd"

var active := false
var _args: Dictionary = {}
var _shots: Array[String] = []

func _ready() -> void:
    _args = _parse_user_args()
    active = _args.has("scenario") or _args.has("shot")
    if not active:
        return
    process_mode = Node.PROCESS_MODE_ALWAYS
    # Pin the frame rate while capturing. Uncapped, the window renders several
    # hundred frames a second, so a frame count is a meaningless unit of time
    # and time-based animation has barely started when the shot is taken.
    Engine.max_fps = CAPTURE_FPS
    _run.call_deferred()

func _parse_user_args() -> Dictionary:
    var out: Dictionary = {}
    var argv: PackedStringArray = OS.get_cmdline_user_args()
    var i := 0
    while i < argv.size():
        var key: String = argv[i]
        if key.begins_with("--"):
            key = key.substr(2)
            var value: String = "1"
            if i + 1 < argv.size() and not argv[i + 1].begins_with("--"):
                value = argv[i + 1]
                i += 1
            out[key] = value
        i += 1
    return out

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
    if _args.has("scenario"):
        await _run_scenario(String(_args["scenario"]))
    else:
        var frames: int = int(_args.get("frames", "90"))
        await settle(frames)
        await shot(String(_args.get("shot", "shot")))
    _finish()

func _run_scenario(name: String) -> void:
    var path: String = SCENARIO_DIR % name
    if not ResourceLoader.exists(path):
        push_error("Dev capture: no scenario named '%s' (%s)" % [name, path])
        return
    var scenario: GDScript = load(path)
    var runner: Object = scenario.new()
    if not runner.has_method("run"):
        push_error("Dev capture: scenario '%s' has no run(cap)" % name)
        return
    await runner.run(self)

## Waits for the game to actually render `frames` frames before capturing, so a
## capture never lands before the view has responded.
func settle(frames: int = 2) -> void:
    for _i in range(maxi(1, frames)):
        await get_tree().process_frame

## Waits real seconds. Anything driven by a Tween or a timer needs this rather
## than a frame count, because those advance on wall-clock delta.
func wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout
    await get_tree().process_frame

func shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    var texture: ViewportTexture = get_viewport().get_texture()
    if texture == null:
        push_error("Dev capture: viewport has no texture (running headless?)")
        return
    var image: Image = texture.get_image()
    var index: String = "%02d" % (_shots.size() + 1)
    var file_name: String = "%s_%s.png" % [index, name]
    var abs_path: String = ProjectSettings.globalize_path(OUT_DIR).path_join(file_name)
    var err: int = image.save_png(abs_path)
    if err != OK:
        push_error("Dev capture: failed to save %s (error %d)" % [abs_path, err])
        return
    _shots.append(file_name)
    print("[capture] %s" % abs_path)

func _finish() -> void:
    print("[capture] %d frame(s) saved" % _shots.size())
    get_tree().quit(0)
