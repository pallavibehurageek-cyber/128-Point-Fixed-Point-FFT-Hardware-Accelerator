`timescale 1ns / 1ps

module twiddle_rom_ecc_wrapper #(
    parameter BIT_WIDTH = 128,
    parameter DATA_WIDTH = 120
)(
    input  wire         clk,
    input  wire         rst,
    input  wire [2:0]   addr, // 3-bit address for 8 elements
    output wire [DATA_WIDTH-1:0] dout,
    output wire         DED
);

    // Array to hold the 128-bit encoded hardcoded values
    wire [BIT_WIDTH-1:0] encoded_ws1 [0:7];

    // ==========================================
    // 1. HARDCODED ENCODED VALUES
    // (Replace these with the output from the Python script)
    // ==========================================
    assign encoded_ws1[0] = 128'h00000880000000094000000102210112;
    assign encoded_ws1[1] = 128'hBB8E306A6E3CF0453B211F391E1EB0A1;
    assign encoded_ws1[2] = 128'hB89BE030FCBA57E42D411E78111DC936;
    assign encoded_ws1[3] = 128'h782763E707B89BE1187E5DC78C1B4DF4;
    assign encoded_ws1[4] = 128'hBA57EBA57E78000000005D2AF9175036;
    assign encoded_ws1[5] = 128'h3E70778276B89BE2E7821CAD4911E3C9;
    assign encoded_ws1[6] = 128'h030FCB89BEBA57EBD2BF5C4CF80D1FC4;
    assign encoded_ws1[7] = 128'h06A6EBB8E33CF04AC4DF3C12D8071E9D;

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
