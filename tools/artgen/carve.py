"""Carves the cutaway cabin into an approved aircraft master.

PixelLab provides the personality; this provides the interior the game needs:
an open cabin band and hold with exact seat/cargo anchors, cut into the sprite
deterministically. Coordinates are hand-picked per master from a grid overlay —
they are part of the approved design, not guesswork.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from pixelart.palette import rgb                                  # noqa: E402

## Per-master carve plans. Slots are [x, y] top-left anchors.
PLANS = {
    "trailhopper_4": {
        "source": ".art_candidates/trailhopper_master.png",
        "cabin": {"x0": 36, "y0": 38, "x1": 93, "y1": 52},
        "hold": {"x0": 40, "y0": 54, "x1": 77, "y1": 61},
        "seat_slot": 8,
        "seats": [[38, 41], [47, 41], [56, 41], [65, 41], [74, 41], [83, 41]],
        "cargo_slot": 7,
        "cargo": [[42, 54], [51, 54], [60, 54], [69, 54]],
    },
}


def _shift(mask: np.ndarray, dy: int, dx: int) -> np.ndarray:
    out = np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
    if dy > 0: out[:dy, :] = False
    elif dy < 0: out[dy:, :] = False
    if dx > 0: out[:, :dx] = False
    elif dx < 0: out[:, dx:] = False
    return out


def _erode(mask: np.ndarray, steps: int = 1) -> np.ndarray:
    out = mask
    for _ in range(steps):
        n = out.copy()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            n &= _shift(out, dy, dx)
        out = n
    return out


def _dilate(mask: np.ndarray) -> np.ndarray:
    out = mask.copy()
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        out |= _shift(mask, dy, dx)
    return out


def _band(data: np.ndarray, hull: np.ndarray, x0: int, y0: int, x1: int, y1: int,
          fill: str, floor: str) -> None:
    """An open interior clipped to the airframe.

    The band only replaces pixels inside the (slightly eroded) hull, so the
    cutaway follows the fuselage curve instead of hanging off it as a pasted
    rectangle — which was exactly the review panel's complaint.
    """
    rect = np.zeros(hull.shape, dtype=bool)
    rect[y0:y1 + 1, x0:x1 + 1] = True
    inside = rect & _erode(hull, 2)
    data[inside, :3] = rgb(fill)
    floor_rect = np.zeros_like(rect)
    floor_rect[y1 - 1:y1 + 1, x0:x1 + 1] = True
    data[floor_rect & inside, :3] = rgb(floor)
    ceiling = np.zeros_like(rect)
    ceiling[y0, x0:x1 + 1] = True
    data[ceiling & inside, :3] = rgb("ice_light")
    frame = _dilate(inside) & ~inside & hull
    data[frame, :3] = rgb("outline")


def carve(family: str, out_dir: Path) -> Path:
    plan = PLANS[family]
    image = Image.open(plan["source"]).convert("RGBA")
    data = np.array(image)
    hull = data[:, :, 3] > 128

    cabin = plan["cabin"]
    _band(data, hull, cabin["x0"], cabin["y0"], cabin["x1"], cabin["y1"], "white", "ice")
    hold = plan["hold"]
    _band(data, hull, hold["x0"], hold["y0"], hold["x1"], hold["y1"], "ice_light", "ice")

    out = Image.fromarray(data, "RGBA")
    target = out_dir / f"{family}_side.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    out.save(target)

    alpha = data[:, :, 3]
    rows = np.where(alpha.max(axis=1) > 128)[0]
    anchors = {
        "canvas": [image.width, image.height],
        "baseline": int(rows.max()) if rows.size else image.height - 1,
        "seat_slot": plan["seat_slot"],
        "cargo_slot": plan["cargo_slot"],
        "seats": plan["seats"],
        "cargo": plan["cargo"],
        "carved": True,
    }
    (out_dir / f"{family}_side.json").write_text(json.dumps(anchors, indent=2) + "\n")
    return target


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent.parent
    target = carve("trailhopper_4",
                   root / "assets" / "art" / "production" / "aircraft" / "trailhopper_4")
    print("carved ->", target.relative_to(root))
