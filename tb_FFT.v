`timescale 1ns / 1ps

module tb_FFT_staggered;

    // Parameters matching your DUT
    parameter INT_WIDTH = 1;
    parameter FRAC_WIDTH = 15;
    localparam TOTAL_WIDTH = INT_WIDTH + FRAC_WIDTH; // 18 bits
    localparam TWIDDLE_WIDTH = TOTAL_WIDTH + 4;
    
    // DUT Inputs
    reg clk;
    reg reset;
    reg load;
    reg signed [TWIDDLE_WIDTH-1:0] ina, inb, inc; // 20 bits (for twiddles & data)
    reg signed [TOTAL_WIDTH-1:0] in3;             // 18 bits
    
    // DUT Outputs (Updated for serial output)
    wire signed [TOTAL_WIDTH-1:0] out;
    wire done, err;

    // Instantiate the Top-Level FFT Module
    FFT #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .M(7) // 128-point configuration
    ) dut (
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

    // Testbench Memories
    reg signed [TOTAL_WIDTH-1:0] signal_mem [0:127];
    reg [TWIDDLE_WIDTH*6-1:0] twiddle_mem [0:31]; 

    // File descriptor and counters for writing outputs
    integer fd_out;
    integer total_word_count = 0;
    integer line_word_count = 0;

    // ---------------------------------------------------------
    // Clock Generation (100 MHz)
    // ---------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ---------------------------------------------------------
    // Test Sequence
    // ---------------------------------------------------------
    integer i;
    initial begin
        // 0. Open the output file for writing
        fd_out = $fopen("/home/dell/Desktop/projects/20cred/FFTaccelerator/PySim/fft_hw_output.txt", "w");
        if (fd_out == 0) begin
            $display("ERROR: Could not open fft_hw_output.txt for writing.");
            $finish;
        end

        // 1. Load the generated Hex files into TB memory
        $readmemh("/home/dell/Desktop/projects/20cred/FFTaccelerator/PySim/input_signal.mem", signal_mem);
        $readmemh("/home/dell/Desktop/projects/20cred/FFTaccelerator/PySim/twiddles108.mem", twiddle_mem);
        
        // 2. Initialize inputs
        reset = 0;
        load  = 0;
        ina   = 0;
        inb   = 0;
        inc   = 0;
        in3   = 0;
        
        // Wait for a clean start on a negative edge
        @(posedge clk);
        
        // =========================================================
        // PHASE 1: Load Twiddle Factors into BRAM
        // =========================================================
        $display("===================================================");
        $display(" PHASE 1: Loading Twiddle Factors into BRAM");
        $display("===================================================");
        
        load = 1; 
        
        // The DUT needs 1 initial cycle for 'lReset' and 'ws1Addra' setup
        @(negedge clk);  

        // Stream 32 twiddle factors
        for (i = 0; i < 32; i = i + 1) begin
            // --- Cycle 1: Lower 60 bits ---
            ina = twiddle_mem[i][0+:TWIDDLE_WIDTH];   // 20 bits
            inb = twiddle_mem[i][TWIDDLE_WIDTH+:TWIDDLE_WIDTH];  // 20 bits
            inc = twiddle_mem[i][TWIDDLE_WIDTH*2+:TWIDDLE_WIDTH];  // 20 bits
            @(negedge clk); // Drive safely on negedge
            
            // --- Cycle 2: Upper 60 bits ---
            ina = twiddle_mem[i][TWIDDLE_WIDTH*3+:TWIDDLE_WIDTH];  // 20 bits
            inb = twiddle_mem[i][TWIDDLE_WIDTH*4+:TWIDDLE_WIDTH];  // 20 bits
            inc = twiddle_mem[i][TWIDDLE_WIDTH*5+:TWIDDLE_WIDTH];// 20 bits
            @(negedge clk); 
        end
        
        load = 0; // Twiddle loading safely complete
        
        // =========================================================
        // PHASE 2: Reset and Prepare for Compute
        // =========================================================
        $display("===================================================");
        $display(" PHASE 2: Resetting Compute Pipeline");
        $display("===================================================");
        
        reset = 1;
        @(posedge clk); // Hold reset for 1 cycle to kickstart FSM
        reset = 0;
        
        // =========================================================
        // PHASE 3: Stream Data Inputs
        // =========================================================
        $display("===================================================");
        $display(" PHASE 3: Streaming Staggered Data Inputs");
        $display("===================================================");
        
        for (i = 0; i < 32; i = i + 1) begin
            ina = signal_mem[i];
            inb = signal_mem[i + 32];
            inc = signal_mem[i + 64];
            in3 = signal_mem[i + 96];
            @(posedge clk);
        end
        
        ina = 0; inb = 0; inc = 0; in3 = 0;
        
        // The testbench will naturally finish inside the always block below
        // once all 256 words (32 lines * 8 words) have been written.
    end
    
    // ---------------------------------------------------------
    // Output Monitoring & File Writing (Serial Stream)
    // ---------------------------------------------------------
    always @(negedge clk) begin
        if (done) begin
            // Write the current word to the file without adding a newline yet
            $fwrite(fd_out, "%04x ", out);
            
            line_word_count = line_word_count + 1;
            total_word_count = total_word_count + 1;
            
            // Once 8 words are printed on the same line, insert a newline
            if (line_word_count == 8) begin
                $fwrite(fd_out, "\n");
                line_word_count = 0;
            end
            
            // 32 groups of 8 words = 256 total words per FFT frame
            if (total_word_count == 256) begin
                $display("===================================================");
                $display("Simulation Complete. 128 complex points (256 serial words) written.");
                $fclose(fd_out);
                $finish;
            end
        end
    end

endmodule
