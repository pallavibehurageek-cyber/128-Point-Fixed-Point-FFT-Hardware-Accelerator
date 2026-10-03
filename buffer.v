`timescale 1ns / 1ps

module dpram_32x128_no_ecc #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 5
)(
    input  wire                   clk,
    
    // -----------------------------------------
    // DEDICATED WRITE PORT (Port 1)
    // -----------------------------------------
    input  wire                   ce_w,      // Active-High Chip Enable
    input  wire                   we,        // Active-High Write Enable
    input  wire [ADDR_WIDTH-1:0]  addr_w,    // 5-bit Write Address
    input  wire [DATA_WIDTH-1:0]  din,       // 128-bit Data In
    
    // -----------------------------------------
    // DEDICATED READ PORT (Port 2)
    // -----------------------------------------
    input  wire                   ce_r,      // Active-High Chip Enable
    input  wire                   re,        // Active-High Read Enable
    input  wire [ADDR_WIDTH-1:0]  addr_r,    // 5-bit Read Address
    output wire [DATA_WIDTH-1:0]  dout       // 128-bit Data Out
);

    localparam MACRO_WIDTH = 8;
    localparam NUM_MACROS  = DATA_WIDTH / MACRO_WIDTH; // Evaluates to 16

    // -----------------------------------------------------------------
    // RAM Array Generation
    // -----------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < NUM_MACROS; g = g + 1) begin : ram_array
            DPRAM_32x8 u_dpram (
                // --- Port 1: WRITE ONLY ---
                .A1   (addr_w),
                .CE1  (clk),
                .WEB1 (~we),          // Active-Low Write Enable
                .OEB1 (1'b1),         // Output disabled
                .CSB1 (~ce_w),        // Active-Low Chip Select
                .I1   (din[(g*8)+7 : (g*8)]), // Direct slice from input
                .O1   (),             // Unused
                
                // --- Port 2: READ ONLY ---
                .A2   (addr_r),
                .CE2  (clk),
                .WEB2 (1'b1),         // Write disabled
                .OEB2 (~re),          // Active-Low Output Enable
                .CSB2 (~ce_r),        // Active-Low Chip Select
                .I2   (8'h00),        // Input disabled
                .O2   (dout[(g*8)+7 : (g*8)]) // Direct slice to output
            );
        end
    endgenerate

endmodule
