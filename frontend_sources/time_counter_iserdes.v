
module time_counter_iserdes #(
    parameter CRC_BITS          = 5,
    parameter MODULE_ID_BITS    = 4,
    parameter PERIOD_BITS       = 48,
    parameter DATA_BITS         = 128,
    parameter COUNTER           = 17
) (
    input wire clk,
    input wire rst,
    input wire [MODULE_ID_BITS - 1:0] module_id,
    input wire stall,

    output wire valid,
    input wire ready,
    output reg [DATA_BITS - 1:0] tt = 0
);
    reg rst_r = 0;

    localparam PADDING_BITS = DATA_BITS - (CRC_BITS + MODULE_ID_BITS + PERIOD_BITS + 4);
    wire [PERIOD_BITS-1:0] period;
    wire [PERIOD_BITS-1:0] period_rst = rst_r ? 48'h0 : period;

    wire [DATA_BITS - 1:0] tt_in = {
        {CRC_BITS{1'b1}},       // Framing bits         5
        1'b0,                   // Single event flag    1
        module_id,              // Module ID            4
        {2{1'b0}},              // Block ID             2
        1'b0,                   // Command flag         1
        {PADDING_BITS{1'b0}},   // Zeros                67
        period_rst              // Time tag counter     48
    };

    wire tt_finished;

    timer #(.COUNTER(COUNTER)) timer_inst (
        .clk(clk), .rst(rst_r),
        .counter(), .period(period),
        .period_done(tt_finished)
    );

    /*
    * Time tags will be emitted at the start of each period, after events from
    * the previous period are completed.
    */

    reg tt_wait = 0;
    reg rst_rising = 0, rst_p = 0;

    assign valid = tt_wait & ~stall;

    always @ (posedge clk) begin

        rst_r           <= rst;
        rst_p           <= rst_r;
        rst_rising      <= rst_r & ~rst_p;

        // This signal goes high with tt_finished and stays high until stall is low and ready is high
        tt_wait <= tt_finished | (tt_wait & (stall | ~ready));

        tt <= (tt_finished | rst_r) ? tt_in : tt;
    end
endmodule
