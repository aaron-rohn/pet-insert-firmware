`timescale 1ns / 1ps

module frontend #(
    NCH        = 10, 
    DATA_WIDTH = 128,
    LINES      = 3,

    // 115MHz system clock
    CLK_PER_TT = 17'd114_998
)(
    output wire config_spi_ncs,
    input wire [3:0] module_id,

    // timing front, timing rear, A-D front, A-D rear
    input wire [NCH - 1:0] block1,
    input wire [NCH - 1:0] block2,
    input wire [NCH - 1:0] block3,
    input wire [NCH - 1:0] block4,

    // High speed interface
    
    // 115MHz input clock from backend
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

    genvar i;
    assign config_spi_ncs = 1;

    /*
    * Instantiation of IO buffers and DDR
    */

    // System clock input
    wire sys_clk_in;
    IBUFGDS sys_clk_inst  (.I(sys_clk_p), .IB(sys_clk_n), .O(sys_clk_in));

    // Reset generation and transfer back to sys_clk_in domain
    wire sys_clk, ub_rst, tt_rst, pll_rst;

    reg full_rst = 0;
    always @ (posedge sys_clk) full_rst <= ub_rst | tt_rst;

    xpm_cdc_pulse #(.RST_USED(0)) pll_rst_inst (
        .src_pulse(ub_rst), .src_clk(sys_clk),
        .dest_pulse(pll_rst), .dest_clk(sys_clk_in)
    );

    wire clk_frontend, clk_frontend_fb;
    PLLE2_BASE #(
        .BANDWIDTH("HIGH"),
        .CLKIN1_PERIOD(8.696), // 115MHz
        .CLKFBOUT_MULT(12),
        .CLKOUT0_DIVIDE(3),
        .CLKOUT1_DIVIDE(12)
    ) clk_frontend_inst (
        .CLKIN1(sys_clk_in),
        .CLKFBIN(clk_frontend_fb),
        .CLKFBOUT(clk_frontend_fb),
        .CLKOUT0(clk_frontend),
        .CLKOUT1(sys_clk),
        .RST(pll_rst),
        .PWRDWN(1'b0)
    );

    // frontend clock is 460MHz -> TDC LSB is 1.087ns
    // 1 / 460e6 / 2

    // Control data input
    wire sys_ctrl_ddr, sys_ctrl;
    IBUFDS  sys_ctrl_inst (.I(sys_ctrl_p), .IB(sys_ctrl_n), .O(sys_ctrl_ddr));
    IDDR #(.DDR_CLK_EDGE("SAME_EDGE")) sys_ctrl_iddr_inst (
        .Q1(), .Q2(sys_ctrl), 
        .D(sys_ctrl_ddr), 
        .C(sys_clk), .CE(1),
        .S(), .R(ub_rst)
    );

    // High speed data clock output
    wire data_clk_ddr;
    ODDR data_clk_oddr (.D1(1'b1), .D2(1'b0), .CE(1'b1), .C(sys_clk), .S(), .R(ub_rst), .Q(data_clk_ddr));
    OBUFDS data_clk_obuf (.I(data_clk_ddr), .O(data_clk_p), .OB(data_clk_n));

    // High speed data output
    wire [LINES-1:0] data_out;
    generate for (i = 0; i < LINES; i = i + 1) begin: data_inst_gen

        wire data_ddr_out;
        ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) data_ddr_inst (
            .D1(data_out[i]), .D2(data_out[i]),
            .CE(1'b1), .C(sys_clk),
            .S(), .R(ub_rst),
            .Q(data_ddr_out)
        );

        OBUFDS data_inst (.I(data_ddr_out), .O(data_p[i]), .OB(data_n[i]));
    end endgenerate

    // Receive data and reset from the backend

    wire [31:0] rx_data_in, cmd_data_in;
    wire rx_valid_in, cmd_valid_in, cmd_ready_in;

    data_rx #(.LENGTH(32), .LINES(1)) high_speed_rx (
        .clk(sys_clk),
        .rst(ub_rst),
        .d(sys_ctrl),
        .rx_err(),
        .valid(rx_valid_in),
        .data(rx_data_in)
    );

    // Split reset signals from data to microblaze

    rst_controller_frontend
    rst_controller_inst (
        .clk(sys_clk), .rst(ub_rst), .rst_out(tt_rst),
        .data_in(rx_data_in), .valid_in(rx_valid_in),
        .data(cmd_data_in), .valid(cmd_valid_in), .ready(cmd_ready_in)
    );

    // Time tag counter
    
    wire [16:0] counter;
    wire [47:0] period;
    wire period_done;

    wire tt_ready, tt_valid, stall;
    wire [DATA_WIDTH-1:0] tt_data;

    time_counter_iserdes #(
        .CLK_PER_TT(CLK_PER_TT)
    ) time_tag_inst (
        .clk(sys_clk), .rst(full_rst), .module_id(module_id),
        .valid(tt_valid), .ready(tt_ready), .tt(tt_data), .stall(stall),
        .counter(counter), .period(period), .period_done(period_done)
    );

    // microblaze instance, FSL and GPIO interfaces

    wire cmd_ready, cmd_valid;
    wire [31:0] cmd_data_out;

    // input gpio bank
    wire [31:0] gpio0 = {28'b0, module_id};

    //output gpio bank
    wire [31:0] gpio1;
    wire [1:0] sgl_blk_select = gpio1[0 +:  2];

    // gpio[2] used to be disable_tt_stall

    // 0 - normal operation, input signals are processed
    // 1 - input signals are disabled and the detector frontend is held in reset
    wire disable_inputs = gpio1[3];

    // reset everything except the ublaze
    assign ub_rst = gpio1[4];

    wire [47:0] sgl_rates [3:0];
    wire [47:0] sgl_rate = sgl_rates[sgl_blk_select];

    low_speed_interfaces_wrapper ublaze_inst (
        .Clk(sys_clk),
        .rst(ub_rst),

        .gpio0_tri_i(gpio0),
        .gpio1_tri_o(gpio1),
        .gpio2_tri_i(sgl_rate[0 +: 32]),
        .gpio3_tri_i(period[0 +: 32]),

        .iic_rtl_0_scl_io(SCL),
        .iic_rtl_0_sda_io(SDA),

        .rxd_tdata(cmd_data_in),
        .rxd_tlast(0),
        .rxd_tready(cmd_ready_in),
        .rxd_tvalid(cmd_valid_in),

        .txd_tdata(cmd_data_out),
        .txd_tlast(),
        .txd_tready(cmd_ready),
        .txd_tvalid(cmd_valid)
    );

    // Package cmd response data for transmission to backend
    // Only the bottom 32 bits are routed back to the workstation
    wire [DATA_WIDTH-1:0] cmd_data = {
        {5{1'b1}},   // Framing bits     5
        1'b0,        // Single ev flag   1
        module_id,   // Module ID        4
        2'b0,        // Block ID         2
        1'b1,        // Command flag     1
        {83{1'b0}},  // Padding          83
        cmd_data_out // Command data     32
    };

    /*
    * Data transmission to backend, both data generated by the detector and
    * status information from the ublaze
    */

    // Manage data generated by the detector and time tags

    wire [3:0] blk_ready, blk_valid;
    wire [DATA_WIDTH-1:0] blk_data [3:0];

    wire fifo_full, fifo_wrst_busy, fifo_rrst_busy;
    wire fifo_ready = ~(fifo_full | fifo_wrst_busy);
    wire fifo_valid = |{tt_valid, cmd_valid, blk_valid};

    wire [DATA_WIDTH-1:0] fifo_data = tt_valid     ? tt_data     :
                                      cmd_valid    ? cmd_data    : 
                                      blk_valid[0] ? blk_data[0] :
                                      blk_valid[1] ? blk_data[1] :
                                      blk_valid[2] ? blk_data[2] :
                                      blk_valid[3] ? blk_data[3] : 0;

    assign tt_ready     = fifo_ready;
    assign cmd_ready    = tt_ready     & ~tt_valid;
    assign blk_ready[0] = cmd_ready    & ~cmd_valid;
    assign blk_ready[1] = blk_ready[0] & ~blk_valid[0];
    assign blk_ready[2] = blk_ready[1] & ~blk_valid[1];
    assign blk_ready[3] = blk_ready[2] & ~blk_valid[2];

    wire fifo_empty, tx_ready;
    wire tx_valid = ~(fifo_empty | fifo_rrst_busy);
    wire [DATA_WIDTH-1:0] tx_data;

    xpm_fifo_sync #(
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .WRITE_DATA_WIDTH(DATA_WIDTH),
        .READ_DATA_WIDTH(DATA_WIDTH)
    ) fifo_mux_inst (
        .wr_clk(sys_clk),
        .rst(full_rst),
        .wr_rst_busy(fifo_wrst_busy),
        .rd_rst_busy(fifo_rrst_busy),

        .full(fifo_full),
        .din(fifo_data),
        .wr_en(fifo_valid & fifo_ready),
    
        .empty(fifo_empty),
        .dout(tx_data),
        .rd_en(tx_valid & tx_ready)
    );

    data_tx high_speed_tx (
        .clk(sys_clk),
        .rst(full_rst),
        .valid(tx_valid),
        .ready(tx_ready),
        .data_in(tx_data),
        .d(data_out)
    );

    /*
    * Detector logic
    */
    
    wire [3:0] stall_blk;
    assign stall = |stall_blk;

    wire [NCH-1:0] blocks [3:0];
    assign blocks[0] = block1;
    assign blocks[1] = block2;
    assign blocks[2] = block3;
    assign blocks[3] = block4;

    generate for (i = 0; i < 4; i = i + 1) begin
        wire [1:0] blk_idx = i;
        detector_iserdes det_inst (
            .sample_clk(clk_frontend),
            .clk(sys_clk),
            .rst(full_rst | disable_inputs),
            .signal(blocks[i]),
            .block_id({module_id, blk_idx}),
            .counter(counter),
            .period_done(period_done),
            .data_ready(blk_ready[i]),
            .data_valid(blk_valid[i]),
            .data_out(blk_data[i]),
            .stall(stall_blk[i]),
            .nsingles(sgl_rates[i])
        );
    end endgenerate

endmodule
