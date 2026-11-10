`timescale 1ns / 1ps
//
// Text screen storage: 80 columns x 30 rows, 1 byte per character cell.
// True dual port, independent clocks, one cycle of read latency on each
// port, the standard inference template for a block RAM primitive. The
// write side belongs to the UART/cursor logic on the system clock, the
// read side belongs to the VGA pixel pipeline. A read landing on the
// same cycle as a write only risks showing the old or new value for
// that one character for one frame, invisible at 60 frames a second.
//
module char_buffer (
    input  wire        wr_clk,
    input  wire        wr_en,
    input  wire [11:0] wr_addr,
    input  wire [7:0]  wr_data,

    input  wire        rd_clk,
    input  wire [11:0] rd_addr,
    output reg  [7:0]  rd_data
);

    localparam DEPTH = 2400; // 80 x 30

    reg [7:0] mem [0:DEPTH-1];

    always @(posedge wr_clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    always @(posedge rd_clk) begin
        rd_data <= mem[rd_addr];
    end

endmodule
