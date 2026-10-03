`timescale 1ns / 1ps

module FFT_top#(
    parameter INT_WIDTH = 1,
    parameter FRAC_WIDTH = 15,
    parameter M = 7,
    
    parameter TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH
)(
    inout PAD_CLK,
    inout PAD_RESET,
    inout PAD_LOAD,
    inout [TOTAL_WIDTH+3:0] PAD_INA, PAD_INB, PAD_INC,
    inout [TOTAL_WIDTH-1:0] PAD_IN3,
    
    inout [TOTAL_WIDTH/4-1:0] PAD_OUT,
    inout PAD_DONE, 
    inout PAD_ERR 
);
    
    // ====================================================
    // FIX: Explicitly declare all internal wires connecting 
    // the pads to the FFT core logic.
    // ====================================================
    wire clk;
    wire reset;
    wire load;
    wire [TOTAL_WIDTH+3:0] ina;
    wire [TOTAL_WIDTH+3:0] inb;
    wire [TOTAL_WIDTH+3:0] inc;
    wire [TOTAL_WIDTH-1:0] in3;
    wire [TOTAL_WIDTH/4-1:0] out;
    wire done;
    wire err;
    // ====================================================

    FFT #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .M(M) // 128-point configuration
    ) fft (
        .clk(clk),
        .reset(reset),
        .load(load),
        .ina(ina), 
        .inb(inb), 
        .inc(inc), 
        .in3(in3),
        .out(out),      // Mapped to the new single port
        .done(done),
        .err(err)
    );
    
    pc3d01 pad_clk(.PAD(PAD_CLK),.CIN(clk));
    pc3d01 pad_reset(.PAD(PAD_RESET),.CIN(reset));
    pc3d01 pad_load(.PAD(PAD_LOAD),.CIN(load));
    
    genvar i;
    generate
    for(i=0;i<TOTAL_WIDTH+4;i=i+1)begin
        pc3d01 pad_ina(.PAD(PAD_INA[i]),.CIN(ina[i]));
        pc3d01 pad_inb(.PAD(PAD_INB[i]),.CIN(inb[i]));
        pc3d01 pad_inc(.PAD(PAD_INC[i]),.CIN(inc[i]));
    end
    
    for(i=0; i<TOTAL_WIDTH/4; i=i+1)begin
        pt3t03u pad_out(.PAD(PAD_OUT[i]),.OEN(1'b0),.I(out[i]));
    end
    
    for(i=0; i<TOTAL_WIDTH; i=i+1)begin
        pc3d01 pad_in3(.PAD(PAD_IN3[i]),.CIN(in3[i]));
    end
    endgenerate
    
    pt3t03u pad_done(.PAD(PAD_DONE),.OEN(1'b0),.I(done));    
    pt3t03u pad_err(.PAD(PAD_ERR),.OEN(1'b0),.I(err));

endmodule
