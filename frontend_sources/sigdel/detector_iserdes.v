module detector_iserdes #(
    parameter CRC_BITS     = 5,
    parameter ID_BITS      = 6,
    parameter DATA_BITS    = 128,
    parameter NCHAN_TOTAL  = 10,
    parameter COUNTER      = 17
)(
    input wire sample_clk,
    input wire clk,
    input wire rst,
    input wire [ID_BITS - 1:0] block_id,
    input wire [NCHAN_TOTAL - 1:0] signal,
    output reg stall = 0,

    input wire data_ready,
    output reg data_valid = 0,
    output wire [DATA_BITS - 1:0] data_out,
    output reg [47:0] period_out = 0
);
    genvar i;

    /*
    * Timing measurement
    */

    wire [1:0] trig;
    reg [2:0] trig_idx [1:0];

    generate for (i = 0; i < 2; i = i + 1) begin
        wire [7:0] ch;
        assign trig[i] = |ch;

        ISERDESE2 #(
            .DATA_RATE("DDR"), .DATA_WIDTH(8), .INTERFACE_TYPE("NETWORKING")
        ) iserdes_inst (
            .Q1(ch[0]), .Q2(ch[1]), .Q3(ch[2]), .Q4(ch[3]),
            .Q5(ch[4]), .Q6(ch[5]), .Q7(ch[6]), .Q8(ch[7]),
            .BITSLIP(0), .CE1(1), .CE2(1), .RST(rst),
            .CLK(sample_clk), .CLKB(~sample_clk),
            .CLKDIV(clk), .D(signal[i]),

            .SHIFTOUT1(), .SHIFTOUT2(), .O(),
            .DYNCLKDIVSEL(), .DYNCLKSEL(),
            .SHIFTIN1(), .SHIFTIN2(), .OFB(),
            .DDLY(), .CLKDIVP(0), .OCLK(), .OCLKB()
        );

        integer j;
        always @(*) begin
            trig_idx[i] = 7;
            for (j = 0; j < 8; j = j + 1) begin
                if (ch[j]) trig_idx[i] = (7 - j);
            end
        end
    end endgenerate

    wire [16:0] counter;
    assign counter[16 -: (16-(COUNTER-1))] = 0;
    wire [47:0] period;
    wire period_done;
    timer #(.COUNTER(COUNTER)) timer_inst (
        .clk(clk), .rst(rst),
        .counter(counter[0 +: COUNTER]), .period(period),
        .period_done(period_done)
    );

    wire [2:0] fine_ctr = trig_idx[0] < trig_idx[1] ? trig_idx[0] : trig_idx[1];
    wire [19:0] new_start_time = {counter, fine_ctr};

    /*
    * Energy measurement
    */

    wire start;
    wire [7:0] active; 
    wire [11:0] energy [7:0];
    wire active_any = |active;
    wire active_all = &active;

    generate for (i = 2; i < 10; i = i + 1) begin
        wire [7:0] ch;
        ISERDESE2 #(
            .DATA_RATE("DDR"), .DATA_WIDTH(8), .INTERFACE_TYPE("NETWORKING")
        ) iserdes_inst (
            .Q1(ch[0]), .Q2(ch[1]), .Q3(ch[2]), .Q4(ch[3]),
            .Q5(ch[4]), .Q6(ch[5]), .Q7(ch[6]), .Q8(ch[7]),
            .BITSLIP(0), .CE1(1), .CE2(1), .RST(rst),
            .CLK(sample_clk), .CLKB(~sample_clk),
            .CLKDIV(clk), .D(signal[i]),

            .SHIFTOUT1(), .SHIFTOUT2(), .O(),
            .DYNCLKDIVSEL(), .DYNCLKSEL(),
            .SHIFTIN1(), .SHIFTIN2(), .OFB(),
            .DDLY(), .CLKDIVP(0), .OCLK(), .OCLKB()
        );

        wire any_bits = |ch;
        reg any_bits_r = 0;
        assign active[i-2] = any_bits | any_bits_r;

        integer j;
        reg [4:0] nbits = 0, nbits_r = 0;
        always @(ch) begin
            nbits = 0;
            for (j = 0; j < 8; j = j + 1) begin
                nbits = nbits + ch[j];
            end
        end

        always @(posedge clk) begin
            nbits_r <= nbits;
            any_bits_r <= any_bits;
        end

        ADDMACC_MACRO #(
            .WIDTH_MULTIPLIER(7),
            .WIDTH_PREADD(5),
            .WIDTH_PRODUCT(12),
            .LATENCY(2)
        ) accum_inst (
            .LOAD(start | rst), .LOAD_DATA(0),
            .MULTIPLIER(1), .PREADD1(nbits_r), .PREADD2(0),
            .RST(rst), .CE(1), .CLK(clk), .CARRYIN(0),
            .PRODUCT(energy[i - 2])
        );
    end endgenerate

    wire [95:0] energy_all;
    generate for (i = 0; i < 8; i = i + 1) begin
        assign energy_all[12*i +: 12] = energy[i];
    end endgenerate

    /*
    * Block control
    */

    reg [1:0] trig_r = 0;
    reg [19:0] start_time = 0;
    reg active_any_r = 0, active_all_latch = 0, valid_ev = 0;

    wire timing_change = |(trig & ~trig_r) & ~valid_ev;
    assign start = active_any & ~active_any_r;
    wire finish = active_any_r & ~active_any;
    wire done = finish & valid_ev & active_all_latch;
    wire data_ack = data_valid & data_ready;

    always @(posedge clk) begin
        active_any_r <= active_any;

        // Latch timing info on event starting edge
        trig_r <= trig;
        start_time <= (timing_change | rst) ? new_start_time : start_time;
        period_out <= (timing_change | rst) ? period : period_out;

        // Event valid signals
        valid_ev <= (valid_ev | timing_change) & ~(finish | rst);
        active_all_latch <= (active_all_latch | active_all) & ~(finish | rst);

        // Stall a current time tag until event finishes
        stall <= (stall | (active_any & period_done)) & ~(finish | rst);

        // Data output handshaking
        data_valid <= (done | data_valid) & ~(data_ack | rst);
    end

    assign data_out = {
        {CRC_BITS{1'b1}},   // Framing bits,         5
        1'b1,               // Single event flag,    1
        block_id,           // Identifier,           6
        energy_all,         // Energy data,         96
        start_time          // Timing data,         20
    };

endmodule
