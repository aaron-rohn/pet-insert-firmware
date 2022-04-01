`timescale 1ns / 1ps

module ev_counter_tb();
    
    reg frontend_clk = 0, clk = 0, rst = 0;
    reg [2:0] ev = 0, load = 0;

    wire [3*48-1:0] counter;
    wire [47:0] counters [2:0];
    assign counters[0] = counter[0 +: 48];
    assign counters[1] = counter[48 +: 48];
    assign counters[2] = counter[(2*48) +: 48];

    event_counter #(.NCOUNTERS(3)) counter_inst (
        .frontend_clk(frontend_clk), .clk(clk), .rst(rst),
        .signal(ev), .load(load),
        .counters(counter)
    );

    initial forever #5 clk <= ~clk;
    initial forever #3 frontend_clk <= ~frontend_clk;

    integer i;

    initial begin
        #10 rst <= 1'b1;
        #20 rst <= 1'b0;
        #20 load[0] <= 1'b1;
        #20 load[0] <= 1'b0;

        #10

        for (i = 0; i < 10; i = i + 1) begin
            @(posedge frontend_clk);
            #3 ev[0] <= 1;
            #6 ev[0] <= 0;
            #60;
        end

        @(posedge clk);
        #20 load[1] <= 1'b1;
        #20 load[1] <= 1'b0;

        #10

        for (i = 0; i < 10; i = i + 1) begin
            @(posedge frontend_clk);
            #3 ev[1] <= 1;
            #6 ev[1] <= 0;
            #60;
        end

        $stop;
    end

endmodule
