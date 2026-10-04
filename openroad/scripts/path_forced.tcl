set lib /OpenROAD-flow-scripts/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
read_liberty $lib
read_db $::env(CR_ODB)
read_sdc $::env(CR_SDC)
source /OpenROAD-flow-scripts/flow/platforms/nangate45/setRC.tcl
read_spef $::env(CR_SPEF)
set_propagated_clock [all_clocks]
puts "PF_TAG $::env(CR_TAG)"
report_checks -path_delay max -from $::env(CR_FROM) -to $::env(CR_TO) -fields {fanout capacitance slew} -digits 3
report_checks -path_delay max -from [all_registers -clock_pins] -to [all_registers -data_pins] -group_path_count 1 -digits 3
