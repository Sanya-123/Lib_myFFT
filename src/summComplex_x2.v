`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.10.2020 18:27:12
// Design Name: 
// Module Name: summComplex
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
// summ and diff complex numder
//////////////////////////////////////////////////////////////////////////////////

//TODO добавить размерность данных
module summComplex_x2 #(parameter DATA_FFT_SIZE = 16)(
    i_clk,
    i_en,
    i_data_in0_i,
    i_data_in0_q,
    i_data_in1_i,
    i_data_in1_q,
    o_data_out0_i,
    o_data_out0_q,
    o_data_out1_i,
    o_data_out1_q
    );

    input i_clk;
    input i_en;
    //DATA_FFT_SIZE = 16
    input [DATA_FFT_SIZE-1:0] i_data_in0_i;
    input [DATA_FFT_SIZE-1:0] i_data_in0_q;
    input [DATA_FFT_SIZE-1:0] i_data_in1_i;
    input [DATA_FFT_SIZE-1:0] i_data_in1_q;
    output reg [DATA_FFT_SIZE-1:0] o_data_out0_i;
    output reg [DATA_FFT_SIZE-1:0] o_data_out0_q;
    output reg [DATA_FFT_SIZE-1:0] o_data_out1_i;
    output reg [DATA_FFT_SIZE-1:0] o_data_out1_q;
    
    reg diff = 1'b0;//ferst closk summ, second cock diff
    
    always @(posedge i_clk)
    begin
        if(i_en)
        begin
            diff <= !diff;
            if(diff) 
            begin
                o_data_out1_i <= i_data_in0_i - i_data_in1_i;
                o_data_out1_q <= i_data_in0_q - i_data_in1_q;
            end
            else 
            begin
                o_data_out0_i <= i_data_in0_i + i_data_in1_i;
                o_data_out0_q <= i_data_in0_q + i_data_in1_q;
            end
        end
    end
    
endmodule
