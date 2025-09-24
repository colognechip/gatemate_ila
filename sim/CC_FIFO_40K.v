
/*
 32K x 1 bit
• 16K x 2 bit
• 8K x 5 bit
• 4K x 10 bit
• 2K x 20 bit
• 1K x 40 bit

*/
module CC_FIFO_40K #(
    parameter [14:0] ALMOST_FULL_OFFSET = 15'hf,  // Offset für "fast voll" Zustand
    parameter [14:0] ALMOST_EMPTY_OFFSET = 15'hf, // Offset für "fast leer" Zustand
    parameter DYN_STAT_SELECT = 1,          // Dynamische Steuerung für fast voll/leer
    parameter A_WIDTH = 20,                 // Breite Port A
    parameter B_WIDTH = 20,                 // Breite Port B
    parameter FIFO_MODE = "ASYNC",    // FIFO-Modus (synchron)
    parameter RAM_MODE = "TDP",      // RAM-Modus (Two-Port)
    parameter A_CLK_INV = 0,                // Invertierung für A-Clock
    parameter B_CLK_INV = 0,                // Invertierung für B-Clock
    parameter A_EN_INV = 0,                 // Invertierung für A-Enable
    parameter B_EN_INV = 0,                 // Invertierung für B-Enable
    parameter A_WE_INV = 0,                 // Invertierung für A-Write Enable
    parameter B_WE_INV = 0,                 // Invertierung für B-Write Enable
    parameter A_DO_REG = 0,                 // A-Datenregister
    parameter B_DO_REG = 0,                 // B-Datenregister
    parameter A_ECC_EN = 0,                 // Fehlerkorrektur für A
    parameter B_ECC_EN = 0                  // Fehlerkorrektur für B
  )(
    input wire  A_CLK,                    // Clock für Pop
    input wire B_CLK,
    input wire  A_EN,                     // Enable für Pop
    input wire  B_EN,                    // Enable für Push
    input wire  B_WE,                    // Write Enable für Push
    input wire  [A_WIDTH-1:0] B_DI,             // Dateneingang
    input wire  [A_WIDTH-1:0] B_BM,             // Bitmask
    output reg [A_WIDTH-1:0] A_DO,             // Datenausgang
    input wire  [14:0] F_ALMOST_FULL_OFFSET,   // Dynamischer Offset für "fast voll"
    input wire  [14:0] F_ALMOST_EMPTY_OFFSET,  // Dynamischer Offset für "fast leer"
    input wire  F_RST_N,                    // Reset (active low)
    output wire F_FULL,                     // FIFO voll
    output wire F_EMPTY,                    // FIFO leer
    output wire F_ALMOST_FULL,              // FIFO fast voll
    output wire F_ALMOST_EMPTY,             // FIFO fast leer
    output reg F_RD_ERROR,                 // Lesefehler
    output reg F_WR_ERROR,                 // Schreibfehler
    output wire [15:0] F_RD_PTR,            // Lesezeiger
    output wire [15:0] F_WR_PTR             // Schreibzeiger
  );
  


  localparam MEM_DEPTH = (A_WIDTH == 1)  ? 32768 :  // 32K x 1 bit
  (A_WIDTH == 2)  ? 16384 :  // 16K x 2 bit
  (A_WIDTH <= 5)  ? 8192  :  // 8K x 5 bit
  (A_WIDTH <= 10) ? 4096  :  // 4K x 10 bit
  (A_WIDTH <= 20) ? 2048  :  // 2K x 20 bit
  1024;                   // 1K x 40 bit
  reg [A_WIDTH-1:0] mem_array [0:MEM_DEPTH-1];

  function [15:0] distance(input [15:0] wr_ptr, input [15:0] rd_ptr);
    if (wr_ptr >= rd_ptr) begin
        distance = wr_ptr - rd_ptr;
    end else begin
        distance = (MEM_DEPTH - rd_ptr) + wr_ptr;
    end
endfunction


  reg [15:0] wr_ptr;  
  reg [15:0] rd_ptr;

  wire [15:0] wr_ptr_next = (wr_ptr == MEM_DEPTH - 1) ? 0 : wr_ptr + 1;
  wire [15:0] rd_ptr_next = (rd_ptr == MEM_DEPTH - 1) ? 0 : rd_ptr + 1;


  always @(posedge A_CLK or negedge F_RST_N) begin
    if (!F_RST_N) begin
      rd_ptr <= 16'b0;
      F_RD_ERROR <= 0;
      A_DO <= 0;
    end else if (A_EN && !F_EMPTY) begin
        A_DO <= mem_array[rd_ptr];  
        F_RD_ERROR <= 0;
        rd_ptr <= rd_ptr_next;   
      end else if (A_EN && F_EMPTY) begin
        F_RD_ERROR <= 1;

      end
    end

  always @(posedge B_CLK or negedge F_RST_N) begin
    if (!F_RST_N) begin
      wr_ptr <= 16'b0;
      F_WR_ERROR <= 0;
    end else begin
      if (B_EN && B_WE && !F_FULL) begin
        F_WR_ERROR <= 0;
        mem_array[wr_ptr] <= (mem_array[wr_ptr] & ~B_BM) | (B_DI & B_BM); 
        wr_ptr <= wr_ptr_next;   
      end else if (B_EN && B_WE && F_FULL) begin
        F_WR_ERROR <= 1;
      end
    end
  end

    assign F_FULL = (wr_ptr_next == rd_ptr);
    assign F_EMPTY = (wr_ptr == rd_ptr);
    assign F_RD_PTR = rd_ptr;
    assign F_WR_PTR = wr_ptr;

    wire [15:0] distance_all = distance(wr_ptr, rd_ptr);
    assign F_ALMOST_FULL = (distance_all >= (MEM_DEPTH - ALMOST_FULL_OFFSET));
    assign F_ALMOST_EMPTY = (distance_all < ALMOST_EMPTY_OFFSET);

endmodule