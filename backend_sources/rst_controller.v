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
    
    localparam RST = 0, RUN = 1;
    reg state = RST;

    wire cmd_out_done = cmd_out_ready & cmd_out_valid;
    assign cmd_in_ready = ~(state == RST | cmd_out_valid); 

    always @ (posedge clk) begin
        case (state)
            RST: begin
                cmd_out_valid   <= ~(rst | cmd_out_done);
                cmd_out         <= RST_CODE;
                state           <= cmd_out_done ? RUN : RST;
            end

            RUN: begin
                // latch goes high with cmd_in_valid and low with cmd_out_ready
                cmd_out_valid   <= (cmd_in_valid | cmd_out_valid) & ~(rst | cmd_out_done);
                cmd_out         <= cmd_in_valid ? cmd_in : cmd_out;
                state           <= rst ? RST : RUN;
            end
        endcase
    end

endmodule
