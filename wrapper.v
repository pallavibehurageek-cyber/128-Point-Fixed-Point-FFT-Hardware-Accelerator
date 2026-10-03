`timescale 1ns / 1ps

module wrapper #(
    parameter BIT_WIDTH = 128,  // 120 data + 8 ECC
    parameter DATA_WIDTH = 120  // 120 useful data bits
)(
    input  wire                   clk,
    input  wire                   rst,
    
    // -----------------------------------------
    // SINGLE SHARED PORT INTERFACE
    // -----------------------------------------
    input  wire                   ce,      // Active-High Chip Enable
    input  wire                   we,      // Active-High Write Enable
    input  wire                   re,      // Active-High Read Enable
    input  wire [4:0]             addr,    // 5-bit Address (Depth = 32)
    input  wire [DATA_WIDTH-1:0]  din,     // 120-bit Data In
    output wire [DATA_WIDTH-1:0]  dout,    // 120-bit Corrected Data Out
    output wire                   DED      // Double Error Detection Flag
);

    // 128 bits total across 8 macros (8 macros * 16 effective bits = 128)
    localparam NUM_MACROS = 8; 

    // Internal 128-bit ECC buses
    wire [BIT_WIDTH-1:0] encoded_write_data;
    wire [BIT_WIDTH-1:0] raw_read_data;

    // -----------------------------------------------------------------
    // 1. Encoder (Combinational Pre-Write)
    // -----------------------------------------------------------------
    ECC_Encoder #(
        .BIT_WIDTH(BIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) encoder_inst (
        .data_in(din),
        .cw_out(encoded_write_data)
    );

    // -----------------------------------------------------------------
    // 2. RAM Array (8 Macros x (two 32x8 RAMs) = 128 bits)
    // -----------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < NUM_MACROS; g = g + 1) begin : ram_array
            
            // --- First 32x8 RAM: Handles the EVEN byte (Bits [g*16+7 : g*16]) ---
            DPRAM_32x8 u_dpram_even (
                // Port 1 (Used for shared Read/Write from the wrapper)
                .A1   (addr),                               // 5-bit Address maps 1:1
                .CE1  (clk),
                .WEB1 (~we),                                // Active-Low Write Enable
                .OEB1 (~re),                                // Active-Low Output Enable
                .CSB1 (~ce),                                // Active-Low Chip Select
                .I1   (encoded_write_data[(g*16)+7 : (g*16)]),
                .O1   (raw_read_data[(g*16)+7 : (g*16)]),
                
                // Port 2 (Unused - tied to inactive states)
                .A2   (5'b0),
                .CE2  (1'b0),
                .WEB2 (1'b1),
                .OEB2 (1'b1),
                .CSB2 (1'b1),
                .I2   (8'b0),
                .O2   ()
            );
            
            // --- Second 32x8 RAM: Handles the ODD byte (Bits [g*16+15 : g*16+8]) ---
            DPRAM_32x8 u_dpram_odd (
                // Port 1 (Used for shared Read/Write from the wrapper)
                .A1   (addr),                               // 5-bit Address maps 1:1
                .CE1  (clk),
                .WEB1 (~we),                                // Active-Low Write Enable
                .OEB1 (~re),                                // Active-Low Output Enable
                .CSB1 (~ce),                                // Active-Low Chip Select
                .I1   (encoded_write_data[(g*16)+15 : (g*16)+8]),
                .O1   (raw_read_data[(g*16)+15 : (g*16)+8]),
                
                // Port 2 (Unused - tied to inactive states)
                .A2   (5'b0),
                .CE2  (1'b0),
                .WEB2 (1'b1),
                .OEB2 (1'b1),
                .CSB2 (1'b1),
                .I2   (8'b0),
                .O2   ()
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


module ECC_Encoder #(
    parameter BIT_WIDTH = 128,
    parameter DATA_WIDTH = 120
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
