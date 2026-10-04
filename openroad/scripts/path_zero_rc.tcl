# worst reg-to-reg path with NO parasitics annotated: wire R = C = 0, pin caps only.
set lib /OpenROAD-flow-scripts/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
read_liberty $lib
read_db $::env(CR_ODB)
read_sdc $::env(CR_SDC)
set_wire_rc -signal -resistance 0 -capacitance 0
set_wire_rc -clock  -resistance 0 -capacitance 0
estimate_parasitics -placement
set_propagated_clock [all_clocks]
puts "PZ_TAG $::env(CR_TAG)"
report_checks -path_delay max -from [all_registers -clock_pins] -to [all_registers -data_pins] -group_path_count 1 -fields {fanout capacitance slew} -digits 3
puts "=== same endpoint/startpoint as the SPEF path, forced:"
report_checks -path_delay max -from $::env(CR_FROM) -to $::env(CR_TO) -fields {fanout capacitance slew} -digits 3
