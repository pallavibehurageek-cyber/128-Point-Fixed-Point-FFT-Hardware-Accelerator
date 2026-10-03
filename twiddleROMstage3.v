`timescale 1ns / 1ps

module twiddle_rom2x128_ecc_wrapper #(
    parameter BIT_WIDTH = 128,
    parameter DATA_WIDTH = 120
)(
    input  wire         clk,
    input  wire         rst,
    input  wire   addr, // 1-bit address for 2 elements
    output wire [DATA_WIDTH-1:0] dout,
    output wire         DED
);

    // Array to hold the 128-bit encoded hardcoded values
    wire [BIT_WIDTH-1:0] encoded_ws1 [0:1];

    // ==========================================
    // 1. HARDCODED ENCODED VALUES
    // (Replace these with the output from the Python script)
    // ==========================================
    assign encoded_ws1[0] = 128'h00000880000000094000000102210112;
    assign encoded_ws1[1] = 128'hBA57EBA57E78000000005D2AF9175036;

    // ==========================================
    // 2. ROM MULTIPLEXER
    // ==========================================
    // Combinationally select the 128-bit word based on the address
    wire [BIT_WIDTH-1:0] selected_encoded_data;
    assign selected_encoded_data = encoded_ws1[addr];

    // ==========================================
    // 3. SECDED DECODER
    // ==========================================
    ECC_1 #(
        .BIT_WIDTH(BIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) decoder_inst (
        .clk(clk),
        .rst(rst),
        .din(selected_encoded_data),
        .DED(DED),
        .dout(dout)
    );

endmodule
