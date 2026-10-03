`timescale 1ns / 1ps

// 1 DELAY for Data, 2 DELAY for Error Flag
module redundant_multiplier #(
    parameter INT_WIDTH  = 1,  // Number of integer bits (including sign bit)
    parameter FRAC_WIDTH = 15, // Number of fractional bits
    parameter OUT_WIDTH  = 16  // Desired output width
)(
    input  wire clk,
    input  wire signed [INT_WIDTH + FRAC_WIDTH - 1 : 0] a,
    input  wire signed [INT_WIDTH + FRAC_WIDTH + 1 : 0] B,
    input  wire val,
    
    output reg done = 0,
    output reg signed [OUT_WIDTH - 1 : 0] prod = 0,
    
    // [FIX 3a] Changed from 'wire' to 'reg' to allow safe synchronous evaluation
    output reg err = 0 
);

    // Calculate internal widths
    localparam TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH;
    localparam FULL_WIDTH  = 2 * TOTAL_WIDTH;
    
    // ---------------------------------------------------------
    // Dynamic Radix Realignment
    // ---------------------------------------------------------
    localparam SHIFT_AMNT = (OUT_WIDTH >= FULL_WIDTH) ? 0 : FRAC_WIDTH;
    
    // Input minimum value for the overflow check
    localparam [TOTAL_WIDTH-1:0] IN_MIN_VAL = {1'b1, {(TOTAL_WIDTH-1){1'b0}}};
    
    // Output maximum value for saturation clamping
    localparam [OUT_WIDTH-1:0] OUT_MAX_VAL = {1'b0, {(OUT_WIDTH-1){1'b1}}};
    
    // Internal product wires
    wire signed [FULL_WIDTH - 1 : 0] full_product;
    wire signed [FULL_WIDTH - 1 : 0] shifted_product;
    wire signed [OUT_WIDTH - 1 : 0]  truncated_product;
    
    wire signed [INT_WIDTH + FRAC_WIDTH - 1 : 0] b;

    assign b = B[TOTAL_WIDTH-1:0];
    
    // Perform the full-precision signed multiplication
    assign full_product = a * b;

    // Shift right to realign radix point
    assign shifted_product = full_product >>> SHIFT_AMNT;

    // ---------------------------------------------------------
    // Tapeout-Clean Truncation (Sinks unused upper bits)
    // ---------------------------------------------------------
    generate
        if (FULL_WIDTH > OUT_WIDTH) begin : gen_trunc
            wire [(FULL_WIDTH - OUT_WIDTH) - 1 : 0] dummy_sink;
            assign {dummy_sink, truncated_product} = shifted_product;
        end else begin : gen_no_trunc
            assign truncated_product = shifted_product[OUT_WIDTH - 1 : 0];
        end
    endgenerate

    // ---------------------------------------------------------
    // Modulo-3 Redundancy / Error Checking Logic
    // ---------------------------------------------------------
    wire [1:0] b_mod3 = B[TOTAL_WIDTH + 1 : TOTAL_WIDTH];

    wire [1:0] a_mod3;
    wire [1:0] actual_mod3_wire;

    // 1. Instantiate Modulo-3 for input 'a'
    mod3_calc #( .WIDTH(TOTAL_WIDTH) ) mod3_inst_a (
        .clk(clk),
        .val_in(a),
        .mod_out(a_mod3)
    );

    // 2. Instantiate Modulo-3 for the actual full_product
    mod3_calc #( .WIDTH(FULL_WIDTH) ) mod3_inst_actual (
        .clk(clk),
        .val_in(full_product),
        .mod_out(actual_mod3_wire)
    );

    // ---------------------------------------------------------
    // OPTIMIZED Modulo 3 Prediction Path
    // ---------------------------------------------------------
    
    // [FIX 1] Pipeline B's mod3 tag to match the 1-cycle delay of A's mod3 extractor
    reg [1:0] b_mod3_reg = 0;

    // [FIX 2] Make terms combinational and remove the mod3_inst_pred module entirely.
    // Since inputs are max 2, max product is 4. Bounded modulo math handles this cleanly.
    wire [3:0] pred_mult = a_mod3 * b_mod3_reg;
    wire [1:0] pred_mod3_comb = (pred_mult >= 3) ? (pred_mult - 3) : pred_mult[1:0];

    // ---------------------------------------------------------
    // Saturation Logic for the -1.0 * -1.0 Edge Case
    // ---------------------------------------------------------
    wire overflow_edge_case = (a == IN_MIN_VAL && b == IN_MIN_VAL) && (SHIFT_AMNT != 0);

    // Pipeline registers for the error check
    reg val_d1 = 0;
    reg err_check = 0;

    always @(negedge clk) begin
        // Pipeline Stage 1: Standard Datapath
        if (val) begin
            prod <= overflow_edge_case ? OUT_MAX_VAL : truncated_product;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
        
        // [FIX 1] Latch the combinatorial B tag
        b_mod3_reg <= b_mod3;
        
        // [FIX 3b] Sync chain to delay error check by 1 cycle relative to 'val'
        val_d1 <= val;
        err_check <= val_d1;
        
        // Pipeline Stage 2: Functional Safety Evaluation
        if (err_check) begin
            // Samples stable combinatorial outputs exactly 1 cycle after mod3_calc finishes
            err <= (actual_mod3_wire != pred_mod3_comb);
        end else begin
            err <= 1'b0;
        end
    end

endmodule
