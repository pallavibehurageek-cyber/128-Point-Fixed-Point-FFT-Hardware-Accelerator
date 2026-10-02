`timescale 1ns / 1ps

// 3 DELAY

module BF4 # (
    parameter INT_WIDTH  = 1,  // Number of integer bits (including sign bit)
    parameter FRAC_WIDTH = 17  // Number of fractional bits
)(
        input wire clk,
        input wire rst,
        input wire signed [INT_WIDTH+FRAC_WIDTH-1:0] a_r,b_r,c_r,d_r,a_i,b_i,c_i,d_i,
        input wire signed [INT_WIDTH+FRAC_WIDTH+3:0] w1_r,w2_r,w3_r,w1_i,w2_i,w3_i,
        input wire val,
        
        output reg signed [INT_WIDTH+FRAC_WIDTH-1:0] A_r, A_i,
        output wire signed [INT_WIDTH+FRAC_WIDTH-1:0] B_r, C_r, D_r, B_i, C_i, D_i,
        output wire done,
        
        output reg err
    );
    
    localparam TOTAL_WIDTH = INT_WIDTH+FRAC_WIDTH;
    
    wire sVal,preVal;
    reg cMulVal;
    wire sDone,preDone;
    wire signed [TOTAL_WIDTH:0] s0_r,s1_r,s2_r,s3_r,s0_i,s1_i,s2_i,s3_i;
    wire signed [TOTAL_WIDTH+1:0] Apre_r,Bpre_r,Cpre_r,Dpre_r,Apre_i,Bpre_i,Cpre_i,Dpre_i;
    reg signed [TOTAL_WIDTH+1:0] ApreReg_r,BpreReg_r,CpreReg_r,DpreReg_r,ApreReg_i,BpreReg_i,CpreReg_i,DpreReg_i;
    reg signed [TOTAL_WIDTH-1:0] Aprev_r,Aprev_i;
    
    // =========================================================
    // ABFT Internal Signals
    // =========================================================
    // Pipeline to delay 'a' by 3 cycles (matching the PreReg stage)
    reg signed [TOTAL_WIDTH-1:0] a_r_d1, a_r_d2;
    reg signed [TOTAL_WIDTH-1:0] a_i_d1, a_i_d2;
    
    // Stage 1 of Adder Tree: sumAB = Apre + Bpre, sumCD = Cpre + Dpre
    // Width grows by 1 to accommodate addition without overflow (TOTAL_WIDTH+2)
    wire signed [TOTAL_WIDTH+2:0] abft_sumAB_r, abft_sumCD_r;
    wire signed [TOTAL_WIDTH+2:0] abft_sumAB_i, abft_sumCD_i;
    wire abft_tree1_done;
    
    // Stage 2 of Adder Tree: sumTotal = sumAB + sumCD
    // Width grows by 1 again (TOTAL_WIDTH+3)
    wire signed [TOTAL_WIDTH+3:0] abft_total_r, abft_total_i;
    wire errDone;
    
    wire error [1:3];
    reg error1;
    
    
    assign sVal=val;
    assign preVal=sDone;
    
    always@(negedge clk)begin
        cMulVal<=preDone;
    end
    
    always@(negedge clk)begin
        ApreReg_r<=Apre_r;
        BpreReg_r<=Bpre_r;
        CpreReg_r<=Cpre_r;
        DpreReg_r<=Dpre_r;
        
        ApreReg_i<=Apre_i;
        BpreReg_i<=Bpre_i;
        CpreReg_i<=Cpre_i;
        DpreReg_i<=Dpre_i;
        
        err <= error1 | error[1] | error[2] | error[3];

        
        // ---------------------------------------------------------
        // ABFT Error Evaluation
        // ---------------------------------------------------------
        // ---------------------------------------------------------
        // ABFT Golden Input Delay Pipeline
        // ---------------------------------------------------------
        // Cycle 1
        a_r_d1 <= a_r; 
        a_i_d1 <= a_i;
        // Cycle 2
        a_r_d2 <= a_r_d1;
        a_i_d2 <= a_i_d1;
        
        // The error tree finishes exactly 2 cycles after ApreReg is populated
        // (Cycle 5 total, aligning perfectly with 'done' signal)
        if (errDone) begin
            // a_r_d3 was populated at Cycle 3 and held. We compare it to the divided total.
            // Slicing check_r to [TOTAL_WIDTH-1:0] for perfect width matching.
            error1 <= (a_r_d1 != abft_total_r[TOTAL_WIDTH+1:2] || a_i_d1 != abft_total_i[TOTAL_WIDTH+1:2]);
        end else begin
            error1 <= 1'b0;
        end
    end
    
    //s0_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) adds0r (
        .a(a_r),
        .b(c_r),
        .val(sVal),
        .done(),
        .sum(s0_r)
    );
    
    // s0_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) adds0i (
        .a(a_i),
        .b(c_i),
        .val(sVal),
        .done(sDone),
        .sum(s0_i)
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    
    //s1_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) adds1r (
        .a(a_r),
        .b(-c_r),
        .val(sVal),
        .done(),
        .sum(s1_r)
    );
    
    // s1_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) adds1i (
        .a(a_i),
        .b(-c_i),
        .val(sVal),
        .done(),
        .sum(s1_i)
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    
    //s2_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) adds2r (
        .a(b_r),
        .b(d_r),
        .val(sVal),
        .done(),
        .sum(s2_r)
    );
    
    // s2_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) adds2i (
        .a(b_i),
        .b(d_i),
        .val(sVal),
        .done(),
        .sum(s2_i)
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    
    //s3_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) adds3r (
        .a(b_r),
        .b(-d_r),
        .val(sVal),
        .done(),
        .sum(s3_r)
    );
    
    // s3_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) adds3i (
        .a(b_i),
        .b(-d_i),
        .val(sVal),
        .done(),
        .sum(s3_i)
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // Apre_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH+1),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addAp_r (
        .a(s0_r),
        .b(s2_r),
        .val(preVal),
        .done(preDone),
        .sum(Apre_r)
    );
    
    // Apre_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH+1),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addAp_i (
        .a(s0_i),
        .b(s2_i),
        .val(preVal),
        .done(),
        .sum(Apre_i)
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    
    //Bpre_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH+1),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addBp_r (
        .a(s1_r),
        .b(s3_i),
        .val(preVal),
        .done(),
        .sum(Bpre_r)
    );
    
    // Bpre_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH+1),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addBp_i (
        .a(s1_i),
        .b(-s3_r),
        .val(preVal),
        .done(),
        .sum(Bpre_i)
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    
    //Cpre_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH+1),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addCp_r (
        .a(s0_r),
        .b(-s2_r),
        .val(preVal),
        .done(),
        .sum(Cpre_r)
    );
    
    // Cpre_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH+1),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addCp_i (
        .a(s0_i),
        .b(-s2_i),
        .val(preVal),
        .done(),
        .sum(Cpre_i)
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    
    //Dpre_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH+1),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addDp_r (
        .a(s1_r),
        .b(-s3_i),
        .val(preVal),
        .done(),
        .sum(Dpre_r)
    );
    
    // Cpre_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH+1),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addDp_i (
        .a(s1_i),
        .b(s3_r),
        .val(preVal),
        .done(),
        .sum(Dpre_i)
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    
    
    // A
    always@(negedge clk)begin
        Aprev_r <= ApreReg_r[TOTAL_WIDTH+1:2] + (ApreReg_r[1] & ApreReg_r[2]);
        Aprev_i <= ApreReg_i[TOTAL_WIDTH+1:2] + (ApreReg_i[1] & ApreReg_i[2]);
        
        A_r<=Aprev_r;
        A_i<=Aprev_i;

    end
    
    // B
//    complexMult #(
//        .INT_WIDTH(INT_WIDTH+2),
//        .FRAC_WIDTH(FRAC_WIDTH)
//    ) cMulB (
//        .clk(clk),
//        .a_r(BpreReg_r), .b_r(w1_r), .a_i(BpreReg_i), .b_i(w1_i),
//        .val(cMulVal),
//        .prod_r(B_r), .prod_i(B_i),
//        .done(done)
//    );
    
    redundantComplexMult #(
        .INT_WIDTH(INT_WIDTH+2),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) cMulB (
        .clk(clk),.rst(rst),
        .a_r(BpreReg_r), .b_r(w1_r), .a_i(BpreReg_i), .b_i(w1_i),
        .val(cMulVal),
        .prod_r(B_r), .prod_i(B_i),
        .done(done),
//        .exact_sum_r(exact_sum_r), .exact_sum_i(exact_sum_i),
        .err(error[1])
    );
    
    // C
    
//    complexMult #(
//        .INT_WIDTH(INT_WIDTH+2),
//        .FRAC_WIDTH(FRAC_WIDTH)
//    ) cMulC (
//        .clk(clk),
//        .a_r(CpreReg_r), .b_r(w2_r), .a_i(CpreReg_i), .b_i(w2_i),
//        .val(cMulVal),
//        .prod_r(C_r), .prod_i(C_i),
//        .done()
//    );
    
    redundantComplexMult #(
        .INT_WIDTH(INT_WIDTH+2),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) cMulC (
        .clk(clk),.rst(rst),
        .a_r(CpreReg_r), .b_r(w2_r), .a_i(CpreReg_i), .b_i(w2_i),
        .val(cMulVal),
        .prod_r(C_r), .prod_i(C_i),
        .done(),
//        .exact_sum_r(exact_sum_r), .exact_sum_i(exact_sum_i),
        .err(error[2])
    );
    
    
    //D 
    
//    complexMult #(
//        .INT_WIDTH(INT_WIDTH+2),
//        .FRAC_WIDTH(FRAC_WIDTH)
//    ) cMulD (
//        .clk(clk),
//        .a_r(DpreReg_r), .b_r(w3_r), .a_i(DpreReg_i), .b_i(w3_i),
//        .val(cMulVal),
//        .prod_r(D_r), .prod_i(D_i),
//        .done()
//    );
    
    redundantComplexMult #(
        .INT_WIDTH(INT_WIDTH+2),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) cMulD (
        .clk(clk),.rst(rst),
        .a_r(DpreReg_r), .b_r(w3_r), .a_i(DpreReg_i), .b_i(w3_i),
        .val(cMulVal),
        .prod_r(D_r), .prod_i(D_i),
        .done(),
//        .exact_sum_r(exact_sum_r), .exact_sum_i(exact_sum_i),
        .err(error[3])
    );
    
    //  ABFT    //
    
    // =========================================================
    // ABFT Adder Tree (Pre-Twiddle Check)
    // =========================================================
    // Tree Level 1: A+B and C+D (Cycle 4)
    
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH+2), .FRAC_WIDTH(FRAC_WIDTH)) 
    abft_add_AB_r (.a(ApreReg_r), .b(BpreReg_r), .val(cMulVal), .sum(abft_sumAB_r), .done(abft_tree1_done));
    
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH+2), .FRAC_WIDTH(FRAC_WIDTH)) 
    abft_add_AB_i (.a(ApreReg_i), .b(BpreReg_i), .val(cMulVal), .sum(abft_sumAB_i), .done());
    
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH+2), .FRAC_WIDTH(FRAC_WIDTH)) 
    abft_add_CD_r (.a(CpreReg_r), .b(DpreReg_r), .val(cMulVal), .sum(abft_sumCD_r), .done());
    
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH+2), .FRAC_WIDTH(FRAC_WIDTH)) 
    abft_add_CD_i (.a(CpreReg_i), .b(DpreReg_i), .val(cMulVal), .sum(abft_sumCD_i), .done());
    
    // Tree Level 2: Total Sum (Cycle 5)
    
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH+3), .FRAC_WIDTH(FRAC_WIDTH)) 
    abft_add_Tot_r (.a(abft_sumAB_r), .b(abft_sumCD_r), .val(abft_tree1_done), .sum(abft_total_r), .done(errDone));
    
    fixed_point_adder #(.INT_WIDTH(INT_WIDTH+3), .FRAC_WIDTH(FRAC_WIDTH)) 
    abft_add_Tot_i (.a(abft_sumAB_i), .b(abft_sumCD_i), .val(abft_tree1_done), .sum(abft_total_i), .done());
    
endmodule
