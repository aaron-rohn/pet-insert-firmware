`timescale 1ns / 1ps
module testbench();

    reg clk_100 = 1;
    wire eth_clk;
    reg [7:0] data = 0;
    reg data_valid = 0;

    sync inst (
        .clk_100_p(clk_100),
        .clk_100_n(~clk_100),

        .user_hs_clk(eth_clk),

        .Q(data),
        .nRx(~data_valid),

        .nTF(3'b111)
    );

    always #5 clk_100 <= ~clk_100;

    initial begin
        #10000

        @ (posedge eth_clk) begin
            data_valid <= 1;
            data <= 8'hF0;
        end

        @ (posedge eth_clk) begin
            data_valid <= 1;
            data <= 8'h00;
        end

        @ (posedge eth_clk) begin
            data_valid <= 1;
        end

        @ (posedge eth_clk) begin
            data_valid <= 1;
        end

        @ (posedge eth_clk) begin
            data_valid <= 0;
        end

        #10000
        $stop;
    end
endmodule
