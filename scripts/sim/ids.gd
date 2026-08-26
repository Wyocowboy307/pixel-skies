class_name Ids
extends RefCounted
## Stable generated identifiers.
##
## Counter-based rather than random so a seeded simulation replays identically
## and saves diff cleanly. Display names are never used as keys
## (docs/TECH_ARCHITECTURE.md, "Canonical IDs").

var _counters: Dictionary = {}

func next(prefix: String) -> String:
    var count: int = int(_counters.get(prefix, 0)) + 1
    _counters[prefix] = count
    return "%s_%d" % [prefix, count]

func to_dict() -> Dictionary:
    return {"counters": _counters.duplicate()}

func from_dict(data: Dictionary) -> void:
    _counters = (data.get("counters", {}) as Dictionary).duplicate()

## Registrations look like aircraft tail numbers so the fleet feels collectable
## (docs/AIRCRAFT_SYSTEM.md, "Personal attachment").
func next_registration() -> String:
    var count: int = int(_counters.get("reg", 0)) + 1
    _counters["reg"] = count
    var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ"
    var first: String = letters[(count / 24) % 24]
    var second: String = letters[count % 24]
    return "N%d%s%s" % [100 + count, first, second]
