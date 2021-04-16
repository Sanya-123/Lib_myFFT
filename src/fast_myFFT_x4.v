`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.01.2021 14:38:40
// Design Name: 
// Module Name: fast_myFFT_x4
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


module fast_myFFT_x4 #( parameter SIZE_DATA = 16,
                        parameter TYPE = "forvard"/*forvard invers*/)(
        i_clk,
        i_valid,
        i_data0_in_i,
        i_data0_in_q,
        i_data1_in_i,
        i_data1_in_q,
        i_data2_in_i,
        i_data2_in_q,
        i_data3_in_i,
        i_data3_in_q,
        o_data0_out_i,
        o_data0_out_q,
        o_data1_out_i,
        o_data1_out_q,
        o_data2_out_i,
        o_data2_out_q,
        o_data3_out_i,
        o_data3_out_q,
        o_complete
    );
    
    input i_clk;
    input i_valid;
    input [SIZE_DATA-1:0] i_data0_in_i;
    input [SIZE_DATA-1:0] i_data0_in_q;
    input [SIZE_DATA-1:0] i_data1_in_i;
    input [SIZE_DATA-1:0] i_data1_in_q;
    input [SIZE_DATA-1:0] i_data2_in_i;
    input [SIZE_DATA-1:0] i_data2_in_q;
    input [SIZE_DATA-1:0] i_data3_in_i;
    input [SIZE_DATA-1:0] i_data3_in_q;
    output reg [SIZE_DATA-1:0] o_data0_out_i;
    output reg [SIZE_DATA-1:0] o_data0_out_q;
    output reg [SIZE_DATA-1:0] o_data1_out_i;
    output reg [SIZE_DATA-1:0] o_data1_out_q;
    output reg [SIZE_DATA-1:0] o_data2_out_i;
    output reg [SIZE_DATA-1:0] o_data2_out_q;
    output reg [SIZE_DATA-1:0] o_data3_out_i;
    output reg [SIZE_DATA-1:0] o_data3_out_q;
    output reg o_complete;
    
    initial o_complete = 1'b0;
    
    always @(posedge i_clk)   o_complete <= i_valid;
    
    
    always @(posedge i_clk)
    begin
        if(i_valid)
        begin
            o_data0_out_i <= i_data0_in_i + i_data1_in_i + i_data2_in_i + i_data3_in_i;
            o_data0_out_q <= i_data0_in_q + i_data1_in_q + i_data2_in_q + i_data3_in_q;
            
            o_data2_out_i <= i_data0_in_i - i_data1_in_i + i_data2_in_i - i_data3_in_i;
            o_data2_out_q <= i_data0_in_q - i_data1_in_q + i_data2_in_q - i_data3_in_q;
        end
    end
    
    generate
    if(TYPE == "forvard")
    begin
        always @(posedge i_clk)
        begin
            if(i_valid)
            begin
                o_data1_out_i <= i_data0_in_i + i_data1_in_q - i_data2_in_i - i_data3_in_q;
                o_data1_out_q <= i_data0_in_q - i_data1_in_i - i_data2_in_q + i_data3_in_i;
                
                o_data3_out_i <= i_data0_in_i - i_data1_in_q - i_data2_in_i + i_data3_in_q;
                o_data3_out_q <= i_data0_in_q + i_data1_in_i - i_data2_in_q - i_data3_in_i;
            end
        end  
    end
    else
    begin
        always @(posedge i_clk)
        begin
            if(i_valid)
            begin
                o_data3_out_i <= i_data0_in_i + i_data1_in_q - i_data2_in_i - i_data3_in_q;
                o_data3_out_q <= i_data0_in_q - i_data1_in_i - i_data2_in_q + i_data3_in_i;
                
                o_data1_out_i <= i_data0_in_i - i_data1_in_q - i_data2_in_i + i_data3_in_q;
                o_data1_out_q <= i_data0_in_q + i_data1_in_i - i_data2_in_q - i_data3_in_i;
            end
        end
    end
    endgenerate
        
endmodule
