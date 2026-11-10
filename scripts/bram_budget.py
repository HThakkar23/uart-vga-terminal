#!/usr/bin/env python3
"""
Works out how much of the XC7Z007S block RAM the character buffer and the
font ROM actually need, in terms of real RAMB18/RAMB36 primitives.

The 7 series fabric builds block RAM out of 18 Kb tiles. Two of them can be
stitched together into a 36 Kb tile. Vivado does this packing on its own
during synthesis, but it is worth knowing the budget before you get there.
"""

RAMB18_BITS = 18 * 1024
RAMB36_BITS = 36 * 1024

# XC7Z007S fabric total, per Xilinx 7 series data sheet (36 Kb tiles)
TOTAL_RAMB36_TILES = 50


def tiles_needed(bits, tile_bits):
    full = bits // tile_bits
    remainder = bits % tile_bits
    return full + (1 if remainder else 0)


def main():
    char_buffer_bits = 2400 * 8          # 80x30 screen, 1 byte per cell
    font_rom_bits = 128 * 16 * 8         # 7 bit ASCII range, 16 rows, 8 bits/row

    print("block RAM budget, XC7Z007S (50 x RAMB36 tiles available)\n")

    for name, bits in [("character buffer (80x30 x 8b)", char_buffer_bits),
                        ("font ROM (128 glyphs x 8x16)", font_rom_bits)]:
        kb = bits / 1024
        t18 = tiles_needed(bits, RAMB18_BITS)
        t36 = tiles_needed(bits, RAMB36_BITS)
        pct = t36 / TOTAL_RAMB36_TILES * 100
        print(name)
        print(f"  raw size        : {bits} bits ({kb:.2f} Kb)")
        print(f"  as RAMB18 tiles : {t18}")
        print(f"  as RAMB36 tiles : {t36}  ({pct:.1f}% of device)")
        print()

    total_bits = char_buffer_bits + font_rom_bits
    total_t36 = tiles_needed(char_buffer_bits, RAMB36_BITS) + tiles_needed(font_rom_bits, RAMB36_BITS)
    print(f"combined design: {total_bits} bits, worst case {total_t36} RAMB36 tiles "
          f"({total_t36 / TOTAL_RAMB36_TILES * 100:.1f}% of device)")
    print("(Vivado may pack both into fewer physical tiles once it maps the design;"
          " this is the pessimistic, not-yet-optimized figure.)")


if __name__ == "__main__":
    main()
