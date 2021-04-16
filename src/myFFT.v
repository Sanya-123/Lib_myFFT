`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.10.2020 17:33:18
// Design Name: 
// Module Name: myFFT
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
// mudole recursi use this module
// the longest state is stateSummFFT when data is mult
// in slow mode mult coplete CONSISTENTLY in fast mode mult complete PARAPERLITY
// NOTE при парарельном использовании данных если долго не считывать данные они могут затереться
// для быльшей точности от умножения тут добавляеться разряд если COMPENS_FP==add
// NOTE при малых FFT (FFT8) если закидывать данные сразу после того как выставиться флаг, данные могут затереться
//////////////////////////////////////////////////////////////////////////////////

/*
 * FFT2 : .SIZE_BUFFER(1) SIZE_BUFFER = 1
 * FFT4 : .SIZE_BUFFER(2) SIZE_BUFFER = 2
 * FFT8 : .SIZE_BUFFER(2) SIZE_BUFFER = 3
 * FFT16 : .SIZE_BUFFER(2) SIZE_BUFFER = 4
 * FFT32 : .SIZE_BUFFER(2) SIZE_BUFFER = 5
 * FFT64 : .SIZE_BUFFER(2) SIZE_BUFFER = 6
 * FFT128 : .SIZE_BUFFER(2) SIZE_BUFFER = 7
 * FFT256 : .SIZE_BUFFER(2) SIZE_BUFFER = 8
*/
module myFFT
    #(parameter SIZE_BUFFER = 1,/*log2(NFFT)*/
      parameter DATA_FFT_SIZE = 16,
      parameter FAST = "slow",/*slow fast ultrafast slow mult x1 fast mult x2 ultrafast mult x4*/
      parameter TYPE = "forvard",/*forvard invers*/
      parameter COMPENS_FP = "false", /*false true or add razrad*/
      parameter MIN_FFT_x4 = 1,/*minumum fft x2 or x4*/ /*WARNING not work MIN_FFT_x4==0*/
      parameter USE_ROUND = 1,/*0 or 1*/
      parameter USE_DSP = 1,/*0 or 1*/
      parameter PARAREL_FFT = 9'b111111111 /*example 8'b 111000000 fft 256,128,64 matht pararel anaouther fft math conv; FFT 256 optimal time/resource 111100000 in OFDM systeam optimum 111000000*/
    )
    (
        i_clk,
        i_reset,
        i_valid,
        i_data_in_i,
        i_data_in_q,
        o_data_out_i,
        o_data_out_q,
        o_complete,
        o_stateFFT,
        i_flag_ready_recive,/*input flags for output data*/
        o_flag_wayt_data/*flag can recive daat data*/
    );
    
    localparam NFFT = 1 << SIZE_BUFFER;
    
    //начиная с fft8 увеличиваю по 1 разряду выходные данные
    localparam SIZE_OUT_DATA        = COMPENS_FP == "add" ? (DATA_FFT_SIZE + (SIZE_BUFFER > 2 ? SIZE_BUFFER - 2 : 0)) : DATA_FFT_SIZE;//на выходе модуля
    localparam SIZE_OUT_DATA_S_FFT  = COMPENS_FP == "add" ? (DATA_FFT_SIZE + (SIZE_BUFFER > 2 ? SIZE_BUFFER - 3 : 0)) : DATA_FFT_SIZE;//на выходе предыдущего модуля
    
    localparam PARAREL_THIS_FFT = PARAREL_FFT[SIZE_BUFFER];

    
    input i_clk;
    input i_reset;
    input i_valid;//flag data is valid
    input [DATA_FFT_SIZE-1:0] i_data_in_i;
    input [DATA_FFT_SIZE-1:0] i_data_in_q;
    output /*reg*/ [SIZE_OUT_DATA-1:0] o_data_out_i;
    output /*reg*/ [SIZE_OUT_DATA-1:0] o_data_out_q;
    output reg o_complete;
    output [2:0] o_stateFFT;
    //debug
    
    input i_flag_ready_recive;
    output /*reg*/ o_flag_wayt_data;
    
    //TODO размеры массивов   
    reg [SIZE_BUFFER:0] counterReciveDataFFT;
    reg [SIZE_BUFFER:0] counterSendData;
    reg [2:0] state;
    reg completeDone_r = 1'b0;
    
    assign o_stateFFT = state;
    
    localparam stateWaytData = 3'b000;
    localparam stateWriteData = 3'b001;
    localparam stateWaytFFT = 3'b010;
    
//    localparam stateSummFFT = 4'b100;
    localparam stateSummFFT = 4'b100;
    localparam stateComplete = 4'b111;
    
    initial
    begin
        counterReciveDataFFT = 0;
        o_complete = 0;
        counterSendData = 0;
        state = stateWaytData;
    end
    
    genvar i;
    generate
    //********это конечная часть рекурсии********
    if(NFFT < 2) begin end
    else if(NFFT == 2) begin : FFT_2 //+
    
        reg [DATA_FFT_SIZE-1:0] data_in_mas_i [1:0];
        reg [DATA_FFT_SIZE-1:0] data_in_mas_q [1:0];
        wire [DATA_FFT_SIZE-1:0] data_out_mas_i [1:0];
        wire [DATA_FFT_SIZE-1:0] data_out_mas_q [1:0];
        
        wire flag_summ;
        assign flag_summ = state == stateComplete;
        
        summComplex_x2 #(.DATA_FFT_SIZE(DATA_FFT_SIZE))
        _summ0(
            .i_clk(i_clk),
            .i_en(flag_summ),
            .i_data_in0_i(data_in_mas_i[0]),
            .i_data_in0_q(data_in_mas_q[0]),
            .i_data_in1_i(data_in_mas_i[1]),
            .i_data_in1_q(data_in_mas_q[1]),
            .o_data_out0_i(data_out_mas_i[0]),
            .o_data_out0_q(data_out_mas_q[0]),
            .o_data_out1_i(data_out_mas_i[1]),
            .o_data_out1_q(data_out_mas_q[1])
        );
        
        always @(posedge i_clk)//fms
        begin : FMS_FFT
            if(i_reset)   state <= stateWaytData;
            else 
            begin
                //машина конечных состоояние по состоянию данных
                case(state)
                stateWaytData : if(counterReciveDataFFT == 2) state <= stateComplete;//сдесь можно ускорить на 1 такт
                stateComplete : if((counterSendData == 1) & i_flag_ready_recive)   state <= stateWaytData;//when all data is send wayt anouther data
                endcase
            end
        end
        
        always @(posedge i_clk)//resiveData
        begin : reciveDataFFT
            if(i_reset)   counterReciveDataFFT <= 0;
            else 
            begin
                if(counterReciveDataFFT < NFFT)
                begin
                    if(i_valid == 1'b1)//flag data is valid
                    begin
                        data_in_mas_i[counterReciveDataFFT[1:0]] <= i_data_in_i;
                        data_in_mas_q[counterReciveDataFFT[1:0]] <= i_data_in_q;
                        counterReciveDataFFT <= counterReciveDataFFT + 1;
                    end
                end
                else if (/*state == stateSummFFT*/flag_summ) counterReciveDataFFT <= 0;//когда все математические операции выполнены можно заново принимать данные
            end
        end
        
//        reg [DATA_FFT_SIZE-1:0] reg_data_out_i;
//        reg [DATA_FFT_SIZE-1:0] reg_data_out_q;
        
//        assign data_out_i = reg_data_out_i;
//        assign data_out_q = reg_data_out_q;

        assign o_data_out_i = counterSendData[0] ? data_out_mas_i[0] : data_out_mas_i[1];
        assign o_data_out_q = counterSendData[0] ? data_out_mas_q[0] : data_out_mas_q[1];
        
        always @(posedge i_clk)//send data
        begin : sendDataFFT
            if(state == stateComplete/*completeDone_r*/)//когда вые выполнено отправляю даннеы
            begin
                if((counterSendData < NFFT) & i_flag_ready_recive)
                begin : FLAG_RECIVE_FFT
                    counterSendData <= counterSendData + 1;
//                    reg_data_out_i <= data_out_mas_i[counterSendData];
//                    reg_data_out_q <= data_out_mas_q[counterSendData];
                end
            end
            else counterSendData <= 0;//когда 
        end
        
        always @(posedge i_clk)//flag complete
        begin : flagComplete
            if(state == stateComplete/*completeDone_r*/)  o_complete <= 1'b1;
            else                        o_complete <= 1'b0;
        end
        
        //можно ускорить на 1 такт
        //flag can read data
        reg reg_flag_wayt_data = 1'b1;
        assign o_flag_wayt_data = reg_flag_wayt_data;
        always @ (posedge i_clk)
        begin
//            if(/*(counterReciveDataFFT < 2)*/(counterReciveDataFFT[1] == 1'b0))  reg_flag_wayt_data <= 1'b1;
//            else                            reg_flag_wayt_data <= 1'b0;

//            reg_flag_wayt_data <= !counterReciveDataFFT[1];
            if((counterReciveDataFFT == 1) & i_valid)   reg_flag_wayt_data <= 1'b0;
            else reg_flag_wayt_data <= !counterReciveDataFFT[1];
        end
        
    end
    else if((MIN_FFT_x4==1) && (NFFT == 4)) //+
    begin
    
        reg [DATA_FFT_SIZE-1:0] data_out_mas_i [3:0];
        reg [DATA_FFT_SIZE-1:0] data_out_mas_q [3:0];
        
        always @(posedge i_clk)//fms
        begin : FMS_FFT
            if(i_reset)   state <= stateWaytData;
            else 
            begin
                //машина конечных состоояние по состоянию данных
                case(state)
                stateWaytData : if((counterReciveDataFFT == 3) & i_valid) /*state <= stateComplete*/ state <= stateSummFFT;//сдесь можно ускорить на 1 такт
                stateSummFFT:   state <= stateComplete;
                stateComplete : if((counterSendData == 3) & i_flag_ready_recive)   state <= stateWaytData;//when all data is send wayt anouther data
                endcase
            end
        end
        
        //TYPE = "forvard",/*forvard invers*/
        localparam numm_1 = TYPE=="forvard" ? 1 : TYPE=="invers" ? 3 : 1;
        localparam numm_3 = TYPE=="forvard" ? 3 : TYPE=="invers" ? 1 : 3;
        
        always @(posedge i_clk)//resiveData
        begin : reciveDataFFT
            if(i_reset)   counterReciveDataFFT <= 0;
            else if(stateWaytData == stateWaytData)
            begin
                if(counterReciveDataFFT < NFFT)
                begin
                    if(i_valid == 1'b1)//flag data is valid
                    begin
                        counterReciveDataFFT <= counterReciveDataFFT + 1;
                        case(counterReciveDataFFT)
                        0:
                        begin
                            data_out_mas_i[0] <= i_data_in_i;
                            data_out_mas_q[0] <= i_data_in_q;
                            
                            data_out_mas_i[numm_1] <= i_data_in_i;
                            data_out_mas_q[numm_1] <= i_data_in_q;
                            
                            data_out_mas_i[2] <= i_data_in_i;
                            data_out_mas_q[2] <= i_data_in_q;
                            
                            data_out_mas_i[numm_3] <= i_data_in_i;
                            data_out_mas_q[numm_3] <= i_data_in_q;
                        end
                        1:
                        begin
                            data_out_mas_i[0] <= data_out_mas_i[0] + i_data_in_i;
                            data_out_mas_q[0] <= data_out_mas_q[0] + i_data_in_q;
                            
                            data_out_mas_i[numm_1] <= data_out_mas_i[numm_1] + i_data_in_q;
                            data_out_mas_q[numm_1] <= data_out_mas_q[numm_1] - i_data_in_i;
                            
                            data_out_mas_i[2] <= data_out_mas_i[2] - i_data_in_i;
                            data_out_mas_q[2] <= data_out_mas_q[2] - i_data_in_q;
                            
                            data_out_mas_i[numm_3] <= data_out_mas_i[numm_3] - i_data_in_q;
                            data_out_mas_q[numm_3] <= data_out_mas_q[numm_3] + i_data_in_i;
                        end
                        2:
                        begin
                            data_out_mas_i[0] <= data_out_mas_i[0] + i_data_in_i;
                            data_out_mas_q[0] <= data_out_mas_q[0] + i_data_in_q;
                            
                            data_out_mas_i[numm_1] <= data_out_mas_i[numm_1] - i_data_in_i;
                            data_out_mas_q[numm_1] <= data_out_mas_q[numm_1] - i_data_in_q;
                            
                            data_out_mas_i[2] <= data_out_mas_i[2] + i_data_in_i;
                            data_out_mas_q[2] <= data_out_mas_q[2] + i_data_in_q;
                            
                            data_out_mas_i[numm_3] <= data_out_mas_i[numm_3] - i_data_in_i;
                            data_out_mas_q[numm_3] <= data_out_mas_q[numm_3] - i_data_in_q;
                        end
                        3:
                        begin
                            data_out_mas_i[0] <= data_out_mas_i[0] + i_data_in_i;
                            data_out_mas_q[0] <= data_out_mas_q[0] + i_data_in_q;
                            
                            data_out_mas_i[numm_1] <= data_out_mas_i[numm_1] - i_data_in_q;
                            data_out_mas_q[numm_1] <= data_out_mas_q[numm_1] + i_data_in_i;
                            
                            data_out_mas_i[2] <= data_out_mas_i[2] - i_data_in_i;
                            data_out_mas_q[2] <= data_out_mas_q[2] - i_data_in_q;
                            
                            data_out_mas_i[numm_3] <= data_out_mas_i[numm_3] + i_data_in_q;
                            data_out_mas_q[numm_3] <= data_out_mas_q[numm_3] - i_data_in_i;
                        end
                        endcase 
                    end
                end
                else counterReciveDataFFT <= 0;//когда все математические операции выполнены можно заново принимать данные
            end
        end
        
        reg [DATA_FFT_SIZE-1:0] reg_data_out_i;
        reg [DATA_FFT_SIZE-1:0] reg_data_out_q;
        
        assign o_data_out_i = reg_data_out_i;
        assign o_data_out_q = reg_data_out_q;
        
        always @(posedge i_clk)//send data
        begin : sendDataFFT
            if(state == stateComplete/*completeDone_r*/)//когда вые выполнено отправляю даннеы
            begin
                if((counterSendData < NFFT) & i_flag_ready_recive)
                begin : FLAG_RECIVE_FFT
                    counterSendData <= counterSendData + 1;
                    reg_data_out_i <= data_out_mas_i[counterSendData];
                    reg_data_out_q <= data_out_mas_q[counterSendData];
                end
            end
            else counterSendData <= 0;//когда 
        end

        
        reg reg_flag_wayt_data = 1'b1;
        assign o_flag_wayt_data = reg_flag_wayt_data;
//        always @ (posedge clk)
//        begin : FLAG_RECIVE_FFT
//            if((counterReciveDataFFT < 4))  reg_flag_wayt_data <= 1'b1;
//            else                            reg_flag_wayt_data <= 1'b0;

//        end

        always @ (posedge i_clk)
        begin : flagReciveFFT
            if((counterReciveDataFFT == 3) & i_valid)               reg_flag_wayt_data <= 1'b0;
            else if((counterSendData == 3) & i_flag_ready_recive)   reg_flag_wayt_data <= 1'b1;

        end
        
        always @(posedge i_clk)//flag complete
        begin : flagComplete
            if(state == stateComplete)  o_complete <= 1'b1;
            else                        o_complete <= 1'b0;
        end
        
        
    end
    else
    begin
        
        wire [SIZE_OUT_DATA_S_FFT-1:0] data_from_secondFFT_chet_i;
        wire [SIZE_OUT_DATA_S_FFT-1:0] data_from_secondFFT_chet_q;
        wire [SIZE_OUT_DATA_S_FFT-1:0] data_from_secondFFT_Nchet_i;
        wire [SIZE_OUT_DATA_S_FFT-1:0] data_from_secondFFT_Nchet_q;
        wire flag_complete_chet;
        wire flag_complete_Nchet;

        
        //*****extern memory for massive data*****
        //after summing
//        (* ram_style="register" *) reg [DATA_FFT_SIZE-1:0] data_summ_out_mas_i_r [NFFT-1:0];
        //chet
        reg _data_summ_out_mas_i_r_writeEn_c = 1'b0;
        reg [SIZE_BUFFER-2:0] _data_summ_out_mas_i_r_addr_c/* = {(SIZE_BUFFER-1){1'b0}}*/;
        reg [SIZE_BUFFER-2:0] _data_summ_out_mas_i_r_addr_r_c/* = {(SIZE_BUFFER-1){1'b0}}*/;
        reg [SIZE_OUT_DATA-1:0] _data_summ_out_mas_i_r_writeData_c;
        wire [SIZE_OUT_DATA-1:0] _data_summ_out_mas_i_r_readData_c;
        
        //nchet
        reg _data_summ_out_mas_i_r_writeEn_Nc = 1'b0;
        reg [SIZE_BUFFER-2:0] _data_summ_out_mas_i_r_addr_Nc/* = {(SIZE_BUFFER-1){1'b0}}*/;
        reg [SIZE_BUFFER-2:0] _data_summ_out_mas_i_r_addr_r_Nc/* = {(SIZE_BUFFER-1){1'b0}}*/;
        reg [SIZE_OUT_DATA-1:0] _data_summ_out_mas_i_r_writeData_Nc;
        wire [SIZE_OUT_DATA-1:0] _data_summ_out_mas_i_r_readData_Nc;
        
        memForFFT #(.DATA_FFT_SIZE(SIZE_OUT_DATA), .SIZE_BITS_ADDRES(SIZE_BUFFER-1)/*, .name("123")*/)//? SIZE_BUFFER : SIZE_BUFFER-1
        data_summ_out_mas_i_r
        (
            .i_clk(i_clk),
            .i_writeEn(_data_summ_out_mas_i_r_writeEn_c),
            .i_readEn(i_flag_ready_recive),
            .i_addr(_data_summ_out_mas_i_r_addr_c),
            .i_addr_r(_data_summ_out_mas_i_r_addr_r_c),
            .i_inData(_data_summ_out_mas_i_r_writeData_c),
            .o_outData(_data_summ_out_mas_i_r_readData_c),
            .i_writeEn2(_data_summ_out_mas_i_r_writeEn_Nc),
            .i_readEn2(i_flag_ready_recive),
            .i_addr2(_data_summ_out_mas_i_r_addr_Nc),
            .i_addr_r2(_data_summ_out_mas_i_r_addr_r_Nc),
            .i_inData2(_data_summ_out_mas_i_r_writeData_Nc),
            .o_outData2(_data_summ_out_mas_i_r_readData_Nc)
        );
//        reg [DATA_FFT_SIZE-1:0] data_summ_out_mas_i_r [NFFT-1:0];
//        (* ram_style="register" *) reg [DATA_FFT_SIZE-1:0] data_summ_out_mas_q_r [NFFT-1:0];
        //chet
        reg _data_summ_out_mas_q_r_writeEn_c = 1'b0;
        reg [SIZE_BUFFER-2:0] _data_summ_out_mas_q_r_addr_c = {(SIZE_BUFFER-1){1'b0}};
        reg [SIZE_BUFFER-2:0] _data_summ_out_mas_q_r_addr_r_c = {(SIZE_BUFFER-1){1'b0}};
        reg [SIZE_OUT_DATA-1:0] _data_summ_out_mas_q_r_writeData_c;
        wire [SIZE_OUT_DATA-1:0] _data_summ_out_mas_q_r_readData_c;
        
        //nchet
        reg _data_summ_out_mas_q_r_writeEn_Nc = 1'b0;
        reg [SIZE_BUFFER-2:0] _data_summ_out_mas_q_r_addr_Nc = {(SIZE_BUFFER-1){1'b0}};
        reg [SIZE_BUFFER-2:0] _data_summ_out_mas_q_r_addr_r_Nc = {(SIZE_BUFFER-1){1'b0}};
        reg [SIZE_OUT_DATA-1:0] _data_summ_out_mas_q_r_writeData_Nc;
        wire [SIZE_OUT_DATA-1:0] _data_summ_out_mas_q_r_readData_Nc;
        
        memForFFT #(.DATA_FFT_SIZE(SIZE_OUT_DATA), .SIZE_BITS_ADDRES(SIZE_BUFFER-1))//? SIZE_BUFFER : SIZE_BUFFER-1
        data_summ_out_mas_q_r
        (
            .i_clk(i_clk),
            .i_writeEn(_data_summ_out_mas_q_r_writeEn_c),
            .i_readEn(i_flag_ready_recive),
            .i_addr(_data_summ_out_mas_q_r_addr_c),
            .i_addr_r(_data_summ_out_mas_q_r_addr_r_c),
            .i_inData(_data_summ_out_mas_q_r_writeData_c),
            .o_outData(_data_summ_out_mas_q_r_readData_c),
            .i_writeEn2(_data_summ_out_mas_q_r_writeEn_Nc),
            .i_readEn2(i_flag_ready_recive),
            .i_addr2(_data_summ_out_mas_q_r_addr_Nc),
            .i_addr_r2(_data_summ_out_mas_q_r_addr_r_Nc),
            .i_inData2(_data_summ_out_mas_q_r_writeData_Nc),
            .o_outData2(_data_summ_out_mas_q_r_readData_Nc)
        );
//        reg [DATA_FFT_SIZE-1:0] data_summ_out_mas_q_r [NFFT-1:0];
        
        reg valid_data_chet;
        reg valid_data_Nchet;
        
        wire [2:0] stateFFTChet;
        wire [2:0] stateFFTNChet;
        reg [SIZE_BUFFER-1:0] counterMultData = 0;
//        reg [SIZE_BUFFER-1:0] counterMultData2 = 0;
        wire [SIZE_BUFFER-1:0] counterMultData2;
        reg mutDone = 1'b0;
        
        reg validChet = 1'b1;
        reg validNChet = 1'b0;
        
//        reg resiveFromChet = 1'b1;
//        reg resiveFromNChet = 1'b1;

        wire resiveFromChet;
        wire resiveFromNChet;
        
        
        wire flag_wayt_data_chet;
        wire flag_wayt_data_Nchet;
        
        
        
        initial
        begin
            valid_data_chet = 0;
            valid_data_Nchet = 0;
        end
        //recursi
        if(PARAREL_THIS_FFT)
        begin
            //0 2 4...
            myFFT #(.SIZE_BUFFER(SIZE_BUFFER-1),.DATA_FFT_SIZE(DATA_FFT_SIZE), .FAST(FAST), .TYPE(TYPE), 
                    .COMPENS_FP(COMPENS_FP), .MIN_FFT_x4(MIN_FFT_x4), .USE_ROUND(USE_ROUND), .USE_DSP(USE_DSP),
                    .PARAREL_FFT(PARAREL_FFT))
            dataChetn(
                .i_clk(i_clk),
                .i_reset(i_reset),
                .i_valid(/*validChet & valid*/(counterReciveDataFFT[0] == 1'b0) & (/*state == stateWaytData*//*flag_wayt_data*/1) & i_valid),
                .i_data_in_i(i_data_in_i),
                .i_data_in_q(i_data_in_q),
                .o_data_out_i(data_from_secondFFT_chet_i),
                .o_data_out_q(data_from_secondFFT_chet_q),
                .o_complete(flag_complete_chet),
                .o_stateFFT(stateFFTChet),
                .i_flag_ready_recive(resiveFromChet),/*input flags for output data*/
                .o_flag_wayt_data(flag_wayt_data_chet)/*flag can recive daat data*/
            );
            //1 3 5...
            myFFT #(.SIZE_BUFFER(SIZE_BUFFER-1),.DATA_FFT_SIZE(DATA_FFT_SIZE), .FAST(FAST), .TYPE(TYPE), 
                    .COMPENS_FP(COMPENS_FP), .MIN_FFT_x4(MIN_FFT_x4), .USE_ROUND(USE_ROUND), .USE_DSP(USE_DSP),
                    .PARAREL_FFT(PARAREL_FFT))
            dataNChetn(
                .i_clk(i_clk),
                .i_reset(i_reset),
                .i_valid(/*validNChet & valid*/(counterReciveDataFFT[0] == 1'b1) & (/*state == stateWaytData*//*flag_wayt_data*/1)  & i_valid),
                .i_data_in_i(i_data_in_i),
                .i_data_in_q(i_data_in_q),
                .o_data_out_i(data_from_secondFFT_Nchet_i),
                .o_data_out_q(data_from_secondFFT_Nchet_q),
                .o_complete(flag_complete_Nchet),
                .o_stateFFT(stateFFTNChet),
                .i_flag_ready_recive(resiveFromNChet),/*input flags for output data*/
                .o_flag_wayt_data(flag_wayt_data_Nchet)/*flag can recive daat data*/
            );
        end
        else
        begin
            wire flag_wayt_data_second;
            wire flag_second_fft_valid;
            wire [DATA_FFT_SIZE-1:0] data_for_secondFFT_i;
            wire [DATA_FFT_SIZE-1:0] data_for_secondFFT_q;
            wire [SIZE_OUT_DATA_S_FFT-1:0] data_from_secondFFT_i;
            wire [SIZE_OUT_DATA_S_FFT-1:0] data_from_secondFFT_q;
            wire flag_complete_second;
            wire resiveFromSecond;
        
            myFFT #(.SIZE_BUFFER(SIZE_BUFFER-1),.DATA_FFT_SIZE(DATA_FFT_SIZE), .FAST(FAST), .TYPE(TYPE), 
                    .COMPENS_FP(COMPENS_FP), .MIN_FFT_x4(MIN_FFT_x4), .USE_ROUND(USE_ROUND), .USE_DSP(USE_DSP),
                    .PARAREL_FFT(PARAREL_FFT))
            dataChetnNChetn(
                .i_clk(i_clk),
                .i_reset(i_reset),
                .i_valid(flag_second_fft_valid),
                .i_data_in_i(data_for_secondFFT_i),
                .i_data_in_q(data_for_secondFFT_q),
                .o_data_out_i(data_from_secondFFT_i),
                .o_data_out_q(data_from_secondFFT_q),
                .o_complete(flag_complete_second),
                .o_stateFFT(stateFFTChet),
                .i_flag_ready_recive(resiveFromSecond),/*input flags for output data*/
                .o_flag_wayt_data(flag_wayt_data_second)/*flag can recive daat data*/
            );
            
            interconnect_data_to_sFFT #(.SIZE_BUFFER(SIZE_BUFFER),/*log2(NFFT)*/
                                        .DATA_FFT_SIZE(DATA_FFT_SIZE)
                                        )                            
            _interconnect_data_to_sFFT(
                .i_clk(i_clk),
                .i_reset(i_reset),
                .i_in_data_i(i_data_in_i),
                .i_in_data_q(i_data_in_q),
                .i_valid(i_valid),
                .i_fft_wayt_data(flag_wayt_data_second),
                .o_out_data_i(data_for_secondFFT_i),
                .o_out_data_q(data_for_secondFFT_q),
                .o_outvalid(flag_second_fft_valid),
                .i_counter_data(counterReciveDataFFT),
                .o_wayt_data_second_NChet(flag_wayt_data_Nchet)
            );
            
            interconnect_sFFT_to_two_data #(.SIZE_BUFFER(SIZE_BUFFER),/*log2(NFFT)*/
                                            .DATA_FFT_SIZE(SIZE_OUT_DATA_S_FFT)
                                            )
            _interconnect_sFFT_to_two_data(
                .i_clk(i_clk),
                .i_reset(i_reset),
                .i_fft_valid(flag_complete_second),
                .i_data_from_fft_i(data_from_secondFFT_i),
                .i_data_from_fft_q(data_from_secondFFT_q),
                
                .i_flag_ready_recive_chet(resiveFromChet),
                .i_flag_ready_recive_Nchet(resiveFromNChet),
                .o_data_fft_chet_i(data_from_secondFFT_chet_i),
                .o_data_fft_chet_q(data_from_secondFFT_chet_q),
                .o_data_fft_Nchet_i(data_from_secondFFT_Nchet_i),
                .o_data_fft_Nchet_q(data_from_secondFFT_Nchet_q),
                .o_complete_chet(flag_complete_chet),
                .o_complete_Nchet(flag_complete_Nchet),
                .o_resiveFromSecond(resiveFromSecond)
            );
            
        end


        reg reg_flag_wayt_data = 1'b1;


        assign o_flag_wayt_data = reg_flag_wayt_data;
        
        if(NFFT == 8)
        begin
            always @(posedge i_clk)//NOTE
            begin : flagWaytData
                if(state == stateComplete)   reg_flag_wayt_data <= 1'b1;
                else if((counterReciveDataFFT == NFFT) /*| !flag_wayt_data_Nchet*/) reg_flag_wayt_data <= 1'b0;
            end
        end
        else
        begin
            always @(posedge i_clk)//NOTE
            begin : flagWaytData
                if((counterMultData2 == /*NFFT/4*/1) )   reg_flag_wayt_data <= 1'b1;//595
//                if((counterMultData2 == /*NFFT/4*/1) | (flag_complete_Nchet & (counterMultData2 == 0)))   reg_flag_wayt_data <= 1'b1;//525
                else if((counterReciveDataFFT == (NFFT-1)) & i_valid /*| !flag_wayt_data_Nchet*/) reg_flag_wayt_data <= 1'b0;
            end
        end
        
        reg completeDoneChet = 1'b0;
        reg completeDoneNChet = 1'b0;
        
//        wire stateToComplete = mutDone;//флаг перехода в состояние отправки данных
        wire stateToComplete = (counterMultData/*2*/ == (/*NFFT/2 - NFFT/4*/1)) | mutDone;//флаг перехода в состояние отправки данных
        //данные можно уже выкидывать когда досчитываються последнии 20%
        //т.е. при FFT 256 можно выкидывать данные когда посчиталось ~100 
        
        always @(posedge i_clk)//fms
        begin : FMS_FFT
            if(i_reset)   state <= stateWaytData;
            else
            begin
                //машина конечных состоояние по состоянию данных
                case(state)
                stateWaytData:  if(counterReciveDataFFT == NFFT)    state <= stateWaytFFT;  else if(stateToComplete)   state <= stateComplete; 
                stateWaytFFT:   if(completeDoneChet & completeDoneNChet)   state <= stateWriteData;/*считывания данных с FFT второго уровня*/ else if(stateToComplete)   state <= stateComplete; 
                stateWriteData: if({flag_complete_chet, flag_complete_Nchet} == 2'b00)  state <= stateSummFFT/*stateComplete*/; else if(stateToComplete)   state <= stateComplete; 
                stateSummFFT:   if(stateToComplete)     state <= stateComplete;
                stateComplete:  if((counterSendData == (NFFT-2))/*возможно 1*/ & i_flag_ready_recive)   state <= stateWaytData;//when all data is send wayt anouther data
                endcase
            end
        end
        
        always @(posedge i_clk)
        begin : waitCompleteSecondFFT
            if(i_reset)  
            begin
                completeDoneChet <= 1'b0;
                completeDoneNChet <= 1'b0;
            end
            else
            begin
                if(state == stateSummFFT)
                begin
                    completeDoneChet <= 1'b0;
                    completeDoneNChet <= 1'b0;
                end
                else
                begin
                    if(flag_complete_chet)
                        completeDoneChet <= 1'b1;
                    if(flag_complete_Nchet)
                        completeDoneNChet <= 1'b1;
                end
            end
            
        end
        
            /*****************************SLOW FFT*****************************/
            wire [SIZE_OUT_DATA-1:0] out_summ_0__NFFT_2_i;
            wire [SIZE_OUT_DATA-1:0] out_summ_0__NFFT_2_q;
            wire [SIZE_OUT_DATA-1:0] out_summ_NFFT_2__NFFT_i;
            wire [SIZE_OUT_DATA-1:0] out_summ_NFFT_2__NFFT_q;
            
            wire interconnect_dataComplete;

            interconnect_two_sFFT_to_mFFT #(   .SIZE_BUFFER(SIZE_BUFFER),/*log2(NFFT)*/
                                               .SIZE_OUT_DATA_S_FFT(SIZE_OUT_DATA_S_FFT),
                                               .SIZE_OUT_DATA(SIZE_OUT_DATA),
                                               .TYPE(TYPE),/*forvard invers*/
                                               .COMPENS_FP(COMPENS_FP), /*false true or add razrad*/
                                               .FAST(FAST),/*slow fast ultrafast slow mult x1 fast mult x2 ultrafast mult x4*/
                                               .USE_ROUND(USE_ROUND),/*0 or 1*/
                                               .USE_DSP(USE_DSP),/*0 or 1*/
                                               .PARAPEL_THIS_FFT(PARAREL_THIS_FFT))
            _interconnect_two_sFFT_to_mFFT(
                .i_clk(i_clk),
                .i_reset(i_reset),
                
                .i_data_from_secondFFT_chet_i(data_from_secondFFT_chet_i),
                .i_data_from_secondFFT_chet_q(data_from_secondFFT_chet_q),
                .i_data_from_secondFFT_Nchet_i(data_from_secondFFT_Nchet_i),
                .i_data_from_secondFFT_Nchet_q(data_from_secondFFT_Nchet_q),
                
                .i_flag_complete_chet(flag_complete_chet),
                .i_flag_complete_Nchet(flag_complete_Nchet),
                
                .o_resiveFromChet(resiveFromChet),
                .o_resiveFromNChet(resiveFromNChet),
                
                .i_mutDone(mutDone),
                
                .o_out_summ_0__NFFT_2_i(out_summ_0__NFFT_2_i),
                .o_out_summ_0__NFFT_2_q(out_summ_0__NFFT_2_q),
                .o_out_summ_NFFT_2__NFFT_i(out_summ_NFFT_2__NFFT_i),
                .o_out_summ_NFFT_2__NFFT_q(out_summ_NFFT_2__NFFT_q),
                
                .o_counterMultData2(counterMultData2),
                .o_dataComplete(interconnect_dataComplete)
            );
            
            always @(posedge i_clk)//from summ to bufer FFT data
            begin : bufferingSummFFT
                if(mutDone | i_reset)
                begin
                    mutDone <= 1'b0;
                    counterMultData <= 0;
                    _data_summ_out_mas_i_r_writeEn_c <= 1'b0; 
                    _data_summ_out_mas_i_r_writeEn_Nc <= 1'b0; 
                    _data_summ_out_mas_q_r_writeEn_c <= 1'b0; 
                    _data_summ_out_mas_q_r_writeEn_Nc <= 1'b0;
                end
                else if(interconnect_dataComplete == 0)
                begin
                    mutDone <= 1'b0;
                    counterMultData <= 0;
                    _data_summ_out_mas_i_r_writeEn_c <= 1'b0; 
                    _data_summ_out_mas_i_r_writeEn_Nc <= 1'b0; 
                    _data_summ_out_mas_q_r_writeEn_c <= 1'b0; 
                    _data_summ_out_mas_q_r_writeEn_Nc <= 1'b0;
                end
                else
                begin
                    if(counterMultData2 > counterMultData) 
                    begin
//                        phi <= phi + 1;
                        counterMultData <= counterMultData + 1;
                        if(counterMultData < NFFT/2)
                        begin
    //                            data_summ_out_mas_i_r[counterMultData2] <= out_summ_0__NFFT_2_i;
                        _data_summ_out_mas_i_r_addr_c <= counterMultData[SIZE_BUFFER-2:0];
                        _data_summ_out_mas_i_r_writeData_c <= out_summ_0__NFFT_2_i;
                        _data_summ_out_mas_i_r_writeEn_c <= 1'b1;
                        
    //                            data_summ_out_mas_q_r[counterMultData2] <= out_summ_0__NFFT_2_q;
                        _data_summ_out_mas_q_r_addr_c <= counterMultData[SIZE_BUFFER-2:0];
                        _data_summ_out_mas_q_r_writeData_c <= out_summ_0__NFFT_2_q;
                        _data_summ_out_mas_q_r_writeEn_c <= 1'b1;
                        
    //                            data_summ_out_mas_i_r[counterMultData2 + NFFT/2] <= out_summ_NFFT_2__NFFT_i;
                        _data_summ_out_mas_i_r_addr_Nc <= counterMultData[SIZE_BUFFER-2:0];
                        _data_summ_out_mas_i_r_writeData_Nc <= out_summ_NFFT_2__NFFT_i;
                        _data_summ_out_mas_i_r_writeEn_Nc <= 1'b1;
                        
    //                            data_summ_out_mas_q_r[counterMultData2 + NFFT/2] <= out_summ_NFFT_2__NFFT_q;
                        _data_summ_out_mas_q_r_addr_Nc <= counterMultData[SIZE_BUFFER-2:0];
                        _data_summ_out_mas_q_r_writeData_Nc <= out_summ_NFFT_2__NFFT_q;
                        _data_summ_out_mas_q_r_writeEn_Nc <= 1'b1;
                        end
                    end
                    else
                    begin
                        _data_summ_out_mas_i_r_writeEn_c <= 1'b0; 
                        _data_summ_out_mas_i_r_writeEn_Nc <= 1'b0; 
                        _data_summ_out_mas_q_r_writeEn_c <= 1'b0; 
                        _data_summ_out_mas_q_r_writeEn_Nc <= 1'b0;
                    end
                    

                end
                
                if(counterMultData2 == NFFT/2)  mutDone <= 1'b1; 
            end
            /*****************************END SLOW FFT*****************************/
        

        always @ (posedge i_clk)//resiveData counter
        begin : reciveFFT
            if(i_reset)  
            begin
                counterReciveDataFFT <= 1'b0;
            end
            else
            begin
                if ((/*flag_wayt_data_chet | */flag_wayt_data_Nchet) == 1'b0) counterReciveDataFFT <= 0;
                else if(counterReciveDataFFT < NFFT)
                begin
                    if(i_valid & o_flag_wayt_data)//flag data is valid
                    begin
                        counterReciveDataFFT <= counterReciveDataFFT + 1;
                    end
                end
            end
        end
        
        
        reg [SIZE_BUFFER:0] counterSendData2;
        reg flagTimerWrite = 1'b0;//delay timer
        
                            
        assign o_data_out_i = counterSendData[SIZE_BUFFER-1] ? _data_summ_out_mas_i_r_readData_Nc : _data_summ_out_mas_i_r_readData_c;
                    
        assign o_data_out_q = counterSendData[SIZE_BUFFER-1] ? _data_summ_out_mas_q_r_readData_Nc : _data_summ_out_mas_q_r_readData_c;
        
//        assign _counterOutData = counterSendData2;
        always @(posedge i_clk)//send data
        begin : sendDataFFT
            if((state == stateComplete) /*| completeDone_r*/ & i_flag_ready_recive)//когда вые выполнено отправляю даннеы
            begin
//                if(counterSendData2 <= NFFT)
//                    counterSendData2 <= counterSendData2 + 1;
                if(counterSendData < NFFT)
                begin
                    flagTimerWrite <= 1'b1;
                    if(counterSendData2 < NFFT) counterSendData2 <= counterSendData2 + 1;
                    if(flagTimerWrite)  counterSendData <= counterSendData + 1;
                   
                    _data_summ_out_mas_i_r_addr_r_c <= counterSendData2[SIZE_BUFFER-2:0];//на такте 0 выставляеться таймер
                    _data_summ_out_mas_i_r_addr_r_Nc <= counterSendData2[SIZE_BUFFER-2:0];//на такте 0 выставляеться таймер
                    _data_summ_out_mas_q_r_addr_r_c <= counterSendData2[SIZE_BUFFER-2:0];//на такте 0 выставляеться таймер
                    _data_summ_out_mas_q_r_addr_r_Nc <= counterSendData2[SIZE_BUFFER-2:0];//на такте 0 выставляеться таймер
                end
            end
            else if(state != stateComplete) begin
                //чтобы по началу считывания я уже считывал с первого аддреса
                counterSendData2 <= 1;//когда 
                if(i_flag_ready_recive)   counterSendData <= 0;
                _data_summ_out_mas_i_r_addr_r_c <= 0;
                _data_summ_out_mas_i_r_addr_r_Nc <= 0;
                _data_summ_out_mas_q_r_addr_r_c <= 0;
                _data_summ_out_mas_q_r_addr_r_Nc <= 0;
                flagTimerWrite <= 1'b0;
            end
            else 
            begin
//                flagTimerWrite <= 1'b0;
            end
        end
        
        always @(posedge i_clk)//flag complete
        begin : flagComplete
            if(state == stateComplete/*completeDone_r*/ /*& (flagTimerWrite)*/)  o_complete <= 1'b1;
            else                        o_complete <= 1'b0;
        end
    end
    endgenerate 
    
endmodule