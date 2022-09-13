`timescale 1ns / 1ps

module testbench_gigex();

    reg sys_clk = 0;
    always #5.555 sys_clk = ~sys_clk;

    reg clk_100 = 0;
    always #5 clk_100 = ~clk_100;

    wire nTx, eth_clk;
    reg nTF = 1;
    
    /* Values for generating the sync/reset */

    reg do_rst = 0;
    reg [3:0] sys_rst_code = 4'b1010, sys_rst_mask = 4'b0111;
    wire sys_rst = sys_rst_code[3];
    always @ (posedge sys_clk) begin
        if (sys_rst_mask[0]) begin
            sys_rst_code <= sys_rst_code << 1;
            sys_rst_mask <= sys_rst_mask >> 1;
        end else begin
            sys_rst_code <= do_rst ? 4'b1100 : 4'b1010;
            sys_rst_mask <= 4'b0111;
        end
    end

    /* Write values to gigex receiver */
    reg [7:0] Q = 0;
    reg nRx = 1'b1;

    /* Values for creating command responses */

    // receive data from backend
    wire [3:0] m_clks_out, m_datas_out;
    data_rx #(.LENGTH(32), .LINES(1)) m_rx_inst[3:0] (
        .clk(m_clks_out),
        .d(m_datas_out),
        .valid(),
        .data()
    );

    // send data to backend
    reg [127:0] m0_data, m1_data, m2_data, m3_data;
    wire [2:0] m_data_lines [3:0];
    reg [3:0] m_data_valid = 0;
    wire [3:0] m_data_ready;
    wire [11:0] m_datas_in = {
        m_data_lines[3],
        m_data_lines[2],
        m_data_lines[1],
        m_data_lines[0]};
    
    reg [3:0] module_id = 0;
    reg is_single = 0, is_cmd = 1;
    reg [31:0] payload = 0;
    // sgl -> 122, cmd -> 115
    wire [127:0] packet = {
        {5{1'b1}},
        is_single,
        module_id,
        2'b0,
        is_cmd,
        83'b0,
        payload
    };

    wire [3:0] m_clks_in = {4{sys_clk}};
    data_tx m0_tx_inst (
        .clk(sys_clk), .rst(0),
        .valid(m_data_valid[0]),
        .ready(m_data_ready[0]),
        .data_in(m0_data),
        .d(m_data_lines[0]));
    data_tx m1_tx_inst (
        .clk(sys_clk), .rst(0),
        .valid(m_data_valid[1]),
        .ready(m_data_ready[1]),
        .data_in(m1_data),
        .d(m_data_lines[1]));
    data_tx m2_tx_inst (
        .clk(sys_clk), .rst(0),
        .valid(m_data_valid[2]),
        .ready(m_data_ready[2]),
        .data_in(m2_data),
        .d(m_data_lines[2]));
    data_tx m3_tx_inst (
        .clk(sys_clk), .rst(0),
        .valid(m_data_valid[3]),
        .ready(m_data_ready[3]),
        .data_in(m3_data),
        .d(m_data_lines[3]));

    backend backend_inst (
        .clk_100_p(clk_100),
        .clk_100_n(~clk_100),
        .sys_clk_p(sys_clk),
        .sys_clk_n(~sys_clk),
        .sys_rst_p(sys_rst),
        .sys_rst_n(~sys_rst),

        // output from backend
        .m_clk_p(m_clks_out),
        .m_clk_n(),
        .m_ctrl_p(m_datas_out),
        .m_ctrl_n(),

        // input to backend
        .m_data_clk_p(m_clks_in),
        .m_data_clk_n(~m_clks_in),
        .m_data_p(m_datas_in),
        .m_data_n(~m_datas_in),

        .gigex_spi_cs(),
        .gigex_spi_sck(),
        .gigex_spi_mosi(),
        .gigex_spi_miso(),

        .user_hs_clk(eth_clk),
        .Q(Q), .nRx(nRx), .RC(3'd1), .nRF(),
        .D(), .nTx(nTx), .TC(), .nTF({ {7{1'b1}}, nTF })
    );

    initial begin
        is_single = 0;
        is_cmd = 1;
        #10;
        m0_data = packet;
        m1_data = 128'h0;
        m2_data = 128'h0;
        m3_data = 128'h0;

        #10_000 @ (negedge sys_rst_mask[0]) do_rst = 1;
        @ (posedge sys_clk) do_rst = 0;

        #50_000
        @ (posedge eth_clk);
        Q = 8'hF0;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h80;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h00;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h00;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h00;
        nRx = 1;

        #50_000
        @ (posedge eth_clk);
        Q = 8'hF0;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h64;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h04;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'hFF;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h00;
        nRx = 1;

        #50_000
        @ (posedge eth_clk);
        Q = 8'hF0;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h80;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h00;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h00;
        nRx = 0;
        @ (posedge eth_clk);
        Q = 8'h00;
        nRx = 1;

        @(posedge sys_clk) m_data_valid[0] = 1'b1;
        #100 m_data_valid[0] = 1'b0;

        #100_000;
        $stop;
    end
    
endmodule
