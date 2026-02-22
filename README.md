# RISC-V 5-Stage Pipelined Processor — RTL to GDSII

A full ASIC design flow implementation of a RISC-V 32-bit pipelined processor,
from RTL design and verification to physical layout and tape-out.

---

## Pipeline Architecture

```
IF  →  ID  →  EX  →  MEM  →  WB
```

| Stage | Description |
|-------|-------------|
| IF    | Instruction Fetch — reads instruction from IMEM using PC |
| ID    | Instruction Decode — decodes opcode, reads register file |
| EX    | Execute — ALU computation, branch resolution |
| MEM   | Memory — read/write data memory |
| WB    | Write Back — writes result to register file |

---

## Hazard Handling

| Hazard | Solution |
|--------|----------|
| EX-EX Data Hazard | Forwarding from EX/MEM register → ALU input |
| MEM-EX Data Hazard | Forwarding from MEM/WB register → ALU input |
| Load-Use Hazard | Stall (1 cycle) + bubble insertion + forwarding |
| Branch Hazard | Flush (2 cycles penalty) on taken branch |

---

## Design Flow

```
RTL (Verilog)
    ↓
Behavioral Simulation — Vivado (6 test scenarios, all passing)
    ↓
Logic Synthesis — Cadence Genus, GPDK045 45nm
    ↓
Gate-Level Netlist Import — Cadence Virtuoso
    ↓
Physical Layout — Virtuoso Layout Suite XL
    ↓
DRC Verification — Cadence PVS/Innovus (0 violations)
    ↓
GDS Streamout ✓
```

---

## STA Results (Cadence Genus, Slow Corner 0.9V 125°C)

| Metric | Value |
|--------|-------|
| Target Clock | 100 MHz (10 ns) |
| WNS | +222 ps ✓ |
| TNS | 0.0 |
| Violations | 0 |
| **Fmax** | **102.3 MHz** |
| Cell Area | 33,064 µm² (0.033 mm²) |
| Flip-Flops | 3,413 |
| Logic Gates | 4,106 |
| Total Cells | 7,519 |

**Critical Path:** EX/MEM register → Forwarding MUX → ALU Carry Chain → PC register

---

## Supported Instructions

| Type | Instructions |
|------|-------------|
| R-type | ADD, SUB, AND, OR |
| I-type | ADDI, LW |
| S-type | SW |
| B-type | BEQ |

---

## Repository Structure

```
riscv-pipeline/
├── rtl/                        # RTL source files (Verilog)
│   ├── riscv_core.v            # Top-level 5-stage pipeline
│   ├── alu.v                   # Arithmetic Logic Unit
│   ├── controller.v            # Main control unit
│   ├── decoder.v               # Instruction decoder
│   ├── alu_decoder.v           # ALU control decoder
│   ├── regfile.v               # Register file (x0-x31)
│   ├── imm_gen.v               # Immediate generator
│   ├── forwarding_unit.v       # Data forwarding logic
│   ├── hazard_detection_unit.v # Load-use hazard detection
│   ├── pc.v                    # Program counter
│   ├── imem.v                  # Instruction memory
│   └── dmem.v                  # Data memory
├── tb/                         # Testbenches
│   ├── riscv_tb.v              # Full pipeline testbench (6 scenarios)
│   ├── core_tb.v               # Core testbench
│   └── pc_tb.v                 # PC testbench
├── scripts/                    # EDA scripts
│   ├── syn_genus.tcl           # Cadence Genus synthesis script
│   ├── genus_sta.tcl           # Static Timing Analysis script
│   ├── import_virtuoso.tcl     # Virtuoso netlist import script
│   └── README_flow.txt         # Full flow instructions
└── picture/                    # Project screenshots
    ├── layout_full.jpg         # Full chip layout
    ├── layout_zoom.jpg         # Zoomed layout (metal layers)
    ├── schematic.jpg           # Gate-level schematic in Virtuoso
    ├── schematic_zoom.jpg      # Zoomed schematic
    └── drc_clean.jpg           # DRC 0 violations proof
```

---

## Tools Used

| Tool | Purpose |
|------|---------|
| Xilinx Vivado | RTL simulation & verification |
| Cadence Genus 25.11 | Logic synthesis (GPDK045 45nm) |
| Cadence Virtuoso | Schematic & physical layout |
| Cadence Innovus | Place & Route, DRC |
| Cadence PVS | Physical verification (DRC/LVS) |

---

## Technology

- **PDK:** GPDK045 (Generic Process Design Kit, 45nm)
- **Standard Cell Library:** gsclib045 SVT
- **Timing Corner:** Slow, 0.9V, 125°C

---

## References

- Patterson & Hennessy — *Computer Organization and Design*
- Weste & Harris — *CMOS VLSI Design*
