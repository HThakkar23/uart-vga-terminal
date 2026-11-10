`timescale 1ns / 1ps
//
// Top level: a serial terminal that prints to a VGA monitor. Characters
// sent over UART land on an 80 by 30 text screen held in block RAM, and
// a second block RAM holds the font used to draw that screen at 640x480.
//
// Two clock domains: clk_sys at 100 MHz runs the UART and the cursor and
// screen logic, clk_pix at 25 MHz runs the VGA timing and renderer. Both
// come from one Clocking Wizard IP instance built in Vivado (see
// SETUP.md), named clk_wiz_0 with the usual clk_in1/clk_out1/clk_out2/
// locked ports.
//
// The onboard UART pins belong to the Zynq processing system, not the
// programmable logic, so this project does not use them. uart_rx and
// uart_tx instead go to PMOD header JC, for an external USB to TTL
// adapter at 115200 8N1. See constr/blackboard.xdc for the pins.
//
// VGA color depth has not been confirmed against a schematic, so this
// stays generic: red, green and blue are each VGA_BITS wide, every bit
// tied to pixel_on, giving white text on black regardless of DAC width.
// Set VGA_BITS to match the board once that is verified.
//
module text_terminal_top #(
    parameter integer VGA_BITS = 4
) (
    input  wire clk_in,      // 100 MHz onboard oscillator
    input  wire [3:0] btn,   // btn[0] reset, btn[1] clear screen, btn[2:3] unused
    input  wire [7:0] sw,    // sw[0] bist enable, sw[3:1] stat select, sw[7:4] unused

    input  wire uart_rx_pin,
    output wire uart_tx_pin,

    output wire vga_hsync,
    output wire vga_vsync,
    output wire [VGA_BITS-1:0] vga_red,
    output wire [VGA_BITS-1:0] vga_green,
    output wire [VGA_BITS-1:0] vga_blue,

    output wire [9:0] led
);

    // ------------------------------------------------------------------
    // Clocking
    // ------------------------------------------------------------------
    wire clk_sys;   // 100 MHz
    wire clk_pix;   // 25 MHz
    wire clk_locked;

    clk_wiz_0 clk_wiz_inst (
        .clk_in1  (clk_in),
        .reset    (1'b0),
        .clk_out1 (clk_sys),
        .clk_out2 (clk_pix),
        .locked   (clk_locked)
    );

    wire raw_rst = btn[0] | btn[1] | ~clk_locked;

    wire rst_sys;
    reset_sync reset_sync_sys (
        .clk           (clk_sys),
        .async_rst_in  (raw_rst),
        .sync_rst_out  (rst_sys)
    );

    wire rst_pix;
    reset_sync reset_sync_pix (
        .clk           (clk_pix),
        .async_rst_in  (raw_rst),
        .sync_rst_out  (rst_pix)
    );

    // ------------------------------------------------------------------
    // UART
    // ------------------------------------------------------------------
    wire tick_16x;
    baud_tick_gen baud_tick_gen_inst (
        .clk     (clk_sys),
        .rst     (rst_sys),
        .tick_16x(tick_16x)
    );

    wire       rx_valid;
    wire [7:0] rx_data;
    wire       rx_frame_err;

    uart_rx uart_rx_inst (
        .clk          (clk_sys),
        .rst          (rst_sys),
        .tick_16x     (tick_16x),
        .rx_pin       (uart_rx_pin),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .rx_frame_err (rx_frame_err)
    );

    wire       tx_start;
    wire [7:0] tx_data;
    wire       tx_busy;

    uart_tx uart_tx_inst (
        .clk      (clk_sys),
        .rst      (rst_sys),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx_busy  (tx_busy),
        .tx_pin   (uart_tx_pin)
    );

    wire bist_enable = sw[0];

    // in BIST mode received bytes feed the self test checker instead of
    // the screen, so a loopback test does not spam the display
    wire       cursor_rx_valid = rx_valid && !bist_enable;
    wire       bist_rx_valid   = rx_valid && bist_enable;

    wire [31:0] bist_sent, bist_good, bist_error;

    uart_bist uart_bist_inst (
        .clk         (clk_sys),
        .rst         (rst_sys),
        .enable      (bist_enable),
        .tx_start    (tx_start),
        .tx_data     (tx_data),
        .tx_busy     (tx_busy),
        .rx_valid    (bist_rx_valid),
        .rx_data     (rx_data),
        .sent_count  (bist_sent),
        .good_count  (bist_good),
        .error_count (bist_error)
    );

    // ------------------------------------------------------------------
    // Cursor / screen logic and the character buffer it writes into
    // ------------------------------------------------------------------
    wire        buf_we;
    wire [11:0] buf_addr;
    wire [7:0]  buf_wdata;

    wire        scroll_toggle;
    wire [31:0] bytes_received, bytes_dropped, framing_errors;
    wire [4:0]  top_row_sys;

    cursor_ctrl cursor_ctrl_inst (
        .clk            (clk_sys),
        .rst            (rst_sys),
        .rx_data        (rx_data),
        .rx_valid       (cursor_rx_valid),
        .rx_frame_err   (rx_frame_err),
        .buf_we         (buf_we),
        .buf_addr       (buf_addr),
        .buf_wdata      (buf_wdata),
        .scroll_toggle  (scroll_toggle),
        .bytes_received (bytes_received),
        .bytes_dropped  (bytes_dropped),
        .framing_errors (framing_errors),
        .top_row        (top_row_sys)
    );

    wire [11:0] char_rd_addr;
    wire [7:0]  char_rd_data;

    char_buffer char_buffer_inst (
        .wr_clk  (clk_sys),
        .wr_en   (buf_we),
        .wr_addr (buf_addr),
        .wr_data (buf_wdata),
        .rd_clk  (clk_pix),
        .rd_addr (char_rd_addr),
        .rd_data (char_rd_data)
    );

    // ------------------------------------------------------------------
    // Clock domain crossing: scroll offset and frame count
    // ------------------------------------------------------------------
    wire [4:0] top_row_pix;
    toggle_sync #(.WIDTH(5), .MAXVAL(29)) top_row_sync (
        .clk_dst    (clk_pix),
        .rst_dst    (rst_pix),
        .toggle_src (scroll_toggle),
        .count_dst  (top_row_pix)
    );

    wire frame_tick;
    reg  frame_toggle;
    always @(posedge clk_pix) begin
        if (rst_pix)
            frame_toggle <= 1'b0;
        else if (frame_tick)
            frame_toggle <= ~frame_toggle;
    end

    wire [31:0] frame_count;
    toggle_sync #(.WIDTH(32), .MAXVAL(32'hFFFFFFFF)) frame_count_sync (
        .clk_dst    (clk_sys),
        .rst_dst    (rst_sys),
        .toggle_src (frame_toggle),
        .count_dst  (frame_count)
    );

    // ------------------------------------------------------------------
    // VGA timing and text rendering
    // ------------------------------------------------------------------
    wire hsync_raw, vsync_raw, active_raw;
    wire [9:0] pixel_x, pixel_y;

    vga_timing vga_timing_inst (
        .clk_pix    (clk_pix),
        .rst        (rst_pix),
        .hsync      (hsync_raw),
        .vsync      (vsync_raw),
        .active     (active_raw),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .frame_tick (frame_tick)
    );

    wire [6:0] font_char_code;
    wire [3:0] font_row_in_glyph;
    wire [7:0] font_row_bits;

    font_rom font_rom_inst (
        .clk          (clk_pix),
        .char_code    (font_char_code),
        .row_in_glyph (font_row_in_glyph),
        .row_bits     (font_row_bits)
    );

    wire pixel_on;

    vga_text_renderer vga_text_renderer_inst (
        .clk_pix           (clk_pix),
        .rst               (rst_pix),
        .pixel_x           (pixel_x),
        .pixel_y           (pixel_y),
        .hsync_in          (hsync_raw),
        .vsync_in          (vsync_raw),
        .active_in         (active_raw),
        .top_row           (top_row_pix),
        .char_rd_addr      (char_rd_addr),
        .char_rd_data      (char_rd_data),
        .font_char_code    (font_char_code),
        .font_row_in_glyph (font_row_in_glyph),
        .font_row_bits     (font_row_bits),
        .hsync_out         (vga_hsync),
        .vsync_out         (vga_vsync),
        .pixel_on          (pixel_on)
    );

    assign vga_red   = {VGA_BITS{pixel_on}};
    assign vga_green = {VGA_BITS{pixel_on}};
    assign vga_blue  = {VGA_BITS{pixel_on}};

    // ------------------------------------------------------------------
    // Status LEDs
    // ------------------------------------------------------------------
    led_display led_display_inst (
        .clk            (clk_sys),
        .rst            (rst_sys),
        .bytes_received (bytes_received),
        .bytes_dropped  (bytes_dropped),
        .framing_errors (framing_errors),
        .frame_count    (frame_count),
        .bist_sent      (bist_sent),
        .bist_good      (bist_good),
        .bist_error     (bist_error),
        .top_row        (top_row_sys),
        .stat_select    (sw[3:1]),
        .rx_valid       (rx_valid),
        .led            (led)
    );

endmodule
