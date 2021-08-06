module block_multiplexer (
    input wire b1_valid,
    input wire b2_valid,
    input wire b3_valid,
    input wire b4_valid,
    input wire tt_valid,

    input wire [47:0] b1_period,
    input wire [47:0] b2_period,
    input wire [47:0] b3_period,
    input wire [47:0] b4_period,
    input wire [47:0] tt_period,

    input wire [127:0] b1_data,
    input wire [127:0] b2_data,
    input wire [127:0] b3_data,
    input wire [127:0] b4_data,
    input wire [127:0] tt_data,

    output wire b1_ready,
    output wire b2_ready,
    output wire b3_ready,
    output wire b4_ready,
    output wire tt_ready,

    output wire block_valid,
    output wire [127:0] block_data
);

    /*
    * Consider three sets of cases:
    *
    * Only one channel, tt, b1, b2, b3, or b4, has data
    *   The data should be emitted immediately
    *
    * The tt channel and one (or more) block has data
    *   - If the period of the data preceeds the period of the time tag, emit
    *   the data (then the time tag).
    *   - If the period of the time tag preceeds the period of the data, emit
    *   the time tag (then the data).
    *
    * Multiple blocks have data
    *   Emit data from b1 to 4 in order. Data should all be from the same
    *   period (?).
    *
    *** Note on b*_select signals
    *
    * To select b1, b1_valid must be true. If tt_valid is false, then there is
    * no time tag and we safely select b1. If tt_valid is true, then b1's
    * period must preceed the time tag (b1_earlier is true).
    *
    * b1_select is equivalent to:
    * (b1_valid & tt_valid & b1_earlier) | (b1_valid & ~tt_valid);
    *
    *** Note on b*_ready signals
    *
    * b1_ready -> if tt_valid is false, then accept data. If tt_valid is true,
    * then b1 must have valid data from before the time tag.
    *
    * b*_ready -> same rules as b1_ready, but output false if any of the
    * higher priority blocks have already been selected.
    *
    *** Note on the relationship between select and ready signals
    *
    * Rows producing true within the truth tables for the b*_select 
    * signals should also be true in the truth tables for the b*_ready
    * signals, although b*_ready should have other rows producing true.
    */

    wire b1_earlier = (b1_period < tt_period);
    wire b2_earlier = (b2_period < tt_period);
    wire b3_earlier = (b3_period < tt_period);
    wire b4_earlier = (b4_period < tt_period);

    wire b1_select  = b1_valid & (~tt_valid | b1_earlier);
    wire b2_select  = b2_valid & (~tt_valid | b2_earlier);
    wire b3_select  = b3_valid & (~tt_valid | b3_earlier);
    wire b4_select  = b4_valid & (~tt_valid | b4_earlier);

    assign b1_ready = (~tt_valid | (b1_valid & b1_earlier));
    assign b2_ready = (~tt_valid | (b2_valid & b2_earlier)) & ~(b1_select);
    assign b3_ready = (~tt_valid | (b3_valid & b3_earlier)) & ~(b1_select | b2_select) ;
    assign b4_ready = (~tt_valid | (b4_valid & b4_earlier)) & ~(b1_select | b2_select | b3_select);
    assign tt_ready = ~(b1_select | b2_select | b3_select | b4_select);

    assign block_valid = tt_valid | b1_valid | b2_valid | b3_valid | b4_valid;
    assign block_data  = b1_select ? b1_data :
                         b2_select ? b2_data :
                         b3_select ? b3_data :
                         b4_select ? b4_data :
                         tt_valid  ? tt_data : 0;

endmodule
