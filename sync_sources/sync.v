`timescale 1ns / 1ps

module sync #(
    NBACKEND = 4
)(
    output wire config_spi_ncs,

    // to DAC to control airflow to vortex tubes
    inout wire sda,
    inout wire scl,

    output wire status_fpga,
    output wire status_network,

    input wire clk_100_p,
    input wire clk_100_n,

    // Ports to backend

    output wire [NBACKEND-1:0] m_clk_p,
    output wire [NBACKEND-1:0] m_clk_n,

    output wire [NBACKEND-1:0] m_rst_p,
    output wire [NBACKEND-1:0] m_rst_n,

    // GigEx ports
    
    output wire user_hs_clk,
    
    input  wire [7:0] Q,
    input  wire nRx,
    input  wire [2:0] RC,
    output reg [7:0] nRF = {8{1'b1}},
            
    output wire [7:0] D,
    output wire nTx,
    output reg [2:0] TC = 3'd0,
    input  wire [7:0] nTF,

    // master spi ports
    input wire gigex_spi_cs,
    input wire gigex_spi_sck,
    input wire gigex_spi_mosi,
    output wire gigex_spi_miso
);
    
    wire self_soft_rst;

    assign config_spi_ncs = 1;

    wire clk_100;
    IBUFGDS clk_100_inst (.I(clk_100_p), .IB(clk_100_n), .O(clk_100));
    assign user_hs_clk = ~clk_100;

    wire sys_clk, sys_clk_fb;
    MMCME2_BASE #(
        .BANDWIDTH("HIGH"),
        .CLKIN1_PERIOD(10),
        /*
        .CLKFBOUT_MULT_F(20.125),
        .CLKOUT0_DIVIDE_F(8.750),
        .DIVCLK_DIVIDE(2)
        */
        .CLKFBOUT_MULT_F(49.5),
        .CLKOUT0_DIVIDE_F(11),
        .DIVCLK_DIVIDE(5)
    ) clk_sys_inst (
        .CLKIN1(clk_100),
        .CLKOUT0(sys_clk),
        .CLKFBIN(sys_clk_fb),
        .CLKFBOUT(sys_clk_fb),
        .RST(1'b0), .PWRDWN(1'b0)
    );

    wire m_rst;
    wire [NBACKEND-1:0] m_clk_ddr, m_rst_ddr;

    // Backend IO inst

    genvar i;
    generate
        for (i = 0; i < NBACKEND; i = i + 1) begin: backend_port_inst
            ODDR   m_clk_oddr_inst (.D1(1), .D2(0), .CE(1), .C(sys_clk), .S(), .R(self_soft_rst), .Q(m_clk_ddr[i]));
            OBUFDS m_clk_obuf_inst (.I(m_clk_ddr[i]), .O(m_clk_p[i]), .OB(m_clk_n[i]));

            ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) m_rst_oddr_inst (.D1(m_rst), .D2(m_rst), .CE(1), .C(sys_clk), .S(), .R(self_soft_rst), .Q(m_rst_ddr[i]));
            OBUFDS m_rst_obuf_inst (.I(m_rst_ddr[i]), .O(m_rst_p[i]), .OB(m_rst_n[i]));
        end
    endgenerate

    // Reset generator logic

    localparam RST_BITS = 4;
    localparam RST_IDLE = 4'b1010, RST_ACTIVE = 4'b1100, RST_MASK = {(RST_BITS-1){1'b1}};
    reg [RST_BITS-1:0] rst_code = RST_IDLE, rst_code_mask = RST_MASK;
    assign m_rst = rst_code[RST_BITS-1];

    wire module_rst_ub;
    reg rst_ack = 0;

    always @ (posedge sys_clk) begin
        if (self_soft_rst) begin
            rst_code_mask   <= RST_MASK;
            rst_code        <= RST_IDLE;
            rst_ack         <= 0;
        end else if (rst_code_mask[0]) begin
            rst_code_mask   <= rst_code_mask >> 1;
            rst_code        <= rst_code << 1;
            rst_ack         <= rst_ack;
        end else begin
            rst_code_mask   <= RST_MASK;
            rst_code        <= module_rst_ub & ~rst_ack ? RST_ACTIVE : RST_IDLE;
            rst_ack         <= module_rst_ub;
        end
    end

    // GPIO assignments

    wire [31:0] gpio_o, gpio_i;
    assign self_soft_rst    = gpio_o[0];
    assign status_fpga      = gpio_o[1];
    assign status_network   = gpio_o[2];
    assign module_rst_ub    = gpio_o[3];

    assign gpio_i[0] = rst_ack;
    assign gpio_i[31:1] = 0;

    // UB Inst

    wire [31:0] cmd_in, cmd_out;
    wire cmd_in_valid, cmd_in_ready, cmd_out_valid;

    design_1_wrapper ub_inst (
        .clk(sys_clk),
        .rst(self_soft_rst),
        .iic_rtl_0_scl_io(scl),
        .iic_rtl_0_sda_io(sda),
        .spi_cs(gigex_spi_cs),
        .spi_sclk(gigex_spi_sck),
        .spi_miso(gigex_spi_miso),
        .spi_mosi(gigex_spi_mosi),
        .gpio_rtl_0_tri_o(gpio_o),
        .gpio_rtl_1_tri_i(gpio_i),

        .cmd_in_tdata(cmd_in),
        .cmd_in_tlast(0),
        .cmd_in_tready(cmd_in_ready),
        .cmd_in_tvalid(cmd_in_valid),

        .cmd_out_tdata(cmd_out),
        .cmd_out_tlast(),
        .cmd_out_tready(1),
        .cmd_out_tvalid(cmd_out_valid)
    );

    // From gigex to uB

    wire [31:0] cmd_in_flip;
    generate for (i = 0; i < 32/8; i = i + 1) begin
        assign cmd_in[(i*8) +: 8] = cmd_in_flip[31-(i*8) -: 8];
    end endgenerate

    wire eth_rx_empty;
    assign cmd_in_valid = ~eth_rx_empty;

    xpm_fifo_async #(
        .FIFO_READ_LATENCY(0),
        .READ_MODE("fwft"),
        .FIFO_WRITE_DEPTH(64),
        .WRITE_DATA_WIDTH(8),
        .READ_DATA_WIDTH(32),
        .PROG_FULL_THRESH(32)
    ) eth_fifo_rx_inst (
        .rst(1'b0),
        .din(Q),
        .wr_en(~nRx),
        .wr_clk(clk_100),
        .full(),
        .dout(cmd_in_flip),
        .rd_en(cmd_in_valid & cmd_in_ready),
        .rd_clk(sys_clk),
        .empty(eth_rx_empty));

    // From uB to gigex

    wire [31:0] cmd_out_flip;
    generate for (i = 0; i < 32/8; i = i + 1) begin
        assign cmd_out_flip[(i*8) +: 8] = cmd_out[31-(i*8) -: 8];
    end endgenerate

    wire eth_tx_emp, eth_tx_ready, eth_tx_valid;
    assign eth_tx_valid = ~eth_tx_emp;
    assign nTx = ~(eth_tx_valid & eth_tx_ready);
    assign eth_tx_ready = nTF[0];

    xpm_fifo_async #(
        .FIFO_READ_LATENCY(0),
        .READ_MODE("fwft"),
        .FIFO_WRITE_DEPTH(16),
        .WRITE_DATA_WIDTH(32),
        .READ_DATA_WIDTH(8)
    ) eth_fifo_cmd_tx_inst (
        .rst(1'b0),
        .din(cmd_out_flip),
        .wr_en(cmd_out_valid),
        .wr_clk(sys_clk),
        .full(),
        .dout(D),
        .rd_en(~nTx),
        .rd_clk(clk_100),
        .empty(eth_tx_emp));

endmodule
