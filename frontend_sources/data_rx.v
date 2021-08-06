`timescale 1ns / 1ps

module data_rx #( LENGTH = 128, LINES = 3 ) (
    input wire clk,
    input wire rst,
    input wire [LINES - 1:0] d,

    output wire rx_err,
    output reg valid = 0,
    output reg [LENGTH-1:0] data = 0
);

    // Start protocol specific parameters

    localparam CLK_PER_CHUNK = 4;

    localparam IDLE_CODE  = { {LINES{1'b1}}, {LINES{1'b1}}, {LINES{1'b0}}, {LINES{1'b0}} };
    localparam START_CODE = { {LINES{1'b1}}, {LINES{1'b0}}, {LINES{1'b1}}, {LINES{1'b0}} };

    localparam CHUNK_LEN = CLK_PER_CHUNK*LINES;

    localparam LENGTH_NXT = (LENGTH % CHUNK_LEN != 0) ? 
        LENGTH + CHUNK_LEN - (LENGTH % CHUNK_LEN) :
        LENGTH;

    localparam CHUNK_PER_DATA = LENGTH_NXT / CHUNK_LEN;

    // End protocol specific parameters

    localparam SCAN = 2'd0, IDLE = 2'd1, DATA = 2'd2;
    reg [1:0] state = SCAN;

    assign rx_err = (state == SCAN);

    reg [CLK_PER_CHUNK-1:0] nbit = {(CLK_PER_CHUNK-1){1'b1}};
    reg [CHUNK_LEN-1:0] chunk = 0;
    reg [CHUNK_PER_DATA-1:0] nchunk = 0;

    // Indicates when one chunck has been received
    wire chunk_done = (nbit[0] == 0);

    // Identify the state indicated by the most recent input byte
    wire [1:0] state_next = (chunk == IDLE_CODE)  ? IDLE :
                            (chunk == START_CODE) ? DATA : SCAN;

    always @ (posedge clk) begin
        if (rst) begin

            // Since input clock may take time to lock, include reset
            state   <= SCAN;
            nbit    <= {(CLK_PER_CHUNK-1){1'b1}};
            nchunk  <= {(CHUNK_PER_DATA-1){1'b1}};
            chunk   <= 0;
            valid   <= 0;
            data    <= 0;

        end else begin

            chunk   <= {chunk, d};
            nbit    <= ((state == SCAN) | chunk_done) ? {(CLK_PER_CHUNK-1){1'b1}} : nbit >> 1;
            nchunk  <= {(CHUNK_PER_DATA-1){1'b1}};

            valid   <= 0;
            data    <= 0;

            case (state)

                // Scan the input data stream until the input matches a header
                SCAN: begin
                    state   <= state_next;
                end

                // Wait in IDLE until the input chunk indicates valid data
                IDLE: begin
                    state   <= chunk_done ? state_next : state;
                end

                // Read in the appropriate number of chunks, then return to idle
                DATA: begin

                    nchunk  <= nchunk;
                    state   <= state;
                    data    <= data;

                    if (chunk_done) begin
                        data         <= {data, chunk};
                        nchunk       <= nchunk >> 1;

                        if (nchunk[0] == 0) begin
                            valid    <= 1;
                            state    <= IDLE;
                        end
                    end
                end

                default: state <= SCAN;

            endcase
        end
    end
endmodule
