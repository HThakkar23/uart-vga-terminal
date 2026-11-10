# UART to VGA terminal

A serial text terminal built in Verilog for the Real Digital Blackboard
(Zynq-7000, XC7Z007S). Plug a USB to serial adapter into one of the
board's PMOD headers, open any terminal program at 115200 baud, and
whatever you type shows up on a VGA monitor, scrolling like a real
terminal. Everything runs in the FPGA fabric. The Zynq's ARM cores are
never touched.

I built this to have something on a real board that actually
demonstrates serial protocol work and a video pipeline together, instead
of another blinking LED project. Every number quoted below comes from a
small Python script in `scripts/`, not from guessing, and the design has
a built in self test mode that reports live byte counts over the same
link it is testing.

## What it does

Type a character into a serial terminal connected to the board, and it
appears on an 80 column by 30 row text screen on a 640x480 monitor.
Enter moves to a new line and scrolls the screen once it reaches the
bottom, backspace erases the previous character, and tab jumps to the
next stop every 8 columns. The screen clears itself once at power up.

A set of switches puts the UART into a built in self test instead: it
sends itself a continuous stream of known bytes and checks whatever
comes back, counting good and bad bytes. Loop the TX and RX pins
together with a jumper wire and this becomes a real, measured
throughput and error rate test of the serial link, with the results
shown live on the board's LEDs.

## Why build the UART instead of using the board's built in one

The Blackboard's onboard USB to serial port is wired straight into the
Zynq's processing system, the hard ARM core side of the chip, not into
the programmable logic where this project lives. Using it would mean
writing software for the ARM cores instead of Verilog. So this project
implements its own 8N1 UART transmitter and receiver from scratch in the
fabric, talking out over two spare pins on a PMOD header to an external
USB to TTL adapter instead. That is really the point of the project: the
UART core, the receiver's oversampling and glitch rejection, and the
timing analysis behind the baud rate choice are all original logic, not
a library block.

## Architecture

```
                         +-------------+        +--------------+
  USB serial adapter --> | uart_rx     | -----> | cursor_ctrl  |
                         +-------------+        +--------------+
                                                       |
                                                 writes characters
                                                       v
                                                +--------------+
                                                | char_buffer  |  (block RAM,
                                                |  80x30       |   dual clock,
                                                +--------------+   dual port)
                                                       |
                                                 reads characters
                                                       v
  +-------------+        +--------------+       +--------------+
  | vga_timing  | -----> | vga_text_    | <-----| font_rom     |
  | (640x480)   |        | renderer     |       | (8x16 glyphs)|
  +-------------+        +--------------+       +--------------+
                                |
                                v
                          VGA output pins
```

Two clock domains meet in this design: the UART and the text buffer
logic run at 100 MHz (`clk_sys`), and the VGA timing and renderer run at
25 MHz (`clk_pix`). The character buffer is a true dual port block RAM,
one port on each clock, which is the standard and well understood way
to build a video frame buffer that something other than the display
logic writes into. A small toggle synchronizer carries the scroll
position and frame counter across the boundary the other direction,
since those only change occasionally and a direct multi bit crossing
would not be safe.

Scrolling does not copy memory. The screen keeps a circular row pointer
(`top_row`) and only clears the one row that is about to become new,
which is why a scroll costs 80 character writes instead of 2400.

### Module list

| File | Role |
|---|---|
| `uart_rx.v` | 8N1 receiver, 16x oversampled, with glitch rejection on the start bit |
| `uart_tx.v` | 8N1 transmitter, its own independent bit timer |
| `baud_tick_gen.v` | generates the 16x oversample tick for the receiver |
| `uart_bist.v` | built in self test: sends a byte counter, checks the echo |
| `cursor_ctrl.v` | turns received bytes into screen writes, tracks cursor and scrolling |
| `char_buffer.v` | 80x30 dual port, dual clock block RAM holding the text screen |
| `font_rom.v` | 8x16 bitmap font, one ROM word per glyph scan line |
| `vga_timing.v` | 640x480 at 60 Hz timing generator |
| `vga_text_renderer.v` | turns character codes and font data into pixels |
| `toggle_sync.v` | reusable clock domain crossing block for slow moving counters |
| `reset_sync.v` | clean reset release in each clock domain |
| `led_display.v` | puts live counters on the board LEDs |
| `text_terminal_top.v` | top level, wires everything above together |

