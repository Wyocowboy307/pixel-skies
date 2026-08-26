class_name TestCase
extends RefCounted
## Base class for Pixel Skies simulation tests.
##
## Every method named `test_*` is discovered and run by scripts/dev/run_tests.gd.
## Checks record failures instead of aborting, so one run reports every problem.

var failures: PackedStringArray = []
var checks := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures.append(message)

func check_eq(actual: Variant, expected: Variant, message: String) -> void:
    checks += 1
    if actual != expected:
        failures.append("%s (expected %s, got %s)" % [message, expected, actual])

func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
    checks += 1
    if absf(actual - expected) > tolerance:
        failures.append("%s (expected %f +/- %f, got %f)" % [message, expected, tolerance, actual])

func check_between(actual: float, low: float, high: float, message: String) -> void:
    checks += 1
    if actual < low or actual > high:
        failures.append("%s (expected %f..%f, got %f)" % [message, low, high, actual])
