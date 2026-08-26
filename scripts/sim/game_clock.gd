class_name GameClock
extends RefCounted
## Time source for the whole simulation.
##
## Production uses wall time; tests install a fixed clock and advance it by hand.
## Nothing in the simulation may read Time directly — flight progress must be
## derived from timestamps, never from how long the game happened to be open
## (docs/TECH_ARCHITECTURE.md, "Game clock").

var _fixed_now := -1.0

## Real wall-clock seconds since the Unix epoch, or the fixed test time.
func now() -> float:
    if _fixed_now >= 0.0:
        return _fixed_now
    return Time.get_unix_time_from_system()

func is_fixed() -> bool:
    return _fixed_now >= 0.0

## Freeze the clock at a given instant. Tests use this so a scenario is
## reproducible rather than dependent on how fast the machine ran.
func set_fixed(unix_seconds: float) -> void:
    _fixed_now = unix_seconds

func advance(seconds: float) -> void:
    assert(is_fixed(), "advance() is only meaningful on a fixed clock")
    _fixed_now += seconds

func use_real_time() -> void:
    _fixed_now = -1.0
