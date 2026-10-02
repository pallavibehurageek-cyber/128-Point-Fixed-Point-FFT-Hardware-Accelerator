`timescale 1ns / 1ps

// Pipeline Delay: 2 Cycles (Due to ABFT check)
module BF2 #(
    parameter INT_WIDTH = 1,
    parameter FRAC_WIDTH = 17
)(
    input wire clk,
    input wire val,
    input wire signed [INT_WIDTH+FRAC_WIDTH-1:0] a_r, b_r, a_i, b_i,
    
    output reg signed [INT_WIDTH+FRAC_WIDTH-1:0] Areg_r, Breg_r, Areg_i, Breg_i,
    output reg doneReg,
    output reg err
);
    
    localparam TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH;
    
    // Main Adders Output Wires (Grown by 1 bit to prevent overflow)
    wire signed [TOTAL_WIDTH:0] A_r, A_i, B_r, B_i;
    
    // Stage 1 Registers for ABFT inputs
    reg signed [TOTAL_WIDTH:0] A_rReg, B_rReg, A_iReg, B_iReg;
    
    // 2-Deep Pipeline for Golden Inputs (Resolves the timing hazard)
    reg signed [TOTAL_WIDTH-1:0] a_r_d1;
    reg signed [TOTAL_WIDTH-1:0] a_i_d1;
    
    // ABFT Adder Output Wires (Grown by 1 more bit for A + B)
    wire signed [TOTAL_WIDTH+1:0] r, i;
    wire signed [TOTAL_WIDTH:0] R, I;
    
    wire done, errVal;
    reg errDone;
    
    // Divide by 2 (Shift right by 1) to evaluate (A+B)/2 = a
    assign R = r[TOTAL_WIDTH+1:1];
    assign I = i[TOTAL_WIDTH+1:1];
    
    always @(negedge clk) begin
        // ---------------------------------------------------------
        // Standard BF2 Datapath
        // ---------------------------------------------------------
        // Convergent Rounding applied to the final stage division
        Areg_r <= A_r[TOTAL_WIDTH:1] + (A_r[0] & A_r[1]);
        Breg_r <= B_r[TOTAL_WIDTH:1] + (B_r[0] & B_r[1]);
        Areg_i <= A_i[TOTAL_WIDTH:1] + (A_i[0] & A_i[1]);
        Breg_i <= B_i[TOTAL_WIDTH:1] + (B_i[0] & B_i[1]);
        
        // ---------------------------------------------------------
        // ABFT Safety Pipeline Synchronization
        // ---------------------------------------------------------
        // Stage 1 ABFT Registers
        A_rReg <= A_r;
        B_rReg <= B_r;
        A_iReg <= A_i;
        B_iReg <= B_i;
        
        // Stage 1 Golden Input Delay
        a_r_d1 <= a_r;
        a_i_d1 <= a_i;
        
        // Stage 2 Golden Input Delay
//        a_r_d2 <= a_r_d1;
//        a_i_d2 <= a_i_d1;
        
        doneReg <= done;
        
        // ---------------------------------------------------------
        // Stage 2 Error Evaluation
        // ---------------------------------------------------------
        errDone<= errVal;
        if (errDone) begin
            // Slicing R and I down to 18 bits ensures an exact width match for the comparator
            err <= (a_r_d1 != R[TOTAL_WIDTH-1:0] || a_i_d1 != I[TOTAL_WIDTH-1:0]);
        end else begin
            // Clear the error flag when no active calculation is finishing
            err <= 1'b0; 
        end
    end
    
    // =========================================================
    // Stage 1: Main Butterfly Additions
    // =========================================================
    // A_r = a_r + b_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) s0r (
        .a(a_r),
        .b(b_r),
        .val(val),
        .sum(A_r),
        .done(done)
    );
    
    // A_i = a_i + b_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) s0i (
        .a(a_i),
        .b(b_i),
        .val(val),
        .sum(A_i),
        .done()
    );
    
    // B_r = a_r - b_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) s1r (
        .a(a_r),
        .b(-b_r),
        .val(val),
        .sum(B_r),
        .done()
    );
    
    // B_i = a_i - b_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) s1i (
        .a(a_i),
        .b(-b_i),
        .val(val),
        .sum(B_i),
        .done()
    );
    
    // =========================================================
    // Stage 2: Algorithm-Based Fault Tolerance (ABFT) Additions
    // =========================================================
    // r = A_r + B_r
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH+1) // Adder needs +1 FRAC_WIDTH because inputs grew to 19 bits
    ) abft_r (
        .a(A_rReg),
        .b(B_rReg),
        .val(done),
        .sum(r),
        .done(errVal)
    );
    
    // i = A_i + B_i
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH+1)
    ) abft_i (
        .a(A_iReg),
        .b(B_iReg),
        .val(done),
        .sum(i),
        .done()
    );
        
endmodule
