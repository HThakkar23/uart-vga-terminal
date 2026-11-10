`timescale 1ns / 1ps
//
// Turns the raw VGA timing signals and pixel coordinates into an actual
// picture: looks up the current character cell in char_buffer, then the
// current pixel row of that glyph in font_rom. Both register their read
// data one cycle after the address is presented, so sync, active, and
// the column inside the cell all ride matching delay lines to come back
// in step, three cycles after the pixel coordinate they describe.
//
// top_row is the circular buffer offset from cursor_ctrl, already synced
// into this clock domain by a toggle_sync instance before it gets here.
//
module vga_text_renderer (
    input  wire clk_pix,
    input  wire rst,

    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire       hsync_in,
    input  wire       vsync_in,
    input  wire       active_in,
    input  wire [4:0] top_row,

    output wire [11:0] char_rd_addr,
    input  wire [7:0]  char_rd_data,

    output wire [6:0] font_char_code,
    output wire [3:0] font_row_in_glyph,
    input  wire [7:0] font_row_bits,

    output reg hsync_out,
    output reg vsync_out,
    output reg pixel_on
);

    localparam integer COLS = 80;
    localparam integer ROWS = 30;

    // raw cell coordinates from the pixel position. char_row_raw needs 6
    // bits: pixel_y reaches 524 during vertical blanking, and 524 >> 4 is
    // 32, which does not fit in 5 bits.
    wire [6:0] char_col_raw = pixel_x[9:3];
    wire [5:0] char_row_raw = pixel_y[9:4];

    wire [6:0] char_col = (char_col_raw > COLS - 1) ? (COLS - 1) : char_col_raw;
    wire [4:0] char_row = (char_row_raw > ROWS - 1) ? (ROWS - 1) : char_row_raw[4:0];

    wire [2:0] sub_x = pixel_x[2:0];
    wire [3:0] sub_y = pixel_y[3:0];

    // fold the on screen row through the circular top_row offset to get
    // the physical row actually holding that line's characters. char_row
    // and top_row are each at most 29, so the sum is at most 58 and a
    // single conditional subtract is always enough.
    wire [5:0] row_sum  = {1'b0, char_row} + {1'b0, top_row};
    wire [4:0] phys_row = (row_sum >= ROWS) ? (row_sum - ROWS) : row_sum[4:0];

    assign char_rd_addr = phys_row * 12'd80 + {5'd0, char_col};

    // char_rd_data arrives one cycle after char_rd_addr and feeds
    // font_char_code with no extra register, so font_rom's own one
    // cycle of read latency is the only latency this stage adds.
    assign font_char_code    = char_rd_data[6:0];
    assign font_row_in_glyph = sub_y_d1;

    // delay lines: sub_y needs to be one cycle old when it reaches
    // font_row_in_glyph, to match char_rd_data's one cycle of latency.
    // sub_x and the sync/active signals need to be two cycles old when
    // they are used against font_row_bits, to match the combined two
    // cycle latency of char_buffer followed by font_rom.
    reg [3:0] sub_y_d1;
    reg [2:0] sub_x_d1, sub_x_d2;
    reg hsync_d1, hsync_d2;
    reg vsync_d1, vsync_d2;
    reg active_d1, active_d2;

    always @(posedge clk_pix) begin
        sub_y_d1  <= sub_y;

        sub_x_d1  <= sub_x;
        sub_x_d2  <= sub_x_d1;

        hsync_d1  <= hsync_in;
        hsync_d2  <= hsync_d1;

        vsync_d1  <= vsync_in;
        vsync_d2  <= vsync_d1;

        active_d1 <= active_in;
        active_d2 <= active_d1;
    end

    always @(posedge clk_pix) begin
        if (rst) begin
            hsync_out <= 1'b1;
            vsync_out <= 1'b1;
            pixel_on  <= 1'b0;
        end else begin
            hsync_out <= hsync_d2;
            vsync_out <= vsync_d2;
            pixel_on  <= active_d2 && font_row_bits[7 - sub_x_d2];
        end
    end

endmodule
