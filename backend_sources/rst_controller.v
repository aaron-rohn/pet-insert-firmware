module rst_controller #(
    parameter RST_CODE = 32'hF000_0000
) (
    input wire clk,
    input wire rst,

    input wire cmd_in_valid,
    output wire cmd_in_ready,
    input wire [31:0] cmd_in,

    input wire cmd_out_ready,
    output reg cmd_out_valid = 0,
    output reg [31:0] cmd_out = 0
);
    
    assign cmd_in_ready = ~cmd_out_valid; 

    always @ (posedge clk) begin
        if (rst) begin
            cmd_out_valid   <= 1;
            cmd_out         <= RST_CODE;
        end else begin
            cmd_out_valid   <= (cmd_in_valid | cmd_out_valid) & ~cmd_out_ready;
            cmd_out         <= cmd_in_valid ? cmd_in : cmd_out;
        end
    end

endmodule
