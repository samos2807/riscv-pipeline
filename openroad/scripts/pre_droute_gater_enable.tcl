# =====================================================================
#  pre_droute_gater_enable.tcl -- PRE_DETAIL_ROUTE_TCL hook.
#
#  Why: in global_route.tcl the flow runs repair_design, then repair_timing,
#  and nothing checks max-capacitance / max-slew again. On this design the
#  clock-gating-check paths (address decode -> NOR3 -> gater enable pin) are
#  within 0.03 ns of the period, and repair_timing's work on them leaves the
#  NOR3_X1 enable drivers with 19-23 fF loads against a 16 fF limit (measured
#  on 5_1_grt.odb with estimate_parasitics: 22.9 fF on u_dmem.g_row[0]).
#  Detailed routing then reports them as max-cap violators.
#
#  Fix: one more repair_design pass after repair_timing, using the flow's own
#  sequence (parasitics from global routes, edits inside an incremental
#  global-route session, legalize, re-route the touched nets). CAP_MARGIN and
#  SLEW_MARGIN come from the config through repair_design_helper.
# =====================================================================
log_cmd estimate_parasitics -global_routing
puts "pre-droute repair: max-cap / max-slew state before"
report_check_types -max_slew -max_capacitance -max_fanout -violators

log_cmd global_route -start_incremental
# Real violators only, plus a 10% margin: the pre-route estimate on these
# nets matched the routed load within 1% (22.88 fF estimated, 22.75 fF
# routed), and the config's 30% margin here inserted 18 buffers that left
# detailed routing stuck on 2 DRC violations for 11 hours.
log_cmd repair_design -cap_margin 10 -slew_margin 10 -verbose
log_cmd detailed_placement
check_placement -verbose
log_cmd global_route -end_incremental \
  -congestion_report_file $::env(REPORTS_DIR)/congestion_post_pre_droute_repair.rpt

log_cmd estimate_parasitics -global_routing
puts "pre-droute repair: max-cap / max-slew state after"
report_check_types -max_slew -max_capacitance -max_fanout -violators
puts "pre-droute repair: done"