## The numbers

These come straight out of the scripts in `scripts/`, which you can run
yourself with a plain Python install (`python scripts/baud_calc.py`, and
so on).

**Baud rate.** Target 115200 baud, 100 MHz system clock, 16x
oversampling. The nearest achievable divisor is 54, giving a real rate of
115740.7 baud, which is 0.47% off the nominal rate. Standard UART
framing tolerates error well past that, so this is a safe, deliberate
choice rather than a coincidence:

```
     baud | divisor |  actual baud |    error
---------------------------------------------
     9600 |     651 |       9600.6 |   +0.01%
    19200 |     326 |      19171.8 |   -0.15%
    38400 |     163 |      38343.6 |   -0.15%
    57600 |     109 |      57339.4 |   -0.45%
   115200 |      54 |     115740.7 |   +0.47%
   230400 |      27 |     231481.5 |   +0.47%
   460800 |      14 |     446428.6 |   -3.12%  out of spec
   921600 |       7 |     892857.1 |   -3.12%  out of spec
```

At the chosen 115200 baud, one byte (8 data bits, a start bit and a stop
bit, 10 bits total) takes 86.4 microseconds, for a theoretical ceiling of
about 11574 bytes a second. The self test mode measures the actual
sustained rate against that ceiling.

**Video timing.** 640x480 at 60 Hz, generated from a 25 MHz pixel clock
instead of the VESA spec's 25.175 MHz, since that is what a simple
integer clock divide gives on this part. 800 pixel clocks per line, 525
lines per frame, 420000 pixel clocks per frame, giving a real refresh
rate of 59.524 Hz, close enough to 60 Hz that no monitor has ever
rejected it in testing this kind of design. The text grid is 80 columns
by 30 rows of 8x16 pixel cells, exactly filling the 640x480 active area.

**Block RAM usage.** The XC7Z007S has 50 RAMB36 equivalent tiles. The
text screen (80x30 characters, 8 bits each) needs 19200 bits, one
RAMB36 tile, 2.0% of the device. The font ROM (128 characters times 16
rows times 8 bits) needs 16384 bits, also one RAMB36 tile, another
2.0%. Worst case combined usage is 2 tiles, 4.0% of the device, with
room to spare for anything added later.

## A known limitation, on purpose

The screen clears itself once at power up, which takes about 2400
clock cycles, roughly 24 microseconds. A byte arriving in that exact
window can be lost, since the design only holds one byte in reserve
while a clear is running and the power up clear is longer than one byte
period at 115200 baud. In practice this means: wait for the screen to
show blank before typing the first character. It is not swept under the
rug. Every dropped byte, including one lost this way, increments a
counter (`bytes_dropped`) that you can watch on the LEDs, so if it ever
happens it is visible and countable, not silent. The much shorter
80-cycle clear that runs after a normal scroll has more than ten times
the margin and does not have this problem.

## Repository layout

```
rtl/        Verilog source for every module
sim/        self checking testbenches (see SETUP.md for how to run them)
scripts/    Python scripts that compute the numbers quoted above, and
            the font ROM generator
font/       generated font ROM data (font.mem)
constr/     Vivado XDC pin and timing constraints
scripts/create_project.tcl   builds the whole Vivado project in one step
SETUP.md    step by step build and bring up instructions
```

## Building it

See [SETUP.md](SETUP.md) for the full walkthrough, including the pins
that need to be double checked against your specific board revision
before building.

## Possible extensions

A few directions this could go if picked back up later: color text by
giving each character cell an attribute byte alongside its character
code, a second UART mode that supports basic ANSI escape codes for
cursor movement, or a small command interpreter that turns the terminal
into an actual interactive shell for reading back the live byte and
frame counters as text instead of binary LED patterns.
