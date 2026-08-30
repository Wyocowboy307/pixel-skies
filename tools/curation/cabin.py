"""Cabin interior crops for the aircraft detail screen's cabin strip.

Side-view cross-section vocabulary: a passenger seat, an oval porthole, the
EXIT door, a galley cart, carpet floor, and the luggage plus cargo net that
fill the hold. All from the curated flight sheets; coordinates were verified
against alpha component bounds so no crop catches a neighbouring sprite.

The seat is recoloured on extraction: the locked visual language calls for
warm orange upholstery (the airline's accent colour), but the flight pack has
none — its only saturated orange is the life-vest ramp. The transform below
hue-shifts the seat's brown upholstery onto that orange while leaving the
grey frame, rails and headrest cover alone, so the shipped seat stays a
reproducible library derivation rather than a hand-painted file.
"""

import colorsys


def _orange_upholstery(piece):
    piece = piece.copy()
    pixels = piece.load()
    for py in range(piece.height):
        for px in range(piece.width):
            r, g, b, a = pixels[px, py]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            # Upholstery = warm brown hues with real saturation; the frame and
            # rails are near-grey and fall below the saturation gate.
            if 0.01 <= h <= 0.16 and s >= 0.10 and v >= 0.18:
                s2 = min(1.0, s * 1.9 + 0.18)
                r2, g2, b2 = colorsys.hsv_to_rgb(0.078, s2, min(1.0, v * 1.12))
                pixels[px, py] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return piece


TRANSFORMS = {
    "cabin/seat_tan.png": _orange_upholstery,
}

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
