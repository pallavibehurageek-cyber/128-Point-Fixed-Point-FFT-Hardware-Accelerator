`timescale 1ns / 1ps

module FFT #(
    parameter INT_WIDTH=1,
    parameter FRAC_WIDTH=15,
    parameter M=7
)(
    input wire clk,
    input wire reset,
    input wire load,
    input wire signed [INT_WIDTH+FRAC_WIDTH+3:0] ina,inb,inc,
    input wire signed [INT_WIDTH+FRAC_WIDTH-1:0] in3,
    
    output reg signed [(INT_WIDTH+FRAC_WIDTH)/4-1:0] out,
    output reg done,
    output reg err
    );
    
    localparam TOTAL_WIDTH=INT_WIDTH+FRAC_WIDTH;
    localparam TWIDDLE_WIDTH=TOTAL_WIDTH+4;
    localparam STAGES = (M+1)/2;
    
    wire stgRst[1:STAGES-1];
    wire [TOTAL_WIDTH*2-1:0] out_0 [0:STAGES-1],out_1 [0:STAGES-1],out_2 [0:STAGES-1],out_3 [0:STAGES-1];
    reg [TOTAL_WIDTH*2-1:0] in_0 [1:STAGES-1],in_1 [1:STAGES-1],in_2 [1:STAGES-1],in_3 [1:STAGES-1];
    reg doneDelay[0:STAGES-2];
    wire stageDone[0:STAGES-1];
//    wire signed [TOTAL_WIDTH-1:0] in0,in1,in2;
    wire [STAGES-1:0] error;
    
    wire [TOTAL_WIDTH*8-1:0] inBuff,outBuff;
    reg [$clog2(128/4)-1:0] addrBuff_w;
    wire [$clog2(128/4)-1:0] addrBuff_r;
    reg [$clog2(7*128/2)+1:0] outCnt;
    wire [4:0] slice;
    reg [1:0] doneBuff;
    reg wT;
    wire buffWE;
    
    assign buffWE = stageDone[3] & wT;
    
    genvar j;
    generate
        for(j=1;j<STAGES;j=j+1)begin
            assign stgRst[j]= stageDone[j-1]^doneDelay[j-1];
        end
    endgenerate
    
//    assign done= stageDone[STAGES-1];    

    
    assign inBuff = {out_3[STAGES-1],out_2[STAGES-1],out_1[STAGES-1],out_0[STAGES-1]};
    assign addrBuff_r = outCnt[9:5];
    assign slice=outCnt[4:0];
//    assign 
        
    FFT_Stage1_to_2 #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .M(7) // 128-point configuration
    ) stage1 (
        .clk(clk),
        .reset(reset),
        .ina(ina), .inb(inb), .inc(inc), .in3(in3),
        .out0(out_0[0]), .out1(out_1[0]), .out2(out_2[0]), .out3(out_3[0]),
        .load(load),
        // .out0_i(out0_i), .out1_i(out1_i), .out2_i(out2_i), .out3_i(out3_i),
        .done(stageDone[0]),
        .err(error[0])
    );
    
    stageFFT #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) stage2 (
        .clk(clk),
        .reset(stgRst[1]),
        .in0_r(in_0[1][TOTAL_WIDTH-1:0]), .in1_r(in_1[1][TOTAL_WIDTH-1:0]), .in2_r(in_2[1][TOTAL_WIDTH-1:0]), .in3_r(in_3[1][TOTAL_WIDTH-1:0]),
        .in0_i(in_0[1][TOTAL_WIDTH*2-1:TOTAL_WIDTH]), .in1_i(in_1[1][TOTAL_WIDTH*2-1:TOTAL_WIDTH]), .in2_i(in_2[1][TOTAL_WIDTH*2-1:TOTAL_WIDTH]), .in3_i(in_3[1][TOTAL_WIDTH*2-1:TOTAL_WIDTH]),
        .out0(out_0[1]), .out1(out_1[1]), .out2(out_2[1]), .out3(out_3[1]),
        .done(stageDone[1]),
        .err(error[1])
    );
    
    stage3FFT #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) stage3 (
        .clk(clk),
        .reset(stgRst[2]),
        .in0_r(in_0[2][TOTAL_WIDTH-1:0]), .in1_r(in_1[2][TOTAL_WIDTH-1:0]), .in2_r(in_2[2][TOTAL_WIDTH-1:0]), .in3_r(in_3[2][TOTAL_WIDTH-1:0]),
        .in0_i(in_0[2][TOTAL_WIDTH*2-1:TOTAL_WIDTH]), .in1_i(in_1[2][TOTAL_WIDTH*2-1:TOTAL_WIDTH]), .in2_i(in_2[2][TOTAL_WIDTH*2-1:TOTAL_WIDTH]), .in3_i(in_3[2][TOTAL_WIDTH*2-1:TOTAL_WIDTH]),
        .out0(out_0[2]), .out1(out_1[2]), .out2(out_2[2]), .out3(out_3[2]),
        .done(stageDone[2]),
        .err(error[2])
    );
    
    stage4FFT #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) stage4 (
        .clk(clk),
        .reset(stgRst[3]),
        .in0_r(in_0[3][TOTAL_WIDTH-1:0]), .in1_r(in_1[3][TOTAL_WIDTH-1:0]), .in2_r(in_2[3][TOTAL_WIDTH-1:0]), .in3_r(in_3[3][TOTAL_WIDTH-1:0]),
        .in0_i(in_0[3][TOTAL_WIDTH*2-1:TOTAL_WIDTH]), .in1_i(in_1[3][TOTAL_WIDTH*2-1:TOTAL_WIDTH]), .in2_i(in_2[3][TOTAL_WIDTH*2-1:TOTAL_WIDTH]), .in3_i(in_3[3][TOTAL_WIDTH*2-1:TOTAL_WIDTH]),
        .out0(out_0[3]), .out1(out_1[3]), .out2(out_2[3]), .out3(out_3[3]),
        .done(stageDone[3]),
        .err(error[3])
    );
    
//    outBUFF out_buff (
//      .clka(clk),    // input wire clka
//      .wea(buffWE),      // input wire [0 : 0] wea
//      .addra(addrBuff_w),  // input wire [6 : 0] addra
//      .dina(inBuff),    // input wire [127 : 0] dina
//      .clkb(clk),    // input wire clkb
//      .addrb(addrBuff_r),  // input wire [6 : 0] addrb
//      .doutb(outBuff)  // output wire [127 : 0] doutb
//    );
    
    dpram_32x128_no_ecc #(
        .DATA_WIDTH(TOTAL_WIDTH*8),
        .ADDR_WIDTH(5)
    ) out_buff (
        .clk(clk),
        .ce_w(buffWE),
        .we(buffWE),
        .addr_w(addrBuff_w),
        .din(inBuff),
        .ce_r(1'b1),
        .re(1'b1),
        .addr_r(addrBuff_r),
        .dout(outBuff)
    );
    
    integer i;
    always @(negedge clk) begin
        if (reset) begin
            // ONLY clear the edge-detection history so it doesn't output 'x'
            for(i=1; i<STAGES; i=i+1) begin
                doneDelay[i-1] <= 1'b0;
            end
        end 
        err <= |error;

        //else begin
            // Normal pipeline operation
            for(i=1; i<STAGES; i=i+1) begin
                doneDelay[i-1] <= stageDone[i-1];
                
                in_0[i] <= out_0[i-1];
                in_1[i] <= out_1[i-1];
                in_2[i] <= out_2[i-1];
                in_3[i] <= out_3[i-1];
            end
//        end
        
        if(stgRst[STAGES-1])begin
            outCnt<=0;
            addrBuff_w<=0;
            doneBuff<=0;
            wT<=1'b1;
        end
        
        if(stageDone[3])begin
            addrBuff_w<=addrBuff_w+1;
//            if(doneBuff==0) doneBuff<=1;
            done<=1'b1;
            out <= outBuff[slice*TOTAL_WIDTH/4+:TOTAL_WIDTH/4];
            outCnt<=1;
            
            if(outCnt==31) wT<=1'b0;
        end
        
        if(doneBuff==1) doneBuff<=2;
//        if(doneBuff==2) 
        
        if(done)begin
            outCnt<=outCnt+1;
//            done<=1;
        end
    end
    
endmodule
