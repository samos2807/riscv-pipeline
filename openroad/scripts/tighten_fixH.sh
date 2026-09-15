#!/bin/bash
# Fix H (rtl_fix7 = gated + one-hot AND-OR dmem read) @1.00 ns, util 76 then 82. Gated on sim pass; waits for the util-82 run (CPU).
OUT=/rtl/fix_logs; LOG=$OUT/driver_fixH.log; CSV=$OUT/tighten_fixH.csv
GATE=/rtl/sim_work/fix7/SIM_PASS
W=0; until [ -f $GATE ]; do sleep 5; W=$((W+5)); [ $W -ge 1800 ] && { echo "[$(date +%H:%M:%S)] GATE TIMEOUT - sim not passed, NOT running" >> $LOG; exit 1; }; done
echo "[$(date +%H:%M:%S)] sim gate open; waiting for gated util run" >> $LOG
W=0; until grep -q '^GATED_UTIL_DONE' $OUT/driver_gated_util.log 2>/dev/null; do sleep 15; W=$((W+15)); [ $W -ge 10800 ] && { echo "[$(date +%H:%M:%S)] wait TIMEOUT" >> $LOG; exit 1; }; done
echo "[$(date +%H:%M:%S)] starting Fix H runs" >> $LOG
BASE=/rtl/orfs/designs/nangate45/riscv_fixG
D=/rtl/orfs/designs/nangate45/riscv_fixH; mkdir -p $D
source /OpenROAD-flow-scripts/env.sh
cd /OpenROAD-flow-scripts/flow || exit 1
RPT=reports/nangate45/riscv_fixH/base/6_finish.rpt
RLOG=logs/nangate45/riscv_fixH/base/6_report.log
echo "core_util,target_period_ns,period_min_ns,fmax_mhz,wns_ns,tns_ns,setup_viol,hold_viol,reg2reg_slack_ns,design_area_um2,seq_cells,total_power_w,status,runtime_s" > $CSV
sed 's|^set clk_period .*|set clk_period 1.00|' $BASE/constraint.sdc > $D/constraint.sdc
for U in 76 82; do
  TAG=fixH_u${U}_p1.00
  sed -e 's|/rtl/rtl_fix6/|/rtl/rtl_fix7/|g' -e 's|riscv_fixG/constraint.sdc|riscv_fixH/constraint.sdc|' -e 's|^export DESIGN_NICKNAME = .*|export DESIGN_NICKNAME = riscv_fixH|' -e "s|^export CORE_UTILIZATION = .*|export CORE_UTILIZATION = ${U}|" $BASE/config.mk > $D/config.mk
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
  echo "$U,1.00,$PMIN,$FMAX,$WNS,$TNS,$SV,$HV,$R2R,$AREA,$SEQ,$POWER,$STATUS,$RT" >> $CSV
  echo "[$(date +%H:%M:%S)] DONE $TAG status=$STATUS ${RT}s pmin=$PMIN fmax=$FMAX wns=$WNS viol=$SV r2r=$R2R area=$AREA power=$POWER" >> $LOG
done
echo "FIXH_DONE $(date +%H:%M:%S)" >> $LOG
