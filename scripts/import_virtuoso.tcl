# ============================================================
# Cadence Virtuoso Import Script — RISC-V Gate-Level Netlist
# Target: GPDK045 (Generic PDK 45nm)
# ============================================================
#
# This script imports the synthesized gate-level Verilog netlist
# into a Cadence Virtuoso library so you can view the schematic
# and proceed to layout.
#
# USAGE:
#   From the Virtuoso CIW (Command Interpreter Window):
#     source /path/to/scripts/import_virtuoso.tcl
#
#   Or from terminal:
#     virtuoso -replay scripts/import_virtuoso.tcl
#
# BEFORE RUNNING:
#   1. Update PDK_ROOT to match your server's GPDK045 path
#   2. Update NETLIST_PATH to point to the Genus output
#   3. Make sure you have the GPDK045 technology library
#      attached in your cds.lib
# ============================================================

# ────────────────────────────────────────────────────────────
# USER-CONFIGURABLE PATHS  (adjust for your server)
# ────────────────────────────────────────────────────────────

# GPDK045 installation root
set PDK_ROOT "/path/to/gpdk045"

# GPDK045 standard cell reference library name
# (this is the library name as it appears in your cds.lib)
set REF_LIB "gsclib045"

# Technology library name
set TECH_LIB "gpdk045"

# Your working library name (will be created)
set WORK_LIB "riscv_core_lib"

# Path to the synthesized gate-level netlist from Genus
set NETLIST_PATH "syn_output/riscv_core_syn.v"

# ────────────────────────────────────────────────────────────
# 1. VERIFY CDS.LIB SETUP
# ────────────────────────────────────────────────────────────
# Your cds.lib should include lines like:
#
#   DEFINE gpdk045        $PDK_ROOT/gpdk045
#   DEFINE gsclib045      $PDK_ROOT/gsclib045
#   DEFINE analogLib      $CADENCE_ROOT/tools/dfII/etc/cdslib/artist/analogLib
#
# If the reference library isn't defined, add it before running
# this script.
# ────────────────────────────────────────────────────────────

puts "============================================"
puts " Virtuoso Import: RISC-V Pipeline Netlist"
puts " Reference library: ${REF_LIB}"
puts " Work library:      ${WORK_LIB}"
puts "============================================"

# ────────────────────────────────────────────────────────────
# 2. CREATE WORKING LIBRARY
# ────────────────────────────────────────────────────────────
puts ">>> Creating work library: ${WORK_LIB}"

# Create the library and attach technology from GPDK045
dbOpenCellViewByType $TECH_LIB "" "" "" "r"
ddCreateLib $WORK_LIB "./${WORK_LIB}"
ddAttachTechFileToLib $WORK_LIB $TECH_LIB

puts "  -> Library created and technology attached"

# ────────────────────────────────────────────────────────────
# 3. IMPORT GATE-LEVEL NETLIST
# ────────────────────────────────────────────────────────────
puts ">>> Importing netlist: ${NETLIST_PATH}"

# Use verilogIn to import the synthesized netlist
# This creates schematic cellviews for each module
dbPurge
verilogIn(
    ?fileList       list(NETLIST_PATH)
    ?libName        WORK_LIB
    ?primaryView    "schematic"
    ?refLibList     list(REF_LIB "analogLib" "basic")
    ?globalPowerNet "VDD"
    ?globalGroundNet "VSS"
)

puts "  -> Netlist imported successfully"

# ────────────────────────────────────────────────────────────
# 4. ALTERNATIVE: USE si COMMAND (SKILL-based import)
# ────────────────────────────────────────────────────────────
# If the verilogIn above doesn't work on your setup, try
# using the si (schematic import) flow instead. Uncomment
# the block below and comment out section 3.
#
# siVerilogIn(
#     ?fileList       list(NETLIST_PATH)
#     ?libName        WORK_LIB
#     ?primaryView    "schematic"
#     ?refLibList     list(REF_LIB "analogLib" "basic")
# )

# ────────────────────────────────────────────────────────────
# 5. ALTERNATIVE: USE THE GUI (manual import)
# ────────────────────────────────────────────────────────────
# If scripted import gives trouble, use the GUI method:
#
#   1. In CIW: File -> Import -> Verilog...
#   2. Set fields:
#      - Verilog Files:     syn_output/riscv_core_syn.v
#      - Target Library:    riscv_core_lib (create it first)
#      - Reference Libraries: gsclib045  analogLib  basic
#      - Global Power:      VDD
#      - Global Ground:     VSS
#   3. Click OK
#   4. Open Library Manager -> riscv_core_lib -> riscv_core -> schematic

# ────────────────────────────────────────────────────────────
# 6. VERIFY IMPORT
# ────────────────────────────────────────────────────────────
puts ">>> Verifying import..."

# Open the top-level schematic to confirm
set cv [dbOpenCellViewByType $WORK_LIB "riscv_core" "schematic" "" "r"]
if { $cv != "" } {
    puts "  -> SUCCESS: riscv_core schematic exists in ${WORK_LIB}"
    puts "  -> Open in Library Manager to view"
    dbClose $cv
} else {
    puts "  -> WARNING: Could not open riscv_core schematic"
    puts "  -> Check Library Manager for imported cells"
}

# ────────────────────────────────────────────────────────────
# DONE
# ────────────────────────────────────────────────────────────
puts ""
puts "============================================"
puts " Import complete!"
puts ""
puts " Next steps:"
puts "   1. Open Library Manager (Tools -> Library Manager)"
puts "   2. Navigate to ${WORK_LIB} -> riscv_core -> schematic"
puts "   3. Verify all cells are properly linked to ${REF_LIB}"
puts "   4. Start layout (Create New Cellview -> layout)"
puts "============================================"
