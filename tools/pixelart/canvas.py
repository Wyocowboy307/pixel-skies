"""Hard-edged pixel drawing.

Every primitive writes whole pixels with binary alpha. There is deliberately no
anti-aliasing, no sub-pixel coordinate and no alpha blending anywhere in this
module: a pixel is either the colour you asked for or untouched.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from .palette import ALLOWED_RGB, rgb

TRANSPARENT = (0, 0, 0, 0)


class Canvas:
    """A fixed-size RGBA pixel buffer."""

    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.data = np.zeros((height, width, 4), dtype=np.uint8)

    # -- basics ------------------------------------------------------------

    def in_bounds(self, x: int, y: int) -> bool:
        return 0 <= x < self.width and 0 <= y < self.height

    def plot(self, x: int, y: int, colour: str | None) -> None:
        x, y = int(x), int(y)
        if not self.in_bounds(x, y):
            return
        if colour is None:
            self.data[y, x] = TRANSPARENT
            return
        self.data[y, x] = rgb(colour) + (255,)

    def get(self, x: int, y: int) -> tuple[int, int, int, int]:
        if not self.in_bounds(x, y):
            return TRANSPARENT
        return tuple(int(v) for v in self.data[y, x])

    def is_opaque(self, x: int, y: int) -> bool:
        return self.get(x, y)[3] == 255

    def fill(self, colour: str) -> None:
        self.data[:, :] = rgb(colour) + (255,)

    def clear(self) -> None:
        self.data[:, :] = TRANSPARENT

    # -- shapes ------------------------------------------------------------

    def hline(self, x0: int, x1: int, y: int, colour: str) -> None:
        if x1 < x0:
            x0, x1 = x1, x0
        for x in range(int(x0), int(x1) + 1):
            self.plot(x, y, colour)

    def vline(self, x: int, y0: int, y1: int, colour: str) -> None:
        if y1 < y0:
            y0, y1 = y1, y0
        for y in range(int(y0), int(y1) + 1):
            self.plot(x, y, colour)

    def rect(self, x: int, y: int, w: int, h: int, colour: str) -> None:
        for row in range(int(y), int(y + h)):
            self.hline(x, x + w - 1, row, colour)

    def rect_outline(self, x: int, y: int, w: int, h: int, colour: str) -> None:
        self.hline(x, x + w - 1, y, colour)
        self.hline(x, x + w - 1, y + h - 1, colour)
        self.vline(x, y, y + h - 1, colour)
        self.vline(x + w - 1, y, y + h - 1, colour)

    def line(self, x0: int, y0: int, x1: int, y1: int, colour: str) -> None:
        """Bresenham — integer endpoints, no AA."""
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.plot(x0, y0, colour)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def polygon(self, points: list[tuple[int, int]], colour: str) -> None:
        """Scanline fill with integer spans. Edges land on exact pixels."""
        if len(points) < 3:
            return
        ys = [int(round(p[1])) for p in points]
        for y in range(min(ys), max(ys) + 1):
            crossings: list[float] = []
            for i in range(len(points)):
                x0, y0 = points[i]
                x1, y1 = points[(i + 1) % len(points)]
                if y0 == y1:
                    continue
                if min(y0, y1) <= y < max(y0, y1):
                    t = (y - y0) / (y1 - y0)
                    crossings.append(x0 + t * (x1 - x0))
            crossings.sort()
            for i in range(0, len(crossings) - 1, 2):
                self.hline(int(round(crossings[i])), int(round(crossings[i + 1])), y, colour)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, colour: str) -> None:
        """Filled ellipse by exact per-row spans — round, but still hard-edged."""
        if rx <= 0 or ry <= 0:
            return
        for y in range(int(np.floor(cy - ry)), int(np.ceil(cy + ry)) + 1):
            dy = (y + 0.5 - cy) / ry
            if abs(dy) > 1.0:
                continue
            half = rx * np.sqrt(max(0.0, 1.0 - dy * dy))
            self.hline(int(round(cx - half)), int(round(cx + half - 0.5)), y, colour)

    def disc(self, cx: float, cy: float, radius: float, colour: str) -> None:
        self.ellipse(cx, cy, radius, radius, colour)

    def ring(self, cx: float, cy: float, radius: float, colour: str) -> None:
        """One-pixel-thick circle outline (midpoint circle)."""
        x, y = int(radius), 0
        err = 1 - x
        while x >= y:
            for sx, sy in ((x, y), (y, x), (-x, y), (-y, x), (-x, -y), (-y, -x), (x, -y), (y, -x)):
                self.plot(int(round(cx)) + sx, int(round(cy)) + sy, colour)
            y += 1
            if err < 0:
                err += 2 * y + 1
            else:
                x -= 1
                err += 2 * (y - x) + 1

    # -- operations --------------------------------------------------------

    def blit(self, other: "Canvas", x: int, y: int) -> None:
        """Paste opaque pixels of `other` at (x, y)."""
        for sy in range(other.height):
            for sx in range(other.width):
                pixel = other.get(sx, sy)
                if pixel[3]:
                    ty, tx = y + sy, x + sx
                    if self.in_bounds(tx, ty):
                        self.data[ty, tx] = pixel

    def mirror_y(self, axis: int) -> None:
        """Mirror the rows above `axis` down onto the rows below it.

        Aircraft are drawn once for the port side and mirrored, which guarantees
        the symmetry the art bible demands rather than hoping two hand-drawn
        halves match.
        """
        for dy in range(1, min(axis + 1, self.height - axis)):
            self.data[axis + dy] = self.data[axis - dy]

    @staticmethod
    def _shift(mask: np.ndarray, dy: int, dx: int) -> np.ndarray:
        """Shift a mask without wrapping.

        np.roll wraps around the edges, which would let an outline on the left
        of a sprite bleed onto the right. Vacated rows/columns are cleared.
        """
        out = np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
        if dy > 0:
            out[:dy, :] = False
        elif dy < 0:
            out[dy:, :] = False
        if dx > 0:
            out[:, :dx] = False
        elif dx < 0:
            out[:, dx:] = False
        return out

    def outline(self, colour: str = "outline", diagonal: bool = False) -> None:
        """Wrap every opaque region in a 1 px outline.

        Computed from a snapshot of the alpha mask, so a freshly written outline
        pixel can never seed further outline on the same pass.
        """
        alpha = self.data[:, :, 3] > 0
        neighbours = np.zeros_like(alpha)
        shifts = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        if diagonal:
            shifts += [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        for dy, dx in shifts:
            neighbours |= self._shift(alpha, dy, dx)
        edge = neighbours & ~alpha
        self.data[edge] = rgb(colour) + (255,)

    def shadow_offset(self, dx: int, dy: int, colour: str = "shadow") -> None:
        """Solid cast shadow under the existing silhouette."""
        alpha = self.data[:, :, 3] > 0
        target = self._shift(alpha, dy, dx) & ~alpha
        self.data[target] = rgb(colour) + (255,)

    # -- validation and output --------------------------------------------

    def assert_valid(self, name: str) -> None:
        """Enforce the style guide: binary alpha, palette-only colours."""
        alpha = self.data[:, :, 3]
        bad_alpha = np.unique(alpha[(alpha != 0) & (alpha != 255)])
        if bad_alpha.size:
            raise ValueError(f"{name}: partial alpha values {bad_alpha.tolist()} — edges must be hard")
        opaque = self.data[alpha == 255][:, :3]
        if opaque.size:
            used = {tuple(int(v) for v in c) for c in np.unique(opaque, axis=0)}
            stray = used - ALLOWED_RGB
            if stray:
                swatches = ", ".join("#%02x%02x%02x" % c for c in sorted(stray))
                raise ValueError(f"{name}: colours outside the locked palette: {swatches}")

    def save(self, path: Path, name: str | None = None) -> None:
        self.assert_valid(name or path.name)
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self.data, "RGBA").save(path)

    def to_image(self) -> Image.Image:
        return Image.fromarray(self.data, "RGBA")
