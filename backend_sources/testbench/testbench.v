`timescale 1ns / 1ps

module testbench();

    reg clk_100 = 0;
    always #5 clk_100 = ~clk_100;

    /* Values for driving the SPI port */

    localparam SPI_CLK_HALF = 57.143;
    reg spi_clk = 0, spi_cs = 1;
    always #SPI_CLK_HALF spi_clk = ~spi_clk;
    wire spi_clk_mask = spi_clk | spi_cs;
    wire spi_miso;
    reg spi_mosi = 0;

    reg [31:0] spi_data_in = 0, spi_data_out = 0;
    wire [19:0] payload = spi_data_out[0 +: 20];
    integer i;
    task spi;
        begin
            for (i = 0; i < 32; i = i + 1) begin
                @(negedge spi_clk);
                spi_cs       <= 0;
                spi_mosi     <= spi_data_in[31];
                spi_data_in  <= spi_data_in << 1;
                spi_data_out <= {spi_data_out, spi_miso};
            end
            @(negedge spi_clk);
            spi_cs <= 1;
        end
    endtask

    task spi_query;
        begin
            spi();
            #10_000;
            spi_data_in <= 0;
            spi();
        end
    endtask

    /* Values for creating command responses */

    reg is_single = 1, is_cmd = 0;

    wire m0_data_ready, m1_data_ready;
    reg m0_data_valid = 0, m1_data_valid = 0;
    wire [2:0] m0_data, m1_data, m2_data, m3_data;
    
    reg [3:0] module_id = 0;
    reg [31:0] m0_data_in = 0, m1_data_in = 0;

    wire [95:0] packet_header = {
        {5{1'b1}},
        is_single,
        module_id,
        2'b0,
        is_cmd,
        83'b0
    };

    /* Values for generating the sync/reset */

    reg do_rst = 0;
    reg [3:0] sys_rst_code = 4'b1010, sys_rst_mask = 4'b0111;
    wire sys_rst = sys_rst_code[3];
    always @ (posedge clk_100) begin
        if (sys_rst_mask[0]) begin
            sys_rst_code <= sys_rst_code << 1;
            sys_rst_mask <= sys_rst_mask >> 1;
        end else begin
            sys_rst_code <= do_rst ? 4'b1100 : 4'b1010;
            sys_rst_mask <= 4'b0111;
        end
    end

    wire [3:0] m_clks_out, m_datas_out;
    wire [3:0] m_clks_in = {4{clk_100}};
    wire [11:0] m_datas_in = {m3_data, m2_data, m1_data, m0_data};

    backend backend_inst (
        .sys_clk_p(clk_100),
        .sys_clk_n(~clk_100),
        .sys_rst_p(sys_rst),
        .sys_rst_n(~sys_rst),

        .m_clk_p(m_clks_out),
        .m_clk_n(),
        .m_ctrl_p(m_datas_out),
        .m_ctrl_n(),

        .m_data_clk_p(m_clks_in),
        .m_data_clk_n(~m_clks_in),
        .m_data_p(m_datas_in),
        .m_data_n(~m_datas_in),

        .gigex_spi_cs(spi_cs),
        .gigex_spi_sck(spi_clk_mask),
        .gigex_spi_mosi(spi_mosi),
        .gigex_spi_miso(spi_miso),

        .Q(), .nRx(), .RC(), .nRF(),
        .D(), .nTx(), .TC(), .nTF({8{1'b1}})
    );
    
    data_rx #(.LENGTH(32), .LINES(1)) m0_rx_inst (
        .clk(m_clks_out[0]),
        .d(m_datas_out[0]),
        .valid(),
        .data()
    );

    data_tx m0_tx_inst (
        .clk(clk_100),
        .rst(0),
        .valid(m0_data_valid),
        .ready(m0_data_ready),
        .data_in({packet_header, m0_data_in}),
        .d(m0_data)
    );
    
    data_tx m1_tx_inst (
        .clk(clk_100),
        .rst(0),
        .valid(m1_data_valid),
        .ready(m1_data_ready),
        .data_in({packet_header, m1_data_in}),
        .d(m1_data)
    );

    data_tx m2_tx_inst (
        .clk(clk_100),
        .rst(0),
        .valid(1'b0),
        .ready(),
        .data_in(128'h0),
        .d(m2_data)
    );

    data_tx m3_tx_inst (
        .clk(clk_100),
        .rst(0),
        .valid(1'b0),
        .ready(),
        .data_in(128'h0),
        .d(m3_data)
    );

    initial begin
        #10_000 @ (negedge sys_rst_mask[0]) do_rst <= 1;
        @ (posedge clk_100) do_rst <= 0;
        #10_000

        spi_data_in <= 32'hF064_04FF;
        spi_query();
        #10_000

        spi_data_in <= 32'hF064_0011;
        spi_query();
        #10_000

        spi_data_in <= 32'hF064_0010;
        spi_query();
        #10_000

        spi_data_in <= 32'hF064_0311;
        spi_query();
        #10_000

        $stop;
    end
    
endmodule
