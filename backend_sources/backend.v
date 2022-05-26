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
    output reg [2:0] TC = 0,    // Tx data channel to gigex
    input  wire [7:0] nTF,      // Tx fifo full flag from gigex

    // master spi ports
    input wire gigex_spi_cs,
    input wire gigex_spi_sck,
    input wire gigex_spi_mosi,
    output wire gigex_spi_miso
);

    // System clock and reset
    wire sys_clk, soft_rst;

    /*
    * IO Port instantiation
    */

    genvar i, j;

    assign config_spi_ncs = 1;
    
    wire clk_100, sys_rst_ddr, sys_rst;
    IBUFGDS clk_100_inst (.I(clk_100_p), .IB(clk_100_n), .O(clk_100));
    IBUFGDS sys_clk_inst (.I(sys_clk_p), .IB(sys_clk_n), .O(sys_clk));
    IBUFDS sys_rst_inst (.I(sys_rst_p), .IB(sys_rst_n), .O(sys_rst_ddr));

    IDDR #(.DDR_CLK_EDGE("SAME_EDGE")) sys_rst_iddr_inst (
        .Q1(), .Q2(sys_rst), .D(sys_rst_ddr), .C(sys_clk), .CE(1'b1), .S(), .R(1'b0));

    // create 125MHz ethernet clock
    wire clk_100_fb;
    PLLE2_BASE #(
        .CLKIN1_PERIOD(10),
        .CLKFBOUT_MULT(10),
        .CLKOUT0_DIVIDE(8)
    ) user_hs_clk_inst (
        .CLKIN1(clk_100),
        .CLKFBIN(clk_100_fb),
        .CLKFBOUT(clk_100_fb),
        .CLKOUT0(user_hs_clk),
        .RST(1'b0),
        .PWRDWN(1'b0)
    );

    // Input and output connections to frontend modules
    wire [NMODULES-1:0] m_clk_ddr, m_ctrl_ddr, m_ctrl, m_data_clk;
    wire [LINES*NMODULES-1:0] m_data_in, m_data_in_ddr;
    generate
        for (i = 0; i < NMODULES; i = i + 1) begin: frontend_port_inst
            // Clock output to frontend (don't reset)
            ODDR m_clk_oddr_inst (
                .D1(1'b1), .D2(1'b0), .CE(1'b1), .C(sys_clk), 
                .S(), .R(1'b0), .Q(m_clk_ddr[i]));
            OBUFTDS m1_clk_obuf_inst (.T(~m_en[i]), .I(m_clk_ddr[i]), .O(m_clk_p[i]), .OB(m_clk_n[i]));

            // Control output to frontend
            ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) m_ctrl_oddr_inst (
                .D1(m_ctrl[i]), .D2(m_ctrl[i]), .CE(1'b1), .C(sys_clk),
                .S(), .R(1'b0), .Q(m_ctrl_ddr[i]));
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
    */

    localparam CMD_LEN = 32;
    wire [31:0] gpio_i, gpio_o;

    assign soft_rst         = gpio_o[0];
    assign status_fpga      = gpio_o[1];
    assign status_network   = gpio_o[2];
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
        .clk(sys_clk),
        .rst(1'b0),

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
    */

    // receive sync/reset code from sync board
    localparam RST_CODE = 4'b1100; // IDLE_CODE = 4'b1010;
    reg [3:0] sys_rst_reg = 0;
    wire sys_rst_valid = (sys_rst_reg == RST_CODE);
    always @ (posedge sys_clk) sys_rst_reg <= {sys_rst_reg, sys_rst};

    // Per-module reset controller and tx controller
    generate for (i = 0; i < NMODULES; i = i + 1) begin: tx_side_inst

        wire tx_ready, tx_valid;
        wire [CMD_LEN-1:0] tx_data;

        rst_controller m_rst_inst (
            .clk(sys_clk),
            .rst(sys_rst_valid),

            .cmd_in_valid(ub_m_cmd_valid[i]),
            .cmd_in_ready(ub_m_cmd_ready[i]),
            .cmd_in(ub_m_cmd_data[i]),

            .cmd_out_ready(tx_ready),
            .cmd_out_valid(tx_valid),
            .cmd_out(tx_data));

        data_tx #(.LENGTH(CMD_LEN), .LINES(1)) m_tx_inst (
            .clk(sys_clk),
            .rst(sys_rst_valid),
            .idle(),

            .valid(tx_valid),
            .ready(tx_ready),
            .data_in(tx_data),

            .d(m_ctrl[i]));

    end endgenerate

    /*
    * Receiver side components
    */

    // Multiplex ready, valid, and data signals for 4 blocks

    wire [NMODULES-1:0] m_data_ready, m_data_valid;
    wire [LENGTH-1:0] m_data_out [NMODULES-1:0];

    wire m_ready;
    wire m_valid = |m_data_valid;

    assign m_data_ready[0] = m_ready;
    assign m_data_ready[1] = m_data_ready[0] & ~m_data_valid[0];
    assign m_data_ready[2] = m_data_ready[1] & ~m_data_valid[1];
    assign m_data_ready[3] = m_data_ready[2] & ~m_data_valid[2];

    wire [LENGTH-1:0] m_data =
        m_data_valid[0] ? m_data_out[0] :
        m_data_valid[1] ? m_data_out[1] :
        m_data_valid[2] ? m_data_out[2] :
        m_data_valid[3] ? m_data_out[3] : {LENGTH{1'b0}};

    // Per-module rx controller and fifos
    generate for (i = 0; i < NMODULES; i = i + 1) begin: rx_side_inst

        // Instantiate receiver for control and data from frontend
        // as well as async fifo to get data to system clock domain

        wire m_rx_valid;
        wire [LENGTH-1:0] m_rx_data;

        data_rx m_data_rx (
            .clk(m_data_clk[i]),
            .rst(1'b0),
            .d(m_data_in[i*LINES +: LINES]),
            .rx_err(),
            .valid(m_rx_valid),
            .data(m_rx_data));

        wire emp;
        wire rd = ~emp;
        wire [LENGTH-1:0] all_data;
        fifo_async rx_all_inst (
            .din(m_rx_data), .wr_en(m_rx_valid),
            .empty(emp), .dout(all_data), .rd_en(rd),
            .wr_clk(m_data_clk[i]), .rd_clk(sys_clk));

        // flags to identify the type of the next event (sgl, tt, cmd)

        localparam SGL_FLAG_OFFSET = 122, CMD_FLAG_OFFSET = 115;
        wire sgl_flag = all_data[SGL_FLAG_OFFSET];
        wire cmd_flag = all_data[CMD_FLAG_OFFSET];
        wire data_isnt_cmd = sgl_flag | ~cmd_flag;
        wire data_is_cmd   = cmd_flag & ~sgl_flag;
        wire data_is_tt    = ~(cmd_flag | sgl_flag);

        // Create counters for singles, timetags, and commands

        wire [EV_COUNTER_CHAN-1:0] counter_signals =
            {data_is_cmd, data_is_tt, sgl_flag} & {EV_COUNTER_CHAN{rd}};

        event_counter counters_inst (
            .clk(sys_clk), .rst(1'b0),
            .signal(counter_signals), .load(channel_load_all[i]),
            .counters({event_counters[i][2],
                       event_counters[i][1],
                       event_counters[i][0]}));

        // Fifo for singles and timetags, going to gigex

        wire data_empty;
        wire dwr = rd & data_isnt_cmd;
        assign m_data_valid[i] = ~data_empty;

        fifo_sync rx_data_fifo (
            .clk(sys_clk), .din(all_data), .wr_en(dwr),
            .empty(data_empty), .dout(m_data_out[i]),
            .rd_en(m_data_valid[i] & m_data_ready[i]));

        // Fifo for commands, going back to microblaze

        wire cmd_empty;
        wire cwr = rd & data_is_cmd;
        assign m_ub_cmd_valid[i] = ~cmd_empty;

        fifo_sync rx_cmd_fifo (
            .clk(sys_clk), .din(all_data), .wr_en(cwr),
            .empty(cmd_empty), .dout(m_ub_cmd_data[i]),
            .rd_en(m_ub_cmd_valid[i] & m_ub_cmd_ready[i]));

    end endgenerate

    /*
    * Ethernet tx interface
    */

    // Flip byte ordering so that MSB is sent first
    wire [LENGTH-1:0] m_data_flip;
    generate for (i = 0; i < 128/8; i = i + 1) begin
        assign m_data_flip[(i*8) +: 8] = m_data[127-(i*8) -: 8];
    end endgenerate

    wire rx_full;
    assign m_ready = ~rx_full;
    wire valid, ready, rx_emp;

    xpm_fifo_async #(
        .FIFO_READ_LATENCY(0),
        .READ_MODE("fwft"),
        .FIFO_WRITE_DEPTH(16),
        .WRITE_DATA_WIDTH(128),
        .READ_DATA_WIDTH(8)
    ) eth_fifo_inst (
        .rst(1'b0),
        .din(m_data_flip),
        .wr_en(m_ready & m_valid),
        .wr_clk(sys_clk),
        .full(rx_full),
        .dout(D),
        .rd_en(~nTx),
        .rd_clk(~user_hs_clk),
        .empty(rx_emp));

    reg nTF1 = 0, nTF2 = 0;
    assign ready = nTF | nTF2;
    assign valid = ~rx_emp;
    assign nTx = ~(valid & ready);

    // nTx can be asserted for 2 clocks after nTF falls
    always @ (negedge user_hs_clk) begin
        nTF1 <= nTF[0];
        nTF2 <= nTF1;
    end

endmodule
