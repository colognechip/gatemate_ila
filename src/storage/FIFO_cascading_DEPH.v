
module FIFO_cascading_DEPH #(
    parameter WIDTH=20,
    parameter DEPH = 3,
    parameter [14:0] ALMOST_EMPTY_OFFSET = 15'hf
)(
    input wire rclk,
    input wire wclk,
    input wire rst,
    input wire PUSH_i,
    input wire POP_i,
    input wire [WIDTH-1:0] DI,
    output reg [WIDTH-1:0] DO,
    output wire FULL_o,
    output wire ALMOST_FULL_o,
    output wire EMPTY_o,
    output wire ALMOST_EMPTY_o
);

wire [WIDTH-1:0] BRAM_do_tmp [DEPH-1:0];
wire [DEPH-1:0] EMPTY, PUSH, POP, FULL, ALMOST_FULL, ALMOST_EMPTY;

wire [DEPH-1:0] enable_read;

assign ALMOST_FULL_o = ALMOST_FULL[0];
assign ALMOST_EMPTY_o = ALMOST_EMPTY[0];

parameter MASK = {WIDTH{1'b1}};
assign FULL_o = FULL[DEPH-1];

assign PUSH[0] = FULL[0] ? 0 : PUSH_i;
assign POP[0] = EMPTY[0] ? 0 : POP_i;
assign enable_read[0] = !EMPTY[0];

generate
    if (DEPH == 1) begin
        always @(posedge rclk) begin
            if (enable_read == 1'b1) begin
                DO <= BRAM_do_tmp[0];
            end else begin
                DO <= {WIDTH{1'b0}};  
            end
        end
    end
    else if (DEPH == 2) begin
        always @(posedge rclk) begin
            if (enable_read != 2'b00) begin
                case (enable_read)
                    2'b01: begin
                        DO <= BRAM_do_tmp[0];
                    end
                    2'b10: begin
                        DO <= BRAM_do_tmp[1];
                    end
                    default: begin
                        DO <= {WIDTH{1'b0}};  
                    end
                endcase
            end else begin
                DO <= {WIDTH{1'b0}}; 
            end
        end
    end
    else if (DEPH == 3) begin
        always @(posedge rclk) begin
            if (enable_read != 3'b000) begin
                case (enable_read)
                    3'b001: begin
                        DO <= BRAM_do_tmp[0];
                    end
                    3'b010: begin
                        DO <= BRAM_do_tmp[1];
                    end
                    3'b100: begin
                        DO <= BRAM_do_tmp[2];
                    end
                    default: begin
                        DO <= {WIDTH{1'b0}};  
                    end
                endcase
            end else begin
                DO <= {WIDTH{1'b0}}; 
            end
        end
    end
    else if (DEPH == 4) begin
        always @(posedge rclk) begin
            if (enable_read != 4'b0000) begin
                case (enable_read)
                    4'b0001: begin
                        DO <= BRAM_do_tmp[0];
                    end
                    4'b0010: begin
                        DO <= BRAM_do_tmp[1];
                    end
                    4'b0100: begin
                        DO <= BRAM_do_tmp[2];
                    end
                    4'b1000: begin
                        DO <= BRAM_do_tmp[3];
                    end
                    default: begin
                        DO <= {WIDTH{1'b0}}; 
                    end
                endcase
            end else begin
                DO <= {WIDTH{1'b0}};  
            end
        end
    end
    else if (DEPH == 5) begin
        always @(posedge rclk) begin
            if (enable_read != 5'b00000) begin
                case (enable_read)
                    5'b00001: begin
                        DO <= BRAM_do_tmp[0];
                    end
                    5'b00010: begin
                        DO <= BRAM_do_tmp[1];
                    end
                    5'b00100: begin
                        DO <= BRAM_do_tmp[2];
                    end
                    5'b01000: begin
                        DO <= BRAM_do_tmp[3];
                    end
                    5'b10000: begin
                        DO <= BRAM_do_tmp[4];
                    end
                    default: begin
                        DO <= {WIDTH{1'b0}};  
                    end
                endcase
            end else begin
                DO <= {WIDTH{1'b0}};  
            end
        end
    end
    else if (DEPH == 6) begin
        always @(posedge rclk) begin
            if (enable_read != 6'b000000) begin
                case (enable_read)
                    6'b000001: begin
                        DO <= BRAM_do_tmp[0];
                    end
                    6'b000010: begin
                        DO <= BRAM_do_tmp[1];
                    end
                    6'b000100: begin
                        DO <= BRAM_do_tmp[2];
                    end
                    6'b001000: begin
                        DO <= BRAM_do_tmp[3];
                    end
                    6'b010000: begin
                        DO <= BRAM_do_tmp[4];
                    end
                    6'b100000: begin
                        DO <= BRAM_do_tmp[5];
                    end
                    default: begin
                        DO <= {WIDTH{1'b0}};  
                    end
                endcase
            end else begin
                DO <= {WIDTH{1'b0}}; 
            end
        end
    end




    genvar i;
    for (i = 1; i < DEPH; i = i+1) begin : loop_con
        assign enable_read[i] = EMPTY[i-1] & (!EMPTY[i]);
        
        assign PUSH[i] = ALMOST_FULL[i-1] ? (FULL[i] ? 0 : PUSH_i) : 0;
        assign POP[i] = enable_read[i] ? POP_i : 0;

    end

    for (i = 0; i < DEPH; i = i+1) begin : loop_init
        CC_FIFO_40K #(
        
        .ALMOST_FULL_OFFSET(15'h1),
        .ALMOST_EMPTY_OFFSET(ALMOST_EMPTY_OFFSET),
        .DYN_STAT_SELECT(0), 
        .A_WIDTH(WIDTH),
        .B_WIDTH(WIDTH),
        .FIFO_MODE("SYNC"),
        .RAM_MODE("TDP"),
        .A_CLK_INV(0), .B_CLK_INV(0),
        .A_EN_INV(0), .B_EN_INV(0),
        .A_WE_INV(0), .B_WE_INV(0),
        .A_DO_REG(1), .B_DO_REG(1),
        .A_ECC_EN(0), .B_ECC_EN(0)
        ) fifo_inst (
        .A_CLK(rclk),
        .B_CLK(wclk), 
        .A_EN(POP[i]),
        .B_EN(PUSH[i]),
        .B_WE(1'b1),
        .B_DI(DI),
        .B_BM(MASK),
        .A_DO(BRAM_do_tmp[i]),
        .F_ALMOST_FULL_OFFSET(),
        .F_ALMOST_EMPTY_OFFSET(),
        .F_RST_N(rst),
        .F_FULL(FULL[i]),
        .F_EMPTY(EMPTY[i]),
        .F_ALMOST_FULL(ALMOST_FULL[i]),
        .F_ALMOST_EMPTY(ALMOST_EMPTY[i]),
        .F_RD_ERROR(),
        .F_WR_ERROR(),
        .F_RD_PTR(),
        .F_WR_PTR()
        );
    end
endgenerate

endmodule 