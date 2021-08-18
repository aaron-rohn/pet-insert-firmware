`timescale 1ns / 1ps

module frontend #(
    NBLOCK         = 4, 
    MODULE_ID_BITS = 4,
    NCHAN_TOTAL    = 10, 
    TIME_BITS      = 20,
    CRC_BITS       = 5,
    DATA_WIDTH     = 128,
    LINES          = 3
)(
    output wire config_spi_ncs,
    input wire [MODULE_ID_BITS - 1:0] module_id,

    // timing front, timing rear, A-D front, A-D rear
    input wire [NCHAN_TOTAL - 1:0] block1,
    input wire [NCHAN_TOTAL - 1:0] block2,
    input wire [NCHAN_TOTAL - 1:0] block3,
    input wire [NCHAN_TOTAL - 1:0] block4,

    // High speed interface
    
    // 100MHz input clock from backend
    input wire sys_clk_p,
    input wire sys_clk_n,
    
    input wire sys_ctrl_p,
    input wire sys_ctrl_n,

    output wire data_clk_p,
    output wire data_clk_n,

    output wire [LINES-1:0] data_p,
    output wire [LINES-1:0] data_n,

    // Low speed interfaces
    
    inout wire SDA,
    inout wire SCL
);

    /*
    * Instantiation of IO buffers and DDR
    */

    assign config_spi_ncs = 1;
    wire sys_clk, sys_ctrl_ddr, sys_ctrl, sys_rst, data_clk_ddr;

    // System clock input
    IBUFGDS sys_clk_inst  (.I(sys_clk_p), .IB(sys_clk_n), .O(sys_clk));

    // Generate frontend clock
    wire clk_frontend, clk_frontend_fb, clk_frontend_out;
    PLLE2_BASE #(.CLKFBOUT_MULT(12), .CLKOUT0_DIVIDE(3), .CLKIN1_PERIOD(10)) clk_frontend_inst (
        .CLKIN1(sys_clk), .CLKOUT0(clk_frontend_out),
        .CLKFBIN(clk_frontend_fb), .CLKFBOUT(clk_frontend_fb),
        .RST(1'b0), .LOCKED()
    );
    IBUFG clk_frontend_buf_inst (.I(clk_frontend_out), .O(clk_frontend));
    
    // Control data input
    IBUFDS  sys_ctrl_inst (.I(sys_ctrl_p), .IB(sys_ctrl_n), .O(sys_ctrl_ddr));
    IDDR #(.DDR_CLK_EDGE("SAME_EDGE")) sys_ctrl_iddr_inst (
        .Q1(), .Q2(sys_ctrl), 
        .D(sys_ctrl_ddr), 
        .C(sys_clk), .CE(1),
        .S(), .R(0)
    );

    // High speed data clock output
    ODDR data_clk_oddr (.D1(1'b1), .D2(1'b0), .CE(1'b1), .C(sys_clk), .S(), .R(1'b0), .Q(data_clk_ddr));
    OBUFDS data_clk_obuf (.I(data_clk_ddr), .O(data_clk_p), .OB(data_clk_n));

    // High speed data output
    wire [LINES-1:0] data_out, data_ddr_out;
    genvar i;
    generate for (i = 0; i < LINES; i = i + 1) begin: data_inst_gen
        ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) data_ddr_inst (
            .D1(data_out[i]), .D2(data_out[i]),
            .CE(1'b1), .C(sys_clk),
            .S(), .R(1'b0),
            .Q(data_ddr_out[i])
        );
        OBUFDS data_inst (.I(data_ddr_out[i]), .O(data_p[i]), .OB(data_n[i]));
    end endgenerate

    /*
    // DDR inputs from frontend detectors
    wire [NCHAN_TOTAL - 1:0] block1_rising, block1_falling;
    wire [NCHAN_TOTAL - 1:0] block2_rising, block2_falling;
    wire [NCHAN_TOTAL - 1:0] block3_rising, block3_falling;
    wire [NCHAN_TOTAL - 1:0] block4_rising, block4_falling;

    genvar j;
    generate for (j = 0; j < NCHAN_TOTAL; j = j + 1) begin: chan_gen
        IDDR block1_iddr_inst (
            .C(clk_frontend), .CE(1), .S(), .R(0),
            .D(block1[j]), .Q1(block1_rising[j]), .Q2(block1_falling[j])
        );

        IDDR block2_iddr_inst (
            .C(clk_frontend), .CE(1), .S(), .R(0),
            .D(block2[j]), .Q1(block2_rising[j]), .Q2(block2_falling[j])
        );

        IDDR block3_iddr_inst (
            .C(clk_frontend), .CE(1), .S(), .R(0),
            .D(block3[j]), .Q1(block3_rising[j]), .Q2(block3_falling[j])
        );

        IDDR block4_iddr_inst (
            .C(clk_frontend), .CE(1), .S(), .R(0),
            .D(block4[j]), .Q1(block4_rising[j]), .Q2(block4_falling[j])
        );
    end endgenerate
    */

    // END IO instantiation
    
    /*
    * Control logic, including data rx from backend, reset, and ublaze
    */

    wire [31:0] rx_data_in, cmd_data_in;
    wire rx_valid_in, cmd_valid_in, cmd_ready_in;

    // Receive data and reset from the backend
    data_rx #(.LENGTH(32), .LINES(1)) high_speed_rx (
        .clk(sys_clk),
        .rst(0),
        .d(sys_ctrl),
        .rx_err(),
        .valid(rx_valid_in),
        .data(rx_data_in)
    );

    // Split reset signals from data to microblaze
    rst_controller_frontend rst_controller_inst (
        .clk(sys_clk),
        .data_in(rx_data_in),
        .valid_in(rx_valid_in),
        .data_out(cmd_data_in),
        .valid_out(cmd_valid_in),
        .ready_out(cmd_ready_in),
        .sys_rst(sys_rst)
    );

    wire cmd_ready_out, cmd_valid_out;
    wire [31:0] cmd_data_out, gpio;

    low_speed_interfaces_wrapper ublaze_inst (
        .Clk(sys_clk),
        .rst(sys_rst),
        .gpio_rtl_0_tri_o(gpio),
        .gpio_rtl_1_tri_i(module_id),
        .iic_rtl_0_scl_io(SCL),
        .iic_rtl_0_sda_io(SDA),

        .rxd_tdata(cmd_data_in),
        .rxd_tlast(0),
        .rxd_tready(cmd_ready_in),
        .rxd_tvalid(cmd_valid_in),

        .txd_tdata(cmd_data_out),
        .txd_tlast(),
        .txd_tready(cmd_ready_out),
        .txd_tvalid(cmd_valid_out)
    );

    /*
    * Data transmission to backend, both data generated by the detector and
    * status information from the ublaze
    */

    // Manage data generated by the detector and time tags
    localparam TT = 4;

    reg [3:0] select_rolling;
    wire [3:0] earlier, select;
    wire [4:0] ready, valid;
    wire [DATA_WIDTH-1:0] data [4:0];
    wire [47:0] period [4:0];

    reg [DATA_WIDTH-1:0] block_data;
    wire block_valid = |valid;

    integer k;
    always @ (*) begin
        // Priority encoder of output data
        block_data = 0;
        for (k = 4; k >= 0; k = k - 1) begin
            if (valid[k])
                block_data = data[k];
        end

        // Rolling application of OR to select bus - Does a block with
        // a higher priority have an event waiting?
        select_rolling[0] = 0;
        for (k = 1; k < 4; k = k + 1) begin
            select_rolling[k] = select[k-1] | select_rolling[k-1];
        end
    end

    // Time-tag period is encoded in lowest 48 bits
    assign period[TT] = data[TT][47:0];
    assign ready[TT]  = ~(|select);

    generate for (i = 0; i < 4; i = i + 1) begin: block_mux
        // Does an event preceed the most recent time tag?
        assign earlier[i] = !(period[i] > period[TT]);

        // Does a block contain a valid event, and if there is a time tag
        // waiting does the event preceed it?
        assign select[i] = valid[i] & (~valid[TT] | earlier[i]);

        // A block is not ready if there is a time tag valid, unless the
        // current block is valid and earlier than the time tag. A block
        // is not valid if a higher priority block has an event waiting
        assign ready[i] = (~valid[TT] | (valid[i] & earlier[i])) & ~select_rolling[i];
    end endgenerate

    // Fifo containing time tags and data from detectors
    wire fifo_mux_empty, fifo_mux_ready;
    wire fifo_mux_valid = ~fifo_mux_empty;
    wire [DATA_WIDTH-1:0] fifo_mux_data;
    
    xpm_fifo_sync #(
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .WRITE_DATA_WIDTH(128),
        .READ_DATA_WIDTH(128)
    ) fifo_mux_inst (
        .full(), .sleep(0), .rst(0),
        .din(block_data),
        .wr_en(block_valid),
        .wr_clk(sys_clk),
    
        .empty(fifo_mux_empty),
        .dout(fifo_mux_data),
        .rd_en(fifo_mux_valid & fifo_mux_ready)
    );

    // Multiplex data from detectors and commands from ublaze
    // commands have priority
    wire tx_data_ready, tx_data_valid;
    wire [DATA_WIDTH-1:0] tx_data_out;

    // Only the bottom 32 bits are routed back to the workstation
    wire [DATA_WIDTH-1:0] cmd_data_out_packet = {
        {CRC_BITS{1'b1}},   // Framing bits     5
        1'b0,               // Single ev flag   1
        module_id,          // Module ID        4
        2'b0,               // Block ID         2
        1'b1,               // Command flag     1
        {83{1'b0}},         // Padding          83
        cmd_data_out        // Command data     32
    };

    assign fifo_mux_ready = tx_data_ready & ~cmd_valid_out;
    assign cmd_ready_out  = tx_data_ready;
    assign tx_data_valid  = fifo_mux_valid | cmd_valid_out;
    assign tx_data_out    = cmd_valid_out ? cmd_data_out_packet : fifo_mux_data;

    data_tx high_speed_tx (
        .clk(sys_clk),
        .rst(0),
        .valid(tx_data_valid),
        .ready(tx_data_ready),
        .data_in(tx_data_out),
        .d(data_out)
    );

    /*
    * Fast frontend logic
    */
    
    wire [3:0] stall;

    /*
    time_counter time_tag_inst (
        .clk_frontend(clk_frontend),
        .clk_backend(sys_clk),
        .rst(sys_rst),
        .module_id(module_id),
        .tt_stall(|stall),

        .tt_valid(valid[4]),
        .tt_ready(ready[4]),
        .tt(data[4])
    );
    */

    localparam counter_width = 13;

    time_counter_iserdes #(.COUNTER(counter_width)) time_tag_inst (
        .clk(sys_clk), .rst(sys_rst), .module_id(module_id), .stall(|stall),
        .valid(valid[4]), .ready(ready[4]), .tt(data[4])
    );

    wire [NCHAN_TOTAL*4-1:0] blocks = {block1, block2, block3, block4};
    generate for (i = 0; i < 4; i = i + 1) begin
        wire [NCHAN_TOTAL-1:0] blk = blocks[i*NCHAN_TOTAL +: NCHAN_TOTAL];
        wire [1:0] blk_idx = i;
        detector_iserdes #(.COUNTER(counter_width)) det_inst (
            .sample_clk(clk_frontend),
            .clk(sys_clk),
            .rst(sys_rst),
            .signal(blk),
            .block_id({module_id, blk_idx}),
            .stall(stall[i]),

            .data_ready(ready[i]),
            .data_valid(valid[i]),
            .data_out(data[i]),
            .period_out(period[i])
        );
    end endgenerate

    /*
    // Implement the four frontend readout blocks

    detector_front_end block1_inst (
        .clk_frontend(clk_frontend),
        .clk_backend(sys_clk),
        .rst(sys_rst),
        .block_id({module_id, 2'h0}),
        .signal_rising(block1_rising),
        .signal_falling(block1_falling),
        .stall(stall[0]),

        .data_ready(ready[0]),
        .data_valid(valid[0]),
        .data_out(data[0]),
        .period_out(period[0])
    );

    detector_front_end block2_inst (
        .clk_frontend(clk_frontend),
        .clk_backend(sys_clk),
        .rst(sys_rst),
        .block_id({module_id, 2'h1}),
        .signal_rising(block2_rising),
        .signal_falling(block2_falling),
        .stall(stall[1]),

        .data_ready(ready[1]),
        .data_valid(valid[1]),
        .data_out(data[1]),
        .period_out(period[1])
    );

    detector_front_end block3_inst (
        .clk_frontend(clk_frontend),
        .clk_backend(sys_clk),
        .rst(sys_rst),
        .block_id({module_id, 2'h2}),
        .signal_rising(block3_rising),
        .signal_falling(block3_falling),
        .stall(stall[2]),

        .data_ready(ready[2]),
        .data_valid(valid[2]),
        .data_out(data[2]),
        .period_out(period[2])
    );

    detector_front_end block4_inst (
        .clk_frontend(clk_frontend),
        .clk_backend(sys_clk),
        .rst(sys_rst),
        .block_id({module_id, 2'h3}),
        .signal_rising(block4_rising),
        .signal_falling(block4_falling),
        .stall(stall[3]),

        .data_ready(ready[3]),
        .data_valid(valid[3]),
        .data_out(data[3]),
        .period_out(period[3])
    );
    */

endmodule
