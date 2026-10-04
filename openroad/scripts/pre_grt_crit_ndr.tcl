# PRE_GLOBAL_ROUTE_TCL hook, experiment for the "routing skeleton" feedback:
# give the data nets of the worst reg-to-reg path a non-default rule (the same
# double-width / double-spacing rule CTS used for the clock nets), so the
# router gives them wider, lower-R, better-isolated wires. Section 4 of the
# PD feedback. The net list comes from reports/path/path_final.txt.
set block [ord::get_db_block]
set crit {
  _00019_ _03045_ _03044_ _03043_ _03019_ net643 _02902_ _02893_ _02890_
  _00308_ _00306_ _01085_ net657 _00839_ _00838_ _00814_ _00813_ _00810_ net1006
}
# reuse the clock NDR if one exists, else make one
set ndr ""; set USE_CLOCK_NDR 0
if { $USE_CLOCK_NDR } { foreach r [$block getNonDefaultRules] { set ndr $r; puts "crit-ndr: found rule [$r getName]"; break } }
if { $ndr == "" } {
  create_ndr -name CRIT_W2 -width *2
  set ndr [$block findNonDefaultRule CRIT_W2]
  puts "crit-ndr: created CRIT_W2 (double width, default spacing)"
}
set n 0
foreach name $crit {
  set net [$block findNet $name]
  if { $net == "NULL" } { puts "crit-ndr: net $name not found"; continue }
  $net setNonDefaultRule $ndr
  incr n
}
puts "crit-ndr: rule [$ndr getName] assigned to $n critical-path nets"
