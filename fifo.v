`timescale 1ns / 1ps

module ECC_DPRAM_Wrapper #(
    parameter BIT_WIDTH = 39,
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst,
    
    // -----------------------------------------
    // WRITE PORT
    // -----------------------------------------
    input  wire                   ce_w,      // Chip Enable Write
    input  wire                   we,        // Write Enable
    input  wire [4:0]             addr_w,    // 5-bit Write Address (Depth = 32)
    input  wire [DATA_WIDTH-1:0]  din,       // 32-bit Data In
    
    // -----------------------------------------
    // READ PORT
    // -----------------------------------------
    input  wire                   ce_r,      // Chip Enable Read
    input  wire                   re,        // Read Enable
    input  wire [4:0]             addr_r,    // 5-bit Read Address (Depth = 32)
    output wire [DATA_WIDTH-1:0]  dout,      // 32-bit Corrected Data Out
    output wire                   DED        // Double Error Detection Flag
);

    // 40 bits total across 5 macros (5 * 8 = 40)
    localparam MACRO_WIDTH = 8;
    localparam NUM_MACROS  = (BIT_WIDTH + MACRO_WIDTH - 1) / MACRO_WIDTH; // Evaluates to 5
    localparam TOTAL_RAM_WIDTH = NUM_MACROS * MACRO_WIDTH;                // Evaluates to 40

    // Internal 39-bit ECC buses
    wire [BIT_WIDTH-1:0] encoded_write_data;
    wire [BIT_WIDTH-1:0] raw_read_data;
    
    // Padded 40-bit buses to cleanly map to the 5 hardware macros
    wire [TOTAL_RAM_WIDTH-1:0] padded_write_data;
    wire [TOTAL_RAM_WIDTH-1:0] padded_read_data;

    // Pad the top bit (Bit 39) with a zero for writing, and strip it for reading
    assign padded_write_data = { {(TOTAL_RAM_WIDTH - BIT_WIDTH){1'b0}}, encoded_write_data };
    assign raw_read_data = padded_read_data[BIT_WIDTH-1:0];

    // -----------------------------------------------------------------
    // 1. Encoder (Combinational Pre-Write)
    // -----------------------------------------------------------------
    ECC_Encoder1 #(
        .BIT_WIDTH(BIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) encoder_inst (
        .data_in(din),
        .cw_out(encoded_write_data)
    );

    // -----------------------------------------------------------------
    // 2. RAM Array (5 Macros x 8 bits = 40 bits)
    // -----------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < NUM_MACROS; g = g + 1) begin : ram_array
            DPRAM_32x8 u_dpram (
                // --- Port 1: DEDICATED WRITE PORT ---
                .A1   (addr_w),
                .CE1  (clk),
                .WEB1 (~we),          // Active-Low Write Enable
                .OEB1 (1'b1),         // Output disabled (we are only writing)
                .CSB1 (~ce_w),        // Active-Low Chip Select
                .I1   (padded_write_data[(g*8)+7 : (g*8)]),
                .O1   (),             // Unused
                
                // --- Port 2: DEDICATED READ PORT ---
                .A2   (addr_r),
                .CE2  (clk),
                .WEB2 (1'b1),         // Write disabled (we are only reading)
                .OEB2 (~re),          // Active-Low Output Enable
                .CSB2 (~ce_r),        // Active-Low Chip Select
                .I2   (8'h00),        // Input disabled
                .O2   (padded_read_data[(g*8)+7 : (g*8)])
            );
        end
    endgenerate

    // -----------------------------------------------------------------
    // 3. Decoder (Sequential Post-Read Correction)
    // -----------------------------------------------------------------
    ECC_1 #(
        .BIT_WIDTH(BIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) decoder_inst (
        .clk(clk),
        .rst(rst),
        .din(raw_read_data),
        .DED(DED),
        .dout(dout)
    );

endmodule

module ECC_Encoder1 #(
    parameter BIT_WIDTH = 39,
    parameter DATA_WIDTH = 32
)(
    input  wire [DATA_WIDTH-1:0] data_in,
    output reg  [BIT_WIDTH-1:0]  cw_out
);
    integer i, j, d_idx;
    
    // Automatically size the syndrome register based on the total bit width
    reg [$clog2(BIT_WIDTH)-1:0] p_calc;
    reg p_overall;

    always @(*) begin
        cw_out = {BIT_WIDTH{1'b0}};
        d_idx = 0;
        
        // 1. Distribute data bits into non-power-of-2 positions
        for (i = 1; i < BIT_WIDTH; i = i + 1) begin
            if ((i & (i - 1)) != 0) begin 
                if (d_idx < DATA_WIDTH) begin // Safety check for bounds
                    cw_out[i] = data_in[d_idx];
                    d_idx = d_idx + 1;
                end
            end
        end
        
        // 2. Calculate the standard parity bits (Syndrome generation)
        p_calc = 0;
        for (i = 1; i < BIT_WIDTH; i = i + 1) begin
            if (cw_out[i]) p_calc = p_calc ^ i[$clog2(BIT_WIDTH)-1:0];
        end
        
        // 3. Insert the parity bits into power-of-2 positions dynamically
        for (j = 0; j < $clog2(BIT_WIDTH); j = j + 1) begin
            cw_out[1 << j] = p_calc[j];
        end

        // 4. Calculate SECDED overall parity for position 0
        p_overall = 1'b0;
        for (i = 1; i < BIT_WIDTH; i = i + 1) begin
            p_overall = p_overall ^ cw_out[i];
        end
        cw_out[0] = p_overall;
    end
endmodule
