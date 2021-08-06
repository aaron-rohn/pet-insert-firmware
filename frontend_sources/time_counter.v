/*
* A fast counter, used to generate time tags with ~1ns precision
* The lowest bit of the counter is set in the frontend logic based
* on the DDR input when an event is detectred
*/

module time_counter #(
    parameter CRC_BITS          = 5,
    parameter MODULE_ID_BITS    = 4,
    parameter PERIOD_BITS       = 48,
    parameter DATA_BITS         = 128
) (
    input wire clk_frontend,
    input wire clk_backend,
    input wire rst,
    input wire [MODULE_ID_BITS - 1:0] module_id,
    input wire tt_stall,

    output wire tt_valid,
    input wire tt_ready,
    output wire [DATA_BITS - 1:0] tt
);
    localparam PADDING_BITS = DATA_BITS - (CRC_BITS + MODULE_ID_BITS + PERIOD_BITS + 4);
    wire [PERIOD_BITS-1:0] period;
    wire [PERIOD_BITS-1:0] period_rst = rst ? 48'h0 : period;

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
    wire tt_fifo_empty;
    assign tt_valid = ~tt_fifo_empty;

    timer timer_inst (.clk(clk_frontend), .rst(rst), .counter(), .period(period), .period_done(tt_finished));

    /*
    * Time tags will be emitted at the start of each period, after events from
    * the previous period are completed.
    */

    reg [DATA_BITS-1:0] tt_in_latch = 0;
    reg write_waiting = 0, write_waiting_p = 0, tt_fifo_write = 0, tt_fifo_write_p = 0;
    reg rst_rising = 0, rst_p = 0;

    always @ (posedge clk_frontend) begin

        rst_p           <= rst;
        rst_rising      <= rst & ~rst_p;

        // This signal goes high with tt_finished and stays high with stall
        write_waiting_p <= write_waiting;
        write_waiting   <= (write_waiting & tt_stall) | tt_finished;
        tt_fifo_write   <= (write_waiting_p & ~write_waiting);
        tt_in_latch     <= (tt_finished | rst) ? tt_in : tt_in_latch;
    end
    
    xpm_fifo_async #(
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .WRITE_DATA_WIDTH(128),
        .READ_DATA_WIDTH(128)
    ) tt_fifo (
        .full(),
        .din(tt_in_latch),
        .wr_en(tt_fifo_write | rst_rising),
        .wr_clk(clk_frontend),
    
        .empty(tt_fifo_empty),
        .dout(tt),
        .rd_en(tt_ready & tt_valid),
        .rd_clk(clk_backend)
    );

endmodule
