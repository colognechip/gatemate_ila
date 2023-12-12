// Company           :   RacyICs GmbH
// Author            :   winter
// E-Mail            :   <email>
//
// Filename          :   refmem_split.v
// Project Name      :   p_cc
// Subproject Name   :   s_fpga
// Description       :   <short description>
//
// Create Date       :   Tue Aug  6 12:47:52 2013
// Last Change       :   $Date: 2016-06-07 13:51:00 +0200 (Tue, 07 Jun 2016) $
// by                :   $Author: glueck $
//------------------------------------------------------------

`timescale 1 ns / 1 ps

module refmem_split
  #(parameter CONFIG_1BIT  = 3'd1, //non-split-->32k x 1 bit; split-->16K x 1 bit
    parameter CONFIG_2BIT  = 3'd2, //non-split-->16k x 2 bit; split-->8K x 2 bit
    parameter CONFIG_5BIT  = 3'd3, //non-split-->8k  x 5 bit; split-->4K x 5 bit
    parameter CONFIG_10BIT = 3'd4, //non-split-->4k  x 10 bit; split-->2K x 10 bit
    parameter CONFIG_20BIT = 3'd5, //non-split-->2k  x 20 bit; split-->1K x 20 bit
    parameter CONFIG_40BIT = 3'd6, //non-split-->1K  x 40 bit; split (SPR)-->512 x 40 bit
    parameter CONFIG_80BIT = 3'd7, //non-split(SPR)-->512 x 80 bit; split-->NA

    parameter  CONFIG_TDP_NONSPLIT = 3'd0,
    parameter  CONFIG_TDP_SPLIT    = 3'd1,
    parameter  CONFIG_SDP_NONSPLIT = 3'd2,
    parameter  CONFIG_SDP_SPLIT    = 3'd3,
    parameter  CONFIG_FIFO_ASYNC   = 3'd7,
    parameter  CONFIG_FIFO_SYNC    = 3'd6,
    parameter  CONFIG_CASCADE_UP   = 3'd5,
    parameter  CONFIG_CASCADE_LOW  = 3'd4
    )
   (// configuration required for nonsplit reference memory
    input  wire [2:0]  cfg_sram_mode_i,
    input  wire [2:0]  cfg_input_config_a_i,
    input  wire [2:0]  cfg_input_config_b_i,
    input  wire [2:0]  cfg_output_config_a_i,
    input  wire [2:0]  cfg_output_config_b_i,
    input  wire        cfg_set_outputreg_a_i,
    input  wire        cfg_set_outputreg_b_i,
    input  wire        cfg_ecc_enable_i,
    input  wire [5:0]  cfg_sram_delay_i,

    // RAM connections of port A
    input  wire        a_clk_i,
    input  wire        a_cs_i,
    input  wire        a_re_i,
    input  wire        a_we_i,
    input  wire [15:0] a_addr_i,
    input  wire [39:0] a_wrdata_i,
    input  wire [39:0] a_bitmask_i,
    output wire [39:0] a_rddata_o,

    // RAM connections of port B
    input  wire        b_clk_i,
    input  wire        b_cs_i,
    input  wire        b_re_i,
    input  wire        b_we_i,
    input  wire [15:0] b_addr_i,
    input  wire [39:0] b_wrdata_i,
    input  wire [39:0] b_bitmask_i,
    output wire [39:0] b_rddata_o,

    output wire        ecc_single_error_flag_o,
    output wire        ecc_double_error_flag_o
    );

   task shift_input;
      input [2:0]   input_config;
      input [15:0]  addr_in;
      input [39:0]  wrdata_in;
      input [39:0]  bitmask_in;
      output [39:0] wrdata_out;
      output [39:0] bitmask_out;

      reg [8:0]     addr;
      integer i;

      begin
         case(input_config)
           CONFIG_1BIT : begin
              addr = addr_in[5:1] + (addr_in[5:1]/4);
              wrdata_out  = 'd0;
              bitmask_out = 'd0;
              wrdata_out  = wrdata_in[0]  << addr;
              bitmask_out = bitmask_in[0] << addr;
           end
           CONFIG_2BIT : begin
              addr        = addr_in[5:2]*2 + (addr_in[5:2]/2);
              wrdata_out  = 'd0;
              bitmask_out = 'd0;
              wrdata_out  = wrdata_in[1:0]  << addr;
              bitmask_out = bitmask_in[1:0] << addr;
           end
           CONFIG_5BIT : begin
              addr = addr_in[5:3]*5;
              wrdata_out  = 'd0;
              bitmask_out = 'd0;
              wrdata_out  = wrdata_in[4:0]  << addr;
              bitmask_out = bitmask_in[4:0] << addr;
           end
           CONFIG_10BIT: begin
              addr = addr_in[5:4]*10;
              wrdata_out  = 'd0;
              bitmask_out = 'd0;
              wrdata_out  = wrdata_in[9:0]  << addr;
              bitmask_out = bitmask_in[9:0] << addr;
           end
           CONFIG_20BIT: begin
              addr = addr_in[5:5]*20;
              wrdata_out  = 'd0;
              bitmask_out = 'd0;
              wrdata_out  = wrdata_in[19:0]  << addr;
              bitmask_out = bitmask_in[19:0] << addr;
           end
           CONFIG_40BIT: begin
              wrdata_out  = wrdata_in[39:0] ;
              bitmask_out = bitmask_in[39:0];
           end
         endcase // case (input_config)
      end
   endtask

   task shift_output;
      input [2:0]   output_config;
      input [15:0]  addr_in;
      input [39:0]  rddata_in;
      output [39:0] rddata_out;

      reg [8:0]     addr;

      begin
         case(output_config)
           CONFIG_1BIT : begin
              addr = addr_in[5:1] + (addr_in[5:1]/4);
              rddata_out = rddata_in >> addr;
              rddata_out[39:1] = 'd0;
           end
           CONFIG_2BIT : begin
              addr = addr_in[5:2]*2 + (addr_in[5:2]/2);
              rddata_out = rddata_in >> addr;
              rddata_out[39:2] = 'd0;
           end
           CONFIG_5BIT : begin
              addr = addr_in[5:3]*5;
              rddata_out = rddata_in >> addr;
              rddata_out[39:5] = 'd0;
           end
           CONFIG_10BIT: begin
              addr = addr_in[5:4]*10;
              rddata_out = rddata_in >> addr;
              rddata_out[39:10] = 'd0;
           end
           CONFIG_20BIT: begin
              addr = addr_in[5:5]*20;
              rddata_out = rddata_in >> addr;
              rddata_out[39:20] = 'd0;
           end
           CONFIG_40BIT: begin
              rddata_out = rddata_in;
           end
         endcase // case (input_config)
      end
   endtask


   wire [39:0]         a_wrdata_ecc, b_wrdata_ecc;
   assign a_wrdata_ecc[39] = 1'b0;
   assign b_wrdata_ecc[39] = 1'b0;
   ecc_encode ecc_encode_a_i0(.data_in({a_wrdata_i[35:20],a_wrdata_i[15: 0]}),.code_out({a_wrdata_ecc[38: 0]}));
   ecc_encode ecc_encode_b_i0(.data_in({b_wrdata_i[35:20],b_wrdata_i[15: 0]}),.code_out({b_wrdata_ecc[38: 0]}));

   reg [39:0]         a_wrdata, b_wrdata, a_bitmask, b_bitmask;
   wire [39:0]        a_rddata, b_rddata;
   always@* begin
      if(cfg_ecc_enable_i) begin
         shift_input(cfg_input_config_a_i, a_addr_i, a_wrdata_ecc, a_bitmask_i & 40'hfffff_fffff, a_wrdata, a_bitmask);
         shift_input(cfg_input_config_b_i, b_addr_i, b_wrdata_ecc, b_bitmask_i & 40'hfffff_fffff, b_wrdata, b_bitmask);
      end
      else begin
         shift_input(cfg_input_config_a_i, a_addr_i, a_wrdata_i, a_bitmask_i, a_wrdata, a_bitmask);
         shift_input(cfg_input_config_b_i, b_addr_i, b_wrdata_i, b_bitmask_i, b_wrdata, b_bitmask);
      end
   end

   //always@(posedge a_clk_i) begin
   //   if( (a_addr_i & 16'h7fc0) == (16'hf058 & 16'h7fc0) ) begin
   //      if(a_cs_i && a_re_i)
   //        $write("INFO REF %d: reading at port A at addr 0x%x!\n", $time, a_addr_i);
   //      if(a_cs_i && a_we_i)
   //        $write("INFO REF %d: writing at port A at addr 0x%x with data=0x%x, bitmask=0x%x!\n",
   //               $time, a_addr_i, a_wrdata, a_bitmask);
   //   end
   //end
   //always@(posedge b_clk_i) begin
   //   if( (b_addr_i & 16'h7fc0) == (16'hf058 & 16'h7fc0) ) begin
   //      if(b_cs_i && b_re_i)
   //        $write("INFO REF %d: reading at port B at addr 0x%x!\n", $time, b_addr_i);
   //      if(b_cs_i && b_we_i)
   //        $write("INFO REF %d: writing at port B at addr 0x%x with data=0x%x, bitmask=0x%x!\n",
   //               $time, b_addr_i, b_wrdata, b_bitmask);
   //   end
   //end

    RM_GF28SLP_2P_core_1cr
   #(.P_DATA_WIDTH(40),
     .P_ADDR_WIDTH(9),
     .P_COUNT(512) )
   memory
     (.A_CLK_I (a_clk_i       ),
      .A_CS_I  (a_cs_i        ),
      .A_ADDR_I(a_addr_i[14:6]),
      .A_DW_I  (a_wrdata      ),
      .A_BM_I  (a_bitmask     ),
      .A_WE_I  (a_we_i        ),
      .A_RE_I  (a_re_i        ),
      .A_DR_O  (a_rddata      ),

      .B_CLK_I (b_clk_i       ),
      .B_CS_I  (b_cs_i        ),
      .B_ADDR_I(b_addr_i[14:6]),
      .B_DW_I  (b_wrdata      ),
      .B_BM_I  (b_bitmask     ),
      .B_WE_I  (b_we_i        ),
      .B_RE_I  (b_re_i        ),
      .B_DR_O  (b_rddata      ),

      .A_DLYL_I  (cfg_sram_delay_i[5:4]),
      .A_DLYH_I  (cfg_sram_delay_i[3:2]),
      .A_DLYCLK_I(cfg_sram_delay_i[1:0]),
      .B_DLYL_I  (cfg_sram_delay_i[5:4]),
      .B_DLYH_I  (cfg_sram_delay_i[3:2]),
      .B_DLYCLK_I(cfg_sram_delay_i[1:0]));

   // shift read data
   reg [15:0]          r_a_addr, r_b_addr;
   always@(posedge a_clk_i) if(a_re_i) r_a_addr <= a_addr_i;
   always@(posedge b_clk_i) if(b_re_i) r_b_addr <= b_addr_i;

   reg [39:0]          a_rddata_shifted, b_rddata_shifted;
   always@* begin
      shift_output(cfg_output_config_a_i, r_a_addr, a_rddata, a_rddata_shifted);
      shift_output(cfg_output_config_b_i, r_b_addr, b_rddata, b_rddata_shifted);
   end

   // ECC correct read data
   wire [39:0]         a_rddata_ecc, b_rddata_ecc;
   wire                single_error_flag_a, single_error_flag_b;
   wire                double_error_flag_a, double_error_flag_b;
   assign a_rddata_ecc[19:16] = 4'd0;
   assign a_rddata_ecc[39:36] = 4'd0;
   assign b_rddata_ecc[19:16] = 4'd0;
   assign b_rddata_ecc[39:36] = 4'd0;
   ecc_decode ecc_decode_a_i0(.code_in({a_rddata_shifted[38: 0]}),.data_out({a_rddata_ecc[35:20],a_rddata_ecc[15: 0]}),.single_error(single_error_flag_a),.double_error(double_error_flag_a));
   ecc_decode ecc_decode_b_i0(.code_in({b_rddata_shifted[38: 0]}),.data_out({b_rddata_ecc[35:20],b_rddata_ecc[15: 0]}),.single_error(single_error_flag_b),.double_error(double_error_flag_b));

   wire [39:0]         a_rddata_out, b_rddata_out;
   wire                ecc_single_error_flag_out;
   wire                ecc_double_error_flag_out;
   assign a_rddata_out[39: 0] = (cfg_ecc_enable_i==1'b1) ? a_rddata_ecc[39: 0] : a_rddata_shifted[39: 0];
   assign b_rddata_out[39: 0] = (cfg_ecc_enable_i==1'b1) ? b_rddata_ecc[39: 0] : b_rddata_shifted[39: 0];
   assign ecc_single_error_flag_out  = (cfg_sram_mode_i==CONFIG_SDP_SPLIT && cfg_ecc_enable_i==1'b1) ? single_error_flag_b : 1'b0;
   assign ecc_double_error_flag_out  = (cfg_sram_mode_i==CONFIG_SDP_SPLIT && cfg_ecc_enable_i==1'b1) ? double_error_flag_b : 1'b0;

   // output register read data
   reg [39:0]          r_a_rddata_out, r_b_rddata_out;
   reg                 r_ecc_single_error_flag_out;
   reg                 r_ecc_double_error_flag_out;
   always@(posedge a_clk_i) r_a_rddata_out <= a_rddata_out;
   always@(posedge b_clk_i) r_b_rddata_out <= b_rddata_out;
   always@(posedge b_clk_i) r_ecc_single_error_flag_out <= ecc_single_error_flag_out;//CRC only possible in SDP-SPLIT (B is read port)
   always@(posedge b_clk_i) r_ecc_double_error_flag_out <= ecc_double_error_flag_out;//CRC only possible in SDP-SPLIT (B is read port)

   // put data out
   assign a_rddata_o = (cfg_set_outputreg_a_i) ? r_a_rddata_out : a_rddata_out;
   assign b_rddata_o = (cfg_set_outputreg_b_i) ? r_b_rddata_out : b_rddata_out;
   assign ecc_single_error_flag_o = (cfg_set_outputreg_a_i) ? r_ecc_single_error_flag_out : ecc_single_error_flag_out; // no output registering
   assign ecc_double_error_flag_o = (cfg_set_outputreg_a_i) ? r_ecc_double_error_flag_out : ecc_double_error_flag_out; // no output registering

endmodule // refmem_split
