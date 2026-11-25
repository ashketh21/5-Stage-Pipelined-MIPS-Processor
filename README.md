# 5-Stage Pipelined MIPS Processor (VHDL / FPGA)

A structural VHDL implementation of a **5-stage pipelined MIPS-style RISC processor** with hardware hazard handling (data forwarding, load-use stalling, and control-hazard flushing), built as a **Lab 3 assignment for CEG 3156 (Computer Systems Design II)** at the University of Ottawa. Designed and verified in **Intel/Altera Quartus II** and **ModelSim** for an **Altera Cyclone** FPGA development board.

---

## Key Features

- **5-Stage Classic RISC Pipeline:** Instruction Fetch (`IF`), Instruction Decode (`ID`), Execute (`EX`), Memory Access (`MEM`), and Write Back (`WB`), separated by `IF/ID`, `ID/EX`, `EX/MEM`, and `MEM/WB` pipeline registers.
- **32-bit Instruction Format, 8-bit Datapath:** Standard 32-bit MIPS instruction encoding paired with a compact 8-bit datapath (32×8-bit register file, 8-bit ALU, and 256×8-bit data memory) suitable for FPGA resource demonstration and 7-segment display debugging.
- **Structural Gate/RTL Design:** Built from the ground up out of modular structural VHDL components (carry-lookahead adder/subtractor, ripple-carry PC adders, 5-bit/8-bit comparators, multiplexers, decoders, and enabled asynchronous-reset D flip-flops).
- **Hardware Hazard Resolution:**
  - **Forwarding Unit (`FU.vhd`):** Resolves EX-to-EX (`EX/MEM`) and MEM-to-EX (`MEM/WB`) data hazards directly at the ALU inputs.
  - **Hazard Detection Unit (`HDU.vhd`):** Detects load-use hazards (`lw` followed by a dependent instruction), stalls the PC and `IF/ID` stage, and inserts pipeline bubbles (NOPs).
  - **Control Hazard Flushing (`CU.vhd`):** Asserts `IF_Flush` on taken `beq`/`bne` branches and `j` jumps to discard wrong-path instructions.
- **On-Board FPGA Debug Multiplexer:** Exposes internal processor state (PC, ALU result, register reads, write-back data, and control signals) via `ValueSelect` for 7-segment display readout.

---

## Repository Structure

```text
.
├── rtl/
│   ├── TopLevel.vhd                    # 5-stage pipelined processor top-level
│   ├── control/
│   │   ├── CU.vhd                      # Main control unit + hazard gating + IF_Flush
│   │   ├── ALU_CU_G1.vhd               # ALU control decoder
│   │   ├── FU.vhd                      # Data forwarding unit
│   │   └── HDU.vhd                     # Load-use hazard detection & stall unit
│   ├── alu/
│   │   ├── ALU.vhd                     # 8-bit structural ALU (AND, OR, ADD, SUB, SLT)
│   │   ├── adderSubtractor8Bit.vhd     # 8-bit adder/subtractor wrapper
│   │   ├── carryLookaheadAdder8Bit.vhd # 8-bit carry-lookahead adder
│   │   ├── comparator5Bit.vhd          # 5-bit comparator (register address matching)
│   │   ├── comparator8Bit.vhd          # 8-bit comparator (SLT)
│   │   ├── ALU_32b_G1.vhd              # 32-bit ripple-carry adder (PC / branch target)
│   │   └── FA_G1.vhd                   # 1-bit full adder
│   ├── storage/
│   │   ├── registerFile.vhd            # 32x8-bit register file ($0 hardwired to 0)
│   │   ├── register32Bit.vhd           # 32-bit pipeline register
│   │   ├── register8Bit.vhd            # 8-bit register (PC, datapath, RF cells)
│   │   ├── register5Bit.vhd            # 5-bit register (Rd pipeline propagation)
│   │   ├── decoder5to32.vhd            # 5-to-32 write-register decoder
│   │   └── enARdFF_2.vhd               # Enabled async-reset D flip-flop
│   ├── mux/                            # Structural 2:1, 4:1, 8:1, and 32:1 multiplexers
│   └── common/
│       └── clockDivider.vhd            # 8-stage ripple clock divider (/2 to /256)
├── mem/
│   ├── Instructions.mif                # 12-instruction verification program (256x32-bit)
│   └── Data.mif                        # Initial data memory (mem[0]=0x55, mem[1]=0xAA)
├── quartus/
│   └── PipelinedMIPS.bdf               # Quartus II top-level schematic (RAM + 7-seg I/O)
└── README.md
```

---

## Getting Started (Quartus II / ModelSim)

1. Create a new **Quartus II** project targeting an Altera Cyclone FPGA.
2. Add all `.vhd` files under `rtl/` to the project and set `TopLevel` (for standalone simulation) or `quartus/PipelinedMIPS.bdf` (for board-level synthesis with LPM RAM and 7-segment display outputs) as the top-level entity.
3. Point the instruction and data LPM RAM blocks to `mem/Instructions.mif` and `mem/Data.mif`.
4. Compile and run functional simulation in **Quartus Waveform Editor** or **ModelSim**.

---