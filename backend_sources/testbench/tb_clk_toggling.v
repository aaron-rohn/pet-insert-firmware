module tb_clk_toggling();

    reg clk1 = 0;
    reg clk1_ce = 0;

    always #5 clk1 = clk1_ce ? ~clk1 : clk1;

    reg clk2 = 0;
    always #5 clk2 = ~clk2;

    wire tog;
    clk_toggling clk_toggling_inst (
        .clk(clk1), .clk_fb(clk2), .toggling(tog)
    );

    initial begin
        #1000 clk1_ce <= 1;
        #1000 clk1_ce <= 0;
        #1000 clk1_ce <= 1;
        #1000 $stop();
    end

endmodule
