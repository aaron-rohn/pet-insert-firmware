/*
* This module counts the number of clocks which the input spends in a high
* state, and filters the input so that spurious trailing pulses are included
* in a single event.
*/

module energy_counter (
    input wire clk,
    input wire rst,
    input wire start,
    input wire signal_rising,
    input wire signal_falling,

    output reg active = 0,
    output wire [11:0] energy
);
    localparam HISTORY_BITS = 16;
    reg [HISTORY_BITS - 1 : 0] history = 0;
    reg signal_falling_r = 0;

    wire either_edge    = signal_rising | signal_falling;
    wire signal_change  = signal_falling & ~signal_falling_r;
    wire rst_cnt        = ~active & (start | signal_change);

    ADDMACC_MACRO #(
        .WIDTH_MULTIPLIER(10),
        .WIDTH_PREADD(2),
        .WIDTH_PRODUCT(12),
        .LATENCY(2)
    ) accum_inst (
        .LOAD(rst_cnt), .LOAD_DATA(0),
        .MULTIPLIER(10'd1), .PREADD1({1'b0, signal_rising}), .PREADD2({1'b0, signal_falling}),
        .RST(rst), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT(energy)
    );

    always @ (posedge clk) begin
        signal_falling_r <= signal_falling;

        // Filtering the signal prevents resetting the
        // count for short pulses at the end of an event.
        history <= rst ? 0 : history >> 1;
        history[HISTORY_BITS - 1] <= either_edge;
        active <= either_edge | (|history);
    end

endmodule
