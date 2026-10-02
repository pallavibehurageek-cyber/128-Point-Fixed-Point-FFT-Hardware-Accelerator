128-Point Fixed-Point FFT Hardware Accelerator

A Verilog RTL implementation of a 128-point fixed-point Fast Fourier Transform (FFT) hardware accelerator.

The design uses a multi-stage FFT datapath with dedicated butterfly units, complex multiplication, twiddle-factor ROMs, buffering, and error-detection/redundancy logic.

---

Overview

Fast Fourier Transform (FFT) algorithms are widely used in digital signal processing, communications, radar, audio processing, and image processing.

This project explores the implementation of a 128-point FFT directly in synthesizable Verilog RTL, replacing software-based computation with dedicated hardware datapath structures.

The accelerator is organized into multiple FFT processing stages and uses fixed-point arithmetic to reduce hardware complexity.

Key Features

- 128-point FFT
- Verilog RTL implementation
- Fixed-point arithmetic
- Multi-stage FFT datapath
- Dedicated BF2 and BF4 butterfly units
- Complex multiplication
- Twiddle-factor ROMs
- Intermediate buffers and FIFOs
- Error-detection / redundancy logic
- Output data memory
- Dedicated RTL testbench
- Designed as synthesizable hardware

---

Architecture

The top-level structure of the accelerator is:

                         ┌─────────────────────┐
                         │      FFT_top.v      │
                         │ External Interface  │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │       FFT.v         │
                         │ FFT Core Integration│
                         │ Control / Handshake │
                         └──────────┬──────────┘
                                    │
                                    ▼
              ┌────────────────────────────────────────┐
              │             FFT PROCESSING             │
              │                                        │
              │  ┌──────────────────────────────────┐  │
              │  │ Stage 1                          │  │
              │  │ FFT processing / BF4 arithmetic │  │
              │  └────────────────┬─────────────────┘  │
              │                   ▼                    │
              │  ┌──────────────────────────────────┐  │
              │  │ Stage 2                          │  │
              │  │ BF4 butterfly processing        │  │
              │  └────────────────┬─────────────────┘  │
              │                   ▼                    │
              │  ┌──────────────────────────────────┐  │
              │  │ Stage 3                          │  │
              │  │ BF4 + Twiddle ROM + Error Logic│  │
              │  └────────────────┬─────────────────┘  │
              │                   ▼                    │
              │  ┌──────────────────────────────────┐  │
              │  │ Stage 4                          │  │
              │  │ BF2 butterfly processing        │  │
              │  └────────────────┬─────────────────┘  │
              └───────────────────┼────────────────────┘
                                  │
                                  ▼
                       ┌─────────────────────┐
                       │   Output Memory     │
                       │    Dual-Port RAM    │
                       └──────────┬──────────┘
                                  │
                                  ▼
                       ┌─────────────────────┐
                       │    FFT Output       │
                       │    DONE / ERR       │
                       └─────────────────────┘

Supporting Hardware

       ┌──────────────────┐
       │  Twiddle ROMs    │
       │ Stage 2 / Stage 3│
       └────────┬─────────┘
                │
                ▼
       ┌──────────────────┐
       │ Complex Multiplier│
       └──────────────────┘

       ┌──────────────────┐
       │ Butterfly Units  │
       │ BF2 / BF4 / BF4real│
       └──────────────────┘

       ┌──────────────────┐
       │ Buffers / FIFOs  │
       └──────────────────┘

       ┌──────────────────┐
       │ Error / ECC and  │
       │ Redundant Logic  │
       └──────────────────┘

---

Processing Flow

The main FFT processing path can be summarized as:

Input Samples
     │
     ▼
 FFT_top.v
     │
     ▼
   FFT.v
     │
     ▼
  Stage 1
     │
     ▼
  Stage 2
     │
     ▼
  Stage 3
     │
     ▼
  Stage 4
     │
     ▼
Output Memory
     │
     ▼
FFT Output

The FFT stages use dedicated butterfly and complex arithmetic modules to perform the required frequency-domain calculations.

---

