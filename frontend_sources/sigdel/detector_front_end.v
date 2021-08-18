module detector_front_end #(
    parameter CRC_BITS     = 5,
    parameter ID_BITS      = 6,
    parameter DATA_BITS    = 128,
    parameter HISTORY_BITS = 16,

    parameter NCHAN_ENERGY = 8,
    parameter NCHAN_TOTAL  = 10
)(
    input wire clk_frontend,
    input wire clk_backend,
    input wire rst,
    input wire [ID_BITS - 1:0] block_id,
    input wire [NCHAN_TOTAL - 1:0] signal_rising,
    input wire [NCHAN_TOTAL - 1:0] signal_falling,
    output wire stall,

    input wire data_ready,
    output wire data_valid,
    output wire [DATA_BITS - 1:0] data_out,
    output wire [47:0] period_out
);
    // Pipeline the inputs to ease timing
    reg [NCHAN_TOTAL-1:0] signal_rising_r = 0, signal_falling_r = 0;
    always @ (posedge clk_frontend) begin
        signal_rising_r <= signal_rising;
        signal_falling_r <= signal_falling;
    end

    // Break out the bus into timing and energy signals
    localparam NCHAN_TIMING = NCHAN_TOTAL - NCHAN_ENERGY;
    wire [NCHAN_TIMING - 1:0] timing_rising  = signal_rising_r[1:0];
    wire [NCHAN_TIMING - 1:0] timing_falling = signal_falling_r[1:0];
    wire [NCHAN_ENERGY - 1:0] energy_signal_rising  = signal_rising_r[9:2];
    wire [NCHAN_ENERGY - 1:0] energy_signal_falling = signal_falling_r[9:2];

    localparam COUNTER_BITS = 12;
    wire [NCHAN_ENERGY*COUNTER_BITS - 1:0] energy;
    wire [19:0] start_time;

    // Build the packet containing the event information that will be sent out
    wire [DATA_BITS - 1:0] data_in = {
        {CRC_BITS{1'b1}},   // Framing bits,         5
        1'b1,               // Single event flag,    1
        block_id,           // Identifier,           6
        energy,             // Energy data,         96
        start_time          // Timing data,         20
    };

    wire start, done;
    wire [NCHAN_ENERGY - 1:0] active;
    wire [47:0] start_period;

    // Fanout and placement of these seems to cause issues, so force pipelining
    (* dont_touch = "true" *) reg done_data = 0, done_period = 0;
    always @ (posedge clk_frontend) begin
        done_data <= done;
        done_period <= done;
    end

    // latches time tag and frames event
    block_coordinator coordinator (
        .clk(clk_frontend),
        .rst(rst),
        .timing_rising(|timing_rising),
        .timing_falling(|timing_falling),
        .active_any(|active),
        .active_all(&active),
        .start(start),
        .done(done),
        .stall(stall),
        .start_time(start_time),
        .start_period(start_period)
    );

    wire fifo_empty;
    assign data_valid = ~fifo_empty;

    // interfaces fast frontend domain to backend
    xpm_fifo_async #(
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .WRITE_DATA_WIDTH(128),
        .READ_DATA_WIDTH(128)
    ) fifo_data (
        .full(),
        .din(data_in),
        .wr_en(done_data),
        .wr_clk(clk_frontend),
    
        .empty(fifo_empty),
        .dout(data_out),
        .rd_en(data_valid & data_ready),
        .rd_clk(clk_backend)
    );

    // Indicate at the output which time tag period the most recent event
    // began in, so that time tags can be emitted at the appropriate point
    
    xpm_fifo_async #(
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .WRITE_DATA_WIDTH(128),
        .READ_DATA_WIDTH(128)
    ) fifo_period (
        .full(),
        .din(start_period),
        .wr_en(done_period),
        .wr_clk(clk_frontend),
    
        .empty(),
        .dout(period_out),
        .rd_en(data_valid & data_ready),
        .rd_clk(clk_backend)
    );

    genvar i;
    generate for (i = 0; i < NCHAN_ENERGY; i = i + 1) begin: counter_gen
        energy_counter energy_counter_inst (
            .clk(clk_frontend), .rst(rst),
            .start(start),
            .signal_rising(energy_signal_rising[i]),
            .signal_falling(energy_signal_falling[i]),
            .active(active[i]),
            .energy(energy[i*COUNTER_BITS +: COUNTER_BITS])
        );
    end endgenerate
endmodule
