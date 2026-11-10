`timescale 1ns / 1ps
//
// Self checking testbench for uart_rx, paired with the real baud_tick_gen
// so the oversample tick it depends on is generated exactly the way it
// would be on the board. Not run as part of this project since no
// simulator is installed on this machine; open it in Vivado's simulator
// or with a local iverilog install
// (iverilog -o sim.out rtl/baud_tick_gen.v rtl/uart_rx.v sim/tb_uart_rx.v && vvp sim.out).
//
// Drives three frames onto rx_pin: two good frames and one with a broken
// stop bit, and checks that the first two are decoded correctly and the
// third is flagged with frame_err.
//
module tb_uart_rx;

    localparam CLK_FREQ_HZ = 100_000_000;
    localparam BAUD_RATE   = 115_200;
    localparam BIT_PERIOD_NS = 1_000_000_000 / BAUD_RATE;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg rx_pin = 1'b1;

    wire tick_16x;
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_frame_err;

    integer errors = 0;
    integer checks = 0;

    baud_tick_gen #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (BAUD_RATE),
        .OVERSAMPLE  (16)
    ) tick_gen (
        .clk      (clk),
        .rst      (rst),
        .tick_16x (tick_16x)
    );

    uart_rx dut (
        .clk          (clk),
        .rst          (rst),
        .tick_16x     (tick_16x),
        .rx_pin       (rx_pin),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .rx_frame_err (rx_frame_err)
    );

    always #5 clk = ~clk; // 100 MHz

    task send_frame;
        input [7:0] data;
        input       good_stop_bit;
        integer i;
        begin
            rx_pin = 1'b0; // start bit
            #(BIT_PERIOD_NS);
            for (i = 0; i < 8; i = i + 1) begin
                rx_pin = data[i];
                #(BIT_PERIOD_NS);
            end
            rx_pin = good_stop_bit ? 1'b1 : 1'b0; // stop bit, possibly broken
            #(BIT_PERIOD_NS);
            rx_pin = 1'b1; // back to idle
            #(BIT_PERIOD_NS);
        end
    endtask

    task expect_byte;
        input [7:0] expected_data;
        input       expected_err;
        input [127:0] label;
        begin
            @(posedge rx_valid);
            checks = checks + 1;
            if (rx_data !== expected_data) begin
                errors = errors + 1;
                $display("FAIL %0s: expected data %h got %h", label, expected_data, rx_data);
            end
            if (rx_frame_err !== expected_err) begin
                errors = errors + 1;
                $display("FAIL %0s: expected frame_err %b got %b", label, expected_err, rx_frame_err);
            end
            @(negedge clk);
        end
    endtask

    initial begin
        #100;
        rst = 1'b0;
        #100;

        fork
            send_frame(8'h41, 1'b1); // 'A', clean frame
            expect_byte(8'h41, 1'b0, "frame 1 (clean 'A')");
        join

        fork
            send_frame(8'hFF, 1'b1); // all ones
            expect_byte(8'hFF, 1'b0, "frame 2 (0xFF)");
        join

        fork
            send_frame(8'h3C, 1'b0); // broken stop bit
            expect_byte(8'h3C, 1'b1, "frame 3 (broken stop bit)");
        join

        $display("uart_rx testbench done: %0d checks, %0d errors", checks, errors);
        if (errors == 0)
            $display("PASS");
        else
            $display("FAIL");

        $finish;
    end

endmodule
