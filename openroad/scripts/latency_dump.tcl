set lib /OpenROAD-flow-scripts/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
read_liberty $lib
read_db $::env(CR_ODB)
read_sdc $::env(CR_SDC)
source /OpenROAD-flow-scripts/flow/platforms/nangate45/setRC.tcl
read_spef $::env(CR_SPEF)
set_propagated_clock [all_clocks]
report_checks -path_delay max -group_path_count 20000 -endpoint_path_count 1 -format full
