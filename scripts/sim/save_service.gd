class_name SaveService
extends RefCounted
## Save/load. Enough state is persisted to reconstruct flights after a restart
## or a long absence (docs/TECH_ARCHITECTURE.md, "Save model").

const SAVE_PATH := "user://pixel_skies_save.json"

## Where saves actually go. The test suite redirects this so a run on a fake
## clock can never overwrite the player's real save — which it did, leaving the
## game loading state timestamped 141 days in the future.
##
## Held on Engine rather than in a static var: the parse-check test re-compiles
## every script to verify it, and re-compiling a script resets its static vars.
## A static redirect therefore silently reverted mid-run and later saves went
## back to the real file. Engine metadata survives script reloads.
const PATH_META := "pixel_skies_save_path"

static func use_path(path: String) -> void:
    Engine.set_meta(PATH_META, path)

static func active_path() -> String:
    if Engine.has_meta(PATH_META):
        return String(Engine.get_meta(PATH_META))
    return SAVE_PATH

static func save(state: AirlineState, ids: Ids, now_unix: float) -> bool:
    state.last_seen_unix = now_unix
    var payload: Dictionary = {"state": state.to_dict(), "ids": ids.to_dict()}
    var file: FileAccess = FileAccess.open(active_path(), FileAccess.WRITE)
    if file == null:
        push_error("Could not open save file for writing: %s" % active_path())
        return false
    file.store_string(JSON.stringify(payload, "  "))
    file.close()
    return true

static func has_save() -> bool:
    return FileAccess.file_exists(active_path())

## Returns {state, ids} or an empty dictionary when there is nothing usable.
static func load_saved() -> Dictionary:
    if not has_save():
        return {}
    var text: String = FileAccess.get_file_as_string(active_path())
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Save file is not valid JSON; ignoring it.")
        return {}
    var data: Dictionary = parsed
    var state_data: Dictionary = data.get("state", {})
    if state_data.is_empty():
        return {}
    state_data = migrate(state_data)
    var state: AirlineState = AirlineState.from_dict(state_data)
    var ids := Ids.new()
    ids.from_dict(data.get("ids", {}))
    return {"state": state, "ids": ids}

## Schema migration. Older saves are upgraded in place rather than discarded.
static func migrate(state_data: Dictionary) -> Dictionary:
    var version: int = int(state_data.get("save_version", 1))
    # No migrations yet: version 1 is the first shipped schema. Each future bump
    # transforms the dictionary here and falls through to the next step.
    state_data["save_version"] = maxi(version, AirlineState.SAVE_VERSION)
    return state_data

static func delete_save() -> void:
    if not has_save():
        return
    # Resolve through DirAccess on the base directory: remove_absolute on a
    # globalized user:// path silently does nothing in a headless run.
    var path: String = active_path()
    var dir: DirAccess = DirAccess.open(path.get_base_dir())
    if dir != null:
        dir.remove(path.get_file())
