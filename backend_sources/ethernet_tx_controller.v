module ethernet_tx_controller (
    input wire clk,
    input wire [7:0] channel_full,

    // Control data channel
    input wire [31:0] ctrl_data,
    input wire ctrl_data_valid,
    output wire ctrl_data_ready,

    // HS data channel
    input wire [127:0] hs_data,
    input wire hs_data_valid,
    output wire hs_data_ready,

    // Gigex side connection
    output wire [7:0] byte_out,
    output wire byte_out_valid,
    output reg [2:0] channel = 0
);
    reg [127:0] data_latch = 0;
    reg [15:0] byte_mask = 0;

    // Delay registers for nTFx value
    reg [7:0] channel_full_d1 = 0, channel_full_d2 = 0;

    assign byte_out       = data_latch[127 -: 8];
    assign byte_out_valid = byte_mask[0] & ~channel_full_d2[channel];

    localparam IDLE = 0, BUSY = 1;
    reg state = IDLE;

    wire ctrl_and_channel_valid = ctrl_data_valid & ~channel_full_d2[1];
    wire data_and_channel_valid = hs_data_valid   & ~channel_full_d2[0];

    assign ctrl_data_ready = (state == IDLE) & ~channel_full_d2[1];
    assign hs_data_ready   = (state == IDLE) & ~channel_full_d2[0] & ~ctrl_data_valid;
        
    always @ (negedge clk) begin

        // Channel full flags must be delayed by 2 clock cycles (as per GigEx data sheet)
        channel_full_d1 <= channel_full;
        channel_full_d2 <= channel_full_d1;

        state       <= state;
        channel     <= channel;

        data_latch  <= 0;
        byte_mask   <= 0;

        case (state)
            IDLE: begin
                if (ctrl_and_channel_valid) begin
                    data_latch  <= {ctrl_data, 96'h0};
                    byte_mask   <= {12'b0, {4{1'b1}}};
                    state       <= BUSY;
                    channel     <= 1;
                end else if (data_and_channel_valid) begin
                    data_latch  <= hs_data;
                    byte_mask   <= {16{1'b1}};
                    state       <= BUSY;
                    channel     <= 0;
                end
            end

            BUSY: begin
                if (byte_mask[0]) begin
                    if (~channel_full_d2[channel]) begin
                        byte_mask   <= byte_mask >> 1;
                        data_latch  <= data_latch << 8;
                    end
                end else begin
                    state       <= IDLE;
                end
            end

        endcase
    end

endmodule
