`timescale 1ns / 1ps

module ecc_shift_register_wrapper #(
    parameter DATA_WIDTH = 32, // Width of unencoded data
    parameter BIT_WIDTH  = 39, // DATA_WIDTH + SECDED ECC bits (32 + 7 = 39)
    parameter DEPTH      = 8   // Depth of the shift register
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  en,   // Shift enable
    input  wire [DATA_WIDTH-1:0] din,  // Data going into the shift register
    output wire [DATA_WIDTH-1:0] dout, // Corrected data coming out
    output wire                  DED   // Double Error Detection flag
);

    wire [BIT_WIDTH-1:0] encoded_din;
    
    // The Shift Register is now expanded to hold the full BIT_WIDTH (Data + ECC)
    // Scaled dynamically using the DEPTH parameter
    reg [BIT_WIDTH-1:0] buff [0:DEPTH-1];
    integer j;

    // -----------------------------------------------------------------
    // 1. Encoder (Combinational Pre-Shift)
    // -----------------------------------------------------------------
    ECC_Encoder1 #(
        .BIT_WIDTH(BIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) encoder_inst (
        .data_in(din),
        .cw_out(encoded_din)
    );

    // -----------------------------------------------------------------
    // 2. The Parameterized Shift Register
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (en) begin
            buff[0] <= encoded_din;
            for(j=1; j<DEPTH; j=j+1) begin
                buff[j] <= buff[j-1];
            end
        end
    end

    // -----------------------------------------------------------------
    // 3. Decoder (Sequential Post-Shift)
    // -----------------------------------------------------------------
    ECC_1 #(
        .BIT_WIDTH(BIT_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) decoder_inst (
        .clk(clk),
        .rst(rst),
        .din(buff[DEPTH-1]), // Automatically taps the final stage
        .DED(DED),
        .dout(dout)
    );

endmodule
