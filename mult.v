`timescale 1ns / 1ps

// 1 DELAY
module fixed_point_multiplier #(
    parameter INT_WIDTH  = 1,  // Number of integer bits (including sign bit)
    parameter FRAC_WIDTH = 15, // Number of fractional bits
    parameter OUT_WIDTH  = 16  // Desired output width
)(
    input  wire clk,
    input  wire signed [INT_WIDTH + FRAC_WIDTH - 1 : 0] a,
    input  wire signed [INT_WIDTH + FRAC_WIDTH - 1 : 0] b,
    input  wire val,
    
    output reg done,
    output reg signed [OUT_WIDTH - 1 : 0] prod // Updated to use parameterized width
);

    // Calculate internal widths
    localparam TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH;
    localparam FULL_WIDTH  = 2 * TOTAL_WIDTH;
    
    // ---------------------------------------------------------
    // Dynamic Radix Realignment
    // ---------------------------------------------------------
    // If OUT_WIDTH is large enough to hold the full exact product (e.g., 36 bits for an 18x18 mult),
    // we do not shift, preserving the exact mathematical result (2*FRAC_WIDTH fractional bits).
    // Otherwise, we shift right to drop FRAC_WIDTH LSBs and realign the radix point.
    localparam SHIFT_AMNT = (OUT_WIDTH >= FULL_WIDTH) ? 0 : FRAC_WIDTH;
    
    // Input minimum value for the overflow check
    localparam [TOTAL_WIDTH-1:0] IN_MIN_VAL = {1'b1, {(TOTAL_WIDTH-1){1'b0}}};
    
    // Output maximum value for saturation clamping
    localparam [OUT_WIDTH-1:0] OUT_MAX_VAL = {1'b0, {(OUT_WIDTH-1){1'b1}}};
    
    // Internal product wires
    wire signed [FULL_WIDTH - 1 : 0] full_product;
    wire signed [FULL_WIDTH - 1 : 0] shifted_product;
    wire signed [OUT_WIDTH - 1 : 0]  truncated_product;

    // Perform the full-precision signed multiplication
    assign full_product = a * b;

    // Shift right to realign radix point (Arithmetic shift '>>>' preserves the sign bit)
    assign shifted_product = full_product >>> SHIFT_AMNT;

    // Slice exactly the requested target output width
    assign truncated_product = shifted_product[OUT_WIDTH - 1 : 0];

    // ---------------------------------------------------------
    // Saturation Logic for the -1.0 * -1.0 Edge Case
    // ---------------------------------------------------------
    // The -1.0 * -1.0 = +1.0 overflow ONLY happens if we are dropping the extra integer 
    // bit generated during multiplication. If we are keeping full precision (SHIFT_AMNT == 0), 
    // the +1.0 fits perfectly into the expanded integer bits and does not need saturation.
    wire overflow_edge_case = (a == IN_MIN_VAL && b == IN_MIN_VAL) && (SHIFT_AMNT != 0);

    always @(negedge clk) begin
        if (val) begin
            prod <= overflow_edge_case ? OUT_MAX_VAL : truncated_product;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule
