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
// 
//////////////////////////////////////////////////////////////////////////////////

//TODO добавить размерность данных
module summComplex #(parameter DATA_FFT_SIZE = 16)(
    i_clk,
    i_en,
    i_data_in0_i,
    i_data_in0_q,
    i_data_in1_i,
    i_data_in1_q,
    o_data_out0_i,
    o_data_out0_q
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
    
    always @(posedge i_clk)
    begin
        if(i_en)  o_data_out0_i <= i_data_in0_i + i_data_in1_i;
//        else      o_data_out0_i <= 0;
        if(i_en)  o_data_out0_q <= i_data_in0_q + i_data_in1_q;
//        else      o_data_out0_q <= 0;
    end

//    output [DATA_FFT_SIZE-1:0] data_out0_i;
//    output [DATA_FFT_SIZE-1:0] data_out0_q;
    
//    assign o_data_out0_i = i_data_in0_i + i_data_in1_i;
//    assign o_data_out0_q = i_data_in0_q + i_data_in1_q;
    
endmodule
