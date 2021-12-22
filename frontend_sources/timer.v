module timer (
    input wire clk,
    input wire rst,
    output reg  [16:0] counter = 0,
    output wire [47:0] period,
    output reg period_done
);
    // 1 ms - subtract 2 clocks for addmacc latency
    localparam clk_per_tt = 17'd99_998;

    reg period_done_a = 0, period_done_b = 0, period_done_c = 0;
    wire [16:0] counter_a;

    ADDMACC_MACRO #(
        .LATENCY(2),
        .WIDTH_PRODUCT(17)
    ) counter_inst (
        .LOAD(rst | period_done_a), .LOAD_DATA(0),
        .MULTIPLIER(1), .PREADD1(1), .PREADD2(0),
        .RST(rst), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT(counter_a)
    );
    
    ADDMACC_MACRO #(
        .LATENCY(2)
    ) period_inst (
        .LOAD(rst), .LOAD_DATA(0),
        .MULTIPLIER(1), .PREADD1({23'b0, period_done_a}), .PREADD2(0),
        .RST(rst), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT(period)
    );

    always @ (posedge clk) begin
        if (rst) begin
            period_done_a   <= 0;
            period_done_b   <= 0;
            period_done_c   <= 0;
            period_done     <= 0;
            counter         <= 0;
        end else begin
            period_done_a   <= (counter_a == clk_per_tt);
            period_done_b   <= period_done_a;
            period_done_c   <= period_done_b;
            period_done     <= period_done_c;
            counter         <= counter_a;
        end
    end
endmodule
