# Setup guide

This walks through building the project in Vivado and getting it running
on a Real Digital Blackboard. It assumes Vivado is already installed
(2019.2 or newer should work fine; this was written against the Zynq-7000
support in current Vivado releases) and that you have the board, a USB
to TTL serial adapter, and a monitor that can take VGA.

## 1. Check the pin constraints first

Open `constr/blackboard.xdc` and read the two blocks marked NEEDS
VERIFICATION near the bottom: one for the UART pins on PMOD header JC,
one for the VGA connector. Board revisions differ slightly, and some
production runs of the Blackboard carry HDMI instead of VGA, so confirm
these against the master XDC Real Digital publishes for your specific
board before you build. The clock, switch, button and LED pins above
them are the standard Blackboard assignments and should not need
changes.

If your board turns out to have no VGA connector, a VGA PMOD breakout
board on any of the other free PMOD headers works too, wired to the
same `vga_hsync`, `vga_vsync`, `vga_red`, `vga_green` and `vga_blue`
ports in `text_terminal_top.v`.

## 2. Build the project

Open Vivado, go to the Tcl console, and run:

```
cd C:/Users/hthakkar/Desktop/Hardware/uart-vga-terminal
source scripts/create_project.tcl
```

This creates a project under `build/`, adds all the RTL files, the
testbenches, `font/font.mem`, and the constraints file, and generates
the Clocking Wizard IP that produces the 100 MHz and 25 MHz clocks the
design needs. It stops before synthesis so you can look at the project
first. The bottom of the script has three commented out lines that run
synthesis, implementation and bitstream generation in one go if you
would rather skip the GUI; uncomment them and re-run the script, or
just use the GUI buttons described below.

If you prefer to build everything by hand through the GUI instead of
running the script, the steps are:

1. File, New Project. Pick the Real Digital Blackboard board file if you
   have it installed, otherwise select part `xc7z007s-1clg400c-1` directly.
2. Add all files under `rtl/` as design sources.
3. Add `font/font.mem` as a design source too. This matters: it has to
   show up for both synthesis and simulation, since `font_rom.v` reads
   it with `$readmemh` in both flows. Adding it with the rest of the RTL
   sources covers both.
4. Add the three files under `sim/` as simulation sources only.
5. Add `constr/blackboard.xdc` as a constraints source.
6. Open the IP catalog, find Clocking Wizard, and create one named
   `clk_wiz_0` with a 100 MHz input, output 1 at 100 MHz, output 2 at
   25 MHz, and both the locked signal and an active-high reset input
   enabled.
7. Set `text_terminal_top` as the top module.

## 3. Run the simulations (optional, needs a simulator)

This machine does not have a simulator installed, so the three
testbenches under `sim/` were written and checked by hand but never
actually run here. Once you have Vivado or another simulator available:

In Vivado, open the Simulation Sources fileset, right click on whichever
of `tb_uart_rx`, `tb_uart_tx` or `tb_vga_timing` you want to run, and set
it as the simulation top, then run behavioral simulation. Each
testbench prints `PASS` or `FAIL` along with an error count to the Tcl
console.

With a standalone Icarus Verilog install instead, from the project root:

```
iverilog -o sim_rx.out rtl/baud_tick_gen.v rtl/uart_rx.v sim/tb_uart_rx.v
vvp sim_rx.out

iverilog -o sim_tx.out rtl/uart_tx.v sim/tb_uart_tx.v
vvp sim_tx.out

iverilog -o sim_vga.out rtl/vga_timing.v sim/tb_vga_timing.v
vvp sim_vga.out
```

## 4. Synthesis, implementation, and the bitstream

From the Flow Navigator: Run Synthesis, then Run Implementation, then
Generate Bitstream. On this part, a clean build typically finishes in a
couple of minutes; the whole design uses a small fraction of the
available logic and only 2 of the 50 RAMB36 block RAM tiles (see the
numbers in README.md), so there is no concern about running out of
resources.

## 5. Program the board

Open Hardware Manager, connect to the board over JTAG, and program the
device with the generated `.bit` file. The LEDs should light up almost
immediately: the heartbeat LED blinking roughly once a second confirms
the system clock is alive and locked, and the stat LEDs (controlled by
`sw[3:1]`, see README.md) default to showing the running byte count,
which should sit at zero before anything is connected to the serial
port.

## 6. Connect a serial terminal

Wire a USB to TTL serial adapter to PMOD header JC: adapter TX to the
board's RX pin, adapter RX to the board's TX pin, and a shared ground.
Do not connect the adapter's own power pin if the board is already
powered. Open a serial terminal on the host PC (PuTTY, Tera Term, or any
equivalent) at 115200 baud, 8 data bits, no parity, 1 stop bit.

Wait until the monitor shows a blank text screen before typing anything.
The screen clears itself once at power up, and a byte that arrives in
the first instant of that clear can be dropped; this is a known,
documented limitation, not a bug, and `cursor_ctrl.v` counts any byte
this happens to on `bytes_dropped` so it is never silently lost without
a trace.

Type on the keyboard connected to the serial terminal program and the
characters should appear on the VGA monitor. Enter scrolls, backspace
erases the previous character, and tab advances to the next multiple of
eight columns.

## 7. Try the built in self test

Flip `sw[0]` on to switch the UART into built in self test mode. In this
mode the design stops listening for typed characters and instead sends
itself a free running byte counter over TX while checking whatever
comes back on RX against what it expects. Loop TX to RX with a jumper
wire directly on the PMOD header (bypassing the serial adapter
entirely) to exercise the link at full speed, or feed it back through
the adapter in loopback mode if your adapter supports that. Use
`sw[3:1]` to pick which 32 bit counter the LEDs show the low byte of;
options 100, 101 and 110 (binary) show the self test's sent, good and
error counts.

## Switch and button reference

| Control | Function |
|---|---|
| `sw[0]` | 0 = normal terminal mode, 1 = UART built in self test |
| `sw[3:1]` | selects which counter the 8 stat LEDs display |
| `sw[7:4]` | reserved, not used |
| `btn[0]` | reset |
| `btn[1]` | also reset (acts as a manual clear screen button) |
| `btn[2]`, `btn[3]` | reserved, not used |

## Stat LED selector values

| `sw[3:1]` | Shows |
|---|---|
| 000 | bytes received, low byte |
| 001 | bytes dropped, low byte |
| 010 | framing errors, low byte |
| 011 | video frame count, low byte |
| 100 | self test bytes sent, low byte |
| 101 | self test bytes good, low byte |
| 110 | self test bytes bad, low byte |
| 111 | current scroll offset (top_row, 0 to 29) |
