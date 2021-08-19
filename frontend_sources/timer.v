module timer #(
    parameter COUNTER = 19
) (
    input wire clk,
    input wire rst,
    output reg  [COUNTER-1:0] counter = 0,
    output wire [47:0] period,
    output reg period_done
);
    /*
    * period_done will go high for one clock when counter rolls over
    */
    wire carry;
    reg carry_p = 0;
    wire period_done_a = carry ^ carry_p;
    reg period_done_b = 0, period_done_c = 0, period_done_d = 0;

    wire [COUNTER-1:0] counter_a;
    reg  [COUNTER-1:0] counter_b = 0, counter_c = 0, counter_d = 0;

    ADDMACC_MACRO #(
        .WIDTH_MULTIPLIER(COUNTER-1),
        .WIDTH_PREADD(2),
        .WIDTH_PRODUCT(COUNTER+1),
        .LATENCY(3)
    ) counter_inst (
        .LOAD(rst), .LOAD_DATA(0),
        .MULTIPLIER( {{(COUNTER-2){1'b0}}, 1'b1} ), .PREADD1(2'sd1), .PREADD2(2'sd0),
        .RST(0), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT({carry, counter_a})
    );
    
    ADDMACC_MACRO #(.LATENCY(3)) period_inst (
        .LOAD(rst), .LOAD_DATA(0),
        .MULTIPLIER(1), .PREADD1({23'b0, period_done_a}), .PREADD2(0),
        .RST(0), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT(period)
    );

    always @ (posedge clk) begin
        carry_p         <= carry;

        period_done_b   <= period_done_a;
        period_done_c   <= period_done_b;
        period_done_d   <= period_done_c;
        period_done     <= period_done_d;

        counter_b       <= counter_a;
        counter_c       <= counter_b;
        counter_d       <= counter_c;
        counter         <= counter_d;
    end
endmodule
