"""Terrain crops for the follow-mode corridor strip (BZN -> BIL).

Sources:
  04_WORLD_BASE/overworld/1.png  opaque 48px terrain: grass, lake water and
                                 banks, cobbled road, snow mountains, foothills
  04_WORLD_BASE/overworld/3.png  transparent town buildings
  04_WORLD_BASE/overworld/7.png  transparent props: trees, pines, bushes,
                                 rocks, fences, tilled farm plots

Everything lands under world/terrain/ and is consumed offline by
tools/compose_corridor.py; the game itself only loads the composed strip
world/corridor_bzn_bil.png.
"""

_OVERWORLD = "04_WORLD_BASE/overworld/1.png"
_TOWN = "04_WORLD_BASE/overworld/3.png"
_PROPS = "04_WORLD_BASE/overworld/7.png"

MANIFEST = {
    _OVERWORLD: [
        # Grass fill from the lake/mountain latitudes, whose richer green
        # matches the mountain, foothill and lake pieces cropped below.
        (600, 1536, 48, 48, "world/terrain/grass_a.png"),
        (720, 1536, 48, 48, "world/terrain/grass_b.png"),
        (1032, 1536, 48, 48, "world/terrain/grass_c.png"),
        (240, 1656, 48, 48, "world/terrain/grass_d.png"),
        (1224, 1656, 48, 48, "world/terrain/grass_e.png"),
        (384, 1776, 48, 48, "world/terrain/grass_f.png"),
        # Lake water and its grass banks (big lake at 1344-1776, 1536-2016).
        (1488, 1680, 48, 48, "world/terrain/water_a.png"),
        (1536, 1728, 48, 48, "world/terrain/water_b.png"),
        (1284, 1656, 48, 48, "world/terrain/bank_west_a.png"),
        (1284, 1704, 48, 48, "world/terrain/bank_west_b.png"),
        (1740, 1656, 48, 48, "world/terrain/bank_east_a.png"),
        (1740, 1698, 48, 48, "world/terrain/bank_east_b.png"),
        # Cobbled road, cropped from the vertical street with its grassy
        # centre line (road spans x 1278-1460 up top).
        (1272, 96, 48, 48, "world/terrain/road_edge_w_a.png"),
        (1272, 192, 48, 48, "world/terrain/road_edge_w_b.png"),
        (1296, 96, 48, 48, "world/terrain/road_mid_a.png"),
        (1344, 96, 48, 48, "world/terrain/road_mid_b.png"),
        (1296, 240, 48, 48, "world/terrain/road_mid_a2.png"),
        (1344, 240, 48, 48, "world/terrain/road_mid_b2.png"),
        (1392, 144, 48, 48, "world/terrain/road_fill.png"),
        # Snow-capped mountain massif and a lone outcrop, on matching grass.
        (8, 1540, 496, 252, "world/terrain/mountains_big.png"),
        # (Every larger foothill composition on this sheet is truncated by
        # its region boundary, so the strip builds its foothills from the
        # transparent pine and rock props instead.)
    ],
    _TOWN: [
        (0, 0, 48, 48, "world/terrain/house_a.png"),
        (48, 0, 48, 48, "world/terrain/house_b.png"),
        (96, 0, 48, 48, "world/terrain/house_c.png"),
        (144, 0, 48, 48, "world/terrain/house_d.png"),
        (0, 48, 48, 48, "world/terrain/house_e.png"),
        (96, 48, 48, 48, "world/terrain/house_f.png"),
        (676, 288, 92, 96, "world/terrain/church.png"),
    ],
    _PROPS: [
        (0, 0, 96, 96, "world/terrain/tree_big_a.png"),
        (96, 0, 96, 96, "world/terrain/tree_big_b.png"),
        (240, 0, 48, 96, "world/terrain/tree_small.png"),
        (288, 0, 48, 96, "world/terrain/pine_a.png"),
        (336, 0, 48, 96, "world/terrain/pine_b.png"),
        (480, 0, 48, 48, "world/terrain/pine_small_a.png"),
        (528, 0, 48, 48, "world/terrain/pine_small_b.png"),
        (384, 0, 48, 48, "world/terrain/bush_a.png"),
        (192, 96, 48, 48, "world/terrain/bush_b.png"),
        (240, 96, 48, 48, "world/terrain/bush_c.png"),
        (288, 96, 48, 48, "world/terrain/bush_d.png"),
        (192, 144, 48, 48, "world/terrain/tuft_a.png"),
        (240, 144, 48, 48, "world/terrain/tuft_b.png"),
        (480, 144, 48, 48, "world/terrain/rock_a.png"),
        (528, 144, 48, 48, "world/terrain/rock_b.png"),
        (96, 672, 96, 96, "world/terrain/plot_a.png"),
        (192, 672, 96, 96, "world/terrain/plot_b.png"),
        (288, 672, 96, 96, "world/terrain/plot_c.png"),
        (384, 672, 96, 96, "world/terrain/plot_d.png"),
        (192, 576, 96, 48, "world/terrain/fence.png"),
    ],
}
