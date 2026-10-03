`timescale 1ns / 1ps

module ECC_1 #(
    parameter BIT_WIDTH = 128,
    parameter DATA_WIDTH = 120
)(
    input wire clk,
    input wire rst,
    input wire [BIT_WIDTH-1:0] din,
    output reg DED,
    output reg [DATA_WIDTH-1:0] dout
);

    integer i, data_idx;
    reg [$clog2(BIT_WIDTH)-1:0] syndrome;
    reg overall_parity;
    
    // Use wires for hardware-explicit dataflow operations
    wire [BIT_WIDTH-1:0] flip_mask;
    wire [BIT_WIDTH-1:0] corrected_data;
    
    reg [DATA_WIDTH-1:0] extracted_data;
    reg ded_comb;

    // ==========================================
    // 1. Syndrome and Parity Calculation
    // ==========================================
    always @(*) begin
        syndrome = 7'b0;
        overall_parity = 1'b0;
        ded_comb = 1'b0;

        for (i = 0; i < BIT_WIDTH; i = i + 1) begin
            overall_parity = overall_parity ^ din[i];
            
            if (i > 0 && din[i] == 1'b1) begin
                syndrome = syndrome ^ i[$clog2(BIT_WIDTH)-1:0];
            end
        end

        // Double error detection logic
        if (syndrome != 0 && overall_parity == 1'b0) begin
            ded_comb = 1'b1;
        end
    end

    // ==========================================
    // 2. Hardware-Explicit Error Correction
    // ==========================================
    // If there is a single error (syndrome != 0 AND parity is odd), 
    // shift a '1' to the syndrome index to create a one-hot mask.
    assign flip_mask = (syndrome != 0 && overall_parity == 1'b1) ? ({{(BIT_WIDTH-1){1'b0}}, 1'b1} << syndrome) : {BIT_WIDTH{1'b0}};
    
    // XOR the mask with the input. The bit aligned with the '1' flips.
    assign corrected_data = din ^ flip_mask;

    // ==========================================
    // 3. Data Extraction
    // ==========================================
    always @(*) begin
        extracted_data = {DATA_WIDTH{1'b0}};
        data_idx = 0;
        
        // Start at index 1 to skip the overall parity bit
        for (i = 1; i < BIT_WIDTH; i = i + 1) begin
            // If 'i' is NOT a power of 2, it is a data bit
            if ((i & (i - 1)) != 0) begin 
                extracted_data[data_idx] = corrected_data[i];
                data_idx = data_idx + 1;
            end
        end
    end

    // ==========================================
    // 4. Output Registration
    // ==========================================
    always @(negedge clk) begin
        if (rst) begin
            dout <= {DATA_WIDTH{1'b0}};
            DED <= 1'b0;
        end else begin
            dout <= extracted_data;
            DED <= ded_comb;
        end
    end

endmodule
