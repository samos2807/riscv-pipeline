================================================================
  RISC-V Pipeline: RTL -> Synthesis -> Virtuoso Layout Flow
  Target PDK: GPDK045 (Generic PDK 45nm)
================================================================

OVERVIEW
--------
This flow takes the verified RISC-V 5-stage pipelined processor
RTL and produces a gate-level netlist (via Cadence Genus) that
can be imported into Cadence Virtuoso for schematic viewing and
layout.

  Verilog RTL  -->  Genus (Synthesis)  -->  Gate-level netlist
                     [GPDK045 cells]        [riscv_core_syn.v]
                                                   |
                                                   v
                                            Virtuoso (Import)
                                            [Schematic + Layout]


================================================================
STEP 0: UPLOAD FILES TO UNIVERSITY SERVER
================================================================

Upload the entire riscv_core/ directory to your server:

  scp -r riscv_core/ youruser@server:/path/to/workspace/

You need these directories on the server:
  riscv_core/
    rtl/            <-- all 12 Verilog source files
    scripts/        <-- syn_genus.tcl, import_virtuoso.tcl


================================================================
STEP 1: FIND YOUR GPDK045 INSTALLATION
================================================================

On your university server, GPDK045 is typically installed at one
of these locations:

  /opt/cadence/gpdk045/
  /usr/local/cadence/gpdk045/
  /tools/cadence/gpdk045/
  ~/cadence/gpdk045/

Ask your TA or check your course setup docs. You need to find:

  1. Liberty file (.lib) - timing/power info for standard cells:
     Usually: <PDK_ROOT>/gsclib045/timing/gsclib045_tt_1p0v_25c.lib

  2. LEF files - physical cell dimensions:
     Usually: <PDK_ROOT>/gsclib045/lef/gsclib045_tech.lef
              <PDK_ROOT>/gsclib045/lef/gsclib045_macro.lef

Quick check:
  find /opt/cadence -name "gsclib045_tt_*.lib" 2>/dev/null
  find /tools -name "gsclib045_tt_*.lib" 2>/dev/null


================================================================
STEP 2: EDIT THE SYNTHESIS SCRIPT
================================================================

Open scripts/syn_genus.tcl and update these lines near the top:

  set PDK_ROOT "/path/to/gpdk045"       <-- your actual path

Verify the liberty filename matches. Common variants:
  gsclib045_tt_1p0v_25c.lib     (typical corner, 25C)
  gsclib045_fast_conditional.lib
  gsclib045_slow_conditional.lib

The default clock is 100 MHz (10 ns period). To change it:
  set CLOCK_PERIOD 10.0    <-- adjust as needed


================================================================
STEP 3: RUN GENUS SYNTHESIS
================================================================

  # Load Cadence environment (server-specific)
  source /path/to/cadence_setup.sh
  # or: module load cadence/genus

  # Navigate to project root
  cd /path/to/riscv_core/

  # Run synthesis
  genus -f scripts/syn_genus.tcl

  # For batch mode (no GUI):
  genus -batch -f scripts/syn_genus.tcl

Expected runtime: 1-5 minutes for this design size.

WHAT TO EXPECT:
  - Genus will read all RTL files, elaborate the design, apply
    constraints, and map to GPDK045 standard cells.
  - You may see warnings about the initial blocks in imem.v and
    dmem.v — this is normal. Genus will infer them as flip-flop
    based storage (register arrays).
  - For a real chip you'd use SRAM macros, but for a class
    project the register-based version works fine.

OUTPUT FILES (in syn_output/):
  riscv_core_syn.v      Gate-level Verilog netlist
  riscv_core_syn.sdc    Timing constraints for P&R
  riscv_core_syn.sdf    Timing annotation for gate-level sim
  timing_report.txt     Timing analysis (check for violations)
  area_report.txt       Cell area breakdown
  power_report.txt      Power estimates
  gates_report.txt      Gate count and cell usage
  qor_report.txt        Quality of results summary


================================================================
STEP 4: CHECK SYNTHESIS RESULTS
================================================================

Open timing_report.txt and look for:
  - "Slack" — positive slack means timing is met.
    Negative slack means the design is too slow for 100 MHz.
    If negative, try increasing CLOCK_PERIOD (slower clock).

Open area_report.txt to see:
  - Total cell area (in um^2)
  - Breakdown by module

Open gates_report.txt to see:
  - Total equivalent gate count
  - Which standard cells were used


================================================================
STEP 5: IMPORT INTO VIRTUOSO
================================================================

