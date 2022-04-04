`timescale 1ns / 1ps

module event_counter #(
    NCOUNTERS = 3,
    WIDTH = 48
)(
    input wire clk, rst,
    input wire [NCOUNTERS-1:0] signal, load,
    output wire [(NCOUNTERS*WIDTH)-1:0] counters
);

    wire [WIDTH-1:0] counter [NCOUNTERS-1:0];

    genvar i;
    generate for (i = 0; i < NCOUNTERS; i = i + 1) begin

        assign counters[i*WIDTH +: WIDTH] = counter[i];

        ADDMACC_MACRO #(
            .LATENCY(2),
            .WIDTH_PREADD(2),
            .WIDTH_PRODUCT(48)
        ) counter_inst (
            .LOAD(load[i]), .LOAD_DATA(0),
            .MULTIPLIER(1), .PREADD1({1'b0, signal[i]}), .PREADD2(0),
            .RST(rst), .CE(1), .CLK(clk), .CARRYIN(0),
            .PRODUCT(counter[i])
        );

    end endgenerate

endmodule
