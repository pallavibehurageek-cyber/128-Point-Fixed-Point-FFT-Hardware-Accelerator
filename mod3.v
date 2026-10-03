`timescale 1ns / 1ps

module mod3_calc #(
    parameter WIDTH = 32
)(
    input clk,
    input  wire signed [WIDTH-1:0] val_in,
    output reg  [1:0] mod_out
);
    reg [WIDTH-1:0] abs_val;
    reg [1:0] rem;

    integer i;
    
    // Sizing the accumulators dynamically based on the input WIDTH
    // A 128-bit input has 64 slices of max value 3 (64*3 = 192), which fits in 8 bits.
    reg [$clog2(WIDTH)+2:0] sum1; 
    reg [4:0]               sum2; 
    reg [3:0]               sum3; 

    always @* begin
        // 1. Get absolute value (Use MSB to check sign to save a comparator)
        abs_val = val_in[WIDTH-1] ? -val_in : val_in;
        
        // ==========================================
        // 2. PARALLEL BASE-4 REDUCTION (Adder Tree)
        // ==========================================
        
        // Stage 1: Sum all 2-bit slices of the input
        sum1 = 0;
        for (i = 0; i < WIDTH; i = i + 2) begin
            // Synthesizer resolves '>> i' to static wire routing, no shifters are built
            sum1 = sum1 + ((abs_val >> i) & 2'b11);
        end

        // Stage 2: Reduce sum1 by summing its 2-bit slices
        // Even for a 256-bit input, sum2 will not exceed 13
        sum2 = 0;
        for (i = 0; i < $clog2(WIDTH)+3; i = i + 2) begin
            sum2 = sum2 + ((sum1 >> i) & 2'b11);
        end

        // Stage 3: Reduce sum2 (splits max 4-bit number into two 2-bit numbers)
        // Maximum possible value of sum3 here is 6
        sum3 = (sum2 >> 2) + (sum2 & 2'b11);

        // Stage 4: Final Lookup Table
        case (sum3)
            0, 3, 6, 9: rem = 2'd0;
            1, 4, 7:    rem = 2'd1;
            2, 5, 8:    rem = 2'd2;
            default:    rem = 2'd0;
        endcase

        // 3. Adjust for negative numbers (strictly positive remainder)
        
    end
    
    always@(negedge clk)begin
        if (val_in[WIDTH-1] && rem != 0) begin
            mod_out <= 3 - rem;
        end else begin
            mod_out <= rem;
        end
    end
endmodule
