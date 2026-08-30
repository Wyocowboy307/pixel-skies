"""World-map cloud puffs, sliced from the curated overworld weather sheet.

Source: 04_WORLD_BASE/overworld/5.png — the white puffy clouds in the sheet's
top-left weather block. Rects are the exact alpha component bounds (verified
programmatically: every non-transparent pixel in the block is alpha 255, so
the crops keep the binary-alpha rule for free), and the three picks are sized
like the generated placeholders they replace (24x12 / 36x16 / 48x20) with
three distinct silhouettes: a compact puff, a bumpy cumulus, and a wide
flat-bottomed drifter.

Destinations are the same logical paths world_overlay.gd already loads
(world/cloud_{0,1,2}.png), so AssetPaths serves these production slices ahead
of the placeholders automatically.
"""

_WEATHER = "04_WORLD_BASE/overworld/5.png"

MANIFEST = {
    _WEATHER: [
        # Small compact puff.
        (153, 163, 30, 20, "world/cloud_0.png"),
        # Medium cumulus with a lumpy top.
        (53, 14, 39, 21, "world/cloud_1.png"),
        # Wide flat-bottomed drifter.
        (50, 109, 45, 23, "world/cloud_2.png"),
    ],
}
