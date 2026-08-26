"""The rejection gate.

Generated art is checked against docs/PIXEL_STYLE_GUIDE.md before it is allowed
anywhere near the game. This is the part that stops the set drifting: a
candidate that fails here is rejected, not quietly imported.

Checks are mechanical only. Charm is judged by eye in the running game — the
whole point of the workflow — but these catch the failures that are objective.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from pixelart.palette import ALLOWED_RGB                      # noqa: E402

## How far a generated colour may sit from the nearest palette entry before the
## asset counts as off-style. Generators never land exactly on a palette, so a
## small tolerance is applied and the asset is then snapped on approval.
COLOUR_TOLERANCE = 42.0
## Share of pixels allowed to be soft-edged before the asset is rejected.
## Approval hardens alpha, so a modest amount is a warning rather than a fault.
MAX_SOFT_ALPHA_SHARE = 0.12
## Beyond this a candidate is photographic rather than pixel art, and snapping
## it to the palette would destroy it rather than clean it up.
UNSALVAGEABLE_COLOURS = 140
## Above this it needs the palette snap, which approval applies.
NEEDS_SNAP_COLOURS = 36
## A sprite that fills almost nothing, or the entire canvas, is badly framed.
MIN_COVERAGE = 0.10
MAX_COVERAGE = 0.97


@dataclass
class Finding:
    level: str          # "reject" | "warn"
    message: str


def _palette_array() -> np.ndarray:
    return np.array(sorted(ALLOWED_RGB), dtype=np.float32)


def nearest_palette_distance(pixels: np.ndarray) -> np.ndarray:
    palette = _palette_array()
    diff = pixels[:, None, :].astype(np.float32) - palette[None, :, :]
    return np.sqrt((diff ** 2).sum(axis=2)).min(axis=1)


def review(path: Path, expected_size: tuple[int, int] | None = None) -> list[Finding]:
    findings: list[Finding] = []
    image = Image.open(path).convert("RGBA")
    data = np.array(image)
    alpha = data[:, :, 3]

    if expected_size and image.size != expected_size:
        findings.append(Finding("reject",
            f"size {image.size} != specified {expected_size}"))

    soft = ((alpha > 8) & (alpha < 247)).sum()
    share = soft / float(alpha.size)
    if share > MAX_SOFT_ALPHA_SHARE:
        findings.append(Finding("reject",
            f"{share:.1%} of pixels have soft alpha — anti-aliased edges"))
    elif soft:
        findings.append(Finding("warn", f"{soft} soft-alpha pixels, will be hardened"))

    opaque = data[alpha > 128][:, :3]
    if opaque.size == 0:
        findings.append(Finding("reject", "image is empty"))
        return findings

    coverage = (alpha > 128).sum() / float(alpha.size)
    if coverage < MIN_COVERAGE:
        findings.append(Finding("reject", f"subject fills only {coverage:.0%} of the canvas"))
    elif coverage > MAX_COVERAGE:
        findings.append(Finding("warn", f"subject fills {coverage:.0%} — no breathing room"))

    # Colour count is calibrated against what approval can repair. A generator
    # never lands on the palette, and snapping fixes that; what snapping cannot
    # fix is an image that was photographic to begin with.
    unique = np.unique(opaque, axis=0)
    if len(unique) > UNSALVAGEABLE_COLOURS:
        findings.append(Finding("reject",
            f"{len(unique)} distinct colours — photographic, not pixel art"))
    elif len(unique) > NEEDS_SNAP_COLOURS:
        findings.append(Finding("warn",
            f"{len(unique)} distinct colours — will be snapped to the palette"))

    distance = nearest_palette_distance(unique)
    far = int((distance > COLOUR_TOLERANCE).sum())
    if far:
        worst = float(distance.max())
        # Far-from-palette colours are only fatal if they dominate: snapping a
        # handful of stray hues is fine, snapping a whole different palette is
        # not the same asset any more.
        level = "reject" if far > len(unique) * 0.6 else "warn"
        findings.append(Finding(level,
            f"{far}/{len(unique)} colours are off-palette (worst distance {worst:.0f})"))
    return findings


def snap_to_palette(image: Image.Image) -> Image.Image:
    """Snap every opaque pixel to its nearest palette entry and harden alpha.

    Applied on approval, so the shipped asset obeys the locked palette exactly
    even though the generator only came close.
    """
    data = np.array(image.convert("RGBA"))
    alpha = data[:, :, 3]
    data[alpha < 128] = (0, 0, 0, 0)
    mask = alpha >= 128
    data[mask, 3] = 255
    pixels = data[mask][:, :3].astype(np.float32)
    if pixels.size:
        palette = _palette_array()
        diff = pixels[:, None, :] - palette[None, :, :]
        index = (diff ** 2).sum(axis=2).argmin(axis=1)
        snapped = palette[index].astype(np.uint8)
        rgba = data[mask]
        rgba[:, :3] = snapped
        data[mask] = rgba
    return Image.fromarray(data, "RGBA")


def verdict(findings: list[Finding]) -> str:
    if any(f.level == "reject" for f in findings):
        return "REJECT"
    if findings:
        return "WARN"
    return "PASS"