Main RTL Modules

Module| Function
"FFT_top.v"| Top-level interface
"FFT.v"| Main FFT integration and control
"BF2.v"| Two-input butterfly processing
"BF4.v"| Four-input butterfly processing
"BF4real.v"| Real-data butterfly processing
"complexMult.v"| Complex multiplication
"stage1.v"| Stage 1 FFT processing
"stageFFT.v"| FFT stage processing
"stage3FFT.v"| Stage 3 processing
"stage4.v"| Final FFT processing
"twiddleROMstage2.v"| Twiddle-factor storage for Stage 2
"twiddleROMstage3.v"| Twiddle-factor storage for Stage 3
"buffer.v"| Intermediate data buffering
"fifo.v"| FIFO-based data storage
"fifio_16x36.v"| FIFO memory structure
"ECC_1.v"| ECC/error-detection logic
"buffECC.v"| ECC-related buffering
"redundantMult.v"| Redundant multiplication
"redundantComplexMult.v"| Redundant complex multiplication
"tb_FFT.v"| FFT simulation testbench

---

Fixed-Point Processing

The accelerator uses fixed-point arithmetic rather than floating-point arithmetic.

This allows the FFT operations to be implemented using hardware-friendly adders, multipliers, and registers while reducing the hardware resources required compared with floating-point computation.

The RTL configuration uses a 16-bit data representation, while the FFT transform size is 128 points.

«Important: 128-point refers to the number of FFT samples/bins. It does not mean 128-bit data width.»

---

Verification

Current Verification Status

The repository includes a dedicated RTL testbench:

tb_FFT.v

The testbench is intended to exercise the FFT accelerator at RTL level.

Current status

Verification Item| Status
RTL implementation| ✅ Available
FFT processing stages| ✅ Available
Butterfly modules| ✅ Available
Twiddle-factor ROMs| ✅ Available
Testbench| ✅ Available
RTL simulation| 🔄 Pending
Waveform capture| 🔄 Pending
Numerical comparison| 🔄 Pending
Measured error| 🔄 Pending

---

Why Simulation Results Are Not Included Yet

The project currently contains the RTL implementation and testbench, but a final simulation waveform and numerical verification result have not yet been generated and documented.

Rather than presenting a waveform from another FFT implementation, this project will use simulation results generated from the actual RTL contained in this repository.

This distinction is important because FFT implementations can differ in:

- FFT size
- fixed-point format
- scaling
- internal architecture
- latency
- output ordering
- rounding/truncation
- twiddle-factor representation

Therefore, results from another FFT project should not be presented as results for this accelerator.

---

Planned Simulation Verification

The next verification step is to compile the complete RTL hierarchy together with:

tb_FFT.v

The simulation will be used to generate:

1. RTL Waveform

The waveform will show relevant signals such as:

Clock
Reset
Input Data
Stage Control
Stage Completion
Output Data
DONE
ERR

2. FFT Output Verification

The generated FFT output will be compared against an independent reference FFT.

The comparison will measure quantities such as:

- Maximum absolute error
- Mean/RMS error
- Output-bin comparison
- Functional PASS/FAIL

The measured values will be added to this README after the actual RTL simulation is completed.

---

Project Goals

The project demonstrates how a relatively complex DSP algorithm can be mapped into dedicated digital hardware.

The main goals are:

1. Implement a 128-point FFT in Verilog.
2. Divide the computation into hardware processing stages.
3. Implement dedicated butterfly and complex arithmetic units.
4. Use fixed-point arithmetic for hardware-efficient computation.
5. Provide twiddle-factor storage using ROM structures.
6. Incorporate buffering and error-detection/redundancy mechanisms.
7. Verify the RTL implementation through simulation.
8. Compare hardware-generated FFT results against a reference implementation.

---

Future Work

- Complete RTL simulation
- Generate GTKWave/EDA waveform
- Perform numerical FFT comparison
- Calculate maximum and RMS error
- Add documented test vectors
- Add synthesis/resource utilization results
- Add timing analysis if the design is synthesized on an FPGA/ASIC flow

---