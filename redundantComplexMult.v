`timescale 1ns / 1ps

// 2 DELAY DATAPATH, 3 DELAY ERROR FLAG
module redundantComplexMult #(
    parameter INT_WIDTH  = 3,  // Number of integer bits (including sign bit)
    parameter FRAC_WIDTH = 15  // Number of fractional bits
)(
    input wire clk,
    input wire rst,
    // 'a' remains standard width. Its mod-3 will be computed dynamically.
    input wire signed [INT_WIDTH+FRAC_WIDTH-1:0] a_r, a_i,
    // 'b' is widened by 2 bits. The 2 MSBs hold the precomputed mod-3 value.
    input wire signed [INT_WIDTH+FRAC_WIDTH+1:0] b_r, b_i,
    input wire val,
    
    // --- Standard Datapath Outputs (Truncated & Rounded) ---
    output reg signed [INT_WIDTH+FRAC_WIDTH-3:0] prod_r = 0, prod_i = 0,
    output reg done,
    
    // --- Functional Safety Error Flag ---
    output reg err  // Initialize to prevent X-propagation
);
    
    localparam TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH;
    localparam EXACT_WIDTH = 2 * TOTAL_WIDTH; // 36 bits
    
    wire mulVal, addVal, mulDone;
    reg addDone;
    
    // Exact 36-bit products from the multipliers
    wire signed [EXACT_WIDTH-1:0] exact_rr, exact_ri, exact_ir, exact_ii;
    wire signed [TOTAL_WIDTH-1:0] PRErr, PREri, PREir, PREii;
    wire signed [TOTAL_WIDTH-3:0] rr, ri, ir, ii;
    wire signed [TOTAL_WIDTH-2:0] preProd_r, preProd_i;
    wire signed [EXACT_WIDTH:0] full_exact_add_r, full_exact_add_i;
    
    assign addVal = mulDone;
    assign mulVal = val;

    wire signed [TOTAL_WIDTH-1:0] b_r_val = b_r[TOTAL_WIDTH-1:0];
    wire signed [TOTAL_WIDTH-1:0] b_i_val = b_i[TOTAL_WIDTH-1:0];
    
    // ---------------------------------------------------------
    // Modulo 3 Hardware Instantiations
    // ---------------------------------------------------------
    wire [1:0] a_r_m3;
    wire [1:0] a_i_m3;
    wire [1:0] actual_r_m3;
    wire [1:0] actual_i_m3;

    // Modulo-3 extractors for input 'a' (Width = TOTAL_WIDTH, 1 Cycle Latency)
    mod3_calc #( .WIDTH(TOTAL_WIDTH) ) mod3_inst_ar (
        .clk(clk),
        .val_in(a_r),
        .mod_out(a_r_m3)
    );

    mod3_calc #( .WIDTH(TOTAL_WIDTH) ) mod3_inst_ai (
        .clk(clk),
        .val_in(a_i),
        .mod_out(a_i_m3)
    );

    // Modulo-3 extractors for exact adders (Width = EXACT_WIDTH + 1, 1 Cycle Latency)
    mod3_calc #( .WIDTH(EXACT_WIDTH + 1) ) mod3_inst_act_r (
        .clk(clk),
        .val_in(full_exact_add_r),
        .mod_out(actual_r_m3)
    );

    mod3_calc #( .WIDTH(EXACT_WIDTH + 1) ) mod3_inst_act_i (
        .clk(clk),
        .val_in(full_exact_add_i),
        .mod_out(actual_i_m3)
    );

    // ---------------------------------------------------------
    // AREA OPTIMIZED Modulo 3 Prediction Path (Combinational)
    // ---------------------------------------------------------
    // Pipeline B's mod3 tags to match the 1-cycle delay of A's mod3 extractors
    reg [1:0] b_r_m3_reg;
    reg [1:0] b_i_m3_reg;

    // 1. Initial 2x2 Multiplication
    // Since inputs are max 2, max product is 4. No product can ever equal 3.
    wire [3:0] term_rr = a_r_m3 * b_r_m3_reg;
    wire [3:0] term_ii = a_i_m3 * b_i_m3_reg;
    wire [3:0] term_ri = a_r_m3 * b_i_m3_reg;
    wire [3:0] term_ir = a_i_m3 * b_r_m3_reg;

    // Trap the value 4 (4 mod 3 = 1), otherwise pass the value safely
    wire [1:0] m_rr = (term_rr == 4) ? 2'd1 : term_rr[1:0];
    wire [1:0] m_ii = (term_ii == 4) ? 2'd1 : term_ii[1:0];
    wire [1:0] m_ri = (term_ri == 4) ? 2'd1 : term_ri[1:0];
    wire [1:0] m_ir = (term_ir == 4) ? 2'd1 : term_ir[1:0];

    // 2. Addition / Subtraction
    // Predicted Real: (m_rr - m_ii). Add +3 to offset subtraction and prevent negative numbers.
    // Bounded range: (0 + 3 - 2) = 1 up to (2 + 3 - 0) = 5.
    wire [2:0] sum_r = m_rr + 3'd3 - m_ii;
    
    // Predicted Imaginary: (m_ri + m_ir). 
    // Bounded range: 0 up to (2 + 2) = 4.
    wire [2:0] sum_i = m_ri + m_ir;

    // 3. Final Bounded Modulo 3 Mapping
    // Bounded subtraction completely replaces the heavy `mod3_calc` modules.
    wire [1:0] pred_r_comb = (sum_r >= 3) ? (sum_r - 3) : sum_r[1:0];
    wire [1:0] pred_i_comb = (sum_i >= 3) ? (sum_i - 3) : sum_i[1:0];

    // --- PIPELINE SYNC REGISTERS ---
    // Delay the combinational prediction by 1 cycle to perfectly match 
    // the latency of the `mod3_inst_act` modules.
    reg [1:0] pred_r_reg;
    reg [1:0] pred_i_reg;

    // ---------------------------------------------------------
    // Path 1: Standard Datapath Formatting
    // ---------------------------------------------------------
    assign PRErr = exact_rr >>> FRAC_WIDTH;
    assign PREri = exact_ri >>> FRAC_WIDTH;
    assign PREir = exact_ir >>> FRAC_WIDTH;
    assign PREii = exact_ii >>> FRAC_WIDTH;
    
    assign rr = PRErr[TOTAL_WIDTH-1 : 2] + PRErr[1];
    assign ri = PREri[TOTAL_WIDTH-1 : 2] + PREri[1];
    assign ir = PREir[TOTAL_WIDTH-1 : 2] + PREir[1];
    assign ii = PREii[TOTAL_WIDTH-1 : 2] + PREii[1];
    
    // ---------------------------------------------------------
    // Path 2: Exact Math for Redundancy Check
    // ---------------------------------------------------------
    assign full_exact_add_r = exact_rr - exact_ii;
    assign full_exact_add_i = exact_ri + exact_ir;
    
    // ---------------------------------------------------------
    // Main Output & Pipeline Synchronization
    // ---------------------------------------------------------
    always @(negedge clk) begin
        if(rst)begin
            done <= 1'b0;
            err <= 1'b0;
            addDone <= 1'b0;
            b_r_m3_reg <= 2'b0;
            b_i_m3_reg <= 2'b0;
            pred_r_reg <= 2'b0;
            pred_i_reg <= 2'b0;
        end else begin
            // Datapath registers
            prod_r <= preProd_r[TOTAL_WIDTH-3:0];
            prod_i <= preProd_i[TOTAL_WIDTH-3:0];
            done   <= addVal;
            
            // Register the incoming B tags
            b_r_m3_reg <= b_r[TOTAL_WIDTH+1 : TOTAL_WIDTH];
            b_i_m3_reg <= b_i[TOTAL_WIDTH+1 : TOTAL_WIDTH];
            
            // Latch prediction to delay it by 1 cycle
            pred_r_reg <= pred_r_comb;
            pred_i_reg <= pred_i_comb;
            
            // Pipeline control
            addDone <= addVal;
            
            // Safely evaluate aligned pipelines
            if (addDone) begin
                err <= (actual_r_m3 != pred_r_reg) || (actual_i_m3 != pred_i_reg);
            end else begin
                err <= 1'b0; // Ensure error clears when data is not valid
            end
        end
    end
    
    // ---------------------------------------------------------
    // Multipliers
    // ---------------------------------------------------------
    fixed_point_multiplier #( .INT_WIDTH(INT_WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .OUT_WIDTH(EXACT_WIDTH) ) 
        mulRR ( .clk(clk), .a(a_r), .b(b_r_val), .val(mulVal), .done(mulDone), .prod(exact_rr) );
    
    fixed_point_multiplier #( .INT_WIDTH(INT_WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .OUT_WIDTH(EXACT_WIDTH) ) 
        mulRI ( .clk(clk), .a(a_r), .b(b_i_val), .val(mulVal), .done(), .prod(exact_ri) );
    
    fixed_point_multiplier #( .INT_WIDTH(INT_WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .OUT_WIDTH(EXACT_WIDTH) ) 
        mulIR ( .clk(clk), .a(a_i), .b(b_r_val), .val(mulVal), .done(), .prod(exact_ir) );
    
    fixed_point_multiplier #( .INT_WIDTH(INT_WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .OUT_WIDTH(EXACT_WIDTH) ) 
        mulII ( .clk(clk), .a(a_i), .b(b_i_val), .val(mulVal), .done(), .prod(exact_ii) );
    
    // ---------------------------------------------------------
    // Adders 
    // ---------------------------------------------------------
    fixed_point_adder #( .INT_WIDTH(INT_WIDTH-2), .FRAC_WIDTH(FRAC_WIDTH) ) 
        addR ( .a(rr), .b(-ii), .val(addVal), .sum(preProd_r), .done() );
    
    fixed_point_adder #( .INT_WIDTH(INT_WIDTH-2), .FRAC_WIDTH(FRAC_WIDTH) ) 
        addI ( .a(ri), .b(ir), .val(addVal), .sum(preProd_i), .done() );
    
endmodule
