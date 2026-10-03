`timescale 1ns / 1ps

// 2 DELAY
module complexMult #(
    parameter INT_WIDTH  = 3,  // Number of integer bits (including sign bit)
    parameter FRAC_WIDTH = 15  // Number of fractional bits
)(
    input wire clk,
    input wire signed [INT_WIDTH+FRAC_WIDTH-1:0] a_r, b_r, a_i, b_i,
    input wire val,
    
    // --- Standard Datapath Outputs (Truncated & Rounded) ---
    output reg signed [INT_WIDTH+FRAC_WIDTH-3:0] prod_r, prod_i,
    output reg done

    // --- NEW: Exact Outputs for Modulo-3 Redundancy Check ---
    // Width is 2*(TOTAL_WIDTH) + 1 to hold the full exact sum without overflow
//    output reg signed [2*(INT_WIDTH+FRAC_WIDTH):0] exact_sum_r, exact_sum_i
);
    
    localparam TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH;
    localparam EXACT_WIDTH = 2 * TOTAL_WIDTH; // 36 bits
    
    reg signed [2*(INT_WIDTH+FRAC_WIDTH):0] exact_sum_r, exact_sum_i;
    
    wire mulVal, addVal, mulDone, addDone;
    
    // Exact 36-bit products from the multipliers
    wire signed [EXACT_WIDTH-1:0] exact_rr, exact_ri, exact_ir, exact_ii;
    
    // The 18-bit truncated product wires for the standard datapath
    wire signed [TOTAL_WIDTH-1:0] PRErr, PREri, PREir, PREii;
    
    // The rounded wires before standard addition
    wire signed [TOTAL_WIDTH-3:0] rr, ri, ir, ii;
    wire signed [TOTAL_WIDTH-2:0] preProd_r, preProd_i;
    
    // Combinational exact sum wires (37-bit)
    wire signed [EXACT_WIDTH:0] full_exact_add_r, full_exact_add_i;
    
    assign addVal = mulDone;
    assign mulVal = val;
    
    // ---------------------------------------------------------
    // Path 1: Standard Datapath Formatting
    // ---------------------------------------------------------
    // Shift right by FRAC_WIDTH to drop the exact LSBs, realigning to 18-bit format.
    // Slicing [TOTAL_WIDTH-1:0] accurately mimics the standard multiplier output.
    assign PRErr = exact_rr >>> FRAC_WIDTH;
    assign PREri = exact_ri >>> FRAC_WIDTH;
    assign PREir = exact_ir >>> FRAC_WIDTH;
    assign PREii = exact_ii >>> FRAC_WIDTH;
    
    // Your exact rounding logic
    assign rr = PRErr[TOTAL_WIDTH-1 : 2] + PRErr[1];
    assign ri = PREri[TOTAL_WIDTH-1 : 2] + PREri[1];
    assign ir = PREir[TOTAL_WIDTH-1 : 2] + PREir[1];
    assign ii = PREii[TOTAL_WIDTH-1 : 2] + PREii[1];
    
    // ---------------------------------------------------------
    // Path 2: Exact Math for Redundancy Check
    // ---------------------------------------------------------
    // No bits are dropped. This preserves the properties required for modulo arithmetic.
    assign full_exact_add_r = exact_rr - exact_ii;
    assign full_exact_add_i = exact_ri + exact_ir;
    
    // ---------------------------------------------------------
    // Pipeline Synchronization
    // ---------------------------------------------------------
    always @(posedge clk) begin
        // Standard Outputs
        prod_r <= preProd_r[TOTAL_WIDTH-3:0];
        prod_i <= preProd_i[TOTAL_WIDTH-3:0];
        done   <= addDone;
        
        // Register the exact sums at the exact same pipeline stage as the standard outputs
        if (addDone) begin
            exact_sum_r <= full_exact_add_r;
            exact_sum_i <= full_exact_add_i;
        end
    end
    
    // ---------------------------------------------------------
    // Multipliers (Now running at EXACT_WIDTH)
    // ---------------------------------------------------------
    // RR      
    fixed_point_multiplier #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .OUT_WIDTH(EXACT_WIDTH)
    ) mulRR (
        .clk(clk), .a(a_r), .b(b_r), .val(mulVal), .done(mulDone), .prod(exact_rr)
    );
    
    // RI
    fixed_point_multiplier #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .OUT_WIDTH(EXACT_WIDTH)
    ) mulRI (
        .clk(clk), .a(a_r), .b(b_i), .val(mulVal), .done(), .prod(exact_ri)
    );
    
    // IR
    fixed_point_multiplier #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .OUT_WIDTH(EXACT_WIDTH)
    ) mulIR (
        .clk(clk), .a(a_i), .b(b_r), .val(mulVal), .done(), .prod(exact_ir)
    );
    
    // II
    fixed_point_multiplier #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .OUT_WIDTH(EXACT_WIDTH)
    ) mulII (
        .clk(clk), .a(a_i), .b(b_i), .val(mulVal), .done(), .prod(exact_ii)
    );
    
    // ---------------------------------------------------------
    // Adders (Standard Truncated Datapath)
    // ---------------------------------------------------------
    // REAL  
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH-2),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addR (
        .a(rr), .b(-ii), .val(addVal), .sum(preProd_r), .done(addDone)
    );
    
    // IMAG  
    fixed_point_adder #(
        .INT_WIDTH(INT_WIDTH-2),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) addI (
        .a(ri), .b(ir), .val(addVal), .sum(preProd_i), .done()
    );
    
endmodule
