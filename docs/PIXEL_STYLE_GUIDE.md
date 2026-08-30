# Pixel Skies — Locked Pixel Style Guide

This file is the **authority** for every visual asset in Pixel Skies. `ART_BIBLE.md`
states the intent; this file states the exact, checkable rules. If an asset
breaks a rule here, the asset is wrong.

## 1. The game is a pixel game

Pixel Skies renders at a fixed internal resolution and is scaled to the window by
whole numbers only. There is no smooth scaling, no anti-aliasing, no vector
shapes and no painterly shading anywhere in the core presentation.

- **Internal resolution: 640×360.**
- Scales 2× to 1280×720 and 3× to 1920×1080 with perfectly square pixels.
- Godot stretch mode `viewport`, scale mode `integer`.
- Every texture imports lossless, nearest filter, no mipmaps.
- Nothing is drawn at a fractional pixel position. Sprites snap to the pixel grid.

## 1b. The curated library

`assets/library/` (gitignored, 144MB) holds the curated pack reduction described
in `docs/LIBRARY_README.md` / `docs/LIBRARY_HANDOFF.md`. Production scene art is
**sliced from these sheets** via `tools/curate.py` manifests and composed via
`tools/compose_airport.py` — never hand-copied, never procedurally faked.

Two consequences:

- **Library art keeps its own palette.** It is approved finished art; snapping
  it to the game palette would destroy it. The locked-palette rule below binds
  the *generated placeholder* tree (`assets/art/placeholder/`), which tests
  enforce; the two palettes are harmonized by curation choices, not by force.
- **Scene airports.** An airport whose layout carries a `scene` key draws one
  composed texture as its entire ground truth; only living things (aircraft,
  walkers, vehicles, weather) draw on top. Procedural airfield drawing survives
  solely as the fallback for airports not yet composed.

## 2. Locked palette

Every asset draws from this palette and no other colour. It is defined once in
`tools/pixelart/palette.py`; the game reads the same values from
`data/world/palette.json`.

### Water
| key | hex | use |
| --- | --- | --- |
| `water_deep` | `#16293b` | open ocean |
| `water` | `#1e4058` | ocean |
| `water_shelf` | `#2b5f7a` | continental shelf, lakes |

### Land
| key | hex | use |
| --- | --- | --- |
| `grass_dark` | `#2c4634` | shadowed vegetation, tree cores |
| `grass` | `#3d6045` | default airfield grass, temperate land |
| `grass_light` | `#537a5a` | lit grass, highlights |
| `scrub` | `#6b7a4a` | steppe, dry grass |
| `sand` | `#8a7a52` | arid land, dirt |
| `sand_light` | `#a3926a` | lit dirt |
| `soil` | `#4a3d2c` | ploughed ground, shadow under decor |

### Cold
| key | hex | use |
| --- | --- | --- |
| `ice` | `#b7cbd4` | ice cap |
| `ice_light` | `#dfeaee` | lit ice, snow highlight |
| `tundra` | `#68786e` | tundra band |

### Surfaces
| key | hex | use |
| --- | --- | --- |
| `asphalt_dark` | `#20262d` | runway shadow side, tyre marks |
| `asphalt` | `#2f3740` | runway surface |
| `asphalt_light` | `#414b56` | runway lit edge, shoulder |
| `taxiway` | `#4a545e` | taxiway surface |
| `concrete` | `#5b646e` | apron, stands |
| `concrete_light` | `#727c87` | lit concrete edge |

### Structures
| key | hex | use |
| --- | --- | --- |
| `roof_terminal` | `#7b6d5c` | terminal roof |
| `roof_hangar` | `#5e6a74` | hangar / tower roof |
| `roof_cargo` | `#6a5f52` | cargo shed roof |
| `wall` | `#3f4750` | building side faces |
| `wall_light` | `#59626c` | lit north-west wall |

### Metal and glass
| key | hex | use |
| --- | --- | --- |
| `metal_dark` | `#39424c` | engine cores, gear, props |
| `metal` | `#6f7b86` | nacelles, struts |
| `metal_light` | `#9dabb5` | lit metal |
| `glass` | `#2c4459` | windows, canopies |
| `glass_light` | `#4c7391` | lit window edge |

### Livery and accents
| key | hex | use |
| --- | --- | --- |
| `livery_light` | `#e8dfc6` | house livery upper surface |
| `livery` | `#cbbe9d` | house livery body |
| `livery_dark` | `#9d906f` | house livery shadow |
| `accent_orange` | `#e08b3c` | airline accent, selection, money |
| `accent_orange_light` | `#f2b167` | accent highlight |
| `accent_teal` | `#4fa3a8` | passenger jobs, info |
| `accent_red` | `#c05a4a` | warnings, refusals |
| `accent_yellow` | `#d9b45a` | ground markings, cargo |
| `accent_green` | `#7fb37a` | profit, confirmation |

### Ink and UI
| key | hex | use |
| --- | --- | --- |
| `outline` | `#0e141a` | the single outline colour for every sprite |
| `shadow` | `#1a2028` | cast shadows (used as a solid, never as alpha blur) |
| `ui_bg` | `#111f29` | panel fill |
| `ui_bg_light` | `#1b2f3c` | panel fill, raised rows |
| `ui_border` | `#33566a` | panel border |
| `ui_border_light` | `#4f7d94` | panel border highlight (top/left) |
| `text` | `#dfe9ec` | body text |
| `text_dim` | `#8ba3b0` | secondary text |
| `white` | `#eef4f6` | markings, brightest highlight |

