module ethernet_rx_controller (
    input wire clk,

    input wire [7:0] data,
    input wire data_good,
    input wire [2:0] channel,

    output reg [31:0] data_out = 0,
    output reg data_out_valid = 0,
    input wire data_out_ready
);

    reg [31:0] data_reg = 0;
    reg [2:0] byte_mask = 0;

    localparam IDLE = 0, BUSY = 1;
    reg state = IDLE;

    always @ (negedge clk) begin

        state       <= state;
        byte_mask   <= {3{1'b1}};

        // Shift in each byte only if data_good is high
        data_reg    <= data_good ? {data_reg, data} : data_reg;

        // Keep valid high until recv'er acknowledges ready or new data comes
        data_out_valid  <= data_out_ready ? 0 : (data_out_valid & ~data_good);
        data_out        <= data_good ? {data_out, data} : data_out;

        case (state)

            IDLE: begin
                // Look for proper byte header before recv'ing full word
                if (data_good && (data[7 -: 4] == 4'hF)) begin
                    state <= BUSY;
                end
            end

            BUSY: begin
                // Shift in byte only if data_good is high
                byte_mask <= byte_mask >> data_good;

                if (~byte_mask[0]) begin
                    state           <= IDLE;
                    data_out_valid  <= 1;
                end
            end

        endcase
    end

endmodule
