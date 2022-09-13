`timescale 1ns / 1ps

module testbench_spi();

    reg sys_clk = 0;
    always #5.555 sys_clk = ~sys_clk;

    reg clk_100 = 0;
    always #5 clk_100 = ~clk_100;

    /* Values for driving the SPI port */

    localparam SPI_CLK_HALF = 14.286;
    reg spi_clk_unmask = 0, spi_cs = 1, spi_msk = 1;
    always #SPI_CLK_HALF spi_clk_unmask = ~spi_clk_unmask;
    wire spi_clk = spi_clk_unmask | spi_msk;
    wire spi_miso;
    reg spi_mosi = 0;

    reg [31:0] spi_data_in = 0, spi_data_out = 0;
    wire [19:0] payload = spi_data_out[0 +: 20];
    integer i = 0;
    task spi;
        begin
            @(negedge spi_clk_unmask) spi_cs = 0;
            for (i = 0; i <= 32; i = i + 1) begin
                @(negedge spi_clk_unmask);
                spi_msk         = (i == 32);
                spi_mosi        = spi_data_in[31];
                spi_data_in     = spi_data_in << 1;
                spi_data_out    = {spi_data_out, spi_miso};
            end
            @(negedge spi_clk_unmask) spi_cs = 1;
        end
    endtask

    task spi_query;
        begin
            spi();
            #10000;
            spi_data_in = 0;
            spi();
        end
    endtask

    /* Values for creating command responses */

    reg is_single = 0, is_cmd = 1;

    wire m0_data_ready, m1_data_ready;
    reg m0_data_valid = 0, m1_data_valid = 0;
    wire [2:0] m0_data, m1_data, m2_data, m3_data;
    
    reg [3:0] module_id = 0;
    reg [31:0] m0_data_in = 0, m1_data_in = 0;

    // sgl -> 122, cmd -> 115
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
    always @ (posedge sys_clk) begin
        if (sys_rst_mask[0]) begin
            sys_rst_code <= sys_rst_code << 1;
            sys_rst_mask <= sys_rst_mask >> 1;
        end else begin
            sys_rst_code <= do_rst ? 4'b1100 : 4'b1010;
            sys_rst_mask <= 4'b0111;
        end
    end

    wire [3:0] m_clks_out, m_datas_out;
    wire [3:0] m_clks_in = {4{sys_clk}};
    wire [11:0] m_datas_in = {m3_data, m2_data, m1_data, m0_data};

    wire nTx, eth_clk;
    reg nTF = 1;

    backend backend_inst (
        .clk_100_p(clk_100),
        .clk_100_n(~clk_100),
        .sys_clk_p(sys_clk),
        .sys_clk_n(~sys_clk),
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
        .gigex_spi_sck(spi_clk),
        .gigex_spi_mosi(spi_mosi),
        .gigex_spi_miso(spi_miso),

        .user_hs_clk(eth_clk),
        .Q(8'h00), .nRx(1'b1), .RC(3'd0), .nRF(),
        .D(), .nTx(nTx), .TC(), .nTF({ {7{1'b1}}, nTF })
    );
    
    data_rx #(.LENGTH(32), .LINES(1)) m0_rx_inst (
        .clk(m_clks_out[0]),
        .d(m_datas_out[0]),
        .valid(),
        .data()
    );

    data_tx m0_tx_inst (
        .clk(sys_clk),
        .rst(0),
        .valid(m0_data_valid),
        .ready(m0_data_ready),
        .data_in({8{16'hFF00}}), //{packet_header, m0_data_in}),
        .d(m0_data)
    );
    
    data_tx m1_tx_inst (
        .clk(sys_clk),
        .rst(0),
        .valid(m1_data_valid),
        .ready(m1_data_ready),
        .data_in({packet_header, m1_data_in}),
        .d(m1_data)
    );

    data_tx m2_tx_inst (
        .clk(sys_clk),
        .rst(0),
        .valid(1'b0),
        .ready(),
        .data_in(128'h0),
        .d(m2_data)
    );

    data_tx m3_tx_inst (
        .clk(sys_clk),
        .rst(0),
        .valid(1'b0),
        .ready(),
        .data_in(128'h0),
        .d(m3_data)
    );

    initial begin
        is_single = 1;
        is_cmd = 0;
        m0_data_in = 32'hFFFF_FFFF;

        #10_000 @ (negedge sys_rst_mask[0]) do_rst = 1;
        @ (posedge sys_clk) do_rst = 0;
        #10_000

        @(posedge sys_clk) m0_data_valid = 1'b1;
        #100 m0_data_valid = 1'b0;

        @(negedge nTx);
        @(negedge eth_clk);
        #50;
        nTF = 0;
        #100;
        nTF = 1;

        /*
        spi_data_in = 32'hF064_04F1;
        spi_query();
        #10_000;

        spi_data_in = 32'hF030_0000;
        spi_query();
        #10_000;

        m0_data_in = 32'hF130_ABCD;
        @(posedge sys_clk) m0_data_valid = 1'b1;
        #100 m0_data_valid = 1'b0;

        #10_000;

        spi_data_in = 0;
        spi();
        */

        #10_000;
        $stop;
    end
    
endmodule
