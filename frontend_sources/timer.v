module timer #(
    parameter COUNTER = 17
) (
    input wire clk,
    input wire rst,
    input wire [COUNTER-1:0] counter_max,
    output reg  [COUNTER-1:0] counter = 0,
    output wire [47:0] period,
    output reg period_done
);
    reg [COUNTER-1:0] counter_max_r = 0;
    reg period_done_a = 0, period_done_b = 0, period_done_c = 0;
    wire [COUNTER-1:0] counter_a;

    ADDMACC_MACRO #(
        .LATENCY(2)
    ) counter_inst (
        .LOAD(rst | period_done_a), .LOAD_DATA(0),
        .MULTIPLIER(1), .PREADD1(1), .PREADD2(0),
        .RST(0), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT(counter_a)
    );
    
    ADDMACC_MACRO #(.LATENCY(2)) period_inst (
        .LOAD(rst), .LOAD_DATA(0),
        .MULTIPLIER(1), .PREADD1({23'b0, period_done_a}), .PREADD2(0),
        .RST(0), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT(period)
    );

    always @ (posedge clk) begin
        counter_max_r   <= counter_max;
        period_done_a   <= (counter_a == counter_max_r);
        period_done_b   <= period_done_a;
        period_done_c   <= period_done_b;
        period_done     <= period_done_c;
        counter         <= counter_a;
    end
endmodule
