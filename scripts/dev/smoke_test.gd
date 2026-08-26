extends SceneTree
## Kept as the historical Milestone-0 entry point. The real checks now live in
## scripts/dev/tests/ and run through scripts/dev/run_tests.gd — use ./verify.sh.

func _init() -> void:
    print("Pixel Skies: smoke checks moved to ./verify.sh (scripts/dev/run_tests.gd).")
    quit(0)
