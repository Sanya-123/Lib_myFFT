`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.10.2020 12:49:35
// Design Name: 
// Module Name: memForFFT
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
// double memory for my fft
//////////////////////////////////////////////////////////////////////////////////


module memForFFT #(parameter DATA_FFT_SIZE = 16,
                   parameter SIZE_BITS_ADDRES = 4 /*log2(size mem)*//*, parameter name="nonoe"*/)
    (
    i_clk,
    i_writeEn,
    i_readEn,
    i_addr,
    i_addr_r,
    i_inData,
    o_outData,
    i_writeEn2,
    i_readEn2,
    i_addr2,
    i_addr_r2,
    i_inData2,
    o_outData2
    );
    
    input i_clk;
    input i_writeEn;
    input i_readEn;
    input [SIZE_BITS_ADDRES-1:0] i_addr;
    input [SIZE_BITS_ADDRES-1:0] i_addr_r;
    input [DATA_FFT_SIZE-1:0] i_inData;
    output reg [DATA_FFT_SIZE-1:0] o_outData;
    
    input i_writeEn2;
    input i_readEn2;
    input [SIZE_BITS_ADDRES-1:0] i_addr2;
    input [SIZE_BITS_ADDRES-1:0] i_addr_r2;
    input [DATA_FFT_SIZE-1:0] i_inData2;
    output reg [DATA_FFT_SIZE-1:0] o_outData2;
    
    reg [DATA_FFT_SIZE-1:0] data [2**SIZE_BITS_ADDRES-1:0];
    reg [DATA_FFT_SIZE-1:0] data2 [2**SIZE_BITS_ADDRES-1:0];
    
    always @(posedge i_clk)
    begin
        if(i_readEn)  o_outData <= data[i_addr_r];//read
        if(i_writeEn) data[i_addr] <= i_inData;//write
        
        if(i_readEn2)  o_outData2 <= data2[i_addr_r2];//read
        if(i_writeEn2) data2[i_addr2] <= i_inData2;//write
    end
    
endmodule
