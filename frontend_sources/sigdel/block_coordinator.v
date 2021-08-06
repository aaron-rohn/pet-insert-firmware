module block_coordinator (
    input wire clk,
    input wire rst,
    input wire timing_rising,
    input wire timing_falling,
    input wire active_any,
    input wire active_all,
    output reg start = 0,
    output reg done  = 0,
    output reg stall = 0,
    output reg [19:0] start_time = 0,
    output reg [47:0] start_period = 0
);
    reg active_any_p = 0, timing_falling_p = 0, valid_ev = 0, active_all_latch = 0, finish = 0;

    wire [18:0] counter;
    wire [47:0] period;
    wire period_done;
    timer timer_inst (.clk(clk), .rst(rst), .counter(counter), .period(period), .period_done(period_done));

    /*
     * Add the lowest bit to the time counter. If timing_rising is low and we're
     * latching an event, then the event occured in the second half of the clock period.
     */
    wire [19:0] new_start_time = {counter, ~timing_rising};
    
    //wire timing_change = timing_falling & ~timing_falling_p & ~valid_ev;
    reg timing_change = 0;

    always @ (posedge clk) begin
        timing_falling_p    <= timing_falling;
        timing_change       <= timing_falling & ~timing_falling_p & ~valid_ev;
        start_time          <= (timing_change | rst) ? new_start_time : start_time;
        start_period        <= (timing_change | rst) ? period         : start_period;

        /*
        * Active indicates that a signal is present on any energy channel input
        * start reg goes high for one clock on the rising edge of active_any
        * finish reg goes high for one clock on the falling edge of active_any
        */

        active_any_p    <= active_any;
        start           <= active_any & ~active_any_p;
        finish          <= active_any_p & ~active_any;
        done            <= finish & valid_ev & active_all_latch;

        /*
        * Start an event on the rising edge of the timing channel and end
        * it on the falling edge of done. This signal must go high for the 
        * done signal to propogate to the output, and must be low to
        * latch a new starting time/period
        */
        valid_ev <= (valid_ev | timing_change) & ~(finish | rst);
        active_all_latch <= (active_all_latch | active_all) & ~(finish | rst);

        /*
        * If an event is active when the period changes, the generation of
        * the time tag should be stalled until the event is completed.
        */
        stall    <= (stall | (active_any & period_done)) & ~(finish | rst);
    end
endmodule
