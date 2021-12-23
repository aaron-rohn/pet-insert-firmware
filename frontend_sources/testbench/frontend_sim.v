`timescale 1ns/1ps

module frontend_sim();

    reg clk = 1;
    wire ctrl, sda, scl;
    pullup(sda);
    pullup(scl);

    reg [9:0] block1_in = 0, block2_in = 0, block3_in = 0, block4_in = 0;
    reg [31:0] cmd_data_in = 0;

    frontend #(
        //.CLK_PER_TT(17'd998
    ) inst (
        .module_id(4'b0),

        .block1(block1_in),
        .block2(block2_in),
        .block3(block3_in),
        .block4(block4_in),
        
        .sys_clk_p(clk),
        .sys_clk_n(~clk),
        .sys_ctrl_p(ctrl),
        .sys_ctrl_n(~ctrl),

        .SDA(sda),
        .SCL(scl)
    );
    
    reg  data_tx_valid = 0;
    wire data_rx_ready;
    data_tx #(.LENGTH(32), .LINES(1)) rst_driver (
        .clk(clk),
        .rst(0),
        .valid(data_tx_valid),
        .ready(data_rx_ready),
        .data_in(cmd_data_in),
        .d(ctrl)
    );

    initial begin
        forever begin
            #5 clk = ~clk;
        end
    end
    
    initial begin
        #10_000

        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hF000_0000; // ub reset
        end 
        #10 data_tx_valid <= 0;

        #10_000

        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hF0B4_0411; // ub reset
        end 
        #10 data_tx_valid <= 0;

        #20_000
          
        block1_in <= {10{1'b1}};
        block2_in <= {10{1'b1}};
        block3_in <= {10{1'b1}};
        block4_in <= {10{1'b1}};
        #10_000
        block1_in <= 0;
        block2_in <= 0;
        block3_in <= 0;
        block4_in <= 0;

        #10_000

        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hF0B4_0211; // disable tt stall
        end 
        #10 data_tx_valid <= 0;

        #20_000

        block1_in <= {10{1'b1}};
        block2_in <= {10{1'b1}};
        block3_in <= {10{1'b1}};
        block4_in <= {10{1'b1}};
        #10_000
        block1_in <= 0;
        block2_in <= 0;
        block3_in <= 0;
        block4_in <= 0;

        #10_000

        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hF0B4_0210; // enable tt stall
        end 
        #10 data_tx_valid <= 0;

        #20_000

        block1_in <= {10{1'b1}};
        block2_in <= {10{1'b1}};
        block3_in <= {10{1'b1}};
        block4_in <= {10{1'b1}};
        #10_000
        block1_in <= 0;
        block2_in <= 0;
        block3_in <= 0;
        block4_in <= 0;

        #10_000

        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hF090_0000; // read period (div 0)
        end 
        #10 data_tx_valid <= 0;

        #10_000

        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hF090_0001; // read period (div 1)
        end 
        #10 data_tx_valid <= 0;

        #10_000
        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hF0A0_0100; // read blk 1 singles rate (div 0)
        end 
        #10 data_tx_valid <= 0;

        #10_000

        #10_000

        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hF0A0_0101; // read blk 1 singles rate (div 1)
        end 
        #10 data_tx_valid <= 0;

        #10_000

        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hF0B4_0311; // disable frontend
        end 
        #10 data_tx_valid <= 0;

        #20_000

        block1_in <= {10{1'b1}};
        block2_in <= {10{1'b1}};
        block3_in <= {10{1'b1}};
        block4_in <= {10{1'b1}};
        #10_000
        block1_in <= 0;
        block2_in <= 0;
        block3_in <= 0;
        block4_in <= 0;
    end

endmodule
