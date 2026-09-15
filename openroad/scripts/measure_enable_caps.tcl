# Measure the global-route-estimated capacitance on the clock-gater enable
# nets, to pick a CAP_MARGIN for the pre-route repair that survives routing.
# Run: make DESIGN_CONFIG=<cfg> run RUN_SCRIPT=/rtl/orfs/measure_enable_caps.tcl
# Then: grep "ENABLE_DRIVER" in the log for the driver pins, and read the
# Cap column of the matching report_checks rows (grep "/ZN (NOR3").
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_1_grt.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]
estimate_parasitics -global_routing

set block [ord::get_db_block]
foreach net [$block getNets] {
  if { ![string match {*u_icg.e} [$net getName]] } { continue }
  foreach it [$net getITerms] {
    if { ![$it isOutputSignal] } { continue }
    set inst [$it getInst]
    set pname "[$inst getName]/[[$it getMTerm] getName]"
    puts "ENABLE_DRIVER [$net getName] $pname [[$inst getMaster] getName]"
    report_checks -through [get_pins $pname] -path_delay max -fields {capacitance} -format full -group_path_count 1
  }
}