OPTION A: Scripted Import
  1. Start Virtuoso:
       virtuoso &

  2. In the CIW (Command Interpreter Window), source the script:
       source "/path/to/riscv_core/scripts/import_virtuoso.tcl"

  3. Before sourcing, edit import_virtuoso.tcl:
       set PDK_ROOT "/path/to/gpdk045"
       set NETLIST_PATH "syn_output/riscv_core_syn.v"

OPTION B: GUI Import (recommended if the script gives trouble)
  1. Start Virtuoso:
       virtuoso &

  2. Make sure your cds.lib includes the GPDK045 libraries:
       DEFINE gpdk045    /path/to/gpdk045
       DEFINE gsclib045  /path/to/gpdk045/gsclib045

  3. Create a new library:
       File -> New -> Library...
       Name: riscv_core_lib
       Technology: Attach to gpdk045

  4. Import the netlist:
       File -> Import -> Verilog...
       - Verilog Files:       syn_output/riscv_core_syn.v
       - Target Library:      riscv_core_lib
       - Reference Libraries: gsclib045  analogLib  basic
       - Global Power Net:    VDD
       - Global Ground Net:   VSS
       Click OK

  5. Verify import:
       Tools -> Library Manager
       Navigate to: riscv_core_lib -> riscv_core -> schematic
       Double-click to open


================================================================
STEP 6: VIEW SCHEMATIC & START LAYOUT
================================================================

After import, you should see:
  - riscv_core_lib in the Library Manager
  - All submodules as separate cells (alu, decoder, etc.)
  - The top-level riscv_core schematic with GPDK045 cells

To start layout:
  1. Select riscv_core in Library Manager
  2. File -> New -> Cellview
     - Cell: riscv_core
     - View: layout
     - Tool: Virtuoso Layout Editor
  3. This opens the layout editor where you can:
     - Place standard cells
     - Route interconnects
     - Add power rings / stripes
     - Run DRC/LVS


================================================================
TROUBLESHOOTING
================================================================

PROBLEM: Genus can't find the liberty file
  -> Double-check PDK_ROOT path
  -> Try: ls ${PDK_ROOT}/gsclib045/timing/
  -> Make sure the .lib filename in the script matches

PROBLEM: "Cannot resolve reference" errors in Genus
  -> A submodule file may be missing from the read_hdl list
  -> Check all RTL files are uploaded to the server

PROBLEM: Negative timing slack
  -> Increase CLOCK_PERIOD (e.g., 15 ns for ~66 MHz)
  -> Check which paths fail and whether they're real

PROBLEM: Virtuoso can't find reference cells during import
  -> Your cds.lib is missing the gsclib045 library definition
  -> Add: DEFINE gsclib045 /path/to/gpdk045/gsclib045
  -> Make sure the library name matches exactly

PROBLEM: "initial" block warnings from Genus
  -> Normal. Genus ignores initial blocks during synthesis.
  -> The memories will be inferred as register arrays.
  -> If you need proper SRAMs, use your university's memory
     compiler to generate SRAM macros and blackbox imem/dmem.


================================================================
OPTIONAL: GATE-LEVEL SIMULATION
================================================================

After synthesis, you can run a gate-level simulation to verify
the netlist still works:

  # Using Xcelium (Cadence simulator)
  xrun \
    -v syn_output/riscv_core_syn.v \
    -v ${PDK_ROOT}/gsclib045/verilog/gsclib045.v \
    tb/riscv_tb.v \
    -sdf_cmd_file sdf_cmd.txt \
    -timescale 1ns/1ps

Create sdf_cmd.txt with:
  COMPILED_SDF_FILE "syn_output/riscv_core_syn.sdf",
  SCOPE = riscv_core,
  LOG_FILE = "sdf.log";

This runs the same testbench against the synthesized netlist
with real cell delays.


================================================================
FILE LISTING
================================================================

scripts/
  syn_genus.tcl          Genus synthesis TCL script
  import_virtuoso.tcl    Virtuoso netlist import script
  README_flow.txt        This file

rtl/                     RTL source files (12 files)
  riscv_core.v           Top-level pipeline
  pc.v                   Program counter
  imem.v                 Instruction memory (ROM)
  dmem.v                 Data memory (RAM)
  decoder.v              Instruction decoder
  controller.v           Main control unit
  alu_decoder.v          ALU control decoder
  alu.v                  Arithmetic logic unit
  regfile.v              Register file (x0-x31)
  imm_gen.v              Immediate generator
  forwarding_unit.v      Data forwarding logic
  hazard_detection_unit.v  Hazard detection (stall)

syn_output/              Created by Genus (after synthesis)
  riscv_core_syn.v       Gate-level netlist
  riscv_core_syn.sdc     Constraints
  riscv_core_syn.sdf     Timing annotation
  *.txt                  Reports
