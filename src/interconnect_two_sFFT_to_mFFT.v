`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 30.11.2020 11:54:49
// Design Name: 
// Module Name: interconnect_two_sFFT_to_mFFT
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


module interconnect_two_sFFT_to_mFFT #(parameter SIZE_BUFFER = 1,/*log2(NFFT)*/
                                       parameter SIZE_OUT_DATA_S_FFT = 16,
                                       parameter SIZE_OUT_DATA = 16,
                                       parameter TYPE = "forvard",/*forvard invers*/
                                       parameter COMPENS_FP = "false", /*false true or add razrad*/
                                       parameter FAST = "slow",/*slow fast ultrafast slow mult x1 fast mult x2 ultrafast mult x4*/
                                       parameter USE_ROUND = 1,/*0 or 1*/
                                       parameter USE_DSP = 1,/*0 or 1*/
                                       parameter PARAPEL_THIS_FFT = 1)
    (
        i_clk,
        i_reset,
        
        i_data_from_secondFFT_chet_i,
        i_data_from_secondFFT_chet_q,
        i_data_from_secondFFT_Nchet_i,
        i_data_from_secondFFT_Nchet_q,
        
        i_flag_complete_chet,
        i_flag_complete_Nchet,
        
        o_resiveFromChet,
        o_resiveFromNChet,
        
        i_mutDone,
        
        o_out_summ_0__NFFT_2_i,
        o_out_summ_0__NFFT_2_q,
        o_out_summ_NFFT_2__NFFT_i,
        o_out_summ_NFFT_2__NFFT_q,
        
        o_counterMultData2,
    

        o_dataComplete
    );
    
    localparam NFFT = 1 << SIZE_BUFFER;
    
    input i_clk;
    input i_reset;
    
    input [SIZE_OUT_DATA_S_FFT-1:0] i_data_from_secondFFT_chet_i;
    input [SIZE_OUT_DATA_S_FFT-1:0] i_data_from_secondFFT_chet_q;
    input [SIZE_OUT_DATA_S_FFT-1:0] i_data_from_secondFFT_Nchet_i;
    input [SIZE_OUT_DATA_S_FFT-1:0] i_data_from_secondFFT_Nchet_q;
    
    input i_flag_complete_chet;
    input i_flag_complete_Nchet;
    
    output o_resiveFromChet;
    output reg o_resiveFromNChet;
    
    input i_mutDone;
    
    output [SIZE_OUT_DATA-1:0] o_out_summ_0__NFFT_2_i;
    output [SIZE_OUT_DATA-1:0] o_out_summ_0__NFFT_2_q;
    output [SIZE_OUT_DATA-1:0] o_out_summ_NFFT_2__NFFT_i;
    output [SIZE_OUT_DATA-1:0] o_out_summ_NFFT_2__NFFT_q;
    
    output reg [SIZE_BUFFER-1:0] o_counterMultData2;
    
    output o_dataComplete;
    
    
    initial o_resiveFromNChet = 1'b1;
    initial o_counterMultData2 = 0;
   

//    reg resiveFromChet = 1'b1;
//    reg resiveFromNChet = 1'b1;
            
       /*****************************SLOW FFT*****************************/
    reg enMult = 1'b0;
    reg [SIZE_OUT_DATA_S_FFT-1:0] multData_i;
    reg [SIZE_OUT_DATA_S_FFT-1:0] multData_q;
    reg [15:0] phi = 16'd0;
    
    wire [SIZE_OUT_DATA-1:0] res_m_phi_i;
    wire [SIZE_OUT_DATA-1:0] res_m_phi_q;
    wire [SIZE_OUT_DATA-1:0] res_p_phi_i;
    wire [SIZE_OUT_DATA-1:0] res_p_phi_q;
//    wire dataComplete;
    
    multComplexE #(.SIZE_DATA_FI(SIZE_BUFFER)/*LOG2(NFFT)*/, .DATA_FFT_SIZE(SIZE_OUT_DATA_S_FFT), .FAST(FAST), .TYPE(TYPE), .COMPENS_FP(COMPENS_FP), .USE_ROUND(USE_ROUND), .USE_DSP(USE_DSP))
    _multComplexE
        (
        .i_clk(i_clk),
        .i_en(enMult),
        .i_in_data_i(multData_i),
        .i_in_data_q(multData_q),
        .i_fi_deg(phi),
        .o_out_data_minus_i(res_m_phi_i),
        .o_out_data_minus_q(res_m_phi_q),
        .o_out_data_plus_i(res_p_phi_i),
        .o_out_data_plus_q(res_p_phi_q),
        .o_outValid(o_dataComplete)
        );
        
    reg [SIZE_OUT_DATA-1:0] d1_res_m_phi_i;
    reg [SIZE_OUT_DATA-1:0] d1_res_m_phi_q;
    reg [SIZE_OUT_DATA-1:0] d1_res_p_phi_i;
    reg [SIZE_OUT_DATA-1:0] d1_res_p_phi_q;
    
    always @(posedge i_clk)
    begin
        d1_res_m_phi_i <= res_m_phi_i;
        d1_res_m_phi_q <= res_m_phi_q;
        d1_res_p_phi_i <= res_p_phi_i;
        d1_res_p_phi_q <= res_p_phi_q;
    end
        
    
//    reg [SIZE_OUT_DATA_S_FFT-1:0] data_summ_chet_i = 0;
//    reg [SIZE_OUT_DATA_S_FFT-1:0] data_summ_chet_q = 0;
    
    wire [SIZE_OUT_DATA-1:0] w_data_summ_chet_i;
    wire [SIZE_OUT_DATA-1:0] w_data_summ_chet_q;
    
    if((COMPENS_FP == "add") && (SIZE_OUT_DATA > SIZE_OUT_DATA_S_FFT))//если разная разрядность то должен учитывать знак
    begin
//        assign w_data_summ_chet_i[SIZE_OUT_DATA-1:1] = data_summ_chet_i[SIZE_OUT_DATA_S_FFT-1:0];
//        assign w_data_summ_chet_q[SIZE_OUT_DATA-1:1] = data_summ_chet_q[SIZE_OUT_DATA_S_FFT-1:0];
        
        assign w_data_summ_chet_i[SIZE_OUT_DATA-1:1] = i_data_from_secondFFT_chet_i[SIZE_OUT_DATA_S_FFT-1:0];
        assign w_data_summ_chet_q[SIZE_OUT_DATA-1:1] = i_data_from_secondFFT_chet_q[SIZE_OUT_DATA_S_FFT-1:0];
        
        assign w_data_summ_chet_i[0] = 0;
        assign w_data_summ_chet_q[0] = 0;  
    end
    else
    begin
//        assign w_data_summ_chet_i = data_summ_chet_i;
//        assign w_data_summ_chet_q = data_summ_chet_q;
        
        assign w_data_summ_chet_i = i_data_from_secondFFT_chet_i;
        assign w_data_summ_chet_q = i_data_from_secondFFT_chet_q;
    end
    
//        assign d_dataComplete = dataComplete;
            
        
    summComplex #(.DATA_FFT_SIZE(SIZE_OUT_DATA)) 
    _summ0__NFFT_2(
        .i_clk(i_clk),
        .i_en(/*state == stateSummFFT*/1'b1),
        .i_data_in0_i(w_data_summ_chet_i),
        .i_data_in0_q(w_data_summ_chet_q),
        .i_data_in1_i(res_m_phi_i),
        .i_data_in1_q(res_m_phi_q),
        .o_data_out0_i(o_out_summ_0__NFFT_2_i),
        .o_data_out0_q(o_out_summ_0__NFFT_2_q)
    );
    summComplex #(.DATA_FFT_SIZE(SIZE_OUT_DATA)) 
    _summNFFT_2__NFFT(
        .i_clk(i_clk),
        .i_en(/*state == stateSummFFT*/1'b1),
        .i_data_in0_i(w_data_summ_chet_i),
        .i_data_in0_q(w_data_summ_chet_q),
        .i_data_in1_i(res_p_phi_i),
        .i_data_in1_q(res_p_phi_q),
        .o_data_out0_i(o_out_summ_NFFT_2__NFFT_i),
        .o_data_out0_q(o_out_summ_NFFT_2__NFFT_q)
    );
    

    
    reg beginReadSummData = 1'b0;
    reg flagWayt = 1'b1;//flag ожидать пока начнеться умножения
    
    reg old_flag_complete_chet = 1'b0;
    reg old_flag_complete_Nchet = 1'b0;
    
    reg d1_enMult = 0;
    
    assign o_resiveFromChet = o_dataComplete | (!i_flag_complete_chet);
    
        
    always @(posedge i_clk)//summ FFT
    begin : summFFT
        
        if(i_reset)
        begin
//            resiveFromChet <= 1'b1;
            o_resiveFromNChet <= 1'b1;
            enMult <= 1'b0;
            o_counterMultData2 <= 0;
            phi <= 0;
        end
        else
        begin
            d1_enMult <= enMult;
            old_flag_complete_chet <= i_flag_complete_chet;
//            if(flag_complete_chet | old_flag_complete_chet)
//            begin
                
//                data_summ_chet_i <= data_from_secondFFT_chet_i;
//                data_summ_chet_q <= data_from_secondFFT_chet_q;
                
//            end
//            else resiveFromChet <= 1'b1;
            
            if(old_flag_complete_Nchet) phi <= phi + 1;
            else    phi <= 0;
            
            old_flag_complete_Nchet <= i_flag_complete_Nchet;
            if(i_flag_complete_Nchet | old_flag_complete_Nchet)
            begin
                multData_i <= i_data_from_secondFFT_Nchet_i;
                multData_q <= i_data_from_secondFFT_Nchet_q;
                
                enMult <= 1'b1;
            end
            else if(o_counterMultData2 == (NFFT/2-1)) enMult <= 1'b0;
            
            if(i_mutDone)         o_counterMultData2 <= 0;
            else
            begin
                if(/*d1_enMult & */o_dataComplete)
                    o_counterMultData2 <= o_counterMultData2 + 1;
                else    o_counterMultData2 <= 0;
            end
        end
    end
    /*****************************END SLOW FFT*****************************/
            
endmodule
