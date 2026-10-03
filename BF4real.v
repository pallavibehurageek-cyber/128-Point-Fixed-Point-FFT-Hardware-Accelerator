`timescale 1ns / 1ps
// 3 DELAY
module BF4real #(
    parameter INT_WIDTH = 1,
    parameter FRAC_WIDTH = 15
)(
        input wire clk,
        input wire val,
        input wire rst,
        input wire signed [INT_WIDTH + FRAC_WIDTH -1:0] a,b,c,d,
        input wire signed [INT_WIDTH + FRAC_WIDTH +3:0] w1_r,w2_r,w3_r,w1_i,w2_i,w3_i,
        
        output reg  signed [INT_WIDTH + FRAC_WIDTH -1:0] A_r,C_r,C_i,
        output wire signed [INT_WIDTH + FRAC_WIDTH -1:0] B_r,B_i,D_r,D_i,
        output wire done,
        
        output reg err
    );
    
    localparam TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH;
    
    wire sVal; // preVal and sDone/preDone removed as they are redundant
    reg cMulVal;
    
    wire signed [TOTAL_WIDTH:0] s0,s1,s2,s3;
    
    wire signed [TOTAL_WIDTH+1:0] Apre_r,Bpre_r,Cpre_r,Dpre_r,Bpre_i,Dpre_i;
    reg  signed [TOTAL_WIDTH+1:0] ApreReg_r,BpreReg_r,CpreReg_r,DpreReg_r,BpreReg_i,DpreReg_i;
    
    wire signed [TOTAL_WIDTH+1:0] Cprev_r,Cprev_i; 
    reg  signed [TOTAL_WIDTH-1:0] Aprev_r,Creg_r,Creg_i;
    
    wire [4:0] error;
        
    // Cycle 1: Capture data from the combinational adder tree
    always@(negedge clk)begin
        ApreReg_r <= Apre_r;
        BpreReg_r <= Bpre_r;
        CpreReg_r <= Cpre_r;
        DpreReg_r <= Dpre_r;
        
        BpreReg_i <= Bpre_i;
        DpreReg_i <= Dpre_i;
        
        err <= |error;
    end
    
    // Delay control signal to trigger multipliers in Cycle 1
    always@(negedge clk)begin
        cMulVal <= val;
    end
    
    // Stage 1 & Stage 2 Adders evaluate entirely in Cycle 0.
    // They must all be driven by the immediate 'val' signal.
    assign sVal = val;
    
    assign Bpre_r = s1;
    assign Bpre_i = -s3; 
    
    assign Dpre_r = s1;
    assign Dpre_i = s3;
    
    // ==============================================
    // STAGE 1 Adders
    // ==============================================
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) adds0 (
        .a(a), .b(c), .val(sVal), .done(), .sum(s0)
    );
    
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) adds1 (
        .a(a), .b(-c), .val(sVal), .done(), .sum(s1)
    );
   
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) adds2 (
        .a(b), .b(d), .val(sVal), .done(), .sum(s2)
    );
    
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) adds3 (
        .a(b), .b(-d), .val(sVal), .done(), .sum(s3)
    );
    
    // ==============================================
    // STAGE 2 Adders (Must use 'val', not 'preVal')
    // ==============================================
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH+1), .FRAC_WIDTH(FRAC_WIDTH)) addAp_r (
        .a(s0), .b(s2), .val(val), .done(), .sum(Apre_r)
    );
    
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH+1), .FRAC_WIDTH(FRAC_WIDTH)) addCp_r (
        .a(s0), .b(-s2), .val(val), .done(), .sum(Cpre_r)
    );
    
    // ==============================================
    // STAGE 3: Output Alignment
    // ==============================================
    
    // A and C Pipeline Output Registers
    always@(negedge clk)begin
        // A is delayed by 2 cycles total (ApreReg -> Aprev -> A_r)
        Aprev_r <= ApreReg_r[TOTAL_WIDTH+1:2] + (ApreReg_r[1] & ApreReg_r[2]);
        A_r <= Aprev_r;
        
//        Creg_r     <= 
//        Creg_i <= ;
        
        C_r <= Cprev_r[TOTAL_WIDTH+1:2]   + (Cprev_r[1] & Cprev_r[2]);
        C_i <= Cprev_i[TOTAL_WIDTH+1:2] + (Cprev_i[1] & Cprev_i[2]);
    end
    
    // Path B Multiplier
//    complexMult #(.INT_WIDTH(INT_WIDTH+2), .FRAC_WIDTH(FRAC_WIDTH)) cMulB (
//        .clk(clk), .val(cMulVal),
//        .a_r(BpreReg_r), .b_r(w1_r), .a_i(BpreReg_i), .b_i(w1_i),
//        .prod_r(B_r), .prod_i(B_i), .done(done)
//    );
    
    redundantComplexMult #(
        .INT_WIDTH(INT_WIDTH+2),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) cMulB (
        .clk(clk),
        .rst(rst),
        .a_r(BpreReg_r), .b_r(w1_r), .a_i(BpreReg_i), .b_i(w1_i),
        .val(cMulVal),
        .prod_r(B_r), .prod_i(B_i),
        .done(done),
//        .exact_sum_r(exact_sum_r), .exact_sum_i(exact_sum_i),
        .err(error[1])
    );
    
    // Path C Multipliers (FIX: Use CpreReg_r, not Cpre_r!)
//    fixed_point_multiplier #(.INT_WIDTH(INT_WIDTH+2), .FRAC_WIDTH(FRAC_WIDTH), .OUT_WIDTH(TOTAL_WIDTH+2)) mulCr (
//        .clk(clk), .val(cMulVal),
//        .a(CpreReg_r), .b(w2_r[TOTAL_WIDTH+1:0]),
//        .done(), .prod(Cprev_r)
//    );
    redundant_multiplier #(
        .INT_WIDTH(INT_WIDTH+2),
        .FRAC_WIDTH(FRAC_WIDTH),
        .OUT_WIDTH(TOTAL_WIDTH+2)
    ) mulCr (
        .clk(clk),
        .a(CpreReg_r),
        .B(w2_r),
        .val(cMulVal),
        .done(),
        .prod(Cprev_r),
        .err(error[2])
    );
    
//    fixed_point_multiplier #(.INT_WIDTH(INT_WIDTH+2), .FRAC_WIDTH(FRAC_WIDTH),.OUT_WIDTH(TOTAL_WIDTH+2)) mulCi (
//        .clk(clk), .val(cMulVal),
//        .a(CpreReg_r), .b(w2_i[TOTAL_WIDTH+1:0]),
//        .done(), .prod(Cprev_i)
//    );
        
      redundant_multiplier #(
        .INT_WIDTH(INT_WIDTH+2),
        .FRAC_WIDTH(FRAC_WIDTH),
        .OUT_WIDTH(TOTAL_WIDTH+2)
    ) mulCi (
        .clk(clk),
        .a(CpreReg_r),
        .B(w2_i),
        .val(cMulVal),
        .done(),
        .prod(Cprev_i),
        .err(error[3])
    );
      
    // Path D Multiplier
//    complexMult #(.INT_WIDTH(INT_WIDTH+2), .FRAC_WIDTH(FRAC_WIDTH)) cMulD (
//        .clk(clk), .val(cMulVal),
//        .a_r(DpreReg_r), .b_r(w3_r), .a_i(DpreReg_i), .b_i(w3_i),
//        .prod_r(D_r), .prod_i(D_i), .done()
//    );

    redundantComplexMult #(
        .INT_WIDTH(INT_WIDTH+2),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) cMulD (
        .clk(clk),
        .rst(rst),
        .a_r(DpreReg_r), .b_r(w3_r), .a_i(DpreReg_i), .b_i(w3_i),
        .val(cMulVal),
        .prod_r(D_r), .prod_i(D_i),
        .done(),
//        .exact_sum_r(exact_sum_r), .exact_sum_i(exact_sum_i),
        .err(error[4])
    );
    
    assign error[0] = done ? ((BpreReg_r!=DpreReg_r) | (BpreReg_i!=-DpreReg_i)) : 1'b0;
    
endmodule
