#!/bin/bash
# Gated design (Fix G RTL, riscv_fixG config) at 1.05 ns for a fully clean gated point. Waits for the G2 sweep to finish.
OUT=/rtl/fix_logs; LOG=$OUT/driver_fixG3.log; CSV=$OUT/tighten_fixG3.csv
W=0; until grep -q '^FIXG2_SWEEP_DONE' $OUT/driver_fixG2.log 2>/dev/null; do sleep 15; W=$((W+15)); [ $W -ge 7200 ] && { echo "[$(date +%H:%M:%S)] wait TIMEOUT" >> $LOG; exit 1; }; done
echo "[$(date +%H:%M:%S)] G2 done; starting gated run @1.05" >> $LOG
D=/rtl/orfs/designs/nangate45/riscv_fixG
SDC=$D/constraint.sdc
source /OpenROAD-flow-scripts/env.sh
cd /OpenROAD-flow-scripts/flow || exit 1
RPT=reports/nangate45/riscv_fixG/base/6_finish.rpt
RLOG=logs/nangate45/riscv_fixG/base/6_report.log
echo "target_period_ns,period_min_ns,fmax_mhz,wns_ns,tns_ns,setup_viol,hold_viol,reg2reg_slack_ns,design_area_um2,seq_cells,total_power_w,status,runtime_s" > $CSV
for P in 1.05; do
  TAG=fixG_p$P
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
  echo "[$(date +%H:%M:%S)] DONE $TAG status=$STATUS ${RT}s pmin=$PMIN fmax=$FMAX wns=$WNS tns=$TNS viol=$SV hold=$HV r2r=$R2R area=$AREA seq=$SEQ power=$POWER" >> $LOG
done
echo "FIXG3_DONE $(date +%H:%M:%S)" >> $LOG
