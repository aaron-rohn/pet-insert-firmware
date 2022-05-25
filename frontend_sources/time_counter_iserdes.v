module time_counter_iserdes (
    input wire clk,
    input wire rst,
    input wire [3:0] module_id,

    output wire valid,
    input wire ready,
    output wire [127:0] tt,
    input wire stall,

    output wire [16:0] counter,
    output wire [47:0] period,
    output wire period_done
);
    // 100MHz -> 1ms
    //parameter CLK_PER_TT = 17'd99_998;

    // 125MHz -> 1ms
    parameter CLK_PER_TT = 17'd124_998;

    assign tt = {
        {5{1'b1}}, // Framing bits         5
        1'b0,      // Single event flag    1
        module_id, // Module ID            4
        {2{1'b0}}, // Block ID             2
        1'b0,      // Command flag         1
        67'b0,     // Zeros                67
        period     // Time tag counter     48
    };

    timer #(.CLK_PER_TT(CLK_PER_TT))
    timer_inst (
        .clk(clk), .rst(rst),
        .counter(counter), .period(period),
        .period_done(period_done)
    );

    /*
    * Time tags will be emitted at the start of each period
    */

    reg rst_r = 0;
    wire rst_done = rst_r & ~rst;

    wire valid_ack = valid & ready;

    reg valid_unmask = 0;
    assign valid = valid_unmask & ~stall;

    always @ (posedge clk) begin
        rst_r <= rst;
        valid_unmask <= (valid_unmask | period_done | rst_done) & ~(valid_ack | rst);
    end
endmodule
