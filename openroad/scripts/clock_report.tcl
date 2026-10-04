# clock_report.tcl: skew, latency, min period and per-endpoint capture latency dump.
# env: CR_ODB CR_SDC CR_SPEF CR_TAG CR_OUT
set lib /OpenROAD-flow-scripts/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
read_liberty $lib
read_db $::env(CR_ODB)
read_sdc $::env(CR_SDC)
source /OpenROAD-flow-scripts/flow/platforms/nangate45/setRC.tcl
read_spef $::env(CR_SPEF)
set_propagated_clock [all_clocks]
puts "CR_TAG $::env(CR_TAG)"
puts "=== report_clock_skew -setup"; report_clock_skew -setup -digits 3
puts "=== report_clock_skew -hold";  report_clock_skew -hold -digits 3
puts "=== report_clock_latency";     report_clock_latency -digits 3
puts "=== report_clock_min_period";  report_clock_min_period
set n 0; set nicg 0
foreach inst [[ord::get_db_block] getInsts] { set m [[$inst getMaster] getName]
  if {[string match "DFF*" $m]} {incr n}; if {[string match "CLKGATE*" $m]} {incr nicg}
  if {[string match "CLKBUF*" $m] || [string match "BUF_*" $m]} { } }
puts "=== sinks: flops $n icg $nicg"
set fh [open $::env(CR_OUT) w]
set ends [find_timing_paths -path_delay max -group_path_count 20000 -endpoint_path_count 1]
foreach pe $ends {
  set p [$pe path]
  set ep [get_full_name [$pe pin]]
  # capture clock latency at the endpoint = arrival of clock at the capture pin
  set lat [$pe target_clk_delay]
  puts $fh "$ep $lat"
}
close $fh
puts "=== wrote [llength $ends] endpoint capture latencies to $::env(CR_OUT)"
