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
    
    input  wire [7:0] Q,    // Rx data from gigex
    input  wire nRx,        // Rx data valid from gigex, active low
    input  wire [2:0] RC,   // Rx data channel from gigex
    output wire [7:0] nRF,  // Rx fifo full flag to gigex, active low
            
    output wire [7:0] D,    // Tx data to gigex
    output wire nTx,        // Tx data valid to gigex
    output wire [2:0] TC,   // Tx data channel to gigex
    input  wire [7:0] nTF   // Tx fifo full flag from gigex
);

    genvar i, j;

    /*
    * IO Port instantiation
    */

    assign config_spi_ncs = 1;
    
    wire clk_100, eth_clk, sys_rst_ddr, sys_rst;
    assign eth_clk = clk_100;

    IBUFGDS sys_clk_inst (.I(sys_clk_p), .IB(sys_clk_n), .O(clk_100));
    IBUFDS sys_rst_inst (.I(sys_rst_p), .IB(sys_rst_n), .O(sys_rst_ddr));
    IDDR #(.DDR_CLK_EDGE("SAME_EDGE")) sys_rst_iddr_inst (
        .Q1(), .Q2(sys_rst), .D(sys_rst_ddr), .C(clk_100), .CE(1), .S(), .R(0));

    wire [NMODULES-1:0] m_clk_ddr, m_ctrl_ddr, m_ctrl, m_data_clk;
    wire [LINES*NMODULES-1:0] m_data_in, m_data_in_ddr;

    generate
        for (i = 0; i < NMODULES; i = i + 1) begin: frontend_port_inst
            // Clock output to frontend
            ODDR m_clk_oddr_inst (.D1(1'b1), .D2(1'b0), .CE(1'b1), .C(clk_100), .S(), .R(1'b0), .Q(m_clk_ddr[i]));
            OBUFDS m1_clk_obuf_inst (.I(m_clk_ddr[i]), .O(m_clk_p[i]), .OB(m_clk_n[i]));

            // Control output to frontend
            ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) m_ctrl_oddr_inst (.D1(m_ctrl[i]), .D2(m_ctrl[i]), .CE(1'b1), .C(clk_100), .S(), .R(1'b0), .Q(m_ctrl_ddr[i]));
            OBUFDS m_ctrl_obuf_inst (.I(m_ctrl_ddr[i]), .O(m_ctrl_p[i]), .OB(m_ctrl_n[i]));    

            // Data clock from frontend
            IBUFGDS m_data_clk_inst (.I(m_data_clk_p[i]), .IB(m_data_clk_n[i]), .O(m_data_clk[i]));

            // Data lines from frontend
            // module 1: 0-2
            // module 2: 3-5
            // module 3: 6-8
            // module 4: 9-11
            for (j = 0; j < LINES; j = j + 1) begin: frontend_data_inst
                IBUFDS m_data_inst (.I(m_data_p[i*LINES+j]), .IB(m_data_n[i*LINES+j]), .O(m_data_in_ddr[i*LINES+j]));

                wire falling_edge_data;
                IDDR #(.DDR_CLK_EDGE("SAME_EDGE")) m_data_iddr_inst (
                    .Q1(), .Q2(falling_edge_data), .D(m_data_in_ddr[i*LINES+j]), .C(m_data_clk[i]), .CE(1), .S(), .R(1'b0));

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

    wire [NMODULES-1:0] rx_err, rx_toggling, tx_idle;
    
    wire [31:0] gpio_i;
    assign gpio_i[0 +: NMODULES] = rx_err | ~rx_toggling;
    assign gpio_i[NMODULES +: NMODULES] = tx_idle;
    assign gpio_i[31:(2*NMODULES)] = 0;

    wire [31:0] gpio_o;
    wire soft_rst           = gpio_o[0];
    assign status_fpga      = gpio_o[1];
    assign status_network   = gpio_o[2];
    assign m_en             = gpio_o[7:4];

    assign status_modules   = |m_en;

    wire [(CMD_LEN*NMODULES)-1:0] m_ub_cmd_data, ub_m_cmd_data;
    wire [NMODULES-1:0] m_ub_cmd_valid, ub_m_cmd_valid, m_ub_cmd_ready, ub_m_cmd_ready;
    wire m_ub_interrupt = |m_ub_cmd_valid;

    wire [CMD_LEN-1:0] eth_ub_cmd_data, ub_eth_cmd_data;
    wire eth_ub_cmd_valid, ub_eth_cmd_valid, eth_ub_cmd_ready, ub_eth_cmd_ready;
    
    low_speed_interface_wrapper low_speed_inst (
        .clk(clk_100),
        .rst(0),

        .gpio_i_tri_i(gpio_i),
        .gpio_o_tri_o(gpio_o),
        .iic_rtl_0_scl_io(scl),
        .iic_rtl_0_sda_io(sda),

        // commands from GigEx to ublaze
        .eth_in_tdata(eth_ub_cmd_data),
        .eth_in_tlast(0),
        .eth_in_tready(eth_ub_cmd_ready),
        .eth_in_tvalid(eth_ub_cmd_valid),
        .eth_in_interrupt(eth_ub_cmd_valid),

        // commands from ublaze to GigEx
        .eth_out_tdata(ub_eth_cmd_data),
        .eth_out_tlast(),
        .eth_out_tready(ub_eth_cmd_ready),
        .eth_out_tvalid(ub_eth_cmd_valid),

        // ublaze interface with modules
        .m_in_interrupt(m_ub_interrupt),

        // Module 0
        .m0_in_tdata(m_ub_cmd_data[0 +: CMD_LEN]),
        .m0_in_tlast(0),
        .m0_in_tready(m_ub_cmd_ready[0]),
        .m0_in_tvalid(m_ub_cmd_valid[0]),

        .m0_out_tdata(ub_m_cmd_data[0 +: CMD_LEN]),
        .m0_out_tlast(),
        .m0_out_tready(ub_m_cmd_ready[0]),
        .m0_out_tvalid(ub_m_cmd_valid[0]),

        // Module 1
        .m1_in_tdata(m_ub_cmd_data[CMD_LEN +: CMD_LEN]),
        .m1_in_tlast(0),
        .m1_in_tready(m_ub_cmd_ready[1]),
        .m1_in_tvalid(m_ub_cmd_valid[1]),

        .m1_out_tdata(ub_m_cmd_data[CMD_LEN +: CMD_LEN]),
        .m1_out_tlast(),
        .m1_out_tready(ub_m_cmd_ready[1]),
        .m1_out_tvalid(ub_m_cmd_valid[1]),

        // Module 2
        .m2_in_tdata(m_ub_cmd_data[2*CMD_LEN +: CMD_LEN]),
        .m2_in_tlast(0),
        .m2_in_tready(m_ub_cmd_ready[2]),
        .m2_in_tvalid(m_ub_cmd_valid[2]),

        .m2_out_tdata(ub_m_cmd_data[2*CMD_LEN +: CMD_LEN]),
        .m2_out_tlast(),
        .m2_out_tready(ub_m_cmd_ready[2]),
        .m2_out_tvalid(ub_m_cmd_valid[2]),

        // Module 3
        .m3_in_tdata(m_ub_cmd_data[3*CMD_LEN +: CMD_LEN]),
        .m3_in_tlast(0),
        .m3_in_tready(m_ub_cmd_ready[3]),
        .m3_in_tvalid(m_ub_cmd_valid[3]),

        .m3_out_tdata(ub_m_cmd_data[3*CMD_LEN +: CMD_LEN]),
        .m3_out_tlast(),
        .m3_out_tready(ub_m_cmd_ready[3]),
        .m3_out_tvalid(ub_m_cmd_valid[3])
    );

    /*
    * Transmitter side components
    * Reset controller and TX controller
    */

    localparam CODE_LEN = 4, RST_CODE = 4'b1100;
    reg [CODE_LEN-1:0] sys_rst_reg = 0;
    wire sys_rst_valid = (sys_rst_reg == RST_CODE);
    always @ (posedge clk_100) sys_rst_reg <= {sys_rst_reg, sys_rst};

    // Per-module reset controller and tx controller
    generate
        for (i = 0; i < NMODULES; i = i + 1) begin: tx_side_inst

            wire rst_m_ready, rst_m_valid;
            wire [CMD_LEN-1:0] rst_m_data;

            // Generate rst signals and forward command data to transmitter
            rst_controller m_rst_inst (
                .clk(clk_100),
                .rst(sys_rst_valid),

                .cmd_in_valid(ub_m_cmd_valid[i]),
                .cmd_in_ready(ub_m_cmd_ready[i]),
                .cmd_in(ub_m_cmd_data[i*CMD_LEN +: CMD_LEN]),

                .cmd_out_ready(rst_m_ready),
                .cmd_out_valid(rst_m_valid),
                .cmd_out(rst_m_data)
            );

            // Instantiate data transmitter
            data_tx #(.LENGTH(CMD_LEN), .LINES(1)) m_tx_inst (
                .clk(clk_100),
                .rst(sys_rst_valid),
                .valid(rst_m_valid),
                .ready(rst_m_ready),
                .data_in(rst_m_data),
                .idle(tx_idle[i]),
                .tx_err(),
                .d(m_ctrl[i])
            );
        end
    endgenerate

    /*
    * Receiver side components
    * RX controller and fifo
    */

    reg [NMODULES-1:0] m_data_ready;
    wire [NMODULES-1:0] m_data_valid;
    wire [LENGTH*NMODULES-1:0] m_data_out;

    // Per-module rx controller and fifos
    generate
        for (i = 0; i < NMODULES; i = i + 1) begin: module_controller_inst

            wire m_rx_valid, m_rx_err;
            wire [LENGTH-1:0] m_rx_data;

            localparam SGL_FLAG_OFFSET = 122, CMD_FLAG_OFFSET = 115;
            wire data_is_cmd = ~m_rx_data[SGL_FLAG_OFFSET] & m_rx_data[CMD_FLAG_OFFSET];

            clk_toggling clk_toggling_inst (
                .clk(m_data_clk[i]), .clk_fb(clk_100), .toggling(rx_toggling[i]));

            // Instantiate receiver for control and data from frontend
            data_rx m_data_rx (
                .clk(m_data_clk[i]),
                .rst(1'b0),
                .d(m_data_in[i*LINES +: LINES]),
                .rx_err(m_rx_err),
                .valid(m_rx_valid),
                .data(m_rx_data)
            );

            xpm_cdc_array_single #(.WIDTH(1)) rx_err_cdc_inst (
                .src_in(m_rx_err), .src_clk(m_data_clk[i]),
                .dest_out(rx_err[i]), .dest_clk(clk_100)
            );

            wire rx_data_fifo_empty, rx_cmd_fifo_empty;
            assign m_data_valid[i] = ~rx_data_fifo_empty;
            assign m_ub_cmd_valid[i]  = ~rx_cmd_fifo_empty;

            // Since each receiver has its own clock domain, pass data through fifo
            
            xpm_fifo_async #(
                .READ_MODE("fwft"),
                .FIFO_READ_LATENCY(0),
                .WRITE_DATA_WIDTH(128),
                .READ_DATA_WIDTH(128)
            ) rx_data_fifo (
                .full(),
                .din(m_rx_data),
                .wr_en(m_rx_valid & ~data_is_cmd),
                .wr_clk(m_data_clk[i]),
    
                .empty(rx_data_fifo_empty),
                .dout(m_data_out[i*LENGTH +: LENGTH]),
                .rd_en(m_data_valid[i] & m_data_ready[i]),
                .rd_clk(clk_100)
            );

            wire [LENGTH-1:0] m_ub_cmd_data_full;
            assign m_ub_cmd_data[i*CMD_LEN +: CMD_LEN] = m_ub_cmd_data_full[0 +: CMD_LEN];

            xpm_fifo_async #(
                .READ_MODE("fwft"),
                .FIFO_READ_LATENCY(0),
                .WRITE_DATA_WIDTH(128),
                .READ_DATA_WIDTH(128)
            ) rx_cmd_fifo (
                .full(),
                .din(m_rx_data),
                .wr_en(m_rx_valid & data_is_cmd),
                .wr_clk(m_data_clk[i]),
    
                .empty(rx_cmd_fifo_empty),
                .dout(m_ub_cmd_data_full),
                .rd_en(m_ub_cmd_valid[i] & m_ub_cmd_ready[i]),
                .rd_clk(clk_100)
            );
        end
    endgenerate

    reg [LENGTH-1:0] m_data_mux;
    reg [NMODULES-1:0] m_ready_suppress;

    integer k;
    always @ (*) begin
        // Priority encoder for data
        m_data_mux = 0;
        for (k = NMODULES-1; k >= 0; k = k - 1)
            if (m_data_valid[k])
                m_data_mux = m_data_out[k*LENGTH +: LENGTH];

        // Rolling OR of valid bus
        m_ready_suppress[0] = 0;
        for (k = 1; k < NMODULES; k = k + 1)
            m_ready_suppress[k] = m_data_valid[k-1] | m_ready_suppress[k-1];

        // Create ready signal
        for (k = 0; k < NMODULES; k = k + 1)
            m_data_ready[k] = ~m_ready_suppress[k];
    end

    /*
    * Ethernet tx/rx controllers and interface fifos
    */

    // singles data fifo to gigex 
    
    wire m_data_mux_valid = (|m_data_valid);
    wire rx_fifo_ready, rx_fifo_empty;
    wire [LENGTH-1:0] rx_fifo_data;
    
    xpm_fifo_async #(
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),
        .WRITE_DATA_WIDTH(128),
        .READ_DATA_WIDTH(128)
    ) m_eth_tx_fifo_inst (
        .full(),
        .din(m_data_mux),
        .wr_en(m_data_mux_valid),
        .wr_clk(clk_100),
    
        .empty(rx_fifo_empty),
        .dout(rx_fifo_data),
        .rd_en(~rx_fifo_empty & rx_fifo_ready),
        .rd_clk(~eth_clk)
    );

    // command data fifo from uBlaze

    wire [CMD_LEN-1:0] cmd_fifo_eth_tx_data;
    wire cmd_fifo_eth_tx_nvalid, cmd_fifo_eth_tx_ready;
    wire cmd_fifo_eth_tx_valid = ~cmd_fifo_eth_tx_nvalid;

    wire cmd_fifo_eth_tx_full;
    assign ub_eth_cmd_ready = ~cmd_fifo_eth_tx_full;
    
    xpm_fifo_async #(
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0)
    ) ublaze_eth_tx_fifo_inst (
        .full(cmd_fifo_eth_tx_full),
        .din(ub_eth_cmd_data),
        .wr_en(ub_eth_cmd_valid & ub_eth_cmd_ready),
        .wr_clk(clk_100),
    
        .empty(cmd_fifo_eth_tx_nvalid),
        .dout(cmd_fifo_eth_tx_data),
        .rd_en(cmd_fifo_eth_tx_valid & cmd_fifo_eth_tx_ready),
        .rd_clk(~eth_clk)
    );

    // GigEx control signals
    wire byte_out_valid;
    assign nTx = ~byte_out_valid;
    assign nRF = {6'b0, 2'b11};
    assign user_hs_clk = eth_clk;

    // ethernet tx controller
    ethernet_tx_controller eth_tx (
        .clk(eth_clk),
        .channel_full(~nTF),

        .ctrl_data(cmd_fifo_eth_tx_data),
        .ctrl_data_valid(cmd_fifo_eth_tx_valid),
        .ctrl_data_ready(cmd_fifo_eth_tx_ready),

        .hs_data_valid(~rx_fifo_empty),
        .hs_data_ready(rx_fifo_ready),
        .hs_data(rx_fifo_data),

        .byte_out(D),
        .byte_out_valid(byte_out_valid),
        .channel(TC)
    );

    // command data fifo to ublaze

    wire [CMD_LEN-1:0] eth_rx_cmd_fifo_data;
    wire eth_rx_cmd_fifo_valid, eth_rx_cmd_fifo_nready;
    wire eth_rx_cmd_fifo_ready = ~eth_rx_cmd_fifo_nready;

    wire eth_ub_cmd_nvalid;
    assign eth_ub_cmd_valid = ~eth_ub_cmd_nvalid;

    xpm_fifo_async #(
        .READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0)
    ) eth_rx_ublaze_fifo_inst (
        // gigex interface side
        .full(eth_rx_cmd_fifo_nready),
        .din(eth_rx_cmd_fifo_data),
        .wr_en(eth_rx_cmd_fifo_valid & eth_rx_cmd_fifo_ready),
        .wr_clk(~eth_clk),
    
        // ublaze interface side
        .empty(eth_ub_cmd_nvalid),
        .dout(eth_ub_cmd_data),
        .rd_en(eth_ub_cmd_valid & eth_ub_cmd_ready),
        .rd_clk(clk_100)
    );

    // ethernet rx controller
    ethernet_rx_controller eth_rx (
        .clk(eth_clk),

        .data(Q),
        .data_good(~nRx),
        .channel(RC),

        .data_out(eth_rx_cmd_fifo_data),
        .data_out_valid(eth_rx_cmd_fifo_valid),
        .data_out_ready(eth_rx_cmd_fifo_ready)
    );

endmodule
