/*
#################################################################################################
#   << CologneChip GateMate ILA - BRAM Control >>                                               #
#   Control of the address and data lines of the BRAM                                           #
# ********************************************************************************************* #
#    Copyright (C) 2023 Cologne Chip AG <support@colognechip.com>                               #
#    Developed by Dave Fohrn                                                                    #
#                                                                                               #
#    This program is free software: you can redistribute it and/or modify                       #
#    it under the terms of the GNU General Public License as published by                       #
#    the Free Software Foundation, either version 3 of the License, or                          #
#    (at your option) any later version.                                                        #
#                                                                                               #
#    This program is distributed in the hope that it will be useful,                            #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of                             #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                              #
#    GNU General Public License for more details.                                               #
#                                                                                               #
#    You should have received a copy of the GNU General Public License                          #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.                     #
#                                                                                               #
# ********************************************************************************************* #
#################################################################################################
*/

module bram_control#(
    parameter [14:0] ALMOST_EMPTY_OFFSET = 15'hf,
    parameter FIFO_IN_WIDTH = 5,
    parameter FIFO_MATRIX_WIDTH = 3,
    parameter FIFO_MATRIX_DEPH = 1,
    parameter SIGNAL_SYNCHRONISATION = 0,
    parameter sample_width = 20
)(
    input i_clk_ILA,
    input i_sclk,
    input i_reset,
    input i_read_active,
    input [(sample_width-1):0] i_sample,
    input i_slave_end_byte_post_edge,
    input i_trigger_triggered,
    output [3:0] o_send_nib,
    output wire o_write_done,
    input  [5:0] trigger_row,
    output [(FIFO_IN_WIDTH-1):0] trigger_out
);

parameter rest = ((FIFO_IN_WIDTH*FIFO_MATRIX_WIDTH) - sample_width);
wire [((FIFO_IN_WIDTH*FIFO_MATRIX_WIDTH)-1):0] FIFO_DI, FIFO_DO;
wire [(sample_width-1):0] o_sample;

wire rd_nxt, FIFO_FULL, FIFO_ALMOST_EMPTY, FIFO_EMPTY, FIFO_POP;
reg write_done;
wire FIFO_clk;
assign FIFO_clk = write_done ? i_sclk : i_clk_ILA;

assign o_sample = FIFO_DO[(sample_width-1):0];


wire [(sample_width-1):0] DI_wire;
generate
    if (SIGNAL_SYNCHRONISATION > 0) begin
        genvar i;
        reg [(sample_width-1):0] sync_DI [(SIGNAL_SYNCHRONISATION-1):0];
        always @(negedge i_clk_ILA) begin 
            if (!i_reset) begin
                sync_DI[0] <= 0;
            end else begin  
                sync_DI[0] <= i_sample;
            end
        end
        for (i = 1; i < SIGNAL_SYNCHRONISATION; i = i+1) begin : loop
            always @(negedge i_clk_ILA) begin
                if (!i_reset) begin
                    sync_DI[i] <= 0;
                end else begin   
                    sync_DI[i] <= sync_DI[i-1];
                end
            end
        end
        assign DI_wire = sync_DI[SIGNAL_SYNCHRONISATION-1];
    end else begin
        assign DI_wire = i_sample;
    end
endgenerate
        assign FIFO_DI = {{rest{1'b0}}, DI_wire};
FIFO_cascading_WIDTH #(
    .WIDTH(FIFO_IN_WIDTH),
    .WIDTH_cnt(FIFO_MATRIX_WIDTH),
    .DEPH(FIFO_MATRIX_DEPH),
    .ALMOST_EMPTY_OFFSET(ALMOST_EMPTY_OFFSET)
) FIFO_cas (
    .rclk(FIFO_clk),
    .wclk(FIFO_clk),
    .rst(i_reset),
    .PUSH_i(!write_done),
    .POP_i(FIFO_POP),
    .DI(FIFO_DI),
    .DO(FIFO_DO),
    .FULL_o(FIFO_FULL),
    .ALMOST_FULL_o(),
    .EMPTY_o(FIFO_EMPTY),
    .ALMOST_EMPTY_o(FIFO_ALMOST_EMPTY),
    .trigger_row(trigger_row),
    .trigger_out(trigger_out)
    
);

always  @(posedge i_clk_ILA) begin
    if (!i_reset) begin 
        write_done <= 0;
    end
    else if(FIFO_FULL) begin
        write_done <= 1;
    end
end
assign FIFO_POP = write_done ? rd_nxt : (i_trigger_triggered ? 0 : !FIFO_ALMOST_EMPTY);

assign o_write_done = write_done;



generate
    if (sample_width > 4) begin 
        smp_to_byte #(.sample_width(sample_width)) byte_from_smp (.i_clk_ILA(i_sclk), .i_read_active(i_read_active), 
                                                        .i_ram_sample(o_sample),
                                                        .i_slave_end_byte_post_edge(i_slave_end_byte_post_edge),
                                                        .o_send_nib(o_send_nib), .o_rd(rd_nxt));
    end
    else begin
        reg [3:0] send_nib_sync;
        localparam rest_send_byte = 8 - sample_width;
        always  @(posedge i_sclk) begin
            if (!i_read_active) begin 
                send_nib_sync <= 0;
            end
            else begin
                send_nib_sync <= {{rest_send_byte{1'b0}}, o_sample};
            end
        end
        assign o_send_nib = send_nib_sync;
        assign rd_nxt = i_slave_end_byte_post_edge;
    end
endgenerate

endmodule