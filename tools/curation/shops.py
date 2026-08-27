"""Shop-screen dressing: props that stand beside the hero aircraft in the
paint shop and upgrade shop so the screens read as workplaces, not forms.

All rects were alpha-checked against a contact sheet before landing here:
the tool cart's 584-587 column sliver is its own push handle (attached at
x=588), not a neighbouring sprite.
"""

MANIFEST = {
    "01_AIRPORT_CORE/airport/6.png": [
        # Rolling tool chest with a pegboard of tools — the mechanic's cart.
        (584, 315, 85, 69, "shop/tool_cart.png"),
        # Classic orange traffic cone with a base plate.
        (684, 162, 25, 31, "shop/cone.png"),
    ],
    "02_AIRCRAFT_AND_CABIN/flight/1.png": [
        # Pair of small amber marker cones from the ramp-equipment rows.
        (532, 640, 40, 17, "shop/cones_small.png"),
    ],
}
