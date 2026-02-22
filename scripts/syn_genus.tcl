# ============================================================
# Cadence Genus Synthesis Script — RISC-V 5-Stage Pipeline
# Target: GPDK045 (Generic PDK 45nm)
# ============================================================
#
# USAGE:
#   On your university server, cd to the project directory, then:
#     genus -f scripts/syn_genus.tcl
#
# BEFORE RUNNING:
#   1. Update LIB_PATH and LEF_PATH below to match your server's
#      GPDK045 installation directory.
#   2. Verify the liberty (.lib) and LEF filenames match what's
#      installed. Common variants:
#        - gsclib045_tt_1p0v_25c.lib   (typical-typical)
#        - gsclib045_ff_1p1v_m40c.lib  (fast-fast)
#        - gsclib045_ss_0p9v_125c.lib  (slow-slow)
#   3. Adjust CLOCK_PERIOD if you want a different target frequency.
#
# NOTE ON MEMORIES:
#   imem.v and dmem.v use Verilog 'initial' blocks and reg arrays.
#   Genus will infer these as register-based storage (flip-flop arrays).
#   For a real tapeout you'd replace them with SRAM macros — but for
#   a class project / layout exercise, the register-based version is
#   fine and will synthesize cleanly.
# ============================================================

# ────────────────────────────────────────────────────────────
# USER-CONFIGURABLE PATHS  (adjust these for your server)
# ────────────────────────────────────────────────────────────

# Root directory of the GPDK045 installation
set PDK_ROOT "/path/to/gpdk045"

# Standard cell library files
set LIB_PATH "${PDK_ROOT}/gsclib045/timing/gsclib045_tt_1p0v_25c.lib"
set LEF_PATH "${PDK_ROOT}/gsclib045/lef/gsclib045_tech.lef"
set CELL_LEF "${PDK_ROOT}/gsclib045/lef/gsclib045_macro.lef"

# Clock period in ns  (10 ns = 100 MHz)
set CLOCK_PERIOD 10.0

# Design name
set TOP_MODULE "riscv_core"

# RTL source directory (relative to where you run genus)
set RTL_DIR "rtl"

# Output directory
set OUT_DIR "syn_output"

# ────────────────────────────────────────────────────────────
# 1. SETUP
# ────────────────────────────────────────────────────────────
puts "============================================"
puts " Genus Synthesis: ${TOP_MODULE}"
puts " Target library: GPDK045 TT 1.0V 25C"
puts " Clock period:   ${CLOCK_PERIOD} ns"
puts "============================================"

# Create output directory
file mkdir $OUT_DIR

# Set library paths
set_db init_lib_search_path "${PDK_ROOT}/gsclib045/timing"
set_db init_hdl_search_path $RTL_DIR

# Read standard cell library
read_libs $LIB_PATH

# Read LEF (for physical info — area, pin locations)
read_physical -lef [list $LEF_PATH $CELL_LEF]

# ────────────────────────────────────────────────────────────
# 2. READ RTL
# ────────────────────────────────────────────────────────────
puts ">>> Reading RTL files..."

read_hdl [list \
    ${RTL_DIR}/pc.v \
    ${RTL_DIR}/imem.v \
    ${RTL_DIR}/dmem.v \
    ${RTL_DIR}/decoder.v \
    ${RTL_DIR}/controller.v \
    ${RTL_DIR}/regfile.v \
    ${RTL_DIR}/imm_gen.v \
    ${RTL_DIR}/alu_decoder.v \
    ${RTL_DIR}/alu.v \
    ${RTL_DIR}/forwarding_unit.v \
    ${RTL_DIR}/hazard_detection_unit.v \
    ${RTL_DIR}/riscv_core.v \
]

# Elaborate the top-level design
elaborate $TOP_MODULE

# Check for elaboration issues
check_design -unresolved

# ────────────────────────────────────────────────────────────
# 3. CONSTRAINTS (SDC)
# ────────────────────────────────────────────────────────────
puts ">>> Applying timing constraints..."

# Define clock on 'clk' port
create_clock -name sys_clk -period $CLOCK_PERIOD [get_ports clk]

# Clock uncertainty (jitter + skew margin)
set_clock_uncertainty 0.2 [get_clocks sys_clk]

# Input delay — assume inputs arrive 30% into the clock period
set_input_delay  [expr {$CLOCK_PERIOD * 0.3}] -clock sys_clk [all_inputs]

# Output delay — assume outputs are needed 30% before clock edge
set_output_delay [expr {$CLOCK_PERIOD * 0.3}] -clock sys_clk [all_outputs]

# Remove clock from input delay set (clock drives itself)
remove_input_delay [get_ports clk]

# Reset is asynchronous — set as false path for timing
set_false_path -from [get_ports rst_n]

# Wire load model (let Genus pick based on area)
set_db auto_wireload_selection true

# ────────────────────────────────────────────────────────────
# 4. SYNTHESIZE
# ────────────────────────────────────────────────────────────
puts ">>> Synthesizing..."

# Generic synthesis (technology-independent optimization)
syn_generic

# Technology mapping (map to GPDK045 standard cells)
syn_map

# Final optimization pass
syn_opt

# ────────────────────────────────────────────────────────────
# 5. REPORTS
# ────────────────────────────────────────────────────────────
puts ">>> Generating reports..."

# Timing report
report_timing > ${OUT_DIR}/timing_report.txt
puts "  -> ${OUT_DIR}/timing_report.txt"

# Area report
report_area   > ${OUT_DIR}/area_report.txt
puts "  -> ${OUT_DIR}/area_report.txt"

# Power report
report_power  > ${OUT_DIR}/power_report.txt
puts "  -> ${OUT_DIR}/power_report.txt"

# Gate count / cell usage
report_gates  > ${OUT_DIR}/gates_report.txt
puts "  -> ${OUT_DIR}/gates_report.txt"

# Design rule violations
report_dp     > ${OUT_DIR}/dp_report.txt
puts "  -> ${OUT_DIR}/dp_report.txt"

# QoS summary
report_qor    > ${OUT_DIR}/qor_report.txt
puts "  -> ${OUT_DIR}/qor_report.txt"

# ────────────────────────────────────────────────────────────
# 6. EXPORT OUTPUTS
# ────────────────────────────────────────────────────────────
puts ">>> Writing outputs..."

# Gate-level Verilog netlist
write_hdl > ${OUT_DIR}/${TOP_MODULE}_syn.v
puts "  -> ${OUT_DIR}/${TOP_MODULE}_syn.v  (gate-level netlist)"

# SDC constraints (for downstream P&R)
write_sdc > ${OUT_DIR}/${TOP_MODULE}_syn.sdc
puts "  -> ${OUT_DIR}/${TOP_MODULE}_syn.sdc"

# SDF timing annotation (for gate-level simulation)
write_sdf > ${OUT_DIR}/${TOP_MODULE}_syn.sdf
puts "  -> ${OUT_DIR}/${TOP_MODULE}_syn.sdf"

# ────────────────────────────────────────────────────────────
# DONE
# ────────────────────────────────────────────────────────────
puts ""
puts "============================================"
puts " Synthesis complete!"
puts " Check ${OUT_DIR}/ for all outputs."
puts ""
puts " Key files:"
puts "   ${TOP_MODULE}_syn.v    — gate-level netlist"
puts "   ${TOP_MODULE}_syn.sdc  — timing constraints"
puts "   timing_report.txt      — check for slack violations"
puts "   area_report.txt        — total cell area"
puts "============================================"

# Exit Genus (comment out if you want to stay interactive)
# exit
