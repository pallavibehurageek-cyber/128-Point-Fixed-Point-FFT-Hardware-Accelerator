`timescale 1ns / 1ps

module stage4FFT #(
    parameter INT_WIDTH=1,
    parameter FRAC_WIDTH=17
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
    
    reg fsm;
    reg dReset,val;
    reg [TOTAL_WIDTH-1:0] buff_r [0:3];
    reg [TOTAL_WIDTH-1:0] buff_i [0:3];
    
    reg [TOTAL_WIDTH-1:0] a_r,b_r,c_r,d_r,a_i,b_i,c_i,d_i;
    wire [TOTAL_WIDTH-1:0] A_r,B_r,C_r,D_r,A_i,B_i,C_i,D_i;
    wire [1:0] error;
    
    assign out0={A_i,A_r};
    assign out1={B_i,B_r};
    assign out2={C_i,C_r};
    assign out3={D_i,D_r};
        
    BF2 #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) bfA (
        .clk(clk),
        .val(val),
        .a_r(a_r), .b_r(b_r), .a_i(a_i), .b_i(b_i),
        .Areg_r(A_r), .Breg_r(B_r), .Areg_i(A_i), .Breg_i(B_i),
        .doneReg(done),
        .err(error[0])
    );
    
    BF2 #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) bfB (
        .clk(clk),
        .val(val),
        .a_r(c_r), .b_r(d_r), .a_i(c_i), .b_i(d_i),
        .Areg_r(C_r), .Breg_r(D_r), .Areg_i(C_i), .Breg_i(D_i),
        .doneReg(),
        .err(error[1])
    );
    
    always@(posedge clk)begin
        if(reset)begin
            fsm<=1;
            val<=1'b0;
            dReset<=1'b0;
        end
        else fsm<=~fsm;
        
        err <= | error;

        
        if(dReset) val<=1'b1;
        
        if(fsm)begin
            dReset<=1'b1;
            
            buff_r[0]<=in0_r;
            buff_r[1]<=in1_r;
            buff_r[2]<=in2_r;
            buff_r[3]<=in3_r;
            
            buff_i[0]<=in0_i;
            buff_i[1]<=in1_i;
            buff_i[2]<=in2_i;
            buff_i[3]<=in3_i;
            
            a_r<=buff_r[2];
            b_r<=buff_r[0]; 
            a_i<=buff_i[2];
            b_i<=buff_i[0];
            
            c_r<=buff_r[3];
            d_r<=buff_r[1];
            c_i<=buff_i[3];
            d_i<=buff_i[1];
        end
        else begin
           buff_r[0]<=in2_r; 
           buff_r[1]<=in3_r;
           buff_i[0]<=in2_i; 
           buff_i[1]<=in3_i; 
           
           a_r<=buff_r[0];
           b_r<=in0_r;
           c_r<=buff_r[1];
           d_r<=in1_r;
           a_i<=buff_i[0];
           b_i<=in0_i;
           c_i<=buff_i[1];
           d_i<=in1_i;
        end
        
    end
    
endmodule
