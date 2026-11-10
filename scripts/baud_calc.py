#!/usr/bin/env python3
"""
Works out the UART baud tick divisor for a given system clock and baud rate,
and reports how far the real hardware baud rate drifts from the target.

The RTL uses a free running counter that rolls over every DIVISOR cycles to
make one 16x oversample tick. Sixteen of those make one bit period. Because
DIVISOR has to be a whole number, the real bit rate is never exactly the
target rate, so this script prints the error so it can be checked against
the 2 percent tolerance most UARTs can absorb.
"""

CLK_HZ = 100_000_000
OVERSAMPLE = 16

TARGET_BAUDS = [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]


def divisor_for(baud):
    ideal = CLK_HZ / (baud * OVERSAMPLE)
    div = round(ideal)
    actual_tick_hz = CLK_HZ / div
    actual_baud = actual_tick_hz / OVERSAMPLE
    error_pct = (actual_baud - baud) / baud * 100
    return div, actual_baud, error_pct


def main():
    print(f"system clock       : {CLK_HZ/1e6:.3f} MHz")
    print(f"oversample factor   : {OVERSAMPLE}x")
    print()
    header = f"{'baud':>9} | {'divisor':>7} | {'actual baud':>12} | {'error':>8}"
    print(header)
    print("-" * len(header))
    for baud in TARGET_BAUDS:
        div, actual, err = divisor_for(baud)
        flag = "" if abs(err) < 2.0 else "  OUT OF SPEC"
        print(f"{baud:>9} | {div:>7} | {actual:>12.1f} | {err:>+7.2f}%{flag}")

    print()
    chosen = 115200
    div, actual, err = divisor_for(chosen)
    bit_time_ns = 1e9 / actual
    frame_bits = 10  # start + 8 data + stop, no parity
    byte_time_us = frame_bits * bit_time_ns / 1000
    bytes_per_sec = actual / frame_bits
    print(f"chosen operating point: {chosen} baud, 8N1")
    print(f"  tick divisor         : {div}")
    print(f"  real baud achieved   : {actual:.1f} ({err:+.2f}% error)")
    print(f"  bit time             : {bit_time_ns:.1f} ns")
    print(f"  byte time (10 bits)  : {byte_time_us:.2f} us")
    print(f"  theoretical max rate : {bytes_per_sec:.0f} bytes/sec")


if __name__ == "__main__":
    main()
