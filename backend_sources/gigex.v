`timescale 1ns / 1ps

module gigex (
    input wire sys_clk,
    input wire eth_clk,

    // data from the system
    input wire [127:0] data_out,
    input wire data_out_valid,
    output wire data_out_ready,

    // commands from the system
    input wire [31:0] cmd_out,
    input wire cmd_out_valid,
    output wire cmd_out_ready,

    // commands to the system
    output wire [31:0] cmd_in,
    output wire cmd_in_valid,
    input wire cmd_in_ready,

    // async info from the system
    input wire [31:0] info_out,
    input wire info_out_valid,
    output wire info_out_ready,

    // gigex ports

    input  wire [7:0] Q,    // Rx data from gigex
    input  wire nRx,        // Rx data valid from gigex, active low
    input  wire [2:0] RC,   // Rx data channel from gigex
    output wire [7:0] nRF,  // Rx fifo full flag to gigex, active low
 
    output reg [7:0] D,     // Tx data to gigex
    output wire nTx,        // Tx data valid to gigex
    output reg [2:0] TC,    // Tx data channel to gigex
    input  wire [7:0] nTF   // Tx fifo full flag from gigex
);

    genvar i;

    // Flip byte ordering so that MSB is sent first
    wire [127:0] data_out_flip;
    generate for (i = 0; i < 128/8; i = i + 1) begin
        assign data_out_flip[(i*8) +: 8] = data_out[127-(i*8) -: 8];
    end endgenerate

    wire [31:0] cmd_out_flip;
    generate for (i = 0; i < 32/8; i = i + 1) begin
        assign cmd_out_flip[(i*8) +: 8] = cmd_out[31-(i*8) -: 8];
    end endgenerate

    wire [31:0] info_out_flip;
    generate for (i = 0; i < 32/8; i = i + 1) begin
        assign info_out_flip[(i*8) +: 8] = info_out[31-(i*8) -: 8];
    end endgenerate

    wire data_full, data_emp, data_read;
    wire cmd_full, cmd_emp, cmd_read;
    wire info_full, info_emp, info_read;

    wire [7:0] gigex_data, gigex_cmd, gigex_info;
    assign data_out_ready = ~data_full;
    assign cmd_out_ready = ~cmd_full;
    assign info_out_ready = ~info_full;
    wire data_valid = ~data_emp;
    wire cmd_valid  = ~cmd_emp;
    wire info_valid = ~info_emp;

    xpm_fifo_async #(
        .FIFO_READ_LATENCY(0),
        .READ_MODE("fwft"),
        .FIFO_WRITE_DEPTH(16),
        .WRITE_DATA_WIDTH(128),
        .READ_DATA_WIDTH(8)
    ) eth_fifo_data_tx_inst (
        .rst(1'b0),
        .din(data_out_flip),
        .wr_en(data_out_ready & data_out_valid),
        .wr_clk(sys_clk),
        .full(data_full),
        .dout(gigex_data),
        .rd_en(data_read),
        .rd_clk(eth_clk),
        .empty(data_emp));

    xpm_fifo_async #(
        .FIFO_READ_LATENCY(0),
        .READ_MODE("fwft"),
        .FIFO_WRITE_DEPTH(16),
        .WRITE_DATA_WIDTH(32),
        .READ_DATA_WIDTH(8)
    ) eth_fifo_cmd_tx_inst (
        .rst(1'b0),
        .din(cmd_out_flip),
        .wr_en(cmd_out_ready & cmd_out_valid),
        .wr_clk(sys_clk),
        .full(cmd_full),
        .dout(gigex_cmd),
        .rd_en(cmd_read),
        .rd_clk(eth_clk),
        .empty(cmd_emp));

    xpm_fifo_async #(
        .FIFO_READ_LATENCY(0),
        .READ_MODE("fwft"),
        .FIFO_WRITE_DEPTH(16),
        .WRITE_DATA_WIDTH(32),
        .READ_DATA_WIDTH(8)
    ) eth_fifo_info_tx_inst (
        .rst(1'b0),
        .din(info_out_flip),
        .wr_en(info_out_ready & info_out_valid),
        .wr_clk(sys_clk),
        .full(info_full),
        .dout(gigex_info),
        .rd_en(info_read),
        .rd_clk(eth_clk),
        .empty(info_emp));

    // delay the nTF signals according to the data sheet
    reg [7:0] nTF1 = 0, nTF2 = 0, nTF3 = 0;
    wire [7:0] chn_ready = nTF2 | nTF3;
    always @ (posedge eth_clk) begin
        nTF1 <= nTF;
        nTF2 <= nTF1;
        nTF3 <= nTF2;
    end

    wire info_ready = chn_ready[2];
    wire cmd_ready  = chn_ready[1];
    wire data_ready = chn_ready[0];

    assign info_read = info_ready & info_valid;
    assign cmd_read  = cmd_ready  & cmd_valid  & ~(info_read);
    assign data_read = data_ready & data_valid & ~(info_read | cmd_read);
    assign nTx = ~(info_read | cmd_read | data_read);

    always @(*) begin
        if (info_read) begin
            TC = 3'd2;
            D  = gigex_info;
        end else if (cmd_read) begin
            TC = 3'd1;
            D  = gigex_cmd;
        end else begin
            TC = 3'd0;
            D  = gigex_data;
        end
    end

    // receive data from gigex
    wire [31:0] cmd_in_flip;
    generate for (i = 0; i < 32/8; i = i + 1) begin
        assign cmd_in[(i*8) +: 8] = cmd_in_flip[31-(i*8) -: 8];
    end endgenerate

    wire eth_rx_empty, eth_rx_full;
    assign cmd_in_valid = ~eth_rx_empty;
    xpm_fifo_async #(
        .FIFO_READ_LATENCY(0),
        .READ_MODE("fwft"),
        .FIFO_WRITE_DEPTH(64),
        .WRITE_DATA_WIDTH(8),
        .READ_DATA_WIDTH(32),
        .PROG_FULL_THRESH(53)
    ) eth_fifo_rx_inst (
        .rst(1'b0),
        .din(Q),
        .wr_en(~nRx),
        .wr_clk(eth_clk),
        .full(),
        .prog_full(eth_rx_full),
        .dout(cmd_in_flip),
        .rd_en(cmd_in_valid & cmd_in_ready),
        .rd_clk(sys_clk),
        .empty(eth_rx_empty));

    assign nRF[0] = ~eth_rx_full;
    assign nRF[7:1] = {7{1'b1}};

endmodule