## 3. Outlines and light

- **One outline colour**: `outline`. Never a darkened tint of the fill.
- Sprites carry a **1 px** outline. Nothing gets a 2 px outline.
- **Light comes from the upper left.** The lit edge of any form is its
  north-west side; the shadow side is south-east.
- A form is shaded with at most **three** steps: shadow, base, light. No ramps,
  no gradients.
- Cast shadows are solid `shadow` pixels offset **+1 x, +1 y** per 16 px of
  subject size, never a soft blur and never a semi-transparent circle.

## 4. Canvas sizes

Sizes are exact. An asset that does not match its canvas is rejected.

### Aircraft — top view (map and airport)
Sized for a 640×360 screen: a small aircraft parked on the apron reads at about
44 px across, which is roughly a tenth of the visible runway.

| tier | canvas | example |
| --- | --- | --- |
| small | 48×48 | Trailhopper 4 |
| medium | 64×64 | Twinwing 8 |
| large | 96×96 | Highline 19 |

Nose points **east (+x)** in the source sprite; the engine rotates it. Sprites
are drawn on a transparent background.

### Aircraft — side view (detail screen)
The detail view shows one aircraft large against a 640×360 screen.

Side profiles are **stylized, not scale**. Real fuselage ratios are 6:1 or
worse, which at sprite size reads as a technical reference drawing rather than
as an aircraft the player owns. These are toys: stubby bodies, round noses,
oversized fins and propellers, fat wheels. Proportions are hand-tuned per family
in `tools/pixelart/aircraft.py` (`SIDE_STYLES`), and the body ratio itself
carries the size tier.

Side sprites are drawn at the density of the approved Trailhopper master and
displayed at one shared integer hero scale (currently 2×), so every family
keeps the same pixel density on the plane, paint and upgrade screens. The
binding constraint is the **hero band**: at the shared scale the whole
airframe — wheels to fin tip — must fit between the screen top and the apron
line (content no taller than ~80 px). Canvases are therefore sized per family
around their art, not to fixed tiers:

| family | canvas | reads as |
| --- | --- | --- |
| Trailhopper 4 | 128×96 | tiny and chunky |
| Twinwing 8 | 160×84 | wider, more capable |
| Highline 19 | 184×68 | long, low, serious |

Length carries the size progression; the height budget keeps them stubby,
which is the toy language doing its job.

The metric spec still governs the top view. The two views agree on everything
that carries identity — wing position, engine count and layout, gear type,
livery — which is what keeps them the same aircraft.

**Silhouette must carry the family, not size alone.** Three aircraft that differ
only in scale read as one aircraft in three sizes. Each family therefore owns a
structural cue visible in both views and in the 15px map icon:

| family | cue |
| --- | --- |
| Trailhopper 4 | nose-high tail-dragger stance, single nose propeller, strutted high wing |
| Twinwing 8 | low wing, engines slung under it, level tricycle stance |
| Highline 19 | **T-tail**, high wing with over-wing engines, long cabin |

Nose points **east (+x)**. The main gear contact point sits on a consistent
baseline so every aircraft lines up in the detail view.

### Airport tiles
- Ground/surface tile grid: **16×16**.
- Tiles must be seamless on all four edges where they represent a continuous
  surface.

### Buildings and vehicles
- Buildings occupy whole 16 px multiples.
- Ground vehicles: **16×16**.
- People: **8×12**.

### UI
- Panel frames are **9-slice** with a 4 px border and a 1 px outer outline.
- Buttons are 9-slice with a 3 px border.
- Icons: **10×10** or **16×16**.

### World map
- LOD textures are power-of-two fractions of a 4096×2048 canvas so each tier
  renders at an integer texel scale. See `WORLD_MAP_AND_ZOOM.md`.

## 5. Text

- One bitmap font: **5×7 pixel cells**, 1 px letter spacing, drawn from `text`.
- The font is drawn as caps; lowercase input renders as small caps.
- Text never scales by a non-integer factor.
- Never use a system or vector font anywhere in the game.

## 6. Dithering

- Dithering is a **2×2 or 4×4 ordered pattern** only, used for band transitions
  on the world map and for large flat surfaces.
- Never dither a sprite smaller than 32 px.
- Never use dithering to fake a gradient inside an aircraft or building.

## 7. Rejection rules

Reject an asset that:
- contains a colour outside the palette;
- has any anti-aliased or semi-transparent edge pixel (alpha is 0 or 255 only);
- uses more than one outline colour;
- lights a form from anywhere but the upper left;
- changes pixel density inside a single asset;
- has a silhouette that is unreadable at its gameplay size;
- would need smooth scaling to be displayed.

## 8. Verification

`tools/build_pixel_assets.py` regenerates every asset from code, and
`scripts/dev/tests/test_pixel_assets.gd` checks the shipped PNGs against the
rules above: palette conformance, binary alpha, and exact canvas size. Art is
therefore verified, not merely intended.
