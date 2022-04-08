module ethernet_tx_controller (
    input wire clk,

    input wire [7:0] data,
    input wire valid,
    output wire ready,

    // Gigex side connection
    input wire [7:0] nTF,
    output wire [7:0] D,
    output wire nTx,
    output wire [2:0] TC
);
    assign D = data;
    assign TC = 0;

    // Delay registers for nTFx value
    // After a falling edge on nTF, the valid flag can
    // be asserted for 2 additional clocks.
    reg [7:0] nTF1 = 0, nTF2 = 0;
    wire [7:0] nTF_mask = nTF | nTF2;
    assign ready = nTF_mask[0];
    assign nTx = ~(valid & ready);

    always @ (negedge clk) begin
        nTF1 <= nTF;
        nTF2 <= nTF1;
    end

endmodule
