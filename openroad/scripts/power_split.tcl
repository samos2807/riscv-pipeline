# =====================================================================
#  power_split.tcl -- leakage vs dynamic power, per group, for one routed
#  design at one or more clock periods. Post-route parasitics from the
#  design's own SPEF. Activity: OpenSTA default (no VCD), the same
#  assumption as the flow's 6_finish.rpt, so numbers are comparable to it.
#
#  env: PS_ODB PS_SDC PS_SPEF PS_TAG PS_PERIODS (space separated, ns)
#  Run from the ORFS flow dir:
#    make DESIGN_CONFIG=<cfg> run RUN_SCRIPT=/rtl/orfs/power_split.tcl
# =====================================================================
set lib /OpenROAD-flow-scripts/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
read_liberty $lib
read_db $::env(PS_ODB)
read_sdc $::env(PS_SDC)
source /OpenROAD-flow-scripts/flow/platforms/nangate45/setRC.tcl
read_spef $::env(PS_SPEF)
set_propagated_clock [all_clocks]

set block [ord::get_db_block]
set n_inst 0; set n_ff 0; set n_icg 0; set n_buf 0
foreach inst [$block getInsts] {
  set m [[$inst getMaster] getName]
  if { [string match "FILLCELL*" $m] || [string match "TAPCELL*" $m] } { continue }
  incr n_inst
  if { [string match "DFF*" $m] } { incr n_ff }
  if { [string match "CLKGATE*" $m] } { incr n_icg }
  if { [string match "CLKBUF*" $m] || [string match "BUF_*" $m] } { incr n_buf }
}
puts "PS_TAG $::env(PS_TAG) insts $n_inst flops $n_ff icg $n_icg buffers $n_buf"
report_design_area

foreach per $::env(PS_PERIODS) {
  set clk [lindex [all_clocks] 0]
  create_clock -name core_clock -period $per [get_ports clk]
  set_propagated_clock [all_clocks]
  puts "PS_PERIOD $::env(PS_TAG) $per"
  report_power
}
