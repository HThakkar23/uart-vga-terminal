`timescale 1ns / 1ps
//
// Turns a stream of received bytes into writes into char_buffer, acting as
// a small terminal: tracks a cursor column and row, wraps at column 80,
// scrolls when the bottom row is full, and understands carriage return,
// line feed, backspace and tab. Anything else is counted and dropped.
//
// Scrolling moves a circular row pointer (top_row) instead of copying 29
// rows of memory on every newline. The row about to become the new
// bottom line still holds old content, so it gets blanked, 80 writes
// handled by the same state machine that clears the whole screen at reset.
//
// A one byte skid buffer catches a byte that arrives mid blank. One byte
// is always enough except right at power up: a byte arriving in the
// first ~24 us after reset, before the initial clear finishes, can still
// be lost. Wait for the screen to show blank before sending the first
// character; bytes_dropped below reads nonzero if that ever happens.
//
module cursor_ctrl (
    input  wire clk,
    input  wire rst,

    input  wire [7:0] rx_data,
    input  wire       rx_valid,
    input  wire       rx_frame_err,

    output reg         buf_we,
    output reg  [11:0] buf_addr,
    output reg  [7:0]  buf_wdata,

    output reg         scroll_toggle,
    output reg [31:0]  bytes_received,
    output reg [31:0]  bytes_dropped,
    output reg [31:0]  framing_errors,
    output reg [4:0]   top_row
);

    localparam integer COLS = 80;
    localparam integer ROWS = 30;
    localparam integer SCREEN_CELLS = COLS * ROWS;
    localparam [4:0] LAST_ROW = ROWS - 1;

    localparam ST_FILL = 1'b0;
    localparam ST_IDLE = 1'b1;

    reg state;

    reg [6:0] col;     // 0..79, on screen column
    reg [4:0] row;     // 0..29, on screen row
    // top_row (0..29, physical row mapped to on screen row 0) is a module
    // output above, since led_display needs to read it too

    reg [11:0] fill_addr;
    reg [11:0] fill_remaining;

    reg       pending_valid;
    reg [7:0] pending_data;
    reg       pending_err;

    wire [7:0] cur_data  = pending_valid ? pending_data : rx_data;
    wire       cur_err   = pending_valid ? pending_err  : rx_frame_err;
    wire       have_byte = pending_valid || rx_valid;

    wire is_printable = (cur_data >= 8'h20) && (cur_data <= 8'h7E);
    wire is_cr  = (cur_data == 8'h0D);
    wire is_lf  = (cur_data == 8'h0A);
    wire is_bs  = (cur_data == 8'h08);
    wire is_tab = (cur_data == 8'h09);

    // modular add, keeps a value in 0..29 the way a 30 row circular buffer needs
    function [4:0] mod30_add;
        input [4:0] a;
        input [4:0] b;
        reg   [5:0] s;
        begin
            s = a + b;
            mod30_add = (s >= 6'd30) ? (s - 6'd30) : s[4:0];
        end
    endfunction

    wire [4:0] phys_row       = mod30_add(row, top_row);
    wire [4:0] next_top_row   = mod30_add(top_row, 5'd1);
    wire [4:0] scroll_phys_row = mod30_add(LAST_ROW, next_top_row);

    task advance_row;
        begin
            if (row == LAST_ROW) begin
                top_row        <= next_top_row;
                scroll_toggle  <= ~scroll_toggle;
                fill_addr      <= scroll_phys_row * 12'd80;
                fill_remaining <= COLS[11:0];
                state          <= ST_FILL;
            end else begin
                row <= row + 1'b1;
            end
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state          <= ST_FILL;
            col            <= 7'd0;
            row            <= 5'd0;
            top_row        <= 5'd0;
            fill_addr      <= 12'd0;
            fill_remaining <= SCREEN_CELLS[11:0];
            buf_we         <= 1'b0;
            buf_addr       <= 12'd0;
            buf_wdata      <= 8'h20;
            pending_valid  <= 1'b0;
            pending_data   <= 8'h00;
            pending_err    <= 1'b0;
            scroll_toggle  <= 1'b0;
            bytes_received <= 32'd0;
            bytes_dropped  <= 32'd0;
            framing_errors <= 32'd0;
        end else begin
            buf_we <= 1'b0;

            if (rx_valid) begin
                bytes_received <= bytes_received + 1'b1;
                if (rx_frame_err)
                    framing_errors <= framing_errors + 1'b1;
            end

            // single entry inbox: capture a fresh byte whenever there is
            // room for it, drop and count it only when the inbox is still
            // full because a blank operation is in progress
            if (state == ST_FILL) begin
                if (rx_valid) begin
                    if (!pending_valid) begin
                        pending_valid <= 1'b1;
                        pending_data  <= rx_data;
                        pending_err   <= rx_frame_err;
                    end else begin
                        bytes_dropped <= bytes_dropped + 1'b1;
                    end
                end
            end else begin
                if (have_byte) begin
                    if (rx_valid) begin
                        pending_valid <= 1'b1;
                        pending_data  <= rx_data;
                        pending_err   <= rx_frame_err;
                    end else begin
                        pending_valid <= 1'b0;
                    end
                end
            end

            case (state)
                ST_FILL: begin
                    buf_we    <= 1'b1;
                    buf_addr  <= fill_addr;
                    buf_wdata <= 8'h20;
                    if (fill_remaining == 12'd1) begin
                        state <= ST_IDLE;
                    end else begin
                        fill_addr      <= fill_addr + 12'd1;
                        fill_remaining <= fill_remaining - 12'd1;
                    end
                end

                ST_IDLE: begin
                    if (have_byte) begin
                        if (is_printable) begin
                            buf_we    <= 1'b1;
                            buf_addr  <= phys_row * 12'd80 + {5'd0, col};
                            buf_wdata <= cur_data;
                            if (col == COLS - 1) begin
                                col <= 7'd0;
                                advance_row;
                            end else begin
                                col <= col + 1'b1;
                            end
                        end else if (is_cr) begin
                            col <= 7'd0;
                        end else if (is_lf) begin
                            advance_row;
                        end else if (is_bs) begin
                            if (col != 7'd0) begin
                                col       <= col - 1'b1;
                                buf_we    <= 1'b1;
                                buf_addr  <= phys_row * 12'd80 + {5'd0, col - 7'd1};
                                buf_wdata <= 8'h20;
                            end
                        end else if (is_tab) begin
                            if (col >= COLS - 8) begin
                                col <= 7'd0;
                                advance_row;
                            end else begin
                                col <= (col | 7'd7) + 7'd1;
                            end
                        end else begin
                            bytes_dropped <= bytes_dropped + 1'b1;
                        end
                    end
                end
            endcase
        end
    end

endmodule
