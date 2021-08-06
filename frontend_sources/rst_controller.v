module rst_controller_frontend #(
    parameter RST_CODE = 32'hF000_0000
) (
    input wire clk,
    input wire [31:0] data_in,
    input wire valid_in,

    output reg [31:0] data_out  = 0,
    output reg valid_out = 0,
    input  wire ready_out,
    output wire sys_rst
);
    localparam RST_DURATION = 32;

    wire data_is_rst = (data_in == RST_CODE);

    wire data_in_valid = (valid_in & ~data_is_rst);
    wire  rst_in_valid = (valid_in &  data_is_rst);

    reg [RST_DURATION-1:0] rst_shift_reg = 0;
    assign sys_rst = rst_shift_reg[0];

    always @ (posedge clk) begin
        rst_shift_reg <= rst_in_valid ? {RST_DURATION{1'b1}} : rst_shift_reg >> 1;

        valid_out <= (data_in_valid | valid_out) & ~(ready_out & valid_out);
        data_out  <= data_in_valid ? data_in : data_out;
    end

endmodule
