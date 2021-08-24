module detector_iserdes #(
    parameter CRC_BITS     = 5,
    parameter ID_BITS      = 6,
    parameter DATA_BITS    = 128,
    parameter NCH          = 10,
    parameter COUNTER      = 17
)(
    input wire sample_clk,
    input wire clk,
    input wire rst,
    input wire [ID_BITS - 1:0] block_id,
    input wire [NCH - 1:0] signal,
    output reg stall = 0,

    input wire [16:0] counter,
    input wire [47:0] period,
    input wire period_done,

    input wire data_ready,
    output reg data_valid = 0,
    output wire [DATA_BITS - 1:0] data_out,
    output reg [47:0] period_out = 0
);

    // Extend the reset by at least two clocks to wait for iserdes
    localparam n_rst_ext = 4;
    reg [n_rst_ext-1:0] rst_sr = {n_rst_ext{1'b1}};
    wire rst_ext = rst | (|rst_sr);
    always @(posedge clk) rst_sr <= {rst_sr, rst};

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
    reg active_any_r = 0, active_all_latch = 0, valid_ev = 0;

    wire timing_change  = |(trig & ~trig_r) & ~valid_ev;
    assign start        = active_any & ~active_any_r;
    wire finish         = active_any_r & ~active_any;
    wire done           = finish & valid_ev & active_all_latch;
    wire data_ack       = data_valid & data_ready;

    always @(posedge clk) begin
        any_energy_bits_r <= any_energy_bits;
        active_any_r <= active_any;

        // Latch timing info on event starting edge
        trig_r <= trig;
        start_time <= (timing_change | rst_ext) ? new_start_time : start_time;
        period_out <= (timing_change | rst_ext) ? period : period_out;

        // Event valid signals
        valid_ev <= (valid_ev | timing_change) & ~(finish | rst_ext);
        active_all_latch <= (active_all_latch | active_all) & ~(finish | rst_ext);

        // Stall a current time tag until event finishes
        stall <= (stall | (active_any & period_done)) & ~(finish | rst_ext);

        // Data output handshaking
        data_valid <= (done | data_valid) & ~(data_ack | rst_ext);
    end

    assign data_out = {
        {CRC_BITS{1'b1}},   // Framing bits,         5
        1'b1,               // Single event flag,    1
        block_id,           // Identifier,           6
        energy,             // Energy data,         96
        start_time          // Timing data,         20
    };

endmodule
