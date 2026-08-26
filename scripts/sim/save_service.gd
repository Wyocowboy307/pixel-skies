class_name SaveService
extends RefCounted
## Save/load. Enough state is persisted to reconstruct flights after a restart
## or a long absence (docs/TECH_ARCHITECTURE.md, "Save model").

const SAVE_PATH := "user://pixel_skies_save.json"

static func save(state: AirlineState, ids: Ids, now_unix: float) -> bool:
    state.last_seen_unix = now_unix
    var payload: Dictionary = {"state": state.to_dict(), "ids": ids.to_dict()}
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Could not open save file for writing: %s" % SAVE_PATH)
        return false
    file.store_string(JSON.stringify(payload, "  "))
    file.close()
    return true

static func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

## Returns {state, ids} or an empty dictionary when there is nothing usable.
static func load_saved() -> Dictionary:
    if not has_save():
        return {}
    var text: String = FileAccess.get_file_as_string(SAVE_PATH)
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
    if has_save():
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
