"""Cabin interior crops for the aircraft detail screen's cabin strip.

Side-view cross-section vocabulary: a passenger seat, an oval porthole, the
EXIT door, a galley cart, carpet floor, and the luggage plus cargo net that
fill the hold. All from the curated flight sheets; coordinates were verified
against alpha component bounds so no crop catches a neighbouring sprite.
"""

MANIFEST = {
    "02_AIRCRAFT_AND_CABIN/flight/2.png": [
        # Tan passenger seat, side view facing right (tray table excluded).
        (289, 287, 57, 98, "cabin/seat_tan.png"),
        # EXIT-signed cabin door.
        (584, 384, 80, 96, "cabin/door_exit.png"),
        # Blue galley trolley.
        (381, 575, 46, 100, "cabin/galley_cart.png"),
        # Blue cabin carpet, thin slice tiled as the floor band.
        (192, 676, 180, 12, "cabin/floor_carpet.png"),
    ],
    "02_AIRCRAFT_AND_CABIN/flight/3.png": [
        # Oval porthole with cream rim.
        (391, 242, 34, 45, "cabin/porthole.png"),
    ],
    "02_AIRCRAFT_AND_CABIN/flight/4.png": [
        # Hold luggage, one per cargo unit.
        (15, 237, 66, 49, "cabin/bag_duffel_navy.png"),
        (110, 237, 67, 50, "cabin/bag_duffel_grey.png"),
        (26, 162, 44, 69, "cabin/bag_case_blue.png"),
        (121, 163, 49, 68, "cabin/bag_backpack.png"),
        (73, 110, 58, 44, "cabin/bag_duffel_black.png"),
        # White cargo net, draped over the loaded stack.
        (3, 390, 90, 70, "cabin/cargo_net.png"),
    ],
}
