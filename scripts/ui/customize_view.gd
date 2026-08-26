class_name CustomizeView
extends Control
## Stub: replaced wholesale by the customize-screen build.

signal closed()

var sim: Simulation
var aircraft_id := ""

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    size = get_viewport_rect().size

func bind(simulation: Simulation, id: String) -> void:
    sim = simulation
    aircraft_id = id
