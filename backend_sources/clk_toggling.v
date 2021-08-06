`timescale 1ns / 1ps

module clk_toggling (
    input wire clk,
    input wire clk_fb,
    output reg toggling = 0
);

    localparam div = 4;

    reg clk_ce = 0;
    always @ (posedge clk) clk_ce <= ~clk_ce;

    wire clkdiv;
    BUFGCE clkdiv_inst (.I(clk), .CE(clk_ce), .O(clkdiv));

    reg [3:0] counter = 0;
    always @ (posedge clkdiv) counter <= counter + 1;

    wire [3:0] counter_out;
    reg [3:0] counter_out_p = 0;

    xpm_cdc_gray #(
        .WIDTH(4)
    ) counter_cdc_inst (
        .src_clk(clkdiv),
        .src_in_bin(counter),
        .dest_clk(clk_fb),
        .dest_out_bin(counter_out)
    );

    reg val_changed = 0;
    reg [7:0] history = 0;

    always @ (posedge clk_fb) begin
        counter_out_p <= counter_out;
        val_changed <= (counter_out_p != counter_out);
        history <= {history, val_changed};
        toggling <= |history;
    end

endmodule
