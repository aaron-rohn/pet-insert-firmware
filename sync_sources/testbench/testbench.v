`timescale 1ns / 1ps
module testbench();

    reg clk_100 = 1;
    always #5 clk_100 <= ~clk_100;

    wire eth_clk;

    reg [7:0] Q = 0;
    reg nRx = 1'b1;

    wire sda, scl;
    pullup(sda);
    pullup(scl);

    sync inst (
        .sda(sda), .scl(scl),
        .status_fpga(),
        .status_network(),
        .clk_100_p(clk_100),
        .clk_100_n(~clk_100),
        .m_clk_p(), .m_clk_n(),
        .m_rst_p(), .m_rst_n(),

        .user_hs_clk(eth_clk),

        .Q(Q), .nRx(nRx), .RC(3'd0), .nRF(),
        .D(), .nTx(), .TC(), .nTF({7{1'b1}})
    );

    initial begin
        #10000
        @(posedge eth_clk);
        Q = 8'hF0;
        nRx = 1'b0;
        @(posedge eth_clk);
        Q = 8'h00;
        nRx = 1'b0;
        @(posedge eth_clk);
        @(posedge eth_clk);
        @(posedge eth_clk);
        nRx = 1'b1;

        #50000;
        $stop;
    end
endmodule
