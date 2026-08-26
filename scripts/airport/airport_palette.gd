class_name AirportPalette
extends RefCounted
## One controlled palette for airport ground scenes, shared by every airport so
## regional flavour comes from decoration rather than a bespoke tileset
## (docs/ART_BIBLE.md, "Biomes").

const ASPHALT := Color("#2f3742")
const ASPHALT_EDGE := Color("#454f5c")
const TAXIWAY := Color("#565c5e")
const TAXIWAY_EDGE := Color("#666c6d")
const CONCRETE := Color("#525a63")
const CONCRETE_EDGE := Color("#626b75")
const MARK_WHITE := Color("#d8e2e6")
const MARK_YELLOW := Color("#d3ac57")
const SHADOW := Color("#101820", 0.35)
const OUTLINE := Color("#141c24")

const TERMINAL_ROOF := Color("#7d7266")
const TERMINAL_FACE := Color("#5d554c")
const TOWER_ROOF := Color("#8a8f96")
const CARGO_ROOF := Color("#6a6f78")
const FUEL_ROOF := Color("#6c7a74")
const HANGAR_ROOF := Color("#6f7a84")

const BIOMES := {
    "mountain": {
        "ground": Color("#4c6349"),
        "ground_alt": Color("#455a43"),
        "decor": Color("#3a5140"),
        "ridge": Color("#6d7a72"),
    },
    "plains": {
        "ground": Color("#6a7348"),
        "ground_alt": Color("#606a42"),
        "decor": Color("#7a8150"),
        "ridge": Color("#8a8a5e"),
    },
    "highplains": {
        "ground": Color("#77764f"),
        "ground_alt": Color("#6c6c49"),
        "decor": Color("#847e56"),
        "ridge": Color("#8f8a63"),
    },
}

static func biome(name: String) -> Dictionary:
    return BIOMES.get(name, BIOMES["plains"])

static func building_roof(kind: String) -> Color:
    match kind:
        "terminal": return TERMINAL_ROOF
        "tower": return TOWER_ROOF
        "cargo": return CARGO_ROOF
        "fuel": return FUEL_ROOF
        "hangar": return HANGAR_ROOF
        _: return CARGO_ROOF
