`timescale 1ns / 1ps
// 0 DELAY
module fixed_point_adder #(
    parameter INT_WIDTH  = 1,  // Number of integer bits (including sign bit)
    parameter FRAC_WIDTH = 15  // Number of fractional bits
)(
    input  wire signed [INT_WIDTH + FRAC_WIDTH - 1 : 0] a,
    input  wire signed [INT_WIDTH + FRAC_WIDTH - 1 : 0] b,
    input  wire val,
    
    // Output is 1 bit wider to accommodate the carry/overflow
    output wire signed [INT_WIDTH + FRAC_WIDTH : 0]     sum,
    output wire done
);

    // Standard combinational addition using continuous assignments.
    // If 'val' is high, output the sum. Otherwise, output zero.
    assign sum  = val ? (a + b) : 0;
    
    // Pass the valid signal directly to the done flag combinationally
    assign done = val;

endmodule
