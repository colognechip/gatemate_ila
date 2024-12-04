
module FIFO_cascading_WIDTH #(
    parameter WIDTH=5,
    parameter WIDTH_cnt=3,
    parameter DEPH = 3,
    parameter [14:0] ALMOST_EMPTY_OFFSET = 15'hf
)(
    (* clkbuf_inhibit *) input wire rclk,
    input wire wclk,
    input wire rst,
    input wire PUSH_i,
    input wire POP_i,
    input wire [(WIDTH_cnt*WIDTH)-1:0] DI,
    output wire [(WIDTH_cnt*WIDTH)-1:0] DO,
    output wire FULL_o,
    output wire ALMOST_FULL_o,
    output wire EMPTY_o,
    output wire ALMOST_EMPTY_o,
    input wire [5:0] trigger_row,
    output wire [(WIDTH-1):0] trigger_out
);



wire [WIDTH-1:0] BRAM_do_tmp [WIDTH_cnt-1:0];
wire [WIDTH-1:0] BRAM_di_tmp [WIDTH_cnt-1:0];
wire [WIDTH_cnt-1:0] EMPTY, PUSH, POP, FULL, ALMOST_FULL, ALMOST_EMPTY;
assign ALMOST_FULL_o = ALMOST_FULL[0];
assign EMPTY_o = EMPTY[0];
assign ALMOST_EMPTY_o = ALMOST_EMPTY[0];
assign FULL_o = FULL[0];

assign trigger_out = BRAM_di_tmp[trigger_row];

generate
    genvar i;
    for (i = 0; i < WIDTH_cnt; i = i+1) begin : loop_con_sync
        
        assign BRAM_di_tmp[i] = DI[((i+1)*WIDTH)-1:i*WIDTH];
        assign DO[((i+1)*WIDTH)-1:i*WIDTH] = BRAM_do_tmp[i];
        assign PUSH[i] = PUSH_i;
        assign POP[i] = POP_i;
        FIFO_cascading_DEPH #(
        .WIDTH(WIDTH),
        .DEPH(DEPH),
        .ALMOST_EMPTY_OFFSET(ALMOST_EMPTY_OFFSET)
        ) fifo_inst (
            .rclk(rclk),
            .wclk(wclk),
            .rst(rst),
            .PUSH_i(PUSH[i]),
            .POP_i(POP[i]),
            .DI(BRAM_di_tmp[i]),
            .DO(BRAM_do_tmp[i]),
            .FULL_o(FULL[i]),
            .ALMOST_FULL_o(ALMOST_FULL[i]),
            .EMPTY_o(EMPTY[i]),
            .ALMOST_EMPTY_o(ALMOST_EMPTY[i])
        );
    end
endgenerate

endmodule 