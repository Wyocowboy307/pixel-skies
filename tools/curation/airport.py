"""Airport-domain crops: the top-down airfield vocabulary from airport/5, the
terminal facade vocabulary from airport/7, and support buildings from the air
force sheet (plain, emblem-free variants only — nothing military ships as-is).
"""

A5 = "01_AIRPORT_CORE/airport/5.png"
A6 = "01_AIRPORT_CORE/airport/6.png"
A7 = "01_AIRPORT_CORE/airport/7.png"
AF = "03_AIRCRAFT_REFERENCE_ONLY/air force/tile-B-02.png"

MANIFEST = {
    A5: [
        # Runway (vertical in the sheet; the composer rotates 90).
        (0, 0, 96, 384, "airfield/runway_full_36L.png"),      # numbers + piano keys + centreline
        (96, 0, 96, 384, "airfield/runway_full_18R.png"),
        # Taxiways (vertical strips with yellow centreline and blue edge lights).
        (192, 0, 96, 384, "airfield/taxiway_lit.png"),
        (288, 0, 96, 384, "airfield/taxiway_marked.png"),
        # Hold-short / chevron strips (horizontal already).
        (0, 480, 192, 96, "airfield/hold_dashed.png"),
        (192, 480, 192, 96, "airfield/hold_stop.png"),
        # Apron parking grid with painted bays.
        (384, 96, 288, 288, "airfield/apron_bays.png"),
        # Plain surfaces.
        (0, 384, 192, 96, "airfield/concrete.png"),
        (192, 384, 192, 96, "airfield/pavers.png"),
        (480, 384, 96, 192, "airfield/grass.png"),   # pure grass; the wider crop caught a road
        # Top-down service vehicles and props.
        (480, 672, 96, 96, "airfield/tug_train.png"),
        (576, 672, 96, 96, "airfield/truck_cargo.png"),
        (672, 672, 48, 96, "airfield/tug_blue.png"),
        (672, 96, 48, 48, "airfield/grate.png"),
        (672, 200, 96, 56, "airfield/truck_small.png"),
        (672, 624, 96, 32, "airfield/sign_terminal.png"),
        (672, 688, 48, 48, "airfield/sign_gate.png"),
        (720, 336, 24, 64, "airfield/light_pole.png"),
        (672, 384, 48, 48, "airfield/barrier_gate.png"),
    ],
    A7: [
        # Terminal facade vocabulary (front-facing, RPG convention).
        (0, 0, 192, 192, "airfield/terminal_glass_wall.png"),
        (192, 96, 192, 96, "airfield/terminal_glass_low.png"),
        (192, 192, 144, 96, "airfield/terminal_doors.png"),
        (384, 0, 96, 48, "airfield/roof_vent_wide.png"),
        (480, 0, 96, 96, "airfield/roof_vents.png"),
        (576, 576, 192, 192, "airfield/planter_palms.png"),
    ],
    A6: [
        # Side-view vehicles for scene dressing near the terminal road.
        (0, 0, 192, 96, "airfield/airport_bus.png"),
        (480, 0, 192, 96, "airfield/fuel_truck_side.png"),
        (672, 0, 96, 96, "airfield/stairs_side.png"),
    ],
    AF: [
        # Plain support buildings, no insignia.
        (192, 0, 96, 96, "airfield/hangar_grey.png"),
        (576, 192, 96, 96, "airfield/tower_plain.png"),
        (96, 288, 96, 96, "airfield/office_green.png"),
        (384, 384, 96, 96, "airfield/fuel_tank_round.png"),
    ],
}
