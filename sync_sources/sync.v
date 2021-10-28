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
            
    output reg [7:0] D = 0,
    output reg nTx = 1,
    output reg [2:0] TC = 0,
    input  wire [7:0] nTF,

    // master spi ports
    input wire gigex_spi_cs,
    input wire gigex_spi_sck,
    input wire gigex_spi_mosi,
    output wire gigex_spi_miso
);
    
    wire self_soft_rst;

    assign config_spi_ncs = 1;
    assign sda = 1'bz;
    assign scl = 1'bz;

    // Clk int

    wire clk_100;
    IBUFGDS clk_100_inst (.I(clk_100_p), .IB(clk_100_n), .O(clk_100));

    wire m_rst;
    wire [NBACKEND-1:0] m_clk_ddr, m_rst_ddr;

    // Backend IO inst

    genvar i;
    generate
        for (i = 0; i < NBACKEND; i = i + 1) begin: backend_port_inst
            ODDR   m_clk_oddr_inst (.D1(1), .D2(0), .CE(1), .C(clk_100), .S(), .R(self_soft_rst), .Q(m_clk_ddr[i]));
            OBUFDS m_clk_obuf_inst (.I(m_clk_ddr[i]), .O(m_clk_p[i]), .OB(m_clk_n[i]));

            ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) m_rst_oddr_inst (.D1(m_rst), .D2(m_rst), .CE(1), .C(clk_100), .S(), .R(self_soft_rst), .Q(m_rst_ddr[i]));
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

    always @ (posedge clk_100) begin
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

    design_1_wrapper ub_inst (
        .clk(clk_100),
        .rst(self_soft_rst),
        .spi_cs(gigex_spi_cs),
        .spi_sclk(gigex_spi_sck),
        .spi_miso(gigex_spi_miso),
        .spi_mosi(gigex_spi_mosi),
        .gpio_rtl_0_tri_o(gpio_o),
        .gpio_rtl_1_tri_i(gpio_i)
    );

endmodule
