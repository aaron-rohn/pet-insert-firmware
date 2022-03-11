module detector_iserdes #(
    parameter DATA_BITS    = 128,
    parameter NCH          = 10
)(
    input wire sample_clk,
    input wire clk,
    input wire rst,
    input wire [5:0] block_id,
    input wire [NCH - 1:0] signal,

    input wire [16:0] counter,
    input wire period_done,

    input wire data_ready,
    output reg data_valid = 0,
    output wire [DATA_BITS - 1:0] data_out,
    output reg stall = 0,

    output wire [47:0] nsingles
);

    // Extend the reset by at least two clocks to wait for iserdes
    localparam n_rst_ext = 4;
    reg [n_rst_ext-1:0] rst_sr = {n_rst_ext{1'b1}};
    reg rst_ext = 0;

    always @(posedge clk) begin
        rst_sr  <= {rst_sr, rst};
        rst_ext <= rst | (|rst_sr);
    end

    genvar i;
    integer j;

    wire [7:0] data [NCH-1:0];
    generate for (i = 0; i < NCH; i = i + 1) begin
        ISERDESE2 #(
            .DATA_RATE("DDR"),
            .DATA_WIDTH(8),
            .INTERFACE_TYPE("NETWORKING")
        ) iserdes_inst (
            .Q1(data[i][0]), .Q2(data[i][1]), .Q3(data[i][2]), .Q4(data[i][3]),
            .Q5(data[i][4]), .Q6(data[i][5]), .Q7(data[i][6]), .Q8(data[i][7]),
            .BITSLIP(0), .CE1(1), .CE2(1), .RST(rst),
            .CLK(sample_clk), .CLKB(~sample_clk),
            .CLKDIV(clk), .CLKDIVP(0), .D(signal[i])
        );
    end endgenerate

    /*
    * Timing measurement
    */

    wire [1:0] trig;
    reg [2:0] trig_idx [1:0];
    wire [2:0] fine_ctr = trig_idx[0] < trig_idx[1] ? trig_idx[0] : trig_idx[1];
    wire [19:0] new_start_time = {counter, fine_ctr};

    generate for (i = 0; i < 2; i = i + 1) begin
        wire [7:0] ch = data[i];
        assign trig[i] = |ch;

        // Find the number of places before the first set bit
        always @(*) begin
            trig_idx[i] = 7;
            for (j = 0; j < 8; j = j + 1) begin
                if (ch[j]) trig_idx[i] = (7 - j);
            end
        end
    end endgenerate

    /*
    * Energy measurement
    */

    wire start;
    wire [7:0] any_energy_bits, active; 
    reg [7:0] any_energy_bits_r = 0;
    assign active = any_energy_bits | any_energy_bits_r;
    wire active_any = |active;
    wire active_all = &active;
    wire [95:0] energy;

    generate for (i = 0; i < 8; i = i + 1) begin
        wire [7:0] ch = data[i + 2];
        assign any_energy_bits[i] = |ch;

        // Count the number of bits set
        reg [4:0] nbits = 0;
        always @(*) begin
            nbits = 0;
            for (j = 0; j < 8; j = j + 1) begin
                nbits = nbits + ch[j];
            end
        end

        ADDMACC_MACRO #(
            .WIDTH_MULTIPLIER(7),
            .WIDTH_PREADD(5),
            .WIDTH_PRODUCT(12),
            .LATENCY(3)
        ) accum_inst (
            .LOAD(start | rst_ext), .LOAD_DATA(0),
            .MULTIPLIER(1), .PREADD1(nbits), .PREADD2(0),
            .RST(rst_ext), .CE(1), .CLK(clk), .CARRYIN(0),
            .PRODUCT(energy[12*i +: 12])
        );
    end endgenerate

    /*
    * Block control
    */

    reg [1:0] trig_r = 0;
    reg [19:0] start_time = 0;
    reg active_any_r = 0, active_all_latch = 0, timing_latch = 0;

    // pulse indicates a rising edge on one of the timing channels
    wire timing = |(trig & ~trig_r) & ~timing_latch;

    // pulse indicates the first rising and last falling energy channel
    assign start = active_any & ~active_any_r;
    wire finish = active_any_r & ~active_any;

    // pulse indicates that a validated event (timing + 8 energies) has completed 
    wire done = finish & timing_latch & active_all_latch;

    // pulse indicates that a time tag would have been emitted during
    // a validated event. used to stall the time tag emission
    wire tt_crossed = period_done & timing_latch & active_all_latch;

    // indicates that data is read from the module
    wire data_ack = data_valid & data_ready;

    always @(posedge clk) begin
        if (rst_ext) begin
            any_energy_bits_r   <= 0;
            active_any_r        <= 0;
            trig_r              <= 0;
            start_time          <= 0;
            timing_latch        <= 0;
            active_all_latch    <= 0;
            data_valid          <= 0;
            stall               <= 0;
        end else begin
            any_energy_bits_r   <= any_energy_bits;
            active_any_r        <= active_any;
            trig_r              <= trig;

            // Latch timing info on event starting edge
            start_time  <= timing ? new_start_time : start_time;

            // Latch if the timing signal went high before/during the event
            timing_latch <= (timing_latch | timing) & ~finish;

            // Latch if all channels went high during the event
            active_all_latch <= (active_all_latch | active_all) & ~finish;

            // Data output handshaking
            data_valid  <= (done  | data_valid) & ~data_ack;
            stall       <= (stall | tt_crossed) & ~data_ack;
        end
    end

    /*
    * energy[ 0:11] -> A_FRONT
    * energy[12:23] -> B_FRONT
    * energy[24:35] -> C_FRONT
    * energy[36:47] -> D_FRONT
    * energy[48:59] -> A_REAR
    * energy[60:71] -> B_REAR
    * energy[72:83] -> C_REAR
    * energy[84:95] -> D_REAR
    */

    assign data_out = {
        {5{1'b1}}, // Framing bits,         5
        1'b1,      // Single event flag,    1
        block_id,  // Identifier,           6
        energy,    // Energy data,         96
        start_time // Timing data,         20
    };

    /*
    * Singles rate measurement
    */

    ADDMACC_MACRO #(
        .LATENCY(2),
        .WIDTH_PREADD(2),
        .WIDTH_PRODUCT(48)
    ) counter_inst (
        .LOAD(rst_ext), .LOAD_DATA(0),
        .MULTIPLIER(1), .PREADD1({1'b0, done}), .PREADD2(0),
        .RST(rst_ext), .CE(1), .CLK(clk), .CARRYIN(0),
        .PRODUCT(nsingles)
    );

endmodule
