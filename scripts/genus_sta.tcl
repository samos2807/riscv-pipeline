# ============================================================
# Genus STA — RISC-V 5-Stage Pipeline
# GPDK045 45nm, slow corner, 1.0V, 100 MHz
# ============================================================
#
# USAGE:
#   genus -f sta_scripts/genus_sta.tcl
#
# ============================================================

# ────────────────────────────────────────────────────────────
# PATHS — לא צריך לשנות אם אתה benshld
# ────────────────────────────────────────────────────────────
set PDK_ROOT "/tech/cadence/gpdk45"
set LIB_FILE "${PDK_ROOT}/gsclib045/timing/slow_vdd1v0_basicCells.lib"
set NETLIST  "/project/gpdk45/users/benshld/ws/riscv_core/syn_output/riscv_core_syn.v"
set SDC_FILE "/project/gpdk45/users/benshld/ws/riscv_core/syn_output/riscv_core_syn.sdc"
set OUT_DIR  "/project/gpdk45/users/benshld/ws/riscv_core/sta_output"
set TOP      "riscv_core"

file mkdir $OUT_DIR

puts "============================================"
puts " Genus STA — RISC-V Pipeline"
puts " Corner: slow, 1.0V, 25C"
puts " Clock:  10 ns (100 MHz)"
puts "============================================"

# ────────────────────────────────────────────────────────────
# 1. READ LIBRARY
# ────────────────────────────────────────────────────────────
puts "\n>>> \[1\] Reading library..."

read_libs $LIB_FILE
puts "  -> loaded: slow_vdd1v0_basicCells.lib"

# ────────────────────────────────────────────────────────────
# 2. READ GATE-LEVEL NETLIST
# ────────────────────────────────────────────────────────────
puts "\n>>> \[2\] Reading gate-level netlist..."

read_hdl -netlist $NETLIST
elaborate $TOP

puts "  -> netlist loaded: riscv_core_syn.v"

# ────────────────────────────────────────────────────────────
# 3. READ SDC
# ────────────────────────────────────────────────────────────
puts "\n>>> \[3\] Reading SDC constraints..."

read_sdc $SDC_FILE
puts "  -> SDC loaded"

# ────────────────────────────────────────────────────────────
# 4. CLOCK REPORT
# ────────────────────────────────────────────────────────────
puts "\n>>> \[4\] Clock analysis..."

report_clock > ${OUT_DIR}/clock.rpt
puts "  -> clock.rpt"

# ────────────────────────────────────────────────────────────
# 5. SETUP — TOP CRITICAL PATHS
# ────────────────────────────────────────────────────────────
puts "\n>>> \[5\] Setup timing (critical paths)..."

report_timing \
    -delay_type max \
    -max_paths  10 \
    -path_type  full \
    > ${OUT_DIR}/setup_paths.rpt

report_timing \
    -delay_type max \
    -max_paths  50 \
    -path_type  summary \
    > ${OUT_DIR}/setup_summary.rpt

puts "  -> setup_paths.rpt   (top 10, full detail)"
puts "  -> setup_summary.rpt (top 50, summary)"

# ────────────────────────────────────────────────────────────
# 6. HOLD — TOP PATHS
# ────────────────────────────────────────────────────────────
puts "\n>>> \[6\] Hold timing..."

report_timing \
    -delay_type min \
    -max_paths  10 \
    -path_type  full \
    > ${OUT_DIR}/hold_paths.rpt

puts "  -> hold_paths.rpt"

# ────────────────────────────────────────────────────────────
# 7. VIOLATIONS ONLY
# ────────────────────────────────────────────────────────────
puts "\n>>> \[7\] Violations check..."

report_timing \
    -delay_type max \
    -slack_lesser_than 0.0 \
    -max_paths 100 \
    > ${OUT_DIR}/setup_violations.rpt

report_timing \
    -delay_type min \
    -slack_lesser_than 0.0 \
    -max_paths 100 \
    > ${OUT_DIR}/hold_violations.rpt

puts "  -> setup_violations.rpt"
puts "  -> hold_violations.rpt"

# ────────────────────────────────────────────────────────────
# 8. QOR
# ────────────────────────────────────────────────────────────
puts "\n>>> \[8\] QOR summary..."

report_qor > ${OUT_DIR}/qor.rpt
puts "  -> qor.rpt"

# ────────────────────────────────────────────────────────────
# 9. FMAX
# ────────────────────────────────────────────────────────────
puts "\n>>> \[9\] Calculating Fmax..."

set worst_path [get_db timing_paths \
                -delay_type max \
                -max_paths 1]
set wns        [get_db $worst_path .slack]

set period     10.0
set fmax_per   [expr {$period - $wns}]
set fmax_mhz   [expr {1000.0 / $fmax_per}]

set fp [open "${OUT_DIR}/fmax.rpt" w]
puts $fp "============================================"
puts $fp " Fmax — RISC-V Pipeline (Genus STA)"
puts $fp "============================================"
puts $fp " Clock period : ${period} ns (100 MHz target)"
puts $fp " WNS          : [format %+.4f $wns] ns"
puts $fp " Fmax period  : [format %.4f $fmax_per] ns"
puts $fp " Fmax         : [format %.2f $fmax_mhz] MHz"
puts $fp ""
if {$wns >= 0} {
    puts $fp " STATUS: TIMING MET at 100 MHz ✓"
    puts $fp " Can push to [format %.1f $fmax_mhz] MHz"
} else {
    puts $fp " STATUS: TIMING VIOLATION at 100 MHz ✗"
    puts $fp " Achievable Fmax: [format %.1f $fmax_mhz] MHz"
    puts $fp " Fix: increase clock period to [format %.1f $fmax_per] ns"
}
puts $fp "============================================"
close $fp

puts ""
puts "  WNS  : [format %+.4f $wns] ns"
puts "  Fmax : [format %.2f $fmax_mhz] MHz"

# ────────────────────────────────────────────────────────────
# 10. MULTI-CORNER (OCV approximation)
# ────────────────────────────────────────────────────────────
puts "\n>>> \[10\] OCV derate (5% — approximates Monte Carlo)..."

set_db timing_derate_cell_delay_late  1.05
set_db timing_derate_cell_delay_early 0.95
set_db timing_derate_net_delay_late   1.05
set_db timing_derate_net_delay_early  0.95

report_timing \
    -delay_type max \
    -max_paths 10 \
    -path_type full \
    > ${OUT_DIR}/ocv_setup.rpt

set worst_ocv [get_db [get_db timing_paths \
               -delay_type max -max_paths 1] .slack]

puts "  WNS with OCV: [format %+.4f $worst_ocv] ns"
puts "  -> ocv_setup.rpt"

# ────────────────────────────────────────────────────────────
# DONE
# ────────────────────────────────────────────────────────────
puts ""
puts "============================================"
puts " STA Complete! Reports in: ${OUT_DIR}/"
puts ""
puts " START HERE:"
puts "   cat ${OUT_DIR}/fmax.rpt"
puts "   cat ${OUT_DIR}/qor.rpt"
puts ""
puts " DETAIL:"
puts "   cat ${OUT_DIR}/setup_paths.rpt"
puts "   cat ${OUT_DIR}/setup_violations.rpt"
puts "   cat ${OUT_DIR}/ocv_setup.rpt"
puts "============================================"
