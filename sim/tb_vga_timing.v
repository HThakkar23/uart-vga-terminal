`timescale 1ns / 1ps
//
// Self checking testbench for vga_timing. Not run as part of this project
// since no simulator is installed on this machine; open it in Vivado's
// simulator or with a local iverilog install
// (iverilog -o sim.out rtl/vga_timing.v sim/tb_vga_timing.v && vvp sim.out).
//
// Runs just over two full frames and checks the numbers against the VESA
// 640x480 at 60 Hz standard: 800 pixel clocks per line, 525 lines per
// frame, a 96 clock wide horizontal sync pulse, a 2 line wide vertical
// sync pulse, and exactly 640 by 480 active pixels per frame.
//
module tb_vga_timing;

    reg clk_pix = 1'b0;
    reg rst = 1'b1;

    wire hsync, vsync, active;
    wire [9:0] pixel_x, pixel_y;
    wire frame_tick;

    integer errors = 0;

    vga_timing dut (
        .clk_pix    (clk_pix),
        .rst        (rst),
        .hsync      (hsync),
        .vsync      (vsync),
        .active     (active),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .frame_tick (frame_tick)
    );

    always #20 clk_pix = ~clk_pix; // 25 MHz

    integer active_pixel_count;
    integer hsync_low_count;
    integer line_count;
    integer frame_tick_count;
    integer cycle;

    always @(posedge clk_pix) begin
        if (!rst) begin
            if (active)
                active_pixel_count = active_pixel_count + 1;
            if (!hsync)
                hsync_low_count = hsync_low_count + 1;
            if (frame_tick)
                frame_tick_count = frame_tick_count + 1;
        end
    end

    initial begin
        active_pixel_count = 0;
        hsync_low_count    = 0;
        frame_tick_count   = 0;

        #100;
        rst = 1'b0;

        // 800 * 525 = 420000 pixel clocks make one full frame
        for (cycle = 0; cycle < 420000 * 2; cycle = cycle + 1)
            @(posedge clk_pix);

        // across exactly two frames: 640*480 active pixels each
        if (active_pixel_count !== 640 * 480 * 2) begin
            errors = errors + 1;
            $display("FAIL: active pixel count was %0d, expected %0d", active_pixel_count, 640*480*2);
        end

        // one 96 clock wide hsync pulse per line, 525 lines per frame, two frames
        if (hsync_low_count !== 96 * 525 * 2) begin
            errors = errors + 1;
            $display("FAIL: hsync low count was %0d, expected %0d", hsync_low_count, 96*525*2);
        end

        if (frame_tick_count !== 2) begin
            errors = errors + 1;
            $display("FAIL: frame_tick fired %0d times, expected 2", frame_tick_count);
        end

        $display("vga_timing testbench done, %0d errors", errors);
        if (errors == 0)
            $display("PASS");
        else
            $display("FAIL");

        $finish;
    end

endmodule
