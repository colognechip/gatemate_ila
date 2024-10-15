
module SPI_master(
    input i_sclk,
    input i_reset,
    output o_ss,
    output o_mosi,
    input i_miso,
    input i_send,
    input[7:0] i_send_byte,
    input i_receive,
    output reg [7:0] o_receive_byte,
    output o_period,
    output o_cnt_end
);
reg [7:0] byte_send;
reg [2:0] counter;
reg [7:0] rec_byte;
reg send_acitve, send_ss, rec_acitve, rec_ss;


always @(negedge i_sclk)
    begin
        if (i_reset == 0) begin
            byte_send <= 8'b00000000;
            send_acitve <= 0;
            send_ss <= 0;
        end
        else if (i_send & counter == 3'b000 ) begin
            byte_send <= i_send_byte;
            send_acitve <= 1;
            send_ss <= 1;
        end
        else if (counter == 3'b111 & !i_send) begin
            byte_send <= {byte_send[6:0], 1'b0};
            send_acitve <= 0;
        end
        else if (send_acitve) begin
            byte_send <= {byte_send[6:0], 1'b0};
        end
        else begin
            byte_send <= 8'b00000000;
            send_ss <= 0;
        end
    end

    always @(posedge i_sclk)
    begin
        if (i_reset == 0) begin
            rec_byte <= 8'b00000000;
            rec_acitve <= 0;
            rec_ss <= 0;
            o_receive_byte <= 8'b00000000;
        end
        else if (!rec_acitve & counter == 3'b000) begin
            if (i_receive) begin
                rec_acitve <= 1;
                rec_ss <= 1;
            end
            else begin
                rec_ss <= 0;
            end

        end
        else if (counter == 3'b111 & !i_receive) begin
            rec_acitve <= 0;
        end
        rec_byte <= {rec_byte[6:0], i_miso};
        if (counter == 3'b111) begin
            o_receive_byte <= {rec_byte[6:0], i_miso};
        end

    end



    always @(posedge i_sclk)
    begin
        if (!i_reset) begin
            counter <= 3'b000;
        end 
        else begin
            if (send_acitve | rec_acitve) begin
                counter <= counter + 1;
            end
            else begin
                counter <= 0;
            end
        end
    end

    assign o_ss = !(rec_ss | send_ss);
    assign o_mosi = byte_send[7] ;
    assign o_period = (counter == 3'b001);
    assign o_cnt_end = (counter == 3'b000);
endmodule
