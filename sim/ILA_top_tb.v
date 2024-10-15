`timescale 1 ns/10 ps

//  Simulation der Logik:
//  iverilog -D sim -o ILA_top_tb.vvp sim/blink.v sim/ILA_top_tb.v sim/SPI_master.v src/storage/* src/*.v 
//  vvp ILA_top_tb.vvp -lxt2
//
// Post-Synthse:
// iverilog -Winfloop -g2012 -gspecify -Ttyp -o sim/synth_sim.vvp ../../bin/yosys/share/gatemate/cells_sim.v net/ila_top_synth24-06-26_18-05-41.v.v sim/ILA_top_tb.v sim/SPI_master.v
// vvp sim/synth_sim.vvp -lxt2
//
// Post-Implementation Symulation:
//
//  iverilog -Winfloop -g2012 -gspecify -Ttyp -o sim/impl_sim.vvp sim/fpga_ram/* ../../bin/p_r/cpelib.v p_r_out/ila_top_24-06-26_18-05-41.v sim/ILA_top_tb.v sim/SPI_master.v 
//  vvp sim/impl_sim.vvp -lxt2

// Within the module "cc_pll," the sampling frequency needs to be configured.
module CC_PLL #(
  parameter PLL_CFG = 96'b0,
  parameter REF_CLK = "", // e.g. "10.0"
  parameter OUT_CLK = "", // e.g. "50.0"
  parameter PERF_MD = "", // LOWPOWER, ECONOMY, SPEED
  parameter LOW_JITTER = 1,
  parameter CI_FILTER_CONST = 2,
  parameter CP_FILTER_CONST = 4
  )(
  input CLK_REF, CLK_FEEDBACK, USR_CLK_REF,
  input USR_LOCKED_STDY_RST, USR_SET_SEL,
  output USR_PLL_LOCKED_STDY, USR_PLL_LOCKED,
  output CLK270, CLK180, CLK90, CLK0, CLK_REF_OUT
  );

  //parameter clk_freq = 40000000; // 40 MHz clk 
  reg clk_out;
  always 
  begin  
    clk_out <= 1'b1;
    #2.5;// (1.0/40000000/2);
    clk_out <= 1'b0;
    #2.5;//(1.0/40000000/2);
  end
  assign CLK180 = clk_out;
  assign CLK0 = clk_out;
  endmodule

  `ifdef sim
 module CC_BUFG (
   input I,
   output O);
   assign O = I;
 endmodule
 `endif
 module CC_USR_RSTN (
  output reg USR_RSTN);
  initial
    begin
      USR_RSTN <= 0;
      #2000;
      USR_RSTN <= 1;
    end
endmodule


module ila_top_tb;
// #################################################################################################
// # ********************************************************************************************* #
    // Implement Logik for SUT
	wire [7:0] led_w;
// #################################################################################################
    // ILA configuration

  parameter FIFO_WIDTH = 5;
  localparam MEM_DEPTH = (FIFO_WIDTH == 1)  ? 32768 :  // 32K x 1 bit
  (FIFO_WIDTH == 2)  ? 16384 :  // 16K x 2 bit
  (FIFO_WIDTH <= 5)  ? 8192  :  // 8K x 5 bit
  (FIFO_WIDTH <= 10) ? 4096  :  // 4K x 10 bit
  (FIFO_WIDTH <= 20) ? 2048  :  // 2K x 20 bit
  1024;                   // 1K x 40 bit
  parameter FIFO_MATRIX_DEPH = 5;
  parameter sampling_freq_MHz = "10.0";
  parameter samples_count = FIFO_MATRIX_DEPH*MEM_DEPTH;
  parameter sample_width = 25;
  parameter PK_PER_DATA = ((sample_width-1)/4)+1;
  parameter all_bytes = PK_PER_DATA*samples_count;
  parameter FIFO_MATRIX_WIDTH = 5;
  reg clk_ILA, spi_clk, reset_r;
  wire ss_r, miso_r, mosi_r;
  wire rst_sig = 1;
  parameter INPUT_CTRL_size_p = 0;
  parameter ALMOST_EMPTY_OFFSET = 15'hCA;

    ila_top 
    #(
      .SIGNAL_SYNCHRONISATION(2),
      .USE_USR_RESET(1),
      .USE_PLL(0),
      .USE_FEATURE_PATTERN(0),
      .INPUT_CTRL_size(INPUT_CTRL_size_p),
      .ALMOST_EMPTY_OFFSET(ALMOST_EMPTY_OFFSET),
      .FIFO_IN_WIDTH(FIFO_WIDTH),
      .FIFO_MATRIX_WIDTH(FIFO_MATRIX_WIDTH),
      .FIFO_MATRIX_DEPH(FIFO_MATRIX_DEPH),
      .sample_width(sample_width), 
      .external_clk_freq("10.0"),
      .sampling_freq_MHz(sampling_freq_MHz),
      .clk_delay(2)
      ) 
      UUT ( 
        .i_sclk_ILA(spi_clk), 
        .i_ss_ILA(ss_r), 
        .i_mosi_ILA(mosi_r), 
        .o_miso_ILA(miso_r), 
// #################################################################################################
// # ********************************************************************************************* #
    // Input and output ports of the SUT 
        .led(led_w),
        .clk(clk_ILA) 
// #################################################################################################        
        );

    reg send_r, spi_receive_byte;
    reg [7:0] byte_to_send;
    wire [7:0] spy_rec_byte;
    wire spi_periode;
    wire cnt_end;

    SPI_master spi_m (.i_sclk(spi_clk), .i_reset(reset_r), .o_ss(ss_r), .o_mosi(mosi_r), .i_miso(miso_r), 
                      .i_send(send_r), .i_send_byte(byte_to_send), .i_receive(spi_receive_byte), .o_receive_byte(spy_rec_byte),
                      .o_period(spi_periode), .o_cnt_end(cnt_end));

always   // 10 MHz 
begin  
  clk_ILA = 1'b1;
  #50;
  clk_ILA = 1'b0;
  #50;
end

initial
begin

  //$display("All defined samples: %d", samples_count);
  //$display("all defined bytes: %d", all_bytes);
  //$display("nibble per Sample: %d", PK_PER_DATA);
    reset_r = 0;
    #3000;
    reset_r = 1;
end


always   // 10 MHz SPI_clk
begin  
  spi_clk = 1'b1;
  #50;
  spi_clk = 1'b0;
  #50;
end

// zu senden
// Reset_ILA: 0110
// Reset_DUT: 1010
// trigger und aktive: 1001
// Read_active: 1100
// Change_patterm: 0011

parameter bytes_to_send = ((sample_width-1)/4)+1;
parameter rest = ((bytes_to_send*4)-sample_width);

parameter input_change = 1;

reg [(bytes_to_send*4)-1:0] bit_pattern = {{rest{1'b1}} ,25'b1111111111111110000010101};
reg [(bytes_to_send*4)-1:0] bit_maske =   {{rest{1'b1}}, 25'b1111111111111110000000000};
parameter [3:0] Reset_ILA = 0,
                Reset_DUT = 1,
                conf_trigger_1 = 2,
                conf_trigger_2 = 3,
                conf_trigger_3 = 4,
                change_input_ctrl = 5,
                change_input_rest = 6,
                wait_for_trigger = 8,
                start_receive = 9,
                wait_for_cnt_end = 10,
                st_spi_first_byte = 11,
                s_receive_Signals = 12,
                get_data_1 = 13,
                get_data_2 = 14
                ;

reg [3:0] st_ila = Reset_ILA;

// drum herum immer ein run und break

reg run_break = 0;
integer count_break;
reg [5:0] trigger_row =    6'b000011;
reg [5:0] trigger_column = 6'b000011;

//reg [INPUT_CTRL_size_p-1:0] input_smp = 26'b10011001101011110001010110;
parameter byte_input = ((INPUT_CTRL_size_p-1)/8)+1;
parameter byte_reg_cnt = (byte_input*8);
parameter nib_reg_cnt = (((INPUT_CTRL_size_p-1)/4)+1)*4;
parameter nib_rest = nib_reg_cnt - INPUT_CTRL_size_p;
parameter rest_inp = byte_reg_cnt - INPUT_CTRL_size_p;
parameter rest_reg_init = rest_inp - nib_rest;

reg [byte_reg_cnt-1:0] input_smp_fit = {{nib_rest{1'b0}}, 25'b1001100110101111000101011, {rest_reg_init{1'b0}}};


reg [3:0] trigger_activation = 4'b0001;
integer counter_samples = 0;

integer byte_counter_spi;
integer counter_rec_bytes_spi;
integer cnt_bit_input_ctrl;

parameter receive_bits = (PK_PER_DATA*4)-1;
reg [receive_bits:0] rec_data;

always @(posedge spi_clk) begin
  if (!reset_r) begin
    st_ila <= Reset_ILA;
    run_break <= 0;
    count_break <= 0;
    send_r <= 0;
    spi_receive_byte <= 0;
    byte_to_send <= 8'b00000000;
    cnt_bit_input_ctrl <= 1;
  end
  else if (!run_break) begin 
    case (st_ila) 
      Reset_ILA : begin
        send_r <= 1;
        byte_to_send <= 8'b01100000;
        if (spi_periode) begin
          st_ila <= Reset_DUT;
        end
      end
      Reset_DUT : begin
        byte_to_send <= 8'b10100000;
        send_r <= 1;
        spi_receive_byte <= 1'b0;
        if (spi_periode) begin
          if (INPUT_CTRL_size_p > 0) begin
            st_ila <= change_input_ctrl;
          end else begin  
            st_ila <= conf_trigger_1;
          end
        end
      end
      //change_input_ctrl : begin
      //  byte_to_send <= 8'b00001110;
      //  if (spi_periode) begin
      //    st_ila <= change_input_rest;
      //  end
      //end
      //change_input_rest : begin
      //  byte_to_send <= input_smp_fit[byte_reg_cnt-1:byte_reg_cnt-8];
      //  if (spi_periode) begin
      //    if (byte_input > cnt_bit_input_ctrl ) begin
      //      cnt_bit_input_ctrl <= cnt_bit_input_ctrl + 1;
      //      input_smp_fit <= {input_smp_fit[byte_reg_cnt-9:0], 8'b0000};
      //    end else begin
      //      st_ila <= conf_trigger_1;
      //    end
      //  end
      //end
      conf_trigger_1 : begin
        byte_to_send <= 8'b00001001;
        send_r <= 1;
        spi_receive_byte <= 1'b0;
        if (spi_periode) begin
          st_ila <= conf_trigger_2;
        end
      end
      conf_trigger_2 : begin
        byte_to_send <= {trigger_row, trigger_column[5:4]};
        if (spi_periode) begin
          st_ila <= conf_trigger_3;
        end
      end
      conf_trigger_3 : begin
        byte_to_send <= {trigger_column[3:0], trigger_activation};
        if (spi_periode) begin
          st_ila <= wait_for_trigger;
        end
      end
    wait_for_trigger : begin
      byte_to_send <= 0;
      spi_receive_byte <= 1'b1;
      send_r <= 0;
      if (spi_periode) begin
          if (spy_rec_byte == 8'b10101010) begin 
            st_ila <= start_receive;
          end
      end
    end
    start_receive : begin
      spi_receive_byte <= 1'b0;
      send_r <= 1;
      byte_to_send <= 8'b11001100;
      counter_rec_bytes_spi <= 0;
      if (spi_periode) begin
        st_ila <= wait_for_cnt_end;
      end
    end
    wait_for_cnt_end : begin
      spi_receive_byte <= 1'b1;
      send_r <= 0;
      byte_to_send <= 0;
      if (cnt_end) begin    // first_byte_start_of
        st_ila <= st_spi_first_byte;
        byte_counter_spi <= 0;
      end
    end
    st_spi_first_byte : begin
      if (cnt_end) begin    // first_byte_start_of
          st_ila <= s_receive_Signals;
          byte_counter_spi <= 0;
          counter_samples <= 0;
        end
      end
    s_receive_Signals : begin
      spi_receive_byte <= 1'b1;
      send_r <= 0;
      if(cnt_end) begin
        st_ila <= get_data_1;
      end
    end
    get_data_1 : begin
        if (byte_counter_spi < (PK_PER_DATA-1)) begin
          byte_counter_spi <= byte_counter_spi +1;
        end
        else begin 
          byte_counter_spi <= 0;
          counter_samples <= counter_samples +1;
          if (PK_PER_DATA > 1) begin
            $display("%d", {spy_rec_byte[7:4], rec_data[receive_bits:4]});
            //$display("%d: sample: %h", counter_samples, {spy_rec_byte[7:4], rec_data[receive_bits:4]});
          end else begin
            $display("%d", rec_data[receive_bits:4]);
            //$display("%d: sample: %h", counter_samples, spy_rec_byte[7:4]);
          end 
        end
        if (PK_PER_DATA > 1) begin
          rec_data <= {spy_rec_byte[7:4], rec_data[receive_bits:4]};
        end 


        if (counter_rec_bytes_spi < all_bytes) begin
          counter_rec_bytes_spi <= counter_rec_bytes_spi +1; 
          st_ila <= get_data_2;
        end
        else begin
          st_ila <= Reset_ILA;
          //$display("********rec finish*************");
          $finish;
          run_break <= 1;
        end
      end
      get_data_2 : begin
        if (byte_counter_spi < (PK_PER_DATA-1)) begin
          byte_counter_spi <= byte_counter_spi +1;
        end
        else begin 
          byte_counter_spi <= 0;
          counter_samples <= counter_samples +1;
          if (PK_PER_DATA > 1) begin
            $display("%d", {spy_rec_byte[3:0], rec_data[receive_bits:4]});
          end else begin
            $display("%d", spy_rec_byte[3:0]);
          end 
        end
        if (PK_PER_DATA > 1) begin
          rec_data <= {spy_rec_byte[3:0], rec_data[receive_bits:4]};
        end 


        if (counter_rec_bytes_spi < all_bytes) begin
          counter_rec_bytes_spi <= counter_rec_bytes_spi +1; 
          st_ila <= s_receive_Signals;
        end
        else begin
          //$display("rec finish");
          $finish;
          st_ila <= Reset_ILA;
          run_break <= 1;
        end
      end
    endcase
  end else begin
    send_r <= 0;
    spi_receive_byte <= 1'b0;
    if (count_break < 8) begin 
      count_break <= count_break +1; 
    end
    else begin
      count_break <= 0;
      run_break <= 0;
    end
  end
end


integer idx;
    initial
 begin
    $dumpfile("ila_top_tb.vcd");
    $dumpvars(0,ila_top_tb);
    //`ifdef sim
    //for (idx = 0; idx < FIFO_MATRIX_DEPH; idx = idx + 1) begin
    //  $dumpvars(0,UUT.mem_control.BRAM_do_tmp[idx]);
    //end
    //for (idx = 0; idx < FIFO_MATRIX_WIDTH; idx = idx + 1) begin
    //  $dumpvars(1,UUT.mem_control.data_in_pipe[idx]);
    //end
    //  
    //`endif
 end
// initial begin
//    #100000000;
//    $finish;
//end


endmodule