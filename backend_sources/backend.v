`timescale 1ns / 1ps

module backend #(
    LINES = 3,
    LENGTH = 128,
    NMODULES = 4
)(
    // Global ports
    
    output wire config_spi_ncs,

    output wire status_fpga,
    output wire status_modules,
    output wire status_network,

    input wire sys_clk_p,
    input wire sys_clk_n,

    input wire sys_rst_p,
    input wire sys_rst_n,
    
    input wire clk_100_p,
    input wire clk_100_n,

    inout wire sda,
    inout wire scl,

    // Module ports
    
    output wire [NMODULES-1:0] m_en,
    
    output wire [NMODULES-1:0] m_clk_p,
    output wire [NMODULES-1:0] m_clk_n,
    
    output wire [NMODULES-1:0] m_ctrl_p,
    output wire [NMODULES-1:0] m_ctrl_n,
    
    input wire [NMODULES-1:0] m_data_clk_p,
    input wire [NMODULES-1:0] m_data_clk_n,
    
    input wire [LINES*NMODULES-1:0] m_data_p,
    input wire [LINES*NMODULES-1:0] m_data_n,
    
    // GigEx ports
    
    output wire user_hs_clk,
    
    input  wire [7:0] Q,        // Rx data from gigex
    input  wire nRx,            // Rx data valid from gigex, active low
    input  wire [2:0] RC,       // Rx data channel from gigex
    output reg [7:0] nRF = 0,   // Rx fifo full flag to gigex, active low
            
    output wire [7:0] D,        // Tx data to gigex
    output wire nTx,            // Tx data valid to gigex
    output wire [2:0] TC,       // Tx data channel to gigex
    input  wire [7:0] nTF,      // Tx fifo full flag from gigex

    // master spi ports
    input wire gigex_spi_cs,
    input wire gigex_spi_sck,
    input wire gigex_spi_mosi,
    output wire gigex_spi_miso
);

    // System clock and reset
    wire clk_100, hard_rst, soft_rst_ub;
    reg soft_rst = 0, soft_rst_ub_r = 0, soft_rst_ub_edge = 0;
    reg [9:0] soft_rst_sr = 0;

    // Only capture the edge of the soft_rst_ub signal
    // Extend any rst event to 10 clocks minimum
    always @(posedge clk_100) begin
        soft_rst_ub_r       <= soft_rst_ub;
        soft_rst_ub_edge    <= soft_rst_ub & ~soft_rst_ub_r;
        soft_rst_sr         <= {soft_rst_sr, soft_rst_ub_edge | hard_rst};
        soft_rst            <= |soft_rst_sr;
    end

    /*
    * IO Port instantiation
    */

    genvar i, j;

    assign config_spi_ncs = 1;
    
    wire sys_rst_ddr, sys_rst;
    IBUFGDS sys_clk_inst (.I(sys_clk_p), .IB(sys_clk_n), .O(clk_100));
    IBUFDS sys_rst_inst (.I(sys_rst_p), .IB(sys_rst_n), .O(sys_rst_ddr));

    IDDR #(.DDR_CLK_EDGE("SAME_EDGE")) sys_rst_iddr_inst (
        .Q1(), .Q2(sys_rst), .D(sys_rst_ddr), .C(clk_100), .CE(1), .S(), .R(soft_rst));

    // Generate 125MHz ethernet clock from system clock
    wire eth_clk, eth_clk_fb;
    PLLE2_BASE #(.CLKFBOUT_MULT(10), .CLKOUT0_DIVIDE(8), .CLKIN1_PERIOD(10)) eth_clk_inst (
        .CLKIN1(clk_100), .CLKOUT0(eth_clk),
        .CLKFBIN(eth_clk_fb), .CLKFBOUT(eth_clk_fb),
        .RST(soft_rst), .LOCKED());

    // Input and output connections to frontend modules
    wire [NMODULES-1:0] m_clk_ddr, m_ctrl_ddr, m_ctrl, m_data_clk;
    wire [LINES*NMODULES-1:0] m_data_in, m_data_in_ddr;
    generate
        for (i = 0; i < NMODULES; i = i + 1) begin: frontend_port_inst
            // Clock output to frontend (don't reset)
            ODDR m_clk_oddr_inst (
                .D1(1'b1), .D2(1'b0), .CE(1'b1), .C(clk_100), 
                .S(), .R(1'b0), .Q(m_clk_ddr[i]));
            OBUFTDS m1_clk_obuf_inst (.T(~m_en[i]), .I(m_clk_ddr[i]), .O(m_clk_p[i]), .OB(m_clk_n[i]));

            // Control output to frontend
            ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) m_ctrl_oddr_inst (
                .D1(m_ctrl[i]), .D2(m_ctrl[i]), .CE(1'b1), .C(clk_100),
                .S(), .R(soft_rst), .Q(m_ctrl_ddr[i]));
            OBUFTDS m_ctrl_obuf_inst (.T(~m_en[i]), .I(m_ctrl_ddr[i]), .O(m_ctrl_p[i]), .OB(m_ctrl_n[i]));    

            // Data clock from frontend
            IBUFGDS m_data_clk_inst (.I(m_data_clk_p[i]), .IB(m_data_clk_n[i]), .O(m_data_clk[i]));

            // Data lines from frontend
            // module 1: 0-2
            // module 2: 3-5
            // module 3: 6-8
            // module 4: 9-11
            for (j = 0; j < LINES; j = j + 1) begin: frontend_data_inst
                IBUFDS m_data_inst (
                    .I(m_data_p[i*LINES+j]), 
                    .IB(m_data_n[i*LINES+j]), 
                    .O(m_data_in_ddr[i*LINES+j]));

                wire falling_edge_data;
                IDDR #(.DDR_CLK_EDGE("SAME_EDGE")) m_data_iddr_inst (
                    .Q1(), .Q2(falling_edge_data), .D(m_data_in_ddr[i*LINES+j]), 
                    .C(m_data_clk[i]), .CE(1'b1), .S(), .R(1'b0));

                // module 2 line 0 (pads D5 and D6) are inverted on the schematic - flip it back to the correct polarity here
                if (i == 2 && j == 0) begin
                    assign m_data_in[i*LINES+j] = ~falling_edge_data;
                end else begin
                    assign m_data_in[i*LINES+j] = falling_edge_data;
                end
            end
        end
    endgenerate

    /*
    * Microblaze instatiation
    * Clocked with 100MHz clock from board
    */

    localparam CMD_LEN = 32;
    wire [31:0] gpio_i, gpio_o;

    assign soft_rst_ub      = gpio_o[0];
    assign status_fpga      = gpio_o[1];
    assign status_network   = gpio_o[2];
    assign hard_rst         = gpio_o[3];
    assign m_en             = gpio_o[7:4];

    assign status_modules   = |m_en;

    // select, read, and reset event, timetag, cmd counters

    localparam EV_COUNTER_WIDTH = 48, EV_COUNTER_CHAN = 3;
    wire [EV_COUNTER_WIDTH-1:0] event_counters [NMODULES-1:0][EV_COUNTER_CHAN-1:0];

    // module_select -> pick a module 0-3 to read
    // channel_select -> pick singles, tt, or cmd rate for the module
    // channel_load_ub -> reset a counter for the selected module
    wire [1:0] module_select  = gpio_o[8  +: 2];
    wire [1:0] channel_select = gpio_o[10 +: 2];
    wire [EV_COUNTER_CHAN-1:0] channel_load_ub = gpio_o[12 +: 3];

    // multiplex the load signal to all 4 modules

    reg [EV_COUNTER_CHAN-1:0] channel_load_all [NMODULES-1:0];

    integer k;
    always @(*) begin
        for (k = 0; k < NMODULES; k = k + 1) begin
            channel_load_all[k] <= (module_select == k) ?
                channel_load_ub : 0;
        end
    end

    // assign the selected counter value to the gpio input
    assign gpio_i =
        event_counters[module_select][channel_select][0 +: 32];


    // nets connecting to and from frontend data

    wire [CMD_LEN-1:0] ub_m_cmd_data [NMODULES-1:0];
    wire [CMD_LEN-1:0] m_ub_cmd_data [NMODULES-1:0];
    wire [NMODULES-1:0] m_ub_cmd_valid, ub_m_cmd_valid, m_ub_cmd_ready, ub_m_cmd_ready;

    // instantiate microblaze

    low_speed_interface_wrapper low_speed_inst (
        .clk(clk_100),
        .rst(hard_rst),

        .gpio_i_tri_i(gpio_i),
        .gpio_o_tri_o(gpio_o),

        .iic_rtl_0_scl_io(scl),
        .iic_rtl_0_sda_io(sda),

        .spi_cs(gigex_spi_cs),
        .spi_sck(gigex_spi_sck),
        .spi_mosi(gigex_spi_mosi),
        .spi_miso(gigex_spi_miso),

        // Module 0
        .m0_in_tdata(m_ub_cmd_data[0]),
        .m0_in_tlast(0),
        .m0_in_tready(m_ub_cmd_ready[0]),
        .m0_in_tvalid(m_ub_cmd_valid[0]),

        .m0_out_tdata(ub_m_cmd_data[0]),
        .m0_out_tlast(),
        .m0_out_tready(ub_m_cmd_ready[0]),
        .m0_out_tvalid(ub_m_cmd_valid[0]),

        // Module 1
        .m1_in_tdata(m_ub_cmd_data[1]),
        .m1_in_tlast(0),
        .m1_in_tready(m_ub_cmd_ready[1]),
        .m1_in_tvalid(m_ub_cmd_valid[1]),

        .m1_out_tdata(ub_m_cmd_data[1]),
        .m1_out_tlast(),
        .m1_out_tready(ub_m_cmd_ready[1]),
        .m1_out_tvalid(ub_m_cmd_valid[1]),

        // Module 2
        .m2_in_tdata(m_ub_cmd_data[2]),
        .m2_in_tlast(0),
        .m2_in_tready(m_ub_cmd_ready[2]),
        .m2_in_tvalid(m_ub_cmd_valid[2]),

        .m2_out_tdata(ub_m_cmd_data[2]),
        .m2_out_tlast(),
        .m2_out_tready(ub_m_cmd_ready[2]),
        .m2_out_tvalid(ub_m_cmd_valid[2]),

        // Module 3
        .m3_in_tdata(m_ub_cmd_data[3]),
        .m3_in_tlast(0),
        .m3_in_tready(m_ub_cmd_ready[3]),
        .m3_in_tvalid(m_ub_cmd_valid[3]),

        .m3_out_tdata(ub_m_cmd_data[3]),
        .m3_out_tlast(),
        .m3_out_tready(ub_m_cmd_ready[3]),
        .m3_out_tvalid(ub_m_cmd_valid[3])
    );

    /*
    * Transmitter side components
    * Reset controller and TX controller
    */

    localparam RST_CODE = 4'b1100; // IDLE_CODE = 4'b1010;
    reg [3:0] sys_rst_reg = 0;
    wire sys_rst_valid = (sys_rst_reg == RST_CODE);
    always @ (posedge clk_100) sys_rst_reg <= {sys_rst_reg, sys_rst};

    // Per-module reset controller and tx controller
    generate for (i = 0; i < NMODULES; i = i + 1) begin: tx_side_inst

        wire tx_ready, tx_valid;
        wire [CMD_LEN-1:0] tx_data;

        rst_controller m_rst_inst (
            .clk(clk_100),
            .rst(soft_rst | sys_rst_valid),

            .cmd_in_valid(ub_m_cmd_valid[i]),
            .cmd_in_ready(ub_m_cmd_ready[i]),
            .cmd_in(ub_m_cmd_data[i]),

            .cmd_out_ready(tx_ready),
            .cmd_out_valid(tx_valid),
            .cmd_out(tx_data));

        data_tx #(.LENGTH(CMD_LEN), .LINES(1)) m_tx_inst (
            .clk(clk_100),
            .rst(soft_rst | sys_rst_valid),
            .idle(),

            .valid(tx_valid),
            .ready(tx_ready),
            .data_in(tx_data),

            .d(m_ctrl[i]));

    end endgenerate

    /*
    * Receiver side components
    * RX controller and fifo
    */

    // Multiplex ready, valid, and data signals for 4 blocks

    wire [NMODULES-1:0] m_data_ready, m_data_valid;
    wire [LENGTH-1:0] m_data_out [NMODULES-1:0];

    wire m_data_mux_ready;
    wire m_data_mux_valid = |m_data_valid;

    assign m_data_ready[0] = m_data_mux_ready;
    assign m_data_ready[1] = m_data_ready[0] & ~m_data_valid[0];
    assign m_data_ready[2] = m_data_ready[1] & ~m_data_valid[1];
    assign m_data_ready[3] = m_data_ready[2] & ~m_data_valid[2];

    wire [LENGTH-1:0] m_data_mux =
        m_data_valid[0] ? m_data_out[0] :
        m_data_valid[1] ? m_data_out[1] :
        m_data_valid[2] ? m_data_out[2] :
        m_data_valid[3] ? m_data_out[3] : {LENGTH{1'b0}};

    // Per-module rx controller and fifos
    generate for (i = 0; i < NMODULES; i = i + 1) begin: rx_side_inst

        wire m_rx_valid;
        wire [LENGTH-1:0] m_rx_data;

        localparam SGL_FLAG_OFFSET = 122, CMD_FLAG_OFFSET = 115;
        wire sgl_flag = m_rx_data[SGL_FLAG_OFFSET];
        wire cmd_flag = m_rx_data[CMD_FLAG_OFFSET];
        wire data_is_cmd = cmd_flag & ~sgl_flag;
        wire data_is_tt  = ~(cmd_flag | sgl_flag);

        // pass-thru the reset signal to the module clock domain

        wire m_soft_rst;
        xpm_cdc_async_rst m_rst_cdc_inst (
            .src_arst(soft_rst), .dest_arst(m_soft_rst),
            .dest_clk(m_data_clk[i]));

        // Instantiate receiver for control and data from frontend

        data_rx m_data_rx (
            .clk(m_data_clk[i]),
            .rst(m_soft_rst),
            .d(m_data_in[i*LINES +: LINES]),
            .rx_err(),
            .valid(m_rx_valid),
            .data(m_rx_data)
        );

        // Create counters for singles, timetags, and commands

        wire [EV_COUNTER_CHAN-1:0] counter_signals =
            {data_is_cmd, data_is_tt, sgl_flag} & {EV_COUNTER_CHAN{m_rx_valid}};

        event_counter counters_inst (
            .frontend_clk(m_data_clk[i]), .clk(clk_100),
            .frontend_rst(m_soft_rst), .rst(soft_rst),
            .signal(counter_signals), .load(channel_load_all[i]),
            .counters({event_counters[i][2],
                       event_counters[i][1],
                       event_counters[i][0]})
        );

        // Since each receiver has its own clock domain, pass data through fifo
        
        // Fifo for singles and timetags, going to gigex

        wire rx_data_fifo_empty, rx_data_rd_rst_busy;
        assign m_data_valid[i] = ~(rx_data_rd_rst_busy | rx_data_fifo_empty);

        xpm_fifo_async #(
            .READ_MODE("fwft"),
            .FIFO_READ_LATENCY(0),
            .WRITE_DATA_WIDTH(128),
            .READ_DATA_WIDTH(128)
        ) rx_data_fifo (
            .rst(m_soft_rst),
            .din(m_rx_data),
            .wr_en(m_rx_valid & ~data_is_cmd),
            .wr_clk(m_data_clk[i]),

            .empty(rx_data_fifo_empty),
            .dout(m_data_out[i]),
            .rd_en(m_data_valid[i] & m_data_ready[i]),
            .rd_clk(clk_100),
            .rd_rst_busy(rx_data_rd_rst_busy)
        );

        // Fifo for commands, going back to microblaze

        wire rx_cmd_fifo_empty, rx_cmd_rd_rst_busy;
        wire [LENGTH-1:0] m_ub_cmd_data_full;
        assign m_ub_cmd_data[i] = m_ub_cmd_data_full[0 +: CMD_LEN];
        assign m_ub_cmd_valid[i] = ~(rx_cmd_fifo_empty | rx_cmd_rd_rst_busy);
        wire m_ub_cmd_ack = m_ub_cmd_valid[i] & m_ub_cmd_ready[i];

        xpm_fifo_async #(
            .READ_MODE("fwft"),
            .FIFO_READ_LATENCY(0),
            .WRITE_DATA_WIDTH(128),
            .READ_DATA_WIDTH(128)
        ) rx_cmd_fifo (
            .rst(m_soft_rst),
            .din(m_rx_data),
            .wr_en(m_rx_valid & data_is_cmd),
            .wr_clk(m_data_clk[i]),

            .empty(rx_cmd_fifo_empty),
            .dout(m_ub_cmd_data_full),
            .rd_en(m_ub_cmd_ack),
            .rd_clk(clk_100),
            .rd_rst_busy(rx_cmd_rd_rst_busy)
        );

    end endgenerate

    /*
    * Ethernet tx interface
    */

    // singles data fifo to gigex 

    wire rx_fifo_full, rx_fifo_wr_rst_busy;
    assign m_data_mux_ready = ~(rx_fifo_full | rx_fifo_wr_rst_busy);

    wire rx_fifo_ready, rx_fifo_empty, rx_fifo_rd_rst_busy;
    wire rx_fifo_valid = ~(rx_fifo_empty | rx_fifo_rd_rst_busy);
    wire [LENGTH-1:0] rx_fifo_data;
    
    xpm_fifo_async #(
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .WRITE_DATA_WIDTH(128),
        .READ_DATA_WIDTH(128)
    ) m_eth_tx_fifo_inst (
        .rst(soft_rst),
        .full(rx_fifo_full),
        .din(m_data_mux),
        .wr_en(m_data_mux_valid),
        .wr_clk(clk_100),
        .wr_rst_busy(rx_fifo_wr_rst_busy),
    
        .empty(rx_fifo_empty),
        .dout(rx_fifo_data),
        .rd_en(rx_fifo_valid & rx_fifo_ready),
        .rd_clk(~eth_clk),
        .rd_rst_busy(rx_fifo_rd_rst_busy)
    );

    // GigEx control signals
    wire byte_out_valid;
    assign nTx = ~byte_out_valid;
    assign user_hs_clk = eth_clk;

    // ethernet tx controller
    ethernet_tx_controller eth_tx (
        .clk(eth_clk),
        .channel_full(~nTF),

        .valid(rx_fifo_valid),
        .ready(rx_fifo_ready),
        .data(rx_fifo_data),

        .byte_out(D),
        .byte_out_valid(byte_out_valid),
        .channel(TC)
    );

endmodule
