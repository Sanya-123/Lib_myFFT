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


module interconnect_data_to_sFFT #( parameter SIZE_BUFFER = 1,/*log2(NFFT)*/
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
        o_wayt_data_second_NChet
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
    output reg o_wayt_data_second_NChet;//специальный флаг говоряший что данные были отправленны правая половина or flag_reset_counter
    
    initial o_wayt_data_second_NChet = 1;
    
    
    localparam NFFT = 1 << SIZE_BUFFER;
    
    reg [DATA_FFT_SIZE-1:0] buff_in_data_i [NFFT/2-1:0];
    reg [DATA_FFT_SIZE-1:0] buff_in_data_q [NFFT/2-1:0];
    
    reg left_path = 1'b1;//FFT левой части
    reg valid_right = 1'b0;
    
    reg [DATA_FFT_SIZE-1:0] data_for_fft_i;
    reg [DATA_FFT_SIZE-1:0] data_for_fft_q;
    
    assign o_outvalid = left_path ? ((i_counter_data[0] == 1'b0) & i_valid) : valid_right;
    assign o_out_data_i = left_path ? i_in_data_i : data_for_fft_i;
    assign o_out_data_q = left_path ? i_in_data_q : data_for_fft_q;
    
    reg [SIZE_BUFFER:0] counter_resive = 0;
    reg [SIZE_BUFFER:0] counter_send = 0;
    
    always @(posedge i_clk)
    begin
        if(i_reset)
        begin
            counter_send <= 0;
            counter_resive <= 0;
            left_path <= 1'b1;
            valid_right <= 1'b0;
            o_wayt_data_second_NChet <= 1'b1;
        end
        else
        begin
            if(left_path & ((i_counter_data[0] == 1'b1) & i_valid))
            begin
                o_wayt_data_second_NChet <= 1'b1;
                buff_in_data_i[counter_resive] <= i_in_data_i;
                buff_in_data_q[counter_resive] <= i_in_data_q;
                counter_resive <= counter_resive + 1;
                if(counter_resive == (NFFT/2-1))
                begin
                    left_path <= 1'b0;
                    counter_send <= 0;
                end
                valid_right <= 1'b0;
            end
            else if((left_path == 1'b0) & (i_fft_wayt_data))
            begin
                
                data_for_fft_i <= buff_in_data_i[counter_send];
                data_for_fft_q <= buff_in_data_q[counter_send];
                if(counter_send < (NFFT/2)) counter_send <= counter_send + 1;
                
                if(counter_send == (NFFT/2))
                begin
                    o_wayt_data_second_NChet <= 1'b0;
                    left_path <= 1'b1;
//                    valid_right <= 1'b0;
                    counter_resive <= 0;
                end
                else
                begin
                    valid_right <= 1'b1;
                    o_wayt_data_second_NChet <= 1'b1;
                end
            end
            else
            begin
                o_wayt_data_second_NChet <= 1'b1;
                valid_right <= 1'b0;
            end
        end
    end
    
    
endmodule
