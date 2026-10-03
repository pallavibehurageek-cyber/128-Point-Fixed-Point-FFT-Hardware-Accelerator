`timescale 1ns / 1ps

module stageFFT #(
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
    output reg done,
    
    output wire err
);
    
    localparam TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH;
    localparam TWIDDLE_WIDTH = TOTAL_WIDTH + 4;
    
//    wire [TWIDDLE_WIDTH*6-1:0] ws1 [0:7];
    
    // ==========================================
    // STAGE 1 VARIABLES
    // ==========================================
    reg signed [TOTAL_WIDTH-1:0] a_r, b_r, c_r, d_r;
    reg signed [TOTAL_WIDTH-1:0] a_i, b_i, c_i, d_i;
    wire signed [TOTAL_WIDTH-1:0] A_r, B_r, C_r, D_r, A_i, B_i, C_i, D_i;
    wire signed [TWIDDLE_WIDTH-1:0] w1_r, w2_r, w3_r, w1_i, w2_i, w3_i;  
    
    wire doneInt;
    reg valInt;
    reg [1:0] dReset;
    wire [TWIDDLE_WIDTH*6-1:0] wsDout;
    wire [7:0] error;
    
    // ==========================================
    // COMMUTATOR VARIABLES 
    // ==========================================
    // Data going INTO Pre-FIFOs (From Stage 1)
    reg [TOTAL_WIDTH*2-1:0] din_w0_pre;
    reg [TOTAL_WIDTH*2-1:0] din_w1_pre;
    reg [TOTAL_WIDTH*2-1:0] din_w2_pre;
    reg [TOTAL_WIDTH*2-1:0] dout_w3_pre; // No delay on W3 pre-switch
    
    // Data coming OUT of Pre-FIFOs (Going to Switch)
    wire [TOTAL_WIDTH*2-1:0] dout_w0_pre;
    wire [TOTAL_WIDTH*2-1:0] dout_w1_pre;
    wire [TOTAL_WIDTH*2-1:0] dout_w2_pre;
    
    // Data going INTO Post-FIFOs (From Switch)
    reg [TOTAL_WIDTH*2-1:0] din_w0_post;
    reg [TOTAL_WIDTH*2-1:0] din_w1_post;
    reg [TOTAL_WIDTH*2-1:0] din_w2_post;
    reg [TOTAL_WIDTH*2-1:0] dout_w3_post; 
    
    // Data coming OUT of Post-FIFOs (Going to Stage 2)
    wire [TOTAL_WIDTH*2-1:0] dout_w0_post;
    wire [TOTAL_WIDTH*2-1:0] dout_w1_post;
    wire [TOTAL_WIDTH*2-1:0] dout_w2_post;
    
    // ==========================================
    // SHIFT REGISTERS (DFF Delays)
    // ==========================================
    // Wire 0 Shift Registers (Depth 24)
//    reg [TOTAL_WIDTH*2-1:0] buff_w0_pre  [0:L*3-1];
//    reg [TOTAL_WIDTH*2-1:0] buff_w0_post [0:L*3-1];
    
    // Wire 1 Shift Registers (Depth 16)
//    reg [TOTAL_WIDTH*2-1:0] buff_w1_pre  [0:L*2-1];
//    reg [TOTAL_WIDTH*2-1:0] buff_w1_post [0:L*2-1];

    // Wire 2 Shift Registers (Depth 8)
//    reg [TOTAL_WIDTH*2-1:0] buff_w2_pre  [0:L-1];
//    reg [TOTAL_WIDTH*2-1:0] buff_w2_post [0:L-1];

    ecc_shift_register_wrapper #(
        .DATA_WIDTH(TOTAL_WIDTH*2),     // e.g., 32 bits
        .BIT_WIDTH(39),   // e.g., 39 bits
        .DEPTH(L*3)
    ) buff_w0_pre (
        .clk(clk),
        .rst(reset),
        .en(1'b1), // Or tie this to your pipeline enable logic if necessary
        .din(din_w0_pre),
        .dout(dout_w0_pre),
        .DED(error[0])
    );
    
    ecc_shift_register_wrapper #(
        .DATA_WIDTH(TOTAL_WIDTH*2),     // e.g., 32 bits
        .BIT_WIDTH(39),   // e.g., 39 bits
        .DEPTH(L*3)
    ) buff_w0_post (
        .clk(clk),
        .rst(reset),
        .en(1'b1), // Or tie this to your pipeline enable logic if necessary
        .din(din_w0_post),
        .dout(dout_w0_post),
        .DED(error[1])
    );
    
    ecc_shift_register_wrapper #(
        .DATA_WIDTH(TOTAL_WIDTH*2),     // e.g., 32 bits
        .BIT_WIDTH(39),   // e.g., 39 bits
        .DEPTH(L*2)
    ) buff_w1_pre (
        .clk(clk),
        .rst(reset),
        .en(1'b1), // Or tie this to your pipeline enable logic if necessary
        .din(din_w1_pre),
        .dout(dout_w1_pre),
        .DED(error[2])
    );
    
    ecc_shift_register_wrapper #(
        .DATA_WIDTH(TOTAL_WIDTH*2),     // e.g., 32 bits
        .BIT_WIDTH(39),   // e.g., 39 bits
        .DEPTH(L*2)
    ) buff_w1_post (
        .clk(clk),
        .rst(reset),
        .en(1'b1), // Or tie this to your pipeline enable logic if necessary
        .din(din_w1_post),
        .dout(dout_w1_post),
        .DED(error[3])
    );
    
    ecc_shift_register_wrapper #(
        .DATA_WIDTH(TOTAL_WIDTH*2),     // e.g., 32 bits
        .BIT_WIDTH(39),   // e.g., 39 bits
        .DEPTH(L)
    ) buff_w2_pre (
        .clk(clk),
        .rst(reset),
        .en(1'b1), // Or tie this to your pipeline enable logic if necessary
        .din(din_w2_pre),
        .dout(dout_w2_pre),
        .DED(error[4])
    );
    
    ecc_shift_register_wrapper #(
        .DATA_WIDTH(TOTAL_WIDTH*2),     // e.g., 32 bits
        .BIT_WIDTH(39),   // e.g., 39 bits
        .DEPTH(L)
    ) buff_w2_post (
        .clk(clk),
        .rst(reset),
        .en(1'b1), // Or tie this to your pipeline enable logic if necessary
        .din(din_w2_post),
        .dout(dout_w2_post),
        .DED(error[5])
    );
    
    // RAM Addresses & Control
    reg [2:0] ws1Addra; // Fixed to wrap naturally around 0-7
    reg [5:0] cnt;
    wire [1:0] fsm;

    // ==========================================
    // DATAPATH ASSIGNMENTS
    // ==========================================
    assign fsm = cnt / L;
    
    // Twiddle Extractor
    assign w1_r = wsDout[0 +: TWIDDLE_WIDTH];
    assign w1_i = wsDout[TWIDDLE_WIDTH +: TWIDDLE_WIDTH];
    assign w2_r = wsDout[TWIDDLE_WIDTH*2 +: TWIDDLE_WIDTH];
    assign w2_i = wsDout[TWIDDLE_WIDTH*3 +: TWIDDLE_WIDTH];
    assign w3_r = wsDout[TWIDDLE_WIDTH*4 +: TWIDDLE_WIDTH];
    assign w3_i = wsDout[TWIDDLE_WIDTH*5 +: TWIDDLE_WIDTH];
    
    // Shift Register Outputs (Last element in the array)
//    assign dout_w0_pre  = buff_w0_pre[3*L-1];
//    assign dout_w0_post = buff_w0_post[3*L-1];
    
//    assign dout_w1_pre  = buff_w1_pre[2*L-1];
//    assign dout_w1_post = buff_w1_post[2*L-1];

//    assign dout_w2_pre  = buff_w2_pre[L-1];
//    assign dout_w2_post = buff_w2_post[L-1];
        
    // Output Wiring
    assign out0 = dout_w0_post;
    assign out1 = dout_w1_post;
    assign out2 = dout_w2_post;
    assign out3 = dout_w3_post;
    
    assign err = |error;
    
    // TWIDDLE MEM (Synthesizable ROM)
    twiddle_rom_ecc_wrapper #(
        .BIT_WIDTH(128),
        .DATA_WIDTH(TWIDDLE_WIDTH*6)
    ) ws1(
        .clk(clk),
        .rst(reset),
        .addr(ws1Addra), // 3-bit address for 8 elements
        .dout(wsDout),
        .DED(error[6])
    );
//    assign ws1[0] = 120'h000008800000000880000000088000;
//    assign ws1[1] = 120'hBB8E306A6E3CF04476423E70787D8A;
//    assign ws1[2] = 120'hB89BE030FCBA57E45A823CF0447642;
//    assign ws1[3] = 120'h782763E707B89BE030FCBB8E306A6E;
//    assign ws1[4] = 120'hBA57EBA57E7800000000BA57E45A82;
//    assign ws1[5] = 120'h3E70778276B89BE3CF04395924471D;
//    assign ws1[6] = 120'h030FCB89BEBA57EBA57EB89BE030FC;
//    assign ws1[7] = 120'h06A6EBB8E33CF04B89BE78276018F9;

    // ==========================================
    // MODULE INSTANTIATIONS
    // ==========================================
    BF4 #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) dut (
        .clk(clk),.rst(reset),
        .a_r(a_r), .b_r(b_r), .c_r(c_r), .d_r(d_r),
        .a_i(a_i), .b_i(b_i), .c_i(c_i), .d_i(d_i),
        .w1_r(w1_r), .w2_r(w2_r), .w3_r(w3_r), 
        .w1_i(w1_i), .w2_i(w2_i), .w3_i(w3_i),
        .val(valInt),
        .A_r(A_r), .B_r(B_r), .C_r(C_r), .D_r(D_r),
        .A_i(A_i), .B_i(B_i), .C_i(C_i), .D_i(D_i),
        .done(doneInt),
        .err(error[7])
    );
    
    // ==========================================
    // COMBINATIONAL SWITCH 
    // ==========================================
    always @(*) begin
        // 1. Pack Stage 1 output into Pre-Delay Wires
        din_w0_pre  = {D_i, D_r};
        din_w1_pre  = {C_i, C_r};
        din_w2_pre  = {B_i, B_r};
        dout_w3_pre = {A_i, A_r};

        // 2. Default Post-Switch Values
        din_w0_post  = 'd0;
        din_w1_post  = 'd0;
        din_w2_post  = 'd0;
        dout_w3_post = 'd0;
            
        // 3. The 4x4 Commutator Switch
        case(fsm)
            2'd0: begin
                din_w0_post  = dout_w3_pre;
                din_w1_post  = dout_w0_pre;
                din_w2_post  = dout_w1_pre;
                dout_w3_post = dout_w2_pre;
            end
            2'd1: begin
                din_w0_post  = dout_w2_pre;
                din_w1_post  = dout_w3_pre;
                din_w2_post  = dout_w0_pre;
                dout_w3_post = dout_w1_pre;
            end
            2'd2: begin
                din_w0_post  = dout_w1_pre;
                din_w1_post  = dout_w2_pre;
                din_w2_post  = dout_w3_pre;
                dout_w3_post = dout_w0_pre;
            end
            2'd3: begin
                din_w0_post  = dout_w0_pre;
                din_w1_post  = dout_w1_pre;
                din_w2_post  = dout_w2_pre;
                dout_w3_post = dout_w3_pre;
            end
        endcase
    end
    
    // ==========================================
    // SEQUENTIAL LOGIC
    // ==========================================
    
    always @(negedge clk) begin
        if(reset) begin
            ws1Addra <= 0;
            dReset <= 1;
            cnt <= 0;
            valInt <= 0;
            done <= 1'b0;
            
        end else begin 
            
            if(dReset==1) valInt <= 1'b1;
            if(dReset && dReset!=3) dReset <= dReset + 1;              
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
            
//            wsDout <= ws1[ws1Addra];
            
            // Start Counter Pipeline
            if(doneInt) begin
                if(!cnt) cnt <= 1;
            end
            
            if(cnt) cnt <= cnt + 1;
                    
            // ----------------------------------------------------
            // SHIFT REGISTER CASCADES
            // ----------------------------------------------------
            // W0 Shift Registers (Depth 24)
//            buff_w0_pre[0]  <= din_w0_pre;    
//            buff_w0_post[0] <= din_w0_post;    
//            for(j=1; j<3*L; j=j+1) begin
//                buff_w0_pre[j]  <= buff_w0_pre[j-1];
//                buff_w0_post[j] <= buff_w0_post[j-1];
//            end
            
//            // W1 Shift Registers (Depth 16)
//            buff_w1_pre[0]  <= din_w1_pre;    
//            buff_w1_post[0] <= din_w1_post;    
//            for(j=1; j<2*L; j=j+1) begin
//                buff_w1_pre[j]  <= buff_w1_pre[j-1];
//                buff_w1_post[j] <= buff_w1_post[j-1];
//            end

//            // W2 Shift Registers (Depth 8)
//            buff_w2_pre[0]  <= din_w2_pre;    
//            buff_w2_post[0] <= din_w2_post;    
//            for(j=1; j<L; j=j+1) begin
//                buff_w2_pre[j]  <= buff_w2_pre[j-1];
//                buff_w2_post[j] <= buff_w2_post[j-1];
//            end
            // ----------------------------------------------------
            
            // Trigger Done Signal when pipeline clears
            if(cnt==3*L-1) done <= 1'b1;
        end
    end
    
endmodule
