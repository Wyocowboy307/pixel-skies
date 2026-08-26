"""Bakes the 5x7 font into a texture atlas plus an AngelCode .fnt descriptor,
which Godot imports directly as a FontFile.

Glyphs are baked white so the engine can tint them by modulation; white
multiplied by a palette colour is exactly that palette colour, so tinted text
stays inside the locked palette.
"""

from __future__ import annotations

from pathlib import Path

from .canvas import Canvas
from . import font5x7 as font

COLUMNS = 16
PAD = 1


def build_atlas() -> tuple[Canvas, list[dict]]:
    chars = list(font.GLYPHS.keys())
    rows = (len(chars) + COLUMNS - 1) // COLUMNS
    cell_w = font.CELL_WIDTH + PAD
    cell_h = font.CELL_HEIGHT + PAD
    canvas = Canvas(COLUMNS * cell_w, rows * cell_h)

    entries: list[dict] = []
    for index, char in enumerate(chars):
        cx = (index % COLUMNS) * cell_w
        cy = (index // COLUMNS) * cell_h
        for y, row in enumerate(font.GLYPHS[char]):
            for x, bit in enumerate(row):
                if bit == "1":
                    canvas.plot(cx + x, cy + y, "white")
        entries.append({
            "char": char,
            "x": cx,
            "y": cy,
            "width": font.CELL_WIDTH,
            "height": font.CELL_HEIGHT,
            "advance": font.advance(char),
        })
    return canvas, entries


def build_fnt(entries: list[dict], atlas_width: int, atlas_height: int,
              texture_name: str) -> str:
    lines = [
        'info face="PixelSkies5x7" size=7 bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1',
        f'common lineHeight={font.LINE_HEIGHT} base={font.CELL_HEIGHT} '
        f'scaleW={atlas_width} scaleH={atlas_height} pages=1 packed=0',
        f'page id=0 file="{texture_name}"',
        f'chars count={len(entries)}',
    ]
    rows: list[str] = []
    for entry in entries:
        # Lowercase maps to the same cell as its capital: the house style is
        # caps, and without these ids any lowercase text renders as .notdef
        # boxes rather than small caps.
        codes = [ord(entry["char"])]
        if entry["char"].isalpha():
            codes.append(ord(entry["char"].lower()))
        for code in codes:
            rows.append(
                f'char id={code} x={entry["x"]} y={entry["y"]} '
                f'width={entry["width"]} height={entry["height"]} xoffset=0 yoffset=0 '
                f'xadvance={entry["advance"]} page=0 chnl=15'
            )
    lines[-1] = f'chars count={len(rows)}'
    lines.extend(rows)
    return "\n".join(lines) + "\n"


def write(out_dir: Path) -> None:
    canvas, entries = build_atlas()
    texture_name = "font5x7.png"
    canvas.save(out_dir / texture_name, "font atlas")
    (out_dir / "font5x7.fnt").write_text(
        build_fnt(entries, canvas.width, canvas.height, texture_name))
