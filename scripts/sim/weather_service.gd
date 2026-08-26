class_name WeatherService
extends RefCounted
## Deterministic per-airport weather, derived from a hash of airport and hour so
## the same moment always looks the same and offline progression needs no stored
## state (docs/WEATHER_SYSTEM.md, "Generation").
##
## Presentation-only for now: nothing here changes durations, legality or money.

enum Kind { CLEAR, RAIN, SNOW }

## Dev/capture override: airport_id -> Kind.
static var _override: Dictionary = {}

static func at(airport_id: String, unix_time: float, lat: float = 45.0) -> Dictionary:
    if _override.has(airport_id):
        return {"kind": _override[airport_id], "intensity": 0.85}
    var hour: int = int(floor(unix_time / 3600.0))
    var roll: int = absi(hash("%s|%d" % [airport_id, hour])) % 100
    var kind: Kind = Kind.CLEAR
    if roll >= 68:
        var second: int = absi(hash("%s|%d|kind" % [airport_id, hour])) % 100
        var cold: bool = lat >= 43.0
        kind = Kind.SNOW if (cold and second < 45) else Kind.RAIN
    var intensity: float = 0.4 + float(absi(hash("%s|%d|i" % [airport_id, hour])) % 55) / 100.0
    return {"kind": kind, "intensity": intensity}

static func set_override(airport_id: String, kind: Kind) -> void:
    _override[airport_id] = kind

static func clear_overrides() -> void:
    _override.clear()

static func name_of(kind: Kind) -> String:
    match kind:
        Kind.RAIN: return "RAIN"
        Kind.SNOW: return "SNOW"
        _: return "CLEAR"
