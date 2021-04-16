`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.12.2020 15:03:40
// Design Name: 
// Module Name: interconnect_sFFT_to_two_data
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


module interconnect_sFFT_to_two_data #( parameter SIZE_BUFFER = 1,/*log2(NFFT)*/
                                        parameter DATA_FFT_SIZE = 16
                                    )
    (
        i_clk,
        i_reset,
        i_fft_valid,
        i_data_from_fft_i,
        i_data_from_fft_q,
        
        i_flag_ready_recive_chet,
        i_flag_ready_recive_Nchet,
        o_data_fft_chet_i,
        o_data_fft_chet_q,
        o_data_fft_Nchet_i,
        o_data_fft_Nchet_q,
        o_complete_chet,
        o_complete_Nchet,
        o_resiveFromSecond
    );
    
    input i_clk;
    input i_reset;
    input i_fft_valid;
    input [DATA_FFT_SIZE-1:0] i_data_from_fft_i;
    input [DATA_FFT_SIZE-1:0] i_data_from_fft_q;
    
    input i_flag_ready_recive_chet;
    input i_flag_ready_recive_Nchet;
    output reg [DATA_FFT_SIZE-1:0] o_data_fft_chet_i;
    output reg [DATA_FFT_SIZE-1:0] o_data_fft_chet_q;
    output [DATA_FFT_SIZE-1:0] o_data_fft_Nchet_i;
    output [DATA_FFT_SIZE-1:0] o_data_fft_Nchet_q;
    output reg o_complete_chet;
    output o_complete_Nchet;
    output o_resiveFromSecond;
    
    initial o_complete_chet = 0;
    
    
    localparam NFFT = 1 << SIZE_BUFFER;
    
    reg [DATA_FFT_SIZE-1:0] data_from_chet_i[NFFT/2-1:0];
    reg [DATA_FFT_SIZE-1:0] data_from_chet_q[NFFT/2-1:0];
    
    reg left_data = 1'b1;
    reg [SIZE_BUFFER:0] counter_send = 0;
    reg [SIZE_BUFFER-1:0] counter_resive_l = 0;
    
    assign o_complete_Nchet = left_data ? 0 : i_fft_valid;
    assign o_data_fft_Nchet_i = left_data ? 0 : i_data_from_fft_i;
    assign o_data_fft_Nchet_q = left_data ? 0 : i_data_from_fft_q;
    
    assign o_resiveFromSecond = left_data ? 1 : i_flag_ready_recive_Nchet;
    
    always @(posedge i_clk)
    begin : sendDataFFT_Chet
        if(i_reset)
        begin
            o_complete_chet <= 0;
            counter_send <= 0;
        end
        else
        begin
            if(((counter_resive_l == 1) | o_complete_chet) & i_flag_ready_recive_chet)
            begin
                if(counter_send < (NFFT/2))     counter_send <= counter_send + 1;
                else                            counter_send <= 0;
                if(counter_send < (NFFT/2))     o_data_fft_chet_i <= data_from_chet_i[counter_send];
                if(counter_send < (NFFT/2))     o_data_fft_chet_q <= data_from_chet_q[counter_send];
                
            end
            else
            begin
                //делаю так же  как и в FFT чтобы сразу когда был выставлен флаг были  выданны данные
                counter_send <= 1;
                o_data_fft_chet_i <= data_from_chet_i[0];
                o_data_fft_chet_q <= data_from_chet_q[0];
            end
            
            if(o_complete_chet == 1'b0)
            begin
                if(counter_resive_l == 1)    o_complete_chet <= 1;
            end
            else if((counter_send == (NFFT/2-1)) & i_flag_ready_recive_chet)  o_complete_chet <= 0;
            
        end
    end
    
    always @(posedge i_clk)
    begin
        if(i_reset)
        begin
            left_data <= 1'b1;
            counter_resive_l <= 0;
        end
        else if(i_fft_valid)
        begin
            if(left_data)
            begin
                data_from_chet_i[counter_resive_l] <= i_data_from_fft_i;
                data_from_chet_q[counter_resive_l] <= i_data_from_fft_q;
                counter_resive_l <= counter_resive_l + 1;
                if(counter_resive_l == (NFFT/2-1))
                begin
                    left_data <= 1'b0;
                    counter_resive_l <= 0;
                end
            end
            else
            begin
                if((counter_send == (NFFT/2)))   left_data <= 1'b1;
                counter_resive_l <= 0;
            end
        end
        else
        begin
            if((counter_send == (NFFT/2)))   left_data <= 1'b1;
            counter_resive_l <= 0;
        end
    end
    
    
endmodule
