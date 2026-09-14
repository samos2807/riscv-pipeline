#!/bin/bash
# The PUBLISHED GitHub RTL (/rtl/rtl_github, pre Fix A/B) through OpenROAD/Nangate45,
# same flow + same corner + same util/cluster as the 1007.55 MHz result, pushed until it breaks.
OUT=/rtl/fix_logs; LOG=$OUT/driver_github2.log; CSV=/rtl/sweep_github2.csv
BASE=/rtl/best_baseline
D=/rtl/orfs/designs/nangate45/riscv_gh; mkdir -p $D
source /OpenROAD-flow-scripts/env.sh
cd /OpenROAD-flow-scripts/flow || exit 1
RPT=reports/nangate45/riscv_gh/base/6_finish.rpt
RLOG=logs/nangate45/riscv_gh/base/6_report.log
sed -e 's|/rtl/rtl_pipelined/|/rtl/rtl_github/|g' \
    -e 's|riscv_pipe/constraint.sdc|riscv_gh/constraint.sdc|' \
    -e 's|^export DESIGN_NICKNAME = .*|export DESIGN_NICKNAME = riscv_gh|' \
    $BASE/config.mk > $D/config.mk
SDC=$D/constraint.sdc; cp $BASE/constraint.sdc $SDC
echo "target_period_ns,period_min_ns,fmax_mhz,wns_ns,tns_ns,setup_viol,hold_viol,design_area_um2,seq_cells,total_power_w,status,runtime_s" > $CSV
echo "[$(date +%H:%M:%S)] START github-RTL sweep (util 76, cluster 20, margin 0, typical corner)" >> $LOG
for P in 1.60 1.55; do
  TAG=gh_p$P
  sed -i "s|^set clk_period .*|set clk_period ${P}|" $SDC
  START=$(date +%s); STATUS=OK
  echo "[$(date +%H:%M:%S)] START $TAG" >> $LOG
  make DESIGN_CONFIG=$D/config.mk clean_all > $OUT/$TAG.log 2>&1
  rm -f $RPT $RLOG
  make DESIGN_CONFIG=$D/config.mk >> $OUT/$TAG.log 2>&1 || STATUS=FLOW_FAIL
  RT=$(( $(date +%s) - START ))
  PMIN=""; FMAX=""; WNS=""; TNS=""; SV=""; HV=""; AREA=""; SEQ=""; POWER=""
  if [ -f $RPT ]; then
    PMIN=$(awk '/period_min/{print $4; exit}' $RPT); FMAX=$(awk '/period_min/{print $7; exit}' $RPT)
    WNS=$(awk '/^wns max/{print $3; exit}' $RPT); TNS=$(awk '/^tns max/{print $3; exit}' $RPT)
    SV=$(awk '/finish setup_violation_count/{f=1} f && /^setup violation count/{print $4; exit}' $RPT)
    HV=$(awk '/finish hold_violation_count/{f=1} f && /^hold violation count/{print $4; exit}' $RPT)
    POWER=$(awk '/finish report_power/{f=1} f && /^Total /{print $5; exit}' $RPT)
    cp $RPT $OUT/6_finish_$TAG.rpt
  else STATUS=FLOW_FAIL; fi
  if [ -f $RLOG ]; then AREA=$(awk '/Design area/{print $3; exit}' $RLOG); SEQ=$(awk '/Sequential cell/{print $3; exit}' $RLOG); cp $RLOG $OUT/6_report_$TAG.log; fi
  [ -z "$PMIN" ] && STATUS=FLOW_FAIL
  if [ "$STATUS" = OK ] && [ -n "$WNS" ] && awk "BEGIN{exit !($WNS < 0)}"; then STATUS=TIMING_VIOL; fi
  echo "$P,$PMIN,$FMAX,$WNS,$TNS,$SV,$HV,$AREA,$SEQ,$POWER,$STATUS,$RT" >> $CSV
  echo "[$(date +%H:%M:%S)] DONE $TAG status=$STATUS ${RT}s pmin=$PMIN fmax=$FMAX wns=$WNS viol=$SV area=$AREA seq=$SEQ power=$POWER" >> $LOG
done
echo "GITHUB_SWEEP_DONE $(date +%H:%M:%S)" >> $LOG
