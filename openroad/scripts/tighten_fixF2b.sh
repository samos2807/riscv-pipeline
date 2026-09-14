#!/bin/bash
# Resume after Docker restart: Fix C+D+E+F2 at 0.95 / 0.90 (1.00 and 1.05 already clean).
OUT=/rtl/fix_logs; LOG=$OUT/driver_fixF2b.log; CSV=$OUT/tighten_fixF2b.csv
GATE=/rtl/sim_work/fix5/SIM_PASS
W=0; until [ -f $GATE ]; do sleep 3; W=$((W+3)); [ $W -ge 300 ] && { echo "[$(date +%H:%M:%S)] GATE TIMEOUT - sim not passed, NOT running" >> $LOG; exit 1; }; done
echo "[$(date +%H:%M:%S)] sim gate open" >> $LOG
BASE=/rtl/orfs/designs/nangate45/riscv_fix3
D=/rtl/orfs/designs/nangate45/riscv_fixF2; mkdir -p $D
sed -e 's|/rtl/rtl_fix3/|/rtl/rtl_fix5/|g' -e 's|riscv_fix3/constraint.sdc|riscv_fixF2/constraint.sdc|' -e 's|^export DESIGN_NICKNAME = .*|export DESIGN_NICKNAME = riscv_fixF2|' $BASE/config.mk > $D/config.mk
SDC=$D/constraint.sdc; cp $BASE/constraint.sdc $SDC
source /OpenROAD-flow-scripts/env.sh
cd /OpenROAD-flow-scripts/flow || exit 1
RPT=reports/nangate45/riscv_fixF2/base/6_finish.rpt
RLOG=logs/nangate45/riscv_fixF2/base/6_report.log
echo "target_period_ns,period_min_ns,fmax_mhz,wns_ns,tns_ns,setup_viol,hold_viol,reg2reg_slack_ns,design_area_um2,seq_cells,total_power_w,status,runtime_s" > $CSV
for P in 0.95 0.90; do
  TAG=fixF2b_p$P
  sed -i "s|^set clk_period .*|set clk_period ${P}|" $SDC
  START=$(date +%s); STATUS=OK
  echo "[$(date +%H:%M:%S)] START $TAG" >> $LOG
  make DESIGN_CONFIG=$D/config.mk clean_all > $OUT/$TAG.log 2>&1
  rm -f $RPT $RLOG
  make DESIGN_CONFIG=$D/config.mk >> $OUT/$TAG.log 2>&1 || STATUS=FLOW_FAIL
  RT=$(( $(date +%s) - START ))
  PMIN=""; FMAX=""; WNS=""; TNS=""; SV=""; HV=""; R2R=""; AREA=""; SEQ=""; POWER=""
  if [ -f $RPT ]; then
    PMIN=$(awk '/period_min/{print $4; exit}' $RPT); FMAX=$(awk '/period_min/{print $7; exit}' $RPT)
    WNS=$(awk '/^wns max/{print $3; exit}' $RPT); TNS=$(awk '/^tns max/{print $3; exit}' $RPT)
    SV=$(awk '/finish setup_violation_count/{f=1} f && /^setup violation count/{print $4; exit}' $RPT)
    HV=$(awk '/finish hold_violation_count/{f=1} f && /^hold violation count/{print $4; exit}' $RPT)
    R2R=$(awk '/finish report_checks -path_delay max reg to reg/{f=1} f && /slack \(/{print $1; exit}' $RPT)
    POWER=$(awk '/finish report_power/{f=1} f && /^Total /{print $5; exit}' $RPT)
    cp $RPT $OUT/6_finish_$TAG.rpt
  else STATUS=FLOW_FAIL; fi
  if [ -f $RLOG ]; then AREA=$(awk '/Design area/{print $3; exit}' $RLOG); SEQ=$(awk '/Sequential cell/{print $3; exit}' $RLOG); cp $RLOG $OUT/6_report_$TAG.log; fi
  [ -z "$PMIN" ] && STATUS=FLOW_FAIL
  if [ "$STATUS" = OK ] && [ -n "$WNS" ] && awk "BEGIN{exit !($WNS < 0)}"; then STATUS=TIMING_VIOL; fi
  echo "$P,$PMIN,$FMAX,$WNS,$TNS,$SV,$HV,$R2R,$AREA,$SEQ,$POWER,$STATUS,$RT" >> $CSV
  echo "[$(date +%H:%M:%S)] DONE $TAG status=$STATUS ${RT}s pmin=$PMIN fmax=$FMAX wns=$WNS tns=$TNS viol=$SV r2r=$R2R area=$AREA power=$POWER" >> $LOG
done
sed -i 's|^set clk_period .*|set clk_period 1.10|' $SDC
echo "FIXF2B_SWEEP_DONE $(date +%H:%M:%S)" >> $LOG
