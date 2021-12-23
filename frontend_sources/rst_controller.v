module rst_controller_frontend #(
    parameter RST_CODE = 32'hF000_0000
) (
    input wire clk,
    input wire rst,
    input wire [31:0] data_in,
    input wire valid_in,

    output reg [31:0] data  = 0,
    output reg valid = 0,
    input  wire ready,
    output wire rst_out
);
    localparam RST_DURATION = 32;
    reg [RST_DURATION-1:0] rst_sr = 0;
    assign rst_out = rst_sr[0];

    wire data_is_rst = (data_in == RST_CODE);
    wire is_data = (valid_in & ~data_is_rst);
    wire is_rst  = (valid_in &  data_is_rst);

    always @ (posedge clk) begin
        if (rst) begin
            rst_sr  <= 0;
            valid   <= 0;
            data    <= 0;
        end else begin
            rst_sr  <= is_rst ? {RST_DURATION{1'b1}} : rst_sr >> 1;
            valid   <= (valid | is_data) & ~(ready & valid);
            data    <= is_data ? data_in : data;
        end
    end

endmodule
