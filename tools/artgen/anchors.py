"""Finds seat and cargo slots in an approved aircraft side sprite.

The plane screen draws passengers into windows and crates into a hold, so it
needs to know where those are. For pipeline-drawn art the builder emits the
positions directly; for generated art they have to be recovered from the image.

Windows are found as connected regions of glass-like colour arranged in a row.
Anything the detector is unsure about is reported rather than guessed at, so a
bad detection shows up as a review finding instead of passengers floating
outside the fuselage.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from pixelart.palette import rgb                                  # noqa: E402

## Colours that count as cabin glazing.
GLASS_KEYS = ("glass", "glass_light", "water_deep", "water", "outline", "shadow")
## A window must be at least this many pixels to be real rather than noise.
MIN_WINDOW_PIXELS = 6


def _glass_mask(data: np.ndarray) -> np.ndarray:
    alpha = data[:, :, 3]
    rgb_data = data[:, :, :3].astype(np.int16)
    mask = np.zeros(alpha.shape, dtype=bool)
    for key in GLASS_KEYS:
        target = np.array(rgb(key), dtype=np.int16)
        close = (np.abs(rgb_data - target).sum(axis=2) < 60)
        mask |= close
    return mask & (alpha > 128)


def _components(mask: np.ndarray) -> list[tuple[int, int, int, int]]:
    """Connected components as (x0, y0, x1, y1) boxes. Iterative flood fill."""
    height, width = mask.shape
    seen = np.zeros_like(mask)
    boxes: list[tuple[int, int, int, int]] = []
    for sy in range(height):
        for sx in range(width):
            if not mask[sy, sx] or seen[sy, sx]:
                continue
            stack = [(sy, sx)]
            seen[sy, sx] = True
            pixels = []
            while stack:
                y, x = stack.pop()
                pixels.append((y, x))
                for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(pixels) < MIN_WINDOW_PIXELS:
                continue
            ys = [p[0] for p in pixels]
            xs = [p[1] for p in pixels]
            boxes.append((min(xs), min(ys), max(xs), max(ys)))
    return boxes


def detect(path: Path, seats: int, cargo: int) -> tuple[dict, list[str]]:
    """Returns (anchors, notes)."""
    image = Image.open(path).convert("RGBA")
    data = np.array(image)
    alpha = data[:, :, 3]
    notes: list[str] = []

    boxes = _components(_glass_mask(data))
    # Windows are the components of similar size sitting on a common row.
    candidates = [b for b in boxes
                  if 3 <= (b[2] - b[0] + 1) <= 18 and 3 <= (b[3] - b[1] + 1) <= 18]
    candidates.sort(key=lambda b: b[0])
    if len(candidates) > seats:
        # Keep the run whose vertical centres agree best — the cabin row.
        centres = [(b[1] + b[3]) / 2.0 for b in candidates]
        median = float(np.median(centres))
        candidates = sorted(candidates, key=lambda b: abs((b[1] + b[3]) / 2.0 - median))[:seats]
        candidates.sort(key=lambda b: b[0])
    if len(candidates) < seats:
        notes.append(f"found {len(candidates)} windows, expected {seats}")

    slot = 11
    if candidates:
        slot = int(round(float(np.median([b[2] - b[0] + 1 for b in candidates]))))
        slot = max(7, min(16, slot))

    seat_anchors: list[list[int]] = []
    for box in candidates[:seats]:
        cx = (box[0] + box[2]) / 2.0
        cy = (box[1] + box[3]) / 2.0
        seat_anchors.append([int(round(cx - slot / 2.0)), int(round(cy - slot / 2.0))])

    # Evenly extend the row if fewer windows were found than the aircraft seats.
    if 2 <= len(seat_anchors) < seats:
        step = seat_anchors[1][0] - seat_anchors[0][0]
        while len(seat_anchors) < seats:
            seat_anchors.append([seat_anchors[-1][0] + step, seat_anchors[-1][1]])

    # Cargo: a row along the lower fuselage, inside the hull.
    columns = np.where(alpha.max(axis=0) > 128)[0]
    rows = np.where(alpha.max(axis=1) > 128)[0]
    cargo_anchors: list[list[int]] = []
    if columns.size and rows.size and cargo > 0:
        x0, x1 = int(columns.min()), int(columns.max())
        y1 = int(rows.max())
        cargo_slot = max(7, min(12, slot - 1))
        span = int((x1 - x0) * 0.52)
        start = x0 + int((x1 - x0) * 0.30)
        step = max(cargo_slot + 1, span // max(1, cargo))
        belly = y1 - int((y1 - rows.min()) * 0.30) - cargo_slot // 2
        for i in range(cargo):
            cargo_anchors.append([start + i * step, belly])
        notes.append("cargo slots placed along the belly (no hold visible in the art)")

    anchors = {
        "canvas": [image.width, image.height],
        "baseline": int(rows.max()) if rows.size else image.height - 1,
        "seat_slot": slot,
        "cargo_slot": max(7, min(12, slot - 1)),
        "seats": seat_anchors[:seats],
        "cargo": cargo_anchors,
        "detected": True,
    }
    return anchors, notes
