class_name GameDB
extends RefCounted

var airports: Dictionary = {}
var aircraft: Dictionary = {}
var airport_upgrades: Dictionary = {}
var job_templates: Dictionary = {}

func load_all() -> void:
    airports = _index_array("res://data/cities.json", "airports")
    aircraft = _index_array("res://data/aircraft.json", "aircraft_families")
    airport_upgrades = _index_array("res://data/airport_upgrades.json", "upgrades")
    job_templates = _index_array("res://data/job_templates.json", "templates")

func _index_array(path: String, key: String) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    var parsed = JSON.parse_string(text)
    assert(typeof(parsed) == TYPE_DICTIONARY, "Invalid JSON: %s" % path)
    var out := {}
    for item in parsed.get(key, []):
        var id := String(item.get("id", ""))
        assert(not id.is_empty(), "Missing id in %s" % path)
        assert(not out.has(id), "Duplicate id %s in %s" % [id, path])
        out[id] = item
    return out
