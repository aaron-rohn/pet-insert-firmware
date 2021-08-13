module ethernet_tx_controller (
    input wire clk,
    input wire [7:0] channel_full,

    input wire [127:0] data,
    input wire valid,
    output wire ready,

    // Gigex side connection
    output wire [7:0] byte_out,
    output wire byte_out_valid,
    output wire [2:0] channel
);

    assign channel = 0;

    reg [127:0] data_latch = 0;
    reg [15:0] byte_mask = 0;

    // Delay registers for nTFx value (only care about channel 0)
    reg channel_full_d1 = 0, channel_full_d2 = 0;

    assign byte_out       = data_latch[127 -: 8];
    assign byte_out_valid = byte_mask[0] & ~channel_full_d2;

    localparam IDLE = 0, BUSY = 1;
    reg state = IDLE;

    wire data_and_channel_valid = valid & ~channel_full_d2;
    assign ready = (state == IDLE) & ~channel_full_d2;
        
    always @ (negedge clk) begin

        // Channel full flags must be delayed by 2 clock cycles (as per data sheet)
        channel_full_d1 <= channel_full[0];
        channel_full_d2 <= channel_full_d1;

        state       <= IDLE;
        byte_mask   <= 0;
        data_latch  <= 0;

        case (state)
            IDLE: begin
                if (data_and_channel_valid) begin
                    state       <= BUSY;
                    byte_mask   <= {16{1'b1}};
                    data_latch  <= data;
                end
            end

            BUSY: begin
                if (byte_mask[0]) begin
                    state <= BUSY;
                    if (~channel_full_d2) begin
                        byte_mask   <= byte_mask >> 1;
                        data_latch  <= data_latch << 8;
                    end else begin
                        byte_mask   <= byte_mask;
                        data_latch  <= data_latch;
                    end
                end
            end

        endcase
    end

endmodule
