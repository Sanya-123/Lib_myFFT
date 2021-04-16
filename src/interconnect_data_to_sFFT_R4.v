`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.12.2020 14:21:00
// Design Name: 
// Module Name: interconnect_data_to_sFFT
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module interconnect_data_to_sFFT_R4 #( parameter SIZE_BUFFER = 1,/*log2(NFFT)*/
                                    parameter DATA_FFT_SIZE = 16
                                    )
                                                                    
    (
        i_clk,
        i_reset,
        i_in_data_i,
        i_in_data_q,
        i_valid,
        i_fft_wayt_data,
        o_out_data_i,
        o_out_data_q,
        o_outvalid,
        i_counter_data,
        o_wayt_data_fft3
    );
    
    input i_clk;
    input i_reset;
    input [DATA_FFT_SIZE-1:0] i_in_data_i;
    input [DATA_FFT_SIZE-1:0] i_in_data_q;
    input i_valid;
    input i_fft_wayt_data;
    output [DATA_FFT_SIZE-1:0] o_out_data_i;
    output [DATA_FFT_SIZE-1:0] o_out_data_q;
    output o_outvalid;
    input [SIZE_BUFFER:0] i_counter_data;
    output reg o_wayt_data_fft3;//специальный флаг говоряший что данные были отправленны правая половина or flag_reset_counter
    
    initial o_wayt_data_fft3 = 1;
    
    
    localparam NFFT = 1 << SIZE_BUFFER;
    
    reg [DATA_FFT_SIZE-1:0] buff1_in_data_i [NFFT/4-1:0];
    reg [DATA_FFT_SIZE-1:0] buff1_in_data_q [NFFT/4-1:0];
    
    reg [DATA_FFT_SIZE-1:0] buff2_in_data_i [NFFT/4-1:0];
    reg [DATA_FFT_SIZE-1:0] buff2_in_data_q [NFFT/4-1:0];
    
    reg [DATA_FFT_SIZE-1:0] buff3_in_data_i [NFFT/4-1:0];
    reg [DATA_FFT_SIZE-1:0] buff3_in_data_q [NFFT/4-1:0];
    
//    reg left_path = 1'b1;//FFT левой части
//    reg valid_right = 1'b0;
    
    reg [1:0] path = 2'b00;
    reg valid_outher_path = 1'b0;
    
    reg [DATA_FFT_SIZE-1:0] data_for_fft_i;
    reg [DATA_FFT_SIZE-1:0] data_for_fft_q;
    
    assign o_outvalid = path == 2'b00 ? ((i_counter_data[1:0] == 2'b00) & i_valid) : valid_outher_path;
    assign o_out_data_i = path == 2'b00 ? i_in_data_i : data_for_fft_i;
    assign o_out_data_q = path == 2'b00 ? i_in_data_q : data_for_fft_q;
    
    reg [SIZE_BUFFER:0] counter_resive1 = 0;
    reg [SIZE_BUFFER:0] counter_resive2 = 0;
    reg [SIZE_BUFFER:0] counter_resive3 = 0;
    reg [SIZE_BUFFER:0] counter_send1 = 0;
    reg [SIZE_BUFFER:0] counter_send2 = 0;
    reg [SIZE_BUFFER:0] counter_send3 = 0;
    
    always @(posedge i_clk)
    begin
        if(i_reset)
        begin
            counter_send1 <= 0;
            counter_send2 <= 0;
            counter_send3 <= 0;
            counter_resive1 <= 0;
            counter_resive2 <= 0;
            counter_resive3 <= 0;
            path <= 2'b00;
            valid_outher_path <= 1'b0;
            o_wayt_data_fft3 <= 1'b1;
        end
        else
        begin
            if((path == 2'b00) & i_valid)
            begin
                o_wayt_data_fft3 <= 1'b1;
                case(i_counter_data[1:0])
                    2'b01 : begin
                        buff1_in_data_i[counter_resive1] <= i_in_data_i;
                        buff1_in_data_q[counter_resive1] <= i_in_data_q;
                        counter_resive1 <= counter_resive1 + 1;
                    end
                    2'b10 : begin
                        buff2_in_data_i[counter_resive2] <= i_in_data_i;
                        buff2_in_data_q[counter_resive2] <= i_in_data_q;
                        counter_resive2 <= counter_resive2 + 1;
                    end
                    2'b11 : begin
                        buff3_in_data_i[counter_resive3] <= i_in_data_i;
                        buff3_in_data_q[counter_resive3] <= i_in_data_q;
                        counter_resive3 <= counter_resive3 + 1;
                    end
                
                endcase
                
                if((counter_resive3 == (NFFT/4-1)) && (i_counter_data[1:0] == 2'b11))
                begin
                    path <= 2'b01;
                    counter_send1 <= 0;
                    counter_send2 <= 0;
                    counter_send3 <= 0;
                end
                
                valid_outher_path <= 1'b0;
                
            end
            else if((path == 2'b01) & (i_fft_wayt_data))
            begin
                
                data_for_fft_i <= buff1_in_data_i[counter_send1];
                data_for_fft_q <= buff1_in_data_q[counter_send1];
                if(counter_send1 < (NFFT/4)) counter_send1 <= counter_send1 + 1;
                
                if(counter_send1 == (NFFT/4))
                begin
//                    wayt_data_second_NChet <= 1'b0;
                    path <= 2'b10;
//                    valid_outher_path <= 1'b0;
                    counter_resive1 <= 0;
                end
                else
                begin
                    valid_outher_path <= 1'b1;
                    o_wayt_data_fft3 <= 1'b1;
                end
            end
            else if((path == 2'b10) & (i_fft_wayt_data))
            begin
                
                data_for_fft_i <= buff2_in_data_i[counter_send2];
                data_for_fft_q <= buff2_in_data_q[counter_send2];
                if(counter_send2 < (NFFT/4)) counter_send2 <= counter_send2 + 1;
                
                if(counter_send2 == (NFFT/4))
                begin
//                    wayt_data_second_NChet <= 1'b0;
                    path <= 2'b11;
//                    valid_outher_path <= 1'b0;
                    counter_resive2 <= 0;
                end
                else
                begin
                    valid_outher_path <= 1'b1;
                    o_wayt_data_fft3 <= 1'b1;
                end
            end
            else if((path == 2'b11) & (i_fft_wayt_data))
            begin
                
                data_for_fft_i <= buff3_in_data_i[counter_send3];
                data_for_fft_q <= buff3_in_data_q[counter_send3];
                if(counter_send3 < (NFFT/4)) counter_send3 <= counter_send3 + 1;
                
                if(counter_send3 == (NFFT/4))
                begin
                    o_wayt_data_fft3 <= 1'b0;
                    path <= 2'b00;
//                    valid_outher_path <= 1'b0;
                    counter_resive3 <= 0;
                end
                else
                begin
                    valid_outher_path <= 1'b1;
                    o_wayt_data_fft3 <= 1'b1;
                end
            end
            
            else
            begin
                o_wayt_data_fft3 <= 1'b1;
                valid_outher_path <= 1'b0;
            end
        end
    end
    
    
endmodule
