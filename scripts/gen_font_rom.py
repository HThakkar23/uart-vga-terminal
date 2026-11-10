#!/usr/bin/env python3
"""
Builds the 8x16 bitmap font the text renderer reads out of block RAM.

Each of the 128 standard ASCII code points gets one 16 byte glyph, one byte
per scan line, most significant bit is the leftmost pixel. Control codes
(0x00-0x1F and 0x7F) are left blank, since cursor_ctrl.v intercepts those
before they ever reach the character buffer.

Glyphs are rendered from Cascadia Mono, the monospace font Microsoft ships
with Windows Terminal and releases under the SIL Open Font License, so the
output bitmap is free to keep in this repository. Each glyph is drawn at
6x the target size and downsampled with a Lanczos filter, which gives a
much cleaner result at 8x16 than drawing straight at native size.

Run it with: python scripts/gen_font_rom.py
If Cascadia Mono is not installed, point FONT_PATH at any monospace TTF.
"""

from PIL import Image, ImageDraw, ImageFont

CELL_W = 8
CELL_H = 16
SUPERSAMPLE = 6
FONT_PATH = r"C:\Windows\Fonts\CascadiaMono.ttf"
FONT_SIZE = 14 * SUPERSAMPLE
THRESHOLD = 100
FIRST_CODE = 0x20
LAST_CODE = 0x7E
OUT_PATH = "font/font.mem"


def render_glyph(font, ch):
    w, h = CELL_W * SUPERSAMPLE, CELL_H * SUPERSAMPLE
    img = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(img)
    draw.text((0, SUPERSAMPLE), ch, font=font, fill=255)
    small = img.resize((CELL_W, CELL_H), Image.LANCZOS)
    pixels = small.load()

    rows = []
    for y in range(CELL_H):
        byte = 0
        for x in range(CELL_W):
            bit = 1 if pixels[x, y] > THRESHOLD else 0
            byte = (byte << 1) | bit
        rows.append(byte)
    return rows


def main():
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    glyphs = {}

    for code in range(0, 128):
        if FIRST_CODE <= code <= LAST_CODE:
            glyphs[code] = render_glyph(font, chr(code))
        else:
            glyphs[code] = [0] * CELL_H

    with open(OUT_PATH, "w") as f:
        for code in range(0, 128):
            for row_byte in glyphs[code]:
                f.write(f"{row_byte:02x}\n")

    drawn = sum(1 for code in glyphs if FIRST_CODE <= code <= LAST_CODE)
    blank = 128 - drawn
    nonzero_rows = sum(1 for code in glyphs for b in glyphs[code] if b != 0)
    total_rows = 128 * CELL_H

    print(f"wrote {OUT_PATH}")
    print(f"  font source          : {FONT_PATH}")
    print(f"  glyph cells total    : 128")
    print(f"  printable glyphs     : {drawn} (0x{FIRST_CODE:02x}-0x{LAST_CODE:02x})")
    print(f"  blank control cells  : {blank}")
    print(f"  non-blank scan lines : {nonzero_rows} / {total_rows} "
          f"({nonzero_rows/total_rows*100:.1f}%)")
    print(f"  rom size             : {128*CELL_H} bytes "
          f"({128*CELL_H*8} bits, {128*CELL_H*8/1024:.2f} Kb)")


if __name__ == "__main__":
    main()
