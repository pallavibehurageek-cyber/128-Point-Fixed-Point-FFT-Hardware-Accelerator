`timescale 1ns / 1ps

module stage3FFT #(
    parameter INT_WIDTH=1,
    parameter FRAC_WIDTH=17,
    parameter M=7,
    parameter L=2
)(
    input wire clk,
    input wire reset,
    input wire signed [INT_WIDTH+FRAC_WIDTH-1:0] in0_r, in1_r, in2_r, in3_r,
    input wire signed [INT_WIDTH+FRAC_WIDTH-1:0] in0_i, in1_i, in2_i, in3_i,
    
    output wire signed [(INT_WIDTH+FRAC_WIDTH)*2-1:0] out0, out1, out2, out3,
    output wire done,
    output reg err
);
    
    localparam TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH;
    localparam TWIDDLE_WIDTH = TOTAL_WIDTH + 4;
    
//    wire [TWIDDLE_WIDTH*6-1:0] ws1 [0:1];
    
    // ==========================================
    // STAGE 1 VARIABLES
    // ==========================================
    reg signed [TOTAL_WIDTH-1:0] a_r, b_r, c_r, d_r;
    reg signed [TOTAL_WIDTH-1:0] a_i, b_i, c_i, d_i;
    wire signed [TOTAL_WIDTH-1:0] A_r, B_r, C_r, D_r, A_i, B_i, C_i, D_i;
    wire signed [TWIDDLE_WIDTH-1:0] w1_r, w2_r, w3_r, w1_i, w2_i, w3_i;  
    
    reg valInt;
    reg [1:0] dReset;
    wire [TWIDDLE_WIDTH*6-1:0] wsDout;
    wire [1:0] error;
    
    // RAM Addresses & Control
    reg ws1Addra; // Fixed to wrap naturally around 0-7
    
    // Twiddle Extractor
    assign w1_r = wsDout[0 +: TWIDDLE_WIDTH];
    assign w1_i = wsDout[TWIDDLE_WIDTH +: TWIDDLE_WIDTH];
    assign w2_r = wsDout[TWIDDLE_WIDTH*2 +: TWIDDLE_WIDTH];
    assign w2_i = wsDout[TWIDDLE_WIDTH*3 +: TWIDDLE_WIDTH];
    assign w3_r = wsDout[TWIDDLE_WIDTH*4 +: TWIDDLE_WIDTH];
    assign w3_i = wsDout[TWIDDLE_WIDTH*5 +: TWIDDLE_WIDTH];
    
    assign out0  = {A_i,A_r};
    assign out1  = {B_i,B_r};
    assign out2  = {C_i,C_r};
    assign out3 = {D_i,D_r};
        
    // TWIDDLE MEM (Synthesizable ROM)
    twiddle_rom2x128_ecc_wrapper #(
        .BIT_WIDTH(128),
        .DATA_WIDTH(TWIDDLE_WIDTH*6)
    ) ws1(
        .clk(clk),
        .rst(reset),
        .addr(ws1Addra), // 3-bit address for 8 elements
        .dout(wsDout),
        .DED(error[0])
    );
//    assign ws1[0] = 120'h000008800000000880000000088000;
//    assign ws1[1] = 120'hBA57EBA57E7800000000BA57E45A82;

    // ==========================================
    // MODULE INSTANTIATIONS
    // ==========================================
    BF4 #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) bf4 (
        .clk(clk),.rst(rst),
        .a_r(a_r), .b_r(b_r), .c_r(c_r), .d_r(d_r),
        .a_i(a_i), .b_i(b_i), .c_i(c_i), .d_i(d_i),
        .w1_r(w1_r), .w2_r(w2_r), .w3_r(w3_r), 
        .w1_i(w1_i), .w2_i(w2_i), .w3_i(w3_i),
        .val(valInt),
        .A_r(A_r), .B_r(B_r), .C_r(C_r), .D_r(D_r),
        .A_i(A_i), .B_i(B_i), .C_i(C_i), .D_i(D_i),
        .done(done),
        .err(error[1])
    );
    
    // ==========================================
    // SEQUENTIAL LOGIC
    // ==========================================
    
    always @(posedge clk) begin
        if(reset) begin
            ws1Addra <= 0;
            dReset <= 1;
            valInt <= 0;
            
        end else begin 
            
            if(dReset==1) valInt <= 1'b1;
            if(valInt) ws1Addra <= ws1Addra + 1;
            
            // Push Stage 1 Inputs
            a_r <= in0_r;
            b_r <= in1_r;
            c_r <= in2_r;
            d_r <= in3_r;
            
            a_i <= in0_i;
            b_i <= in1_i;
            c_i <= in2_i;
            d_i <= in3_i;
            err <= |error;

//            wsDout <= ws1[ws1Addra];
        end
    end
    
endmodule
