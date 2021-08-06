`timescale 1ns / 1ps

module sync #(
    NBACKEND = 4
)(
    output wire config_spi_ncs,

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
    
    input  wire [7:0] Q,    // Rx data from gigex
    input  wire nRx,        // Rx data valid from gigex, active low
    input  wire [2:0] RC,   // Rx data channel from gigex
    output wire [7:0] nRF,  // Rx fifo full flag to gigex, active low
            
    output wire [7:0] D,    // Tx data to gigex
    output wire nTx,        // Tx data valid to gigex
    output wire [2:0] TC,   // Tx data channel to gigex
    input  wire [7:0] nTF   // Tx fifo full flag from gigex
);

    genvar i;

    assign config_spi_ncs = 1;

    assign status_fpga = 1;
    assign status_network = 0;
    assign sda = 1'bz;
    assign scl = 1'bz;

    wire clk_100;
    IBUFGDS clk_100_inst (.I(clk_100_p), .IB(clk_100_n), .O(clk_100));

    wire m_rst;
    wire [NBACKEND-1:0] m_clk_ddr, m_rst_ddr;

    generate
        for (i = 0; i < NBACKEND; i = i + 1) begin: backend_port_inst
            ODDR   m_clk_oddr_inst (.D1(1), .D2(0), .CE(1), .C(clk_100), .S(), .R(0), .Q(m_clk_ddr[i]));
            OBUFDS m_clk_obuf_inst (.I(m_clk_ddr[i]), .O(m_clk_p[i]), .OB(m_clk_n[i]));

            ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) m_rst_oddr_inst (.D1(m_rst), .D2(m_rst), .CE(1), .C(clk_100), .S(), .R(0), .Q(m_rst_ddr[i]));
            OBUFDS m_rst_obuf_inst (.I(m_rst_ddr[i]), .O(m_rst_p[i]), .OB(m_rst_n[i]));
        end
    endgenerate

    localparam RST_BITS = 4;
    localparam RST_IDLE = 4'b1010, RST_ACTIVE = 4'b1100, RST_MASK = {(RST_BITS-1){1'b1}};
    reg [RST_BITS-1:0] rst_code = RST_IDLE, rst_code_mask = RST_MASK;
    assign m_rst = rst_code[RST_BITS-1];

    localparam RST_CODE = 32'hF000_0000;
    wire recv_valid;
    wire [31:0] recv_data;
    wire data_valid = (recv_data == RST_CODE);
    wire recv_ready = (rst_code_mask[0] == 0);

    always @ (posedge clk_100) begin
        if (rst_code_mask[0]) begin
            rst_code_mask   <= rst_code_mask >> 1;
            rst_code        <= rst_code << 1;
        end else begin
            rst_code_mask   <= RST_MASK;
            rst_code        <= (recv_valid & data_valid) ? RST_ACTIVE : RST_IDLE;
        end
    end

    wire byte_out_valid;
    assign nTx = ~byte_out_valid;
    assign nRF = {6'b0, 2'b11};
    assign user_hs_clk = clk_100;

    // loopback control data to workstation
    ethernet_tx_controller eth_tx (
        .clk(clk_100),
        .channel_full(~nTF),

        .ctrl_data(recv_data),
        .ctrl_data_valid(recv_valid & data_valid & recv_ready),
        .ctrl_data_ready(),

        // No HS data on the sync board
        .hs_data_valid(0),
        .hs_data_ready(),
        .hs_data(),

        .byte_out(D),
        .byte_out_valid(byte_out_valid),
        .channel(TC)
    );

    wire eth_rx_fifo_empty, eth_rx_fifo_full;
    wire eth_rx_valid;
    wire [31:0] eth_rx_data;

    assign recv_valid = ~eth_rx_fifo_empty;
    
    // latch rx data on clock falling edge
    xpm_fifo_async #(
        .FIFO_READ_LATENCY(0),
        .READ_MODE("fwft")
    ) eth_rx_fifo_inst (
        .empty(eth_rx_fifo_empty),
        .dout(recv_data),
        .rd_en(recv_valid & recv_ready),
        .rd_clk(clk_100),

        .full(eth_rx_fifo_full),
        .din(eth_rx_data),
        .wr_en(eth_rx_valid & ~eth_rx_fifo_full),
        .wr_clk(~clk_100),
        
        .rst(1'b0)
    );

    ethernet_rx_controller eth_rx (
        .clk(clk_100),

        .data(Q),
        .data_good(~nRx),
        .channel(RC),

        .data_out(eth_rx_data),
        .data_out_valid(eth_rx_valid),
        .data_out_ready(~eth_rx_fifo_full)
    );

endmodule
