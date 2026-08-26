class_name WorldLod
extends RefCounted
## Visual level-of-detail tiers for the world map.
##
## `world_scale` is how many world units one texel of that tier covers, against
## the 2048x1024 world canvas. Screen pixels per
## texel is `world_scale * camera_zoom`; keeping that at or above 1 means the map
## is never downsampled, which is what stops pixel art shimmering during zoom.

const TIERS: Array[Dictionary] = [
    {"name": "lod0", "texture": "world/world_lod0.png", "world_scale": 4.0},
    {"name": "lod1", "texture": "world/world_lod1.png", "world_scale": 2.0},
    {"name": "lod2", "texture": "world/world_lod2.png", "world_scale": 1.0},
    {"name": "lod3", "texture": "world/world_lod3.png", "world_scale": 0.5},
]

## Finest tier that still renders at >= 1 screen pixel per texel.
static func tier_for_zoom(zoom: float) -> int:
    for index in range(TIERS.size() - 1, -1, -1):
        var scale: float = float(TIERS[index]["world_scale"])
        if scale * zoom >= 1.0:
            return index
    return 0

static func texture_path(index: int) -> String:
    return String(TIERS[clampi(index, 0, TIERS.size() - 1)]["texture"])

static func world_scale(index: int) -> float:
    return float(TIERS[clampi(index, 0, TIERS.size() - 1)]["world_scale"])
