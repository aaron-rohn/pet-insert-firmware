`timescale 1ns / 1ps

module event_counter #(
    NCOUNTERS = 3,
    WIDTH = 48
)(
    input wire frontend_clk, clk,
    input wire frontend_rst, rst,
    input wire [NCOUNTERS-1:0] signal, load,
    output wire [(NCOUNTERS*WIDTH)-1:0] counters
);

    wire [WIDTH-1:0] counter [NCOUNTERS-1:0];

    genvar i;
    generate for (i = 0; i < NCOUNTERS; i = i + 1) begin

        assign counters[i*WIDTH +: WIDTH] = counter[i];
        wire pulse;

        localparam nsync = 4;
        reg [nsync-1:0] signal_r = 0;
        wire signal_wide = |signal_r;
        wire valid_signal = signal[i] & ~signal_wide;

        always @(posedge frontend_clk)
            signal_r <= {signal_r, valid_signal};

        xpm_cdc_pulse cdc_inst (
            .src_pulse(signal_wide), .src_rst(frontend_rst), .src_clk(frontend_clk),
            .dest_pulse(pulse), .dest_rst(rst), .dest_clk(clk));

        ADDMACC_MACRO #(
            .LATENCY(2),
            .WIDTH_PREADD(2),
            .WIDTH_PRODUCT(48)
        ) counter_inst (
            .LOAD(load[i]), .LOAD_DATA(0),
            .MULTIPLIER(1), .PREADD1({1'b0, pulse}), .PREADD2(0),
            .RST(rst), .CE(1), .CLK(clk), .CARRYIN(0),
            .PRODUCT(counter[i])
        );

    end endgenerate

endmodule
