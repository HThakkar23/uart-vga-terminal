`timescale 1ns / 1ps
//
// Crosses a slowly changing event count from one clock domain to another
// without touching a multi-bit bus across the boundary.
//
// The source domain toggles toggle_src once per event instead of pulsing
// it, since a single cycle pulse can be missed entirely by a destination
// clock that samples at a different rate. The destination domain runs the
// toggle through a three flop synchronizer and counts every edge it sees,
// which rebuilds the original event count safely as long as events in the
// source domain are spaced out by more than a couple of destination clock
// periods, true here with wide margin on both counters this module feeds
// (video frames and scroll events against a 25 MHz or 100 MHz destination).
//
module toggle_sync #(
    parameter integer WIDTH  = 5,
    parameter integer MAXVAL = 29 // count wraps to 0 after reaching this value
) (
    input  wire clk_dst,
    input  wire rst_dst,
    input  wire toggle_src,

    output reg [WIDTH-1:0] count_dst
);

    reg [2:0] sync_ff;

    always @(posedge clk_dst) begin
        sync_ff <= {sync_ff[1:0], toggle_src};
    end

    wire edge_seen = sync_ff[2] ^ sync_ff[1];

    always @(posedge clk_dst) begin
        if (rst_dst)
            count_dst <= {WIDTH{1'b0}};
        else if (edge_seen)
            count_dst <= (count_dst == MAXVAL[WIDTH-1:0]) ? {WIDTH{1'b0}} : count_dst + 1'b1;
    end

endmodule
