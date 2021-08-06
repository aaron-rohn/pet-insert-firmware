`timescale 1ns / 1ps
module macc_test();

    reg rst = 0;
    reg clk = 0;
    always #5 clk <= ~clk;
    
    wire carry;
    wire [4:0] counter_a;
    wire [47:0] period;
    
    reg carry_r = 0, new_period = 0;
    
    always @ (posedge clk) begin
        carry_r <= carry;
        new_period <= carry_r ^ carry;
    end
    
    ADDMACC_MACRO #(
        .WIDTH_MULTIPLIER(4),
        .WIDTH_PREADD(2),
        .WIDTH_PRODUCT(6),
        .LATENCY(1)
    ) counter_inst (
        .LOAD(rst), .LOAD_DATA(0),
        .MULTIPLIER(17'd1), .PREADD1(2'd1), .PREADD2(2'd0),
        .RST(0), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT({carry, counter_a})
    );
    
    ADDMACC_MACRO #(
        .LATENCY(1)
    ) period_inst (
        .LOAD(rst), .LOAD_DATA(0),
        .MULTIPLIER(18'd1), .PREADD1(24'd1), .PREADD2(24'd0),
        .RST(0), .CE(new_period), .CLK(clk), .CARRYIN(0),
        .PRODUCT(period)
    );
    
    initial begin
        #100 rst <= 1'b1;
        #10  rst <= 1'b0; 
        #1000 $stop();
    end
    
endmodule
