// Single Port RAM (NO_CHANGE)
module bram_ila #(
    parameter DATA_WIDTH=32,
    parameter ADDR_WIDTH=9
    )(
    input wire we,
    input wire clk,
    input wire [DATA_WIDTH-1:0] di,
    input wire [ADDR_WIDTH-1:0] addr_read,
    input wire [ADDR_WIDTH-1:0] addr_write,
    output reg [DATA_WIDTH-1:0] do
    );

    localparam WORD = (DATA_WIDTH-1);
    localparam DEPTH = (2**ADDR_WIDTH-1);
    reg [WORD:0] memory [0:DEPTH];
    reg [WORD:0] save_reg;

    always @(posedge clk) begin
        save_reg <= di;
    if (we) begin
        memory[addr_write] <= save_reg;
    end
    

    end
    always @(posedge clk) begin

            do <= memory[addr_read];
    end


    endmodule