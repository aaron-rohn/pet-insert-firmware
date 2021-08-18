`timescale 1ns / 1ps

module data_tx #( LENGTH = 128, LINES = 3 ) (
    input wire clk,
    input wire rst,

    input wire valid,
    output wire ready,
    input wire [LENGTH-1:0] data_in,

    output wire idle,
    output wire [LINES - 1:0] d
);

    /*
    * To maintain framing between tx and rx, idle and start codes must be
    * emitted as part of the communication protocol. Length of these codes
    * sets the minimum 'chunk' length that's used when sending data. This is
    * chosen to be 4 times the number of physical lines, so each chunk takes
    * 4 clocks to send. Idle codes ensure that the receiver remains locked,
    * while start codes signify upcoming valid data.
    */

    localparam CLK_PER_CHUNK = 4;

    /* 
    * Codes must be selected so that the RX cannot lock at the wrong phase,
    * and so that the start code is not a shifted version of the idle code.
    * Idle codes should also be DC balanced if the transmission line has high
    * pass characteristics.
    */
    localparam IDLE_CODE  = { {LINES{1'b1}}, {LINES{1'b1}}, {LINES{1'b0}}, {LINES{1'b0}} };
    localparam START_CODE = { {LINES{1'b1}}, {LINES{1'b0}}, {LINES{1'b1}}, {LINES{1'b0}} };

    // number of bits per data chunk
    localparam CHUNK_LEN = CLK_PER_CHUNK*LINES;

    // Get the next highest multiple of the chunk length for the input data
    localparam LENGTH_NXT = (LENGTH % CHUNK_LEN != 0) ? 
        LENGTH + CHUNK_LEN - (LENGTH % CHUNK_LEN) :
        LENGTH;

    localparam CHUNK_PER_DATA = LENGTH_NXT / CHUNK_LEN;

    // End protocol specific parameters
    
    localparam NBIT_RST   = {(CLK_PER_CHUNK-1){1'b1}};
    localparam NCHUNK_RST = {(CHUNK_PER_DATA-1){1'b1}};

    reg [LENGTH_NXT-1:0] data = 0;
    reg [CLK_PER_CHUNK-1:0] nbit = NBIT_RST;
    reg [CHUNK_PER_DATA-1:0] nchunk = NCHUNK_RST;
    reg [CHUNK_LEN-1:0] chunk_next = IDLE_CODE, chunk = IDLE_CODE;

    wire chunk_done = ~nbit[0];

    localparam START_OR_DATA = 1, IDLE_OR_DATA = 0;
    localparam IDLE = 2'b01, START = 2'b10, DATA = 2'b11;
    reg [1:0] state_next = IDLE, state = IDLE;

    assign d = chunk[(CHUNK_LEN-1) -: LINES];
    assign ready = chunk_done & (state == IDLE | nchunk[0] == 0);
    assign idle = (state == IDLE);

    /*
    * Possible state transitions, only used when chunk finishes
    *
    * IDLE -> START : if  valid
    * IDLE -> IDLE  : if ~valid
    *
    * START -> DATA : always
    *
    * DATA -> DATA  : if nchunk[0]
    * DATA -> START : if  valid
    * DATA -> IDLE  : if ~valid
    */

    always @ (*) begin
        if (nchunk[0] & state[START_OR_DATA]) begin
            // state is START or DATA, with at least one byte remaining
            // If state is START then nchunk will always be NCHUNK_RST
            state_next <= DATA;
            chunk_next <= data[(LENGTH_NXT-1) -: CHUNK_LEN];

        end else if (valid & state[IDLE_OR_DATA]) begin
            // state is IDLE or DATA, with data at the input
            // If state is DATA then we're on the last byte
            state_next <= START;
            chunk_next <= START_CODE;

        end else begin
            // state is IDLE or DATA, with no data at the input
            // If state is DATA then we're on the last byte
            state_next <= IDLE;
            chunk_next <= IDLE_CODE;
        end
    end

    always @ (posedge clk) begin
        if (rst) begin
            data    <= 0;
            nchunk  <= NCHUNK_RST;
            state   <= IDLE;
            chunk   <= IDLE_CODE;
            nbit    <= NBIT_RST;
        end else begin
            data    <= data;
            nchunk  <= NCHUNK_RST;
            state   <= chunk_done ? state_next : state;
            chunk   <= chunk_done ? chunk_next : chunk << LINES;
            nbit    <= chunk_done ? NBIT_RST   : nbit >> 1;

            case (state)
                IDLE: begin
                    if (chunk_done & valid) begin
                        // state proceeds to START
                        // output chunk is START_CODE
                        data <= data_in;
                    end
                end

                START: begin
                    if (chunk_done) begin
                        // state proceeds to DATA
                        // output chunk is top bits of data
                        data <= data << CHUNK_LEN;
                    end
                end

                DATA: begin
                    nchunk <= nchunk;

                    if (chunk_done) begin
                        // state stays here until nchunk[0] == 0, then sets to
                        // START if valid is high or IDLE otherwise
                        nchunk  <= nchunk >> 1;
                        data    <= nchunk[0] ? data << CHUNK_LEN :
                                   valid     ? data_in : 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
