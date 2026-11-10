`timescale 1ns / 1ps
//
// Built in self test for the UART link.
//
// While enabled, this keeps uart_tx continuously busy sending a free
// running byte counter (0, 1, 2, ... 255, 0, ...), and independently
// checks whatever comes back on the receive side against the same
// sequence. Loop TX back to RX with a jumper wire on the PMOD header to
// exercise the link at full rate and get a real measured byte count
// instead of a simulated one.
//
// A mismatch resynchronizes to the byte that was actually received plus
// one, rather than latching onto the wrong offset forever after a single
// dropped byte.
//
module uart_bist (
    input  wire clk,
    input  wire rst,
    input  wire enable,

    output reg        tx_start,
    output reg  [7:0] tx_data,
    input  wire       tx_busy,

    input  wire       rx_valid,
    input  wire [7:0] rx_data,

    output reg [31:0] sent_count,
    output reg [31:0] good_count,
    output reg [31:0] error_count
);

    reg [7:0] next_tx_byte;
    reg [7:0] expected_rx_byte;

    always @(posedge clk) begin
        if (rst || !enable) begin
            tx_start         <= 1'b0;
            tx_data          <= 8'd0;
            next_tx_byte     <= 8'd0;
            expected_rx_byte <= 8'd0;
            sent_count       <= 32'd0;
            good_count       <= 32'd0;
            error_count      <= 32'd0;
        end else begin
            if (!tx_busy) begin
                tx_data      <= next_tx_byte;
                tx_start     <= 1'b1;
                next_tx_byte <= next_tx_byte + 1'b1;
                sent_count   <= sent_count + 1'b1;
            end else begin
                tx_start <= 1'b0;
            end

            if (rx_valid) begin
                if (rx_data == expected_rx_byte)
                    good_count <= good_count + 1'b1;
                else
                    error_count <= error_count + 1'b1;
                expected_rx_byte <= rx_data + 1'b1;
            end
        end
    end

endmodule
