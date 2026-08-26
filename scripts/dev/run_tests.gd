extends SceneTree
## Headless test runner:
##   Godot --headless --path . --script res://scripts/dev/run_tests.gd
##
## Discovers every scripts/dev/tests/test_*.gd, runs each `test_*` method on a
## fresh instance, and exits non-zero if anything failed.

const TEST_DIR := "res://scripts/dev/tests"

const TEST_SAVE := "user://pixel_skies_test_save.json"

func _init() -> void:
    # Tests run on a fake clock. Pointed at the real save path they leave the
    # game loading state timestamped months in the future, so they get their own
    # file and delete it when the run finishes.
    SaveService.use_path(TEST_SAVE)
    var files: PackedStringArray = _discover()
    var total_checks := 0
    var failed_tests := 0
    var run_tests := 0
    var report: PackedStringArray = []

    for file: String in files:
        var script: GDScript = load(file)
        var suite_name: String = file.get_file().get_basename()
        for method: Dictionary in script.get_script_method_list():
            var method_name: String = String(method["name"])
            if not method_name.begins_with("test_"):
                continue
            var case: TestCase = script.new()
            run_tests += 1
            case.call(method_name)
            total_checks += case.checks
            if not case.failures.is_empty():
                failed_tests += 1
                for failure: String in case.failures:
                    report.append("  FAIL %s::%s — %s" % [suite_name, method_name, failure])

    for line: String in report:
        print(line)
    SaveService.delete_save()
    print("Pixel Skies tests: %d tests, %d checks, %d failed." % [run_tests, total_checks, failed_tests])
    if failed_tests > 0:
        quit(1)
        return
    quit(0)

func _discover() -> PackedStringArray:
    var out: PackedStringArray = []
    var dir: DirAccess = DirAccess.open(TEST_DIR)
    if dir == null:
        push_error("No test directory at %s" % TEST_DIR)
        return out
    for file: String in dir.get_files():
        if file.begins_with("test_") and file.ends_with(".gd"):
            out.append(TEST_DIR.path_join(file))
    out.sort()
    return out
