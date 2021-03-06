`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.10.2020 13:38:10
// Design Name: 
// Module Name: multComplexE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: moduul for FFT
// для быльшей точности от умножения тут добавляеться разряд если COMPENS_FP==add
//////////////////////////////////////////////////////////////////////////////////

module multComplexE #(parameter SIZE_DATA_FI = 2/*LOG2(NFFT)*/,
                      parameter DATA_FFT_SIZE = 16,
                      parameter FAST = "slow",/*slow fast ultrafast slow mult x1 fast mult x2 ultrafast mult x4*/
                      parameter TYPE = "forvard",/*forvard invers*/
                      parameter COMPENS_FP = "false", /*false true or add razrad*/
                      parameter USE_ROUND = 1,/*0 or 1*/
                      parameter USE_DSP = 1/*0 or 1*/)(
    i_clk,
    i_en,
    i_in_data_i,
    i_in_data_q,
    i_fi_deg,/*NOTE только положительные данные для данного модуля size [SIZE_DATA_FI-2:0]*/
    o_out_data_minus_i,
    o_out_data_minus_q,
    o_out_data_plus_i,
    o_out_data_plus_q,
    o_outValid
    );
    
    localparam _USE_ROUND = USE_ROUND==0 ? 0 : 1;
    localparam _USE_DSP = USE_DSP == 0 ? 0 : 1;
    
    //есть 2 возможных способа увеличенияточности
    //1 увеличивать по 1 биту кажду раз
    //2 data_int = (data_float*2 + 1)/2 
    
    input i_clk;
    input i_en;
    input [DATA_FFT_SIZE-1:0] i_in_data_i;
    input [DATA_FFT_SIZE-1:0] i_in_data_q;
    input [15:0] i_fi_deg;
    output [DATA_FFT_SIZE-1 + (COMPENS_FP=="add"?1:0) :0] o_out_data_minus_i;
    output [DATA_FFT_SIZE-1 + (COMPENS_FP=="add"?1:0) :0] o_out_data_minus_q;
    output [DATA_FFT_SIZE-1 + (COMPENS_FP=="add"?1:0) :0] o_out_data_plus_i;
    output [DATA_FFT_SIZE-1 + (COMPENS_FP=="add"?1:0) :0] o_out_data_plus_q;
    output reg o_outValid;
    
    initial o_outValid = 1'b0;
    
    //входные данные 1 а фазы то зеркальные
    assign o_out_data_plus_i = -o_out_data_minus_i;
    assign o_out_data_plus_q = -o_out_data_minus_q;
    
//    output reg module_en = 1'b0;
    
    genvar i;
    generate
    if(SIZE_DATA_FI > 2) 
    begin
    

    reg _module_en = 1'b0;
    reg mult = 1'b0;
    reg multDone = 1'b0;

    
    reg [16:0] in_cos = 0;
    reg [16:0] in_sin = 0;

    reg [DATA_FFT_SIZE-1:0] in_mult_data_i;
    reg [DATA_FFT_SIZE-1:0] in_mult_data_q;
    
    wire multComplexComplete;
   
//    reg [16:0] d1_in_cos;
//    reg [16:0] d1_in_sin;
    
//    reg [DATA_FFT_SIZE-1:0] d1_in_mult_data_i;
//    reg [DATA_FFT_SIZE-1:0] d1_in_mult_data_q;
    
//    reg d1_mult;

    cmplx_mixer
    #(
      .pIDAT_W(DATA_FFT_SIZE) ,
      .pDDS_W(17) ,
      .pODAT_W(DATA_FFT_SIZE+2 + (COMPENS_FP=="add"?1:0)) ,
      .pMUL_W(0) ,
      .pCONJ(0) ,
      .pUSE_DSP_ADD(_USE_DSP) , // use altera dsp internal adder or not (differ registers)
      .pUSE_ROUND(_USE_ROUND)
    )
    cmplx_mult(
      .iclk(i_clk)    ,
      .ireset(0)  ,
      .iclkena(1'b1) ,
      //
      .ival(mult)    ,
      .idat_re(/*in_data_i*/in_mult_data_i) ,
      .idat_im(/*in_data_q*/in_mult_data_q) ,
//      .idat_re(d1_in_mult_data_i) ,
//      .idat_im(d1_in_mult_data_q) ,
      //
      .icos(in_cos)    ,
      .isin(in_sin)    ,
//      .icos(d1_in_cos)    ,
//      .isin(d1_in_sin)    ,
      //
      .oval(multComplexComplete),
      .odat_re(o_out_data_minus_i) ,
      .odat_im(o_out_data_minus_q)
    );

    //(* ram_style="block" *)
    //(* ram_style="distributed" *)
    //(* ram_style="register" *)
    //(* ram_style="ultra" *)
    //специальные cos sin для FFT
    /*(* ram_style="block" *)*/reg [16:0] cos [2**(SIZE_DATA_FI)/2-1:0];
    /*(* ram_style="block" *)*/reg [16:0] sin [2**(SIZE_DATA_FI)/2-1:0];

    reg [3:0] timer_4clock = 0;
    
    
//    always @(posedge clk)
//    begin
//        d1_mult <= mult;
//        d1_in_cos <= in_cos;
//        d1_in_sin <= in_sin;
//        d1_in_mult_data_i <= in_mult_data_i;
//        d1_in_mult_data_q <= in_mult_data_q;
//    end
    

    always @(posedge i_clk)
    begin
        
        if(mult | i_en)   begin if(timer_4clock < (3 + _USE_ROUND)) timer_4clock <= timer_4clock + 1;end
        else            timer_4clock <= 0;
        
        if(timer_4clock == (3 + _USE_ROUND))        o_outValid <= 1'b1;
        else /*if(en)*/                             o_outValid <= 1'b0;
        
        if(i_en)
        begin
            in_cos = cos[i_fi_deg[SIZE_DATA_FI-2:0]];
            
            if(TYPE == "forvard")
            begin
                in_sin = sin[i_fi_deg[SIZE_DATA_FI-2:0]];
            end
            else if(TYPE == "invers")
            begin
                in_sin = -sin[i_fi_deg[SIZE_DATA_FI-2:0]];
            end
            
            in_mult_data_i <= i_in_data_i;
            in_mult_data_q <= i_in_data_q;
            
            
            if(!mult) mult <= 1'b1;//begin mult(on second clk mult will be done)
            else if((timer_4clock == (3 + _USE_ROUND)) & (i_en == 1'b0)) mult <= 1'b0;
        end
        else if((timer_4clock == (3 + _USE_ROUND)) & (i_en == 1'b0)) mult <= 1'b0;
    end

    initial
    begin
        if(SIZE_DATA_FI == 2)//8dot
        begin
            $readmemh("cos4.mem",cos);
            $readmemh("sin4.mem",sin);
        end
        else if(SIZE_DATA_FI == 3)//8dot
        begin
            $readmemh("cos8.mem",cos);
            $readmemh("sin8.mem",sin);
        end
        else if(SIZE_DATA_FI == 4)//16dot
        begin
            $readmemh("cos16.mem",cos);
            $readmemh("sin16.mem",sin);
        end
        else if(SIZE_DATA_FI == 5)//32dot
        begin
            $readmemh("cos32.mem",cos);
            $readmemh("sin32.mem",sin);
        end
        else if(SIZE_DATA_FI == 6)//64dot
        begin
            $readmemh("cos64.mem",cos);
            $readmemh("sin64.mem",sin);
        end
        else if(SIZE_DATA_FI == 7)//128dot
        begin
            $readmemh("cos128.mem",cos);
            $readmemh("sin128.mem",sin);
        end
        else if(SIZE_DATA_FI == 8)//256dot
        begin
            $readmemh("cos256.mem",cos);
            $readmemh("sin256.mem",sin);
        end
        
//        for(i = SIZE_DATA_FI/2; i < SIZE_DATA_FI; i=i+1)
//        begin
//            cos[i] = sin[i - SIZE_DATA_FI/2];
//            sin[i] = -cos[i - SIZE_DATA_FI/2];
//        end
    end
    
    end
    else if(SIZE_DATA_FI == 2)//если 4 точки в этом случае все просто
    begin
        reg multDone = 1'b0;
        
        reg [DATA_FFT_SIZE-1:0] data_i;
        reg [DATA_FFT_SIZE-1:0] data_q;
        assign o_out_data_minus_i = data_i;
        assign o_out_data_minus_q = data_q;
        always @(posedge i_clk)
        begin
            if(i_en)
            begin
                multDone <= 1'b1;
                if(TYPE == "forvard")
                begin
                    if(i_fi_deg[0]) data_i <= i_in_data_q;
                    else            data_i <= i_in_data_i;
                    if(i_fi_deg[0]) data_q <= -i_in_data_i;
                    else            data_q <= i_in_data_q;
                end
                else if(TYPE == "invers")
                begin
                    if(i_fi_deg[0]) data_i <= -i_in_data_q;
                    else            data_i <= i_in_data_i;
                    if(i_fi_deg[0]) data_q <= i_in_data_i;
                    else            data_q <= i_in_data_q;
                end
            end
            else
            begin
                multDone <= 1'b0;
            end
        end
        
    end
    else//в случае если 2 или меньше точек FFT
    begin
    assign o_out_data_minus_i = i_in_data_i;
    assign o_out_data_minus_q = i_in_data_q;
    end
    endgenerate
    
    
endmodule
