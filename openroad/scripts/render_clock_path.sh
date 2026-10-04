#!/bin/bash
# Clock-network-only renders of both designs at the same scale, plus a
# high-resolution worst-path render of the final design for cropping.
source /OpenROAD-flow-scripts/env.sh
cd /OpenROAD-flow-scripts/flow || exit 1
OUT=/rtl/best_final_1ghz/images_png; mkdir -p $OUT
LIB=/OpenROAD-flow-scripts/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
render () {  # odb sdc spef tag res mode
cat > /tmp/r_$4.tcl <<EOT
read_liberty $LIB
read_db $1
read_sdc $2
source /OpenROAD-flow-scripts/flow/platforms/nangate45/setRC.tcl
read_spef $3
set_propagated_clock [all_clocks]
gui::show {
  set OUT /rtl/best_final_1ghz/images_png
  gui::save_display_controls
  gui::clear_highlights -1 ; gui::clear_selections ; gui::fit
  gui::set_display_controls "*" visible false
  gui::set_display_controls "Layers/*" visible true
  gui::set_display_controls "Shape Types/*" visible true
  gui::set_display_controls "Misc/Instances/*" visible false
  gui::set_display_controls "Misc/Scale bar" visible true
  gui::set_display_controls "Misc/Detailed view" visible true
  if { "$6" == "clock" } {
    gui::set_display_controls "Nets/*" visible false
    gui::set_display_controls "Nets/Clock" visible true
    gui::set_display_controls "Instances/*" visible false
    gui::set_display_controls "Instances/StdCells/Clock tree/*" visible true
    gui::set_display_controls "Instances/StdCells/Sequential" visible true
    save_image -resolution $5 \$OUT/clock_$4.png
  } else {
    gui::set_display_controls "Nets/*" visible false
    gui::set_display_controls "Instances/*" visible true
    gui::set_display_controls "Shape Types/Routing/*" visible false
    gui::set_display_controls "Timing Path/*" visible true
    gui::show_worst_path
    save_image -resolution $5 \$OUT/worst_path_hires_$4.png
  }
  gui::restore_display_controls
  puts "SAVED $4 $6"
} false
EOT
QT_QPA_PLATFORM=offscreen openroad -exit -no_init -no_splash /tmp/r_$4.tcl 2>&1 | grep -E 'SAVED|Error' | head -3
}
GH=$PWD/results/nangate45/riscv_gh/base; FN=/rtl/best_final_1ghz/layout
render $GH/6_final.odb $GH/6_final.sdc $GH/6_final.spef published 0.08 clock
render $FN/6_final.odb $FN/6_final.sdc $FN/6_final.spef final 0.08 clock
render $FN/6_final.odb $FN/6_final.sdc $FN/6_final.spef final 0.03 path
ls -la $OUT
