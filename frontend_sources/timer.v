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
    reg carry_p = 0, period_done_a = 0;
    wire [COUNTER-1:0] counter_a;
    reg  [COUNTER-1:0] counter_b = 0;

    ADDMACC_MACRO #(
        .WIDTH_MULTIPLIER(COUNTER-1),
        .WIDTH_PREADD(2),
        .WIDTH_PRODUCT(COUNTER+1),
        .LATENCY(2)
    ) counter_inst (
        .LOAD(rst), .LOAD_DATA(0),
        .MULTIPLIER( {{(COUNTER-2){1'b0}}, 1'b1} ), .PREADD1(2'sd1), .PREADD2(2'sd0),
        .RST(0), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT({carry, counter_a})
    );
    
    ADDMACC_MACRO #(.LATENCY(2)) period_inst (
        .LOAD(rst), .LOAD_DATA(0),
        .MULTIPLIER(18'sd1), .PREADD1(24'sd1), .PREADD2(24'sd0),
        .RST(0), .CE(period_done_a), .CLK(clk), .CARRYIN(0),
        .PRODUCT(period)
    );

    always @ (posedge clk) begin
        carry_p <= carry;
        period_done_a <= carry ^ carry_p;
        period_done   <= period_done_a;

        counter_b     <= counter_a;
        counter       <= counter_b;
    end
endmodule
