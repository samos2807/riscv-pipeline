# =====================================================================
#  eco_maxcap.tcl -- post-route ECO for max-capacitance violations.
#
#  The pre-route repair_design works on estimated parasitics; two nets that
#  drive data-memory clock-gater enables ended up with about twice the
#  estimated load after detailed routing (22.8 fF and 19.4 fF on NOR3_X1
#  drivers limited to 16.0 fF). This script repairs them on the routed
#  design with extracted parasitics, legalizes, reroutes, and re-checks.
#
#  Run from the ORFS flow directory, after the normal flow has finished:
#    make DESIGN_CONFIG=<config.mk> run RUN_SCRIPT=/rtl/orfs/eco_maxcap.tcl
#  It rewrites results/<platform>/<design>/base/5_2_route.odb (the original
#  is kept as 5_2_route_pre_eco.odb); then re-run the finish stages:
#    make DESIGN_CONFIG=<config.mk> do-6_1_fill do-6_report
# =====================================================================
source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]
set res $::env(RESULTS_DIR)
set rep $::env(REPORTS_DIR)

puts "=== ECO: extracting parasitics of the routed design"
extract_parasitics -ext_model_file $::env(RCX_RULES)
write_spef $res/eco_pre.spef
read_spef $res/eco_pre.spef

puts "=== ECO: violators before"
report_check_types -max_slew -max_capacitance -max_fanout -violators

puts "=== ECO: repair_design on extracted parasitics"
repair_design -cap_margin 15 -slew_margin 10 -verbose

puts "=== ECO: legalize"
detailed_placement
check_placement -verbose

puts "=== ECO: detailed route"
detailed_route -output_drc $rep/eco_route_drc.rpt -output_maze $res/eco_maze.log \
    -droute_end_iter 64 -verbose 1 -drc_report_iter_step 5
if { ![design_is_routed] } {
  error "ECO: design has unrouted nets"
}

puts "=== ECO: re-extract and re-check"
extract_parasitics -ext_model_file $::env(RCX_RULES)
write_spef $res/eco_post.spef
read_spef $res/eco_post.spef
report_check_types -max_slew -max_capacitance -max_fanout -violators
report_tns
report_wns
report_worst_slack -max
report_worst_slack -min
report_design_area

exec cp $res/5_2_route.odb $res/5_2_route_pre_eco.odb
orfs_write_db $res/5_2_route.odb
puts "=== ECO: done, 5_2_route.odb rewritten (original in 5_2_route_pre_eco.odb)"
