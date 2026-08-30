"""Airport-domain crops: the top-down airfield vocabulary from airport/5, the
terminal facade vocabulary from airport/7, loose-luggage clutter from airport/6,
support buildings from the air force sheet (plain, emblem-free variants only),
and landside/cargo dressing from the 07_AIRPORT_SUPPORT packs.

Scale rule: everything destined for the top-down apron must sit correctly next
to a 44px parked plane and the ~90px runway. airport/6's big side-view vehicles
(bus, fuel bowser, stairs) are detail-screen material only — the bus crop is
kept for that future use and must never be composed into a top-down scene.
"""

A5 = "01_AIRPORT_CORE/airport/5.png"
A6 = "01_AIRPORT_CORE/airport/6.png"
A7 = "01_AIRPORT_CORE/airport/7.png"
AF = "03_AIRCRAFT_REFERENCE_ONLY/air force/tile-B-02.png"
PORT = "07_AIRPORT_SUPPORT/port/tile-B-01.png"
BLD = "07_AIRPORT_SUPPORT/building/tile-B-02.png"

MANIFEST = {
    A5: [
        # Runway (vertical in the sheet; the composer rotates 90).
        (0, 0, 96, 384, "airfield/runway_full_36L.png"),      # numbers + piano keys + centreline
        (96, 0, 96, 384, "airfield/runway_full_18R.png"),
        # Taxiways (vertical strips with yellow centreline and edge lights).
        (192, 0, 96, 384, "airfield/taxiway_lit.png"),
        (288, 0, 96, 384, "airfield/taxiway_marked.png"),
        # Hold-short bar band from the marked taxiway (amber bars, grey shoulders).
        (288, 320, 96, 58, "airfield/hold_bars.png"),
        # Service-road strips (amber-dash GSE lane; STOP bars + no-entry chevrons).
        (0, 480, 192, 96, "airfield/hold_dashed.png"),
        (192, 480, 192, 96, "airfield/hold_stop.png"),
        # LANDSIDE car park: one stall row + drive lane with painted STOPs.
        # Car scale (44px stalls) — never used airside as aircraft stands.
        (384, 96, 288, 96, "airfield/car_park.png"),
        # Plain surfaces.
        (0, 384, 192, 96, "airfield/concrete.png"),
        (192, 384, 192, 96, "airfield/pavers.png"),
        (480, 384, 96, 192, "airfield/grass.png"),   # pure grass; the wider crop caught a road
        # Landside two-lane roads with kerbs.
        (576, 480, 96, 96, "airfield/road_land_v.png"),
        (384, 576, 96, 96, "airfield/road_land_h.png"),
        (576, 576, 96, 96, "airfield/road_land_c.png"),
        # Top-down/three-quarter service vehicles at tug scale.
        (528, 676, 96, 42, "airfield/tug_train.png"),     # grey tug pulling a trailer
        (624, 676, 46, 42, "airfield/tug_blue.png"),      # blue pushback tug
        (574, 722, 46, 44, "airfield/truck_cargo.png"),   # small white cargo van
        (672, 200, 96, 56, "airfield/truck_small.png"),   # tug + blue baggage trailer
        (672, 292, 48, 42, "airfield/belt_loader.png"),
        (720, 486, 48, 38, "airfield/cart_luggage.png"),
        # Props and small dressing.
        (672, 96, 48, 48, "airfield/grate.png"),
        (486, 724, 36, 38, "airfield/manhole.png"),
        (730, 294, 28, 36, "airfield/cone_small.png"),
        (672, 624, 96, 32, "airfield/sign_terminal.png"),
        (672, 672, 48, 48, "airfield/sign_gate.png"),          # dark GATE A1 gantry
        (720, 672, 48, 48, "airfield/sign_gate_green.png"),    # green GATE A1 gantry
        (720, 336, 24, 64, "airfield/light_pole.png"),
        (672, 384, 48, 48, "airfield/barrier_gate.png"),
        (672, 0, 96, 44, "airfield/fence_gate.png"),
        (672, 52, 48, 32, "airfield/jersey_grey.png"),
        (720, 52, 48, 32, "airfield/jersey_striped.png"),
        (724, 530, 44, 38, "airfield/stain_oil.png"),
    ],
    A7: [
        # Terminal facade vocabulary (front-facing, RPG convention).
        (0, 0, 192, 192, "airfield/terminal_glass_wall.png"),
        (192, 96, 192, 96, "airfield/terminal_glass_low.png"),
        (192, 192, 144, 96, "airfield/terminal_doors.png"),
        (384, 192, 192, 96, "airfield/terminal_doors_b.png"),
        # The buildable Expanded Terminal annex (see hangar_small note).
        (384, 192, 192, 96, "airports/buildings/terminal_2.png"),
        (0, 192, 96, 96, "airfield/corner_glass_l.png"),
        (96, 192, 96, 96, "airfield/corner_glass_r.png"),
        (384, 0, 96, 48, "airfield/roof_vent_wide.png"),
        (480, 0, 96, 96, "airfield/roof_vents.png"),
        (576, 0, 96, 96, "airfield/poster_fly.png"),
        (672, 0, 96, 96, "airfield/poster_duty.png"),
        (96, 288, 96, 48, "airfield/floodlights.png"),
        (576, 432, 96, 48, "airfield/railing.png"),
    ],
    A6: [
        # Side-view bus kept ONLY as future detail-screen dressing (4x scale).
        (0, 0, 192, 96, "airfield/airport_bus.png"),
        # Loose luggage at 12-40px — apron clutter that works at plane scale.
        (508, 146, 58, 50, "airfield/bags_cluster.png"),
        (203, 631, 28, 40, "airfield/bag_olive.png"),
        (196, 696, 44, 28, "airfield/bag_khaki.png"),
        (198, 728, 38, 40, "airfield/bag_red.png"),
        (245, 724, 42, 44, "airfield/bag_blue.png"),
        (390, 694, 36, 28, "airfield/bag_purple.png"),
        (432, 734, 44, 34, "airfield/bag_green.png"),
        # Flat cargo staging mat with amber corner angles (top-down).
        (300, 678, 70, 90, "airfield/pallet_zone.png"),
    ],
    AF: [
        # Plain support buildings, no insignia.
        (192, 0, 96, 96, "airfield/hangar_grey.png"),
        # The buildable Maintenance Hangar: same art, served at the logical
        # path the upgrade-slot renderer resolves (production beats the
        # placeholder drawing, so built upgrades match the library scene).
        (192, 0, 96, 96, "airports/buildings/hangar_small.png"),
        (576, 192, 96, 96, "airfield/tower_plain.png"),
        (96, 288, 96, 96, "airfield/office_green.png"),
        (384, 384, 96, 96, "airfield/fuel_tank_round.png"),
    ],
    PORT: [
        # Cargo-yard dressing for the DEN freight corner.
        (384, 0, 140, 96, "airfield/containers_stack.png"),
        # The buildable Cargo Shed upgrade (see hangar_small note above).
        (384, 0, 140, 96, "airports/buildings/cargo_shed.png"),
        (540, 42, 66, 50, "airfield/container_teal.png"),
        (676, 150, 36, 36, "airfield/crate_blue.png"),
        (714, 148, 42, 38, "airfield/crate_wood.png"),
    ],
    BLD: [
        # Top-down cars at the same RPG car scale as the A5 stall rows.
        (7, 577, 34, 46, "airfield/car_blue.png"),
        (55, 577, 34, 46, "airfield/car_red.png"),
        (151, 577, 34, 46, "airfield/car_yellow.png"),
        (199, 577, 34, 46, "airfield/car_green.png"),
        (7, 625, 34, 46, "airfield/car_grey.png"),
        (151, 625, 34, 46, "airfield/car_purple.png"),
        (199, 625, 34, 46, "airfield/car_black.png"),
        (103, 623, 34, 48, "airfield/car_silver.png"),
    ],
}
