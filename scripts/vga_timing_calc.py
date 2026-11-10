#!/usr/bin/env python3
"""
Prints the VGA timing numbers the vga_timing.v module is built from, and
checks the resulting refresh rate against the VESA standard for 640x480.

Also works out what pixel clock the Vivado Clocking Wizard needs to produce,
and how far off 25 MHz lands from the textbook 25.175 MHz dot clock.
"""

MODES = {
    "640x480@60 (VESA)": dict(
        h_active=640, h_fp=16, h_sync=96, h_bp=48,
        v_active=480, v_fp=10, v_sync=2, v_bp=33,
        pixel_clock_mhz=25.175,
    ),
}


def report(name, m):
    h_total = m["h_active"] + m["h_fp"] + m["h_sync"] + m["h_bp"]
    v_total = m["v_active"] + m["v_fp"] + m["v_sync"] + m["v_bp"]
    pixels_per_frame = h_total * v_total
    exact_refresh = m["pixel_clock_mhz"] * 1e6 / pixels_per_frame

    print(f"== {name} ==")
    print(f"  horizontal: active {m['h_active']}, front porch {m['h_fp']}, "
          f"sync {m['h_sync']}, back porch {m['h_bp']}, total {h_total}")
    print(f"  vertical  : active {m['v_active']}, front porch {m['v_fp']}, "
          f"sync {m['v_sync']}, back porch {m['v_bp']}, total {v_total}")
    print(f"  pixels per frame     : {pixels_per_frame}")
    print(f"  spec pixel clock     : {m['pixel_clock_mhz']} MHz")
    print(f"  refresh at spec clock: {exact_refresh:.3f} Hz")

    for approx_mhz in (25.0, 25.175):
        refresh = approx_mhz * 1e6 / pixels_per_frame
        print(f"  refresh at {approx_mhz:>7.3f} MHz pixel clock: {refresh:.3f} Hz")

    line_time_us = h_total / (25.0 * 1e6) * 1e6
    frame_time_ms = v_total * line_time_us / 1000
    print(f"  line time  at 25.000 MHz : {line_time_us:.3f} us")
    print(f"  frame time at 25.000 MHz : {frame_time_ms:.3f} ms")
    print()


def main():
    for name, m in MODES.items():
        report(name, m)

    # character cell budget for an 80x30 text screen with an 8x16 font
    h_active, v_active = 640, 480
    cell_w, cell_h = 8, 16
    cols, rows = h_active // cell_w, v_active // cell_h
    print(f"text grid at {cell_w}x{cell_h} cells: {cols} columns x {rows} rows "
          f"= {cols * rows} characters")


if __name__ == "__main__":
    main()
