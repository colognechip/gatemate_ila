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
    parameter samples_count_before_trigger = 200,
    parameter bits_samples_count_before_trigger = 8,
    parameter bits_samples_count = 9,
    parameter sample_width = 20,
    parameter BRAM_matrix_wide = 1,
    parameter BRAM_matrix_deep = 1,
    parameter BRAM_single_wide = 5,
    parameter BRAM_single_deep = 9
    
)(
    input i_clk_ILA,
    input i_reset,
    input i_read_active,
    input [(sample_width-1):0] i_sample,
    input i_slave_end_byte_nedge_edge,
    input i_trigger_triggered,
    output [7:0] o_send_byte,
    output o_write_done,
    input  [5:0] trigger_row,
    output [(BRAM_single_wide-1):0] trigger_out
);

wire [(sample_width-1):0] RAM_smp_out;

reg write_done;

parameter ma_deep_ad =  $clog2(BRAM_matrix_deep);

reg [((BRAM_single_deep+ma_deep_ad)-1):0] addr_cnt_rd;
reg [((BRAM_single_deep+ma_deep_ad)-1):0] addr_cnt_wd;


reg [bits_samples_count:0] wd_counter;
wire i_clk_BRAM;

assign i_clk_BRAM = !i_clk_ILA;
wire [(BRAM_single_wide-1):0] data_in_pipe  [(BRAM_matrix_wide-1):0];
wire [(BRAM_matrix_deep-1):0] we_BRAM;
wire [(BRAM_single_wide*BRAM_matrix_wide)-1:0] BRAM_do_tmp [BRAM_matrix_deep-1:0];


parameter rest = ((BRAM_single_wide*BRAM_matrix_wide) % sample_width);
assign trigger_out = data_in_pipe[trigger_row];



generate
    genvar i, j;
    for (i = 0; i < BRAM_matrix_deep; i = i+1) begin : loop_init
        if (BRAM_matrix_deep == 1) begin
            assign we_BRAM[i] = !write_done; 
        end else begin
            assign we_BRAM[i] = ((!write_done) & (addr_cnt_wd[((BRAM_single_deep+ma_deep_ad)-1):BRAM_single_deep] == i));
        end
    end
    for (j = 0; j < BRAM_matrix_wide; j = j +1) begin : loop
        if (j == (BRAM_matrix_wide-1)) begin 
            assign data_in_pipe[j] = {{rest{1'b0}}, i_sample[(sample_width-1):(BRAM_single_wide)*(j)]};
        end
        else begin 
                assign data_in_pipe[j] = i_sample[((BRAM_single_wide)*(j+1)-1):(BRAM_single_wide)*(j)];
        end
        for (i = 0; i < BRAM_matrix_deep; i = i+1) begin : loop
            bram_ila  #(.DATA_WIDTH(BRAM_single_wide), 
                        .ADDR_WIDTH(BRAM_single_deep)) 
            ila_bram   (.clk(i_clk_BRAM), 
                        .we(we_BRAM[i]),
                        .di(i_sample[((BRAM_single_wide)*(j+1)-1):(BRAM_single_wide)*(j)]),
                        .addr_read(addr_cnt_rd[BRAM_single_deep-1:0]),
                        .addr_write(addr_cnt_wd[BRAM_single_deep-1:0]),
                        .do(BRAM_do_tmp[i][(BRAM_single_wide*(j+1))-1 :BRAM_single_wide*j]));
        end
    end
    if (BRAM_matrix_deep == 1) begin
        assign RAM_smp_out = BRAM_do_tmp[0][(sample_width-1):0];
    end else begin
        assign RAM_smp_out = BRAM_do_tmp[addr_cnt_rd[((BRAM_single_deep+ma_deep_ad)-1):BRAM_single_deep]][(sample_width-1):0];
    end

endgenerate

wire period_done_sig;

nedge_edge_detection wd_cnt_done_edge (.i_clk(i_clk_ILA), .i_reset(i_reset), .i_signal(addr_cnt_wd[bits_samples_count]), .o_nedge_edge(period_done_sig));


reg period_done;

always @(posedge i_clk_ILA) begin  
    if (!i_reset) begin
        period_done <= 0;
    end else if (!period_done & period_done_sig) begin
        period_done <= 1;
    end
end
wire rd_nxt;

wire initial_done_sig; 

nedge_edge_detection initial_done_edge (.i_clk(i_clk_ILA), .i_reset(i_reset), .i_signal(addr_cnt_wd[bits_samples_count_before_trigger]), .o_nedge_edge(initial_done_sig));

reg initial_done;

always @(posedge i_clk_ILA) begin  
    if (!i_reset) begin
        initial_done <= 0;
    end else if (!initial_done & initial_done_sig) begin
        initial_done <= 1;
    end
end


always @(posedge i_clk_ILA) begin         
    if (!i_reset) begin
        addr_cnt_rd <= 0;
    end
    else if ((!write_done & period_done) | rd_nxt) begin 
        addr_cnt_rd <= addr_cnt_rd+1;
    end
end


always @(posedge i_clk_ILA) begin
    if (!i_reset) begin
        addr_cnt_wd <= 0;
    end
    else begin
            addr_cnt_wd <= addr_cnt_wd + 1;
    end
end


reg make_wd_cnt;
always @(posedge i_clk_ILA) begin
    if (!i_reset) begin
        make_wd_cnt <= 0;
    end
    else if ((!write_done) & i_trigger_triggered & initial_done) begin
        make_wd_cnt <= 1;
    end
    else begin
        make_wd_cnt <= 0;
    end
end

always @(posedge i_clk_ILA) begin
    if (!i_reset) begin
        wd_counter <= samples_count_before_trigger;
    end
    else if (make_wd_cnt) begin
        wd_counter <= wd_counter + 1;
    end
end

wire write_done_edge_nedge;

nedge_edge_detection write_done_edge (.i_clk(i_clk_ILA), .i_reset(i_reset), .i_signal(wd_counter[bits_samples_count]), .o_nedge_edge(write_done_edge_nedge));


always  @(posedge i_clk_ILA) begin
    if (!i_reset) begin 
        write_done <= 0;
    end
    else if(write_done_edge_nedge) begin
        write_done <= 1;
    end
end

assign o_write_done = write_done;



generate
    if (sample_width > 8) begin 
        smp_to_byte #(.sample_width(sample_width)) byte_from_smp (.i_clk_ILA(i_clk_ILA), .i_read_active(i_read_active), 
                                                        .i_ram_sample(RAM_smp_out),
                                                        .i_slave_end_byte_nedge_edge(i_slave_end_byte_nedge_edge),
                                                        .o_send_byte(o_send_byte), .o_rd(rd_nxt));
    end
    else begin
        assign o_send_byte = RAM_smp_out;
        assign rd_nxt = i_slave_end_byte_nedge_edge;
    end
endgenerate

endmodule