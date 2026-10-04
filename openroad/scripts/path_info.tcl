# path_info.tcl: worst reg-to-reg path, pin list with cell type and placement,
# then the same path with zero wire RC (cell delay + pin caps only).
set lib /OpenROAD-flow-scripts/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
read_liberty $lib
read_db $::env(CR_ODB)
read_sdc $::env(CR_SDC)
source /OpenROAD-flow-scripts/flow/platforms/nangate45/setRC.tcl
read_spef $::env(CR_SPEF)
set_propagated_clock [all_clocks]
puts "PI_TAG $::env(CR_TAG)"
set pe [lindex [find_timing_paths -path_delay max -group_path_count 1 -endpoint_path_count 1 -from [all_registers -clock_pins] -to [all_registers -data_pins]] 0]
set p [$pe path]
puts "=== PINS (name master x y)"
set nets {}
foreach pin [$p pins] {
  set name [get_full_name $pin]
  set it [sta::sta_to_db_pin $pin]
  if { $it == "NULL" } { puts "PIN $name PORT - -"; continue }
  set inst [$it getInst]; set bb [$inst getBBox]
  set x [expr {([$bb xMin]+[$bb xMax])/2.0/2000.0}]; set y [expr {([$bb yMin]+[$bb yMax])/2.0/2000.0}]
  puts "PIN $name [[$inst getMaster] getName] [format %.2f $x] [format %.2f $y]"
  set net [$it getNet]; if { $net != "NULL" && [$it isOutputSignal] } { lappend nets [$net getName] }
}
puts "=== NETS driven along the path"
foreach n $nets { puts "NET $n" }
puts "=== WITH SPEF"
report_checks -path_delay max -from [all_registers -clock_pins] -to [all_registers -data_pins] -group_path_count 1 -fields {fanout capacitance slew} -digits 3
puts "=== ZERO WIRE RC (placement estimate with R=C=0)"
set_wire_rc -signal -resistance 0 -capacitance 0
set_wire_rc -clock  -resistance 0 -capacitance 0
estimate_parasitics -placement
report_checks -path_delay max -from [all_registers -clock_pins] -to [all_registers -data_pins] -group_path_count 1 -fields {fanout capacitance slew} -digits 3
