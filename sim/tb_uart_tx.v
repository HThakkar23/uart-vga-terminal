`timescale 1ns / 1ps
//
// Self checking testbench for uart_tx. Not run as part of this project
// since no simulator is installed on this machine; open it in Vivado's
// simulator (add it as a simulation source, set it as the top module for
// simulation, run behavioral simulation) or with a local iverilog install
// (iverilog -o sim.out rtl/uart_tx.v sim/tb_uart_tx.v && vvp sim.out).
//
// Sends two bytes back to back and checks every bit of both frames
// against what was asked for, including the idle gap, both start bits
// and both stop bits, and reports a pass or fail count at the end.
//
module tb_uart_tx;

    localparam CLK_FREQ_HZ = 100_000_000;
    localparam BAUD_RATE   = 115_200;
    localparam BIT_PERIOD_NS = 1_000_000_000 / BAUD_RATE;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg tx_start = 1'b0;
    reg [7:0] tx_data = 8'h00;

    wire tx_pin;
    wire tx_busy;

    integer errors = 0;
    integer checks = 0;

    uart_tx #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (BAUD_RATE)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx_pin   (tx_pin),
        .tx_busy  (tx_busy)
    );

    always #5 clk = ~clk; // 100 MHz

    task check_bit;
        input [7:0] expected;
        input [127:0] label;
        begin
            checks = checks + 1;
            if (tx_pin !== expected[0]) begin
                errors = errors + 1;
                $display("FAIL %0s: expected %b got %b at time %0t", label, expected[0], tx_pin, $time);
            end
        end
    endtask

    task send_and_check;
        input [7:0] byte_to_send;
        integer i;
        begin
            @(posedge clk);
            tx_data  = byte_to_send;
            tx_start = 1'b1;
            @(posedge clk);
            tx_start = 1'b0;

            // start bit
            #(BIT_PERIOD_NS/2);
            check_bit(1'b0, "start bit");

            // 8 data bits, lsb first
            for (i = 0; i < 8; i = i + 1) begin
                #(BIT_PERIOD_NS);
                check_bit(byte_to_send[i], "data bit");
            end

            // stop bit
            #(BIT_PERIOD_NS);
            check_bit(1'b1, "stop bit");

            #(BIT_PERIOD_NS/2);
            if (tx_busy !== 1'b0) begin
                errors = errors + 1;
                $display("FAIL: tx_busy still high after stop bit at time %0t", $time);
            end
        end
    endtask

    initial begin
        #100;
        rst = 1'b0;
        #100;

        if (tx_pin !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: tx_pin not idle high before first transmission");
        end

        send_and_check(8'h55); // 0101_0101
        send_and_check(8'hA3); // 1010_0011

        $display("uart_tx testbench done: %0d checks, %0d errors", checks, errors);
        if (errors == 0)
            $display("PASS");
        else
            $display("FAIL");

        $finish;
    end

endmodule
