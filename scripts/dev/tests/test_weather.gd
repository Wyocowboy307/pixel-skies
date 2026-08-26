extends TestCase
## Weather must be deterministic — same airport, same hour, same sky — and the
## dev override must win so capture scenarios can stage bad weather.

func test_deterministic() -> void:
    WeatherService.clear_overrides()
    var a: Dictionary = WeatherService.at("apt_bzn", 1_800_000_100.0, 45.7)
    var b: Dictionary = WeatherService.at("apt_bzn", 1_800_000_500.0, 45.7)
    check_eq(a["kind"], b["kind"], "same hour, same weather")
    check_near(float(a["intensity"]), float(b["intensity"]), 0.0001, "same intensity")

func test_changes_over_time_and_produces_all_kinds() -> void:
    WeatherService.clear_overrides()
    var seen: Dictionary = {}
    for hour in range(600):
        var state: Dictionary = WeatherService.at("apt_bzn", 1_800_000_000.0 + hour * 3600.0, 45.7)
        seen[state["kind"]] = int(seen.get(state["kind"], 0)) + 1
    check(seen.has(WeatherService.Kind.CLEAR), "clear happens")
    check(seen.has(WeatherService.Kind.RAIN), "rain happens")
    check(seen.has(WeatherService.Kind.SNOW), "snow happens in the north")
    check(int(seen.get(WeatherService.Kind.CLEAR, 0)) > 300, "clear is the majority")

func test_override_wins_and_clears() -> void:
    WeatherService.set_override("apt_bzn", WeatherService.Kind.SNOW)
    check_eq(WeatherService.at("apt_bzn", 123.0)["kind"], WeatherService.Kind.SNOW, "override wins")
    WeatherService.clear_overrides()
