`timescale 1ns/1ps

module frontend_sim();

    reg clk = 1;
    wire ctrl, sda, scl;
    pullup(sda);
    pullup(scl);

    reg [9:0] block1_in = 0, block2_in = 0, block3_in = 0, block4_in = 0;
    reg [31:0] cmd_data_in = 0;

    frontend inst (
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
            cmd_data_in <= 32'hF000_0000; // reset
        end 
        #10 data_tx_valid <= 0;

        /*
        #500_000
        @ (posedge data_rx_ready) begin
            data_tx_valid <= 1;
            cmd_data_in <= 32'hf020_0000; // ADC read
        end 
        #10 data_tx_valid <= 0;
        */
    end
    
    initial begin
        #200_000 
          
        block1_in <= {10{1'b1}};
        block2_in <= {10{1'b1}};
        block3_in <= {10{1'b1}};
        block4_in <= {10{1'b1}};
        #1000
        block1_in <= 0;
        block2_in <= 0;
        block3_in <= 0;
        block4_in <= 0;
        #1_556_500 // 1.6ms
        
        block1_in <= {10{1'b1}};
        block2_in <= {10{1'b1}};
        block3_in <= {10{1'b1}};
        block4_in <= {10{1'b1}};
        #1000
        block1_in <= 0;
        block2_in <= 0;
        block3_in <= 0;
        block4_in <= 0;
        #200_000
        
        block1_in <= {10{1'b1}};
        block2_in <= {10{1'b1}};
        block3_in <= {10{1'b1}};
        block4_in <= {10{1'b1}};
        #1000
        block1_in <= 0;
        block2_in <= 0;
        block3_in <= 0;
        block4_in <= 0;
        #200_000
        
        $stop;
    end

endmodule
