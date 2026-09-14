#!/bin/bash
# Fix C+D+E+F RTL (/rtl/rtl_fix4) at 1.00 ns: default flow / no adder map / both.
# Waits for the adder experiments (shared CPU). Reference Fix C+D+E @1.00 default: wns -0.04, 12 viol, pmin 1.04.
OUT=/rtl/fix_logs; LOG=$OUT/driver_fixF.log; CSV=$OUT/fixF_exp.csv
GATE=/rtl/sim_work/fix4/SIM_PASS; [ -f $GATE ] || { echo 'no sim gate' >> $LOG; exit 1; }
W=0; until grep -q '^ADDER_EXP_DONE' $OUT/driver_adder.log 2>/dev/null; do sleep 15; W=$((W+15)); [ $W -ge 5400 ] && { echo "[$(date +%H:%M:%S)] adder-exp wait TIMEOUT" >> $LOG; exit 1; }; done
echo "[$(date +%H:%M:%S)] adder experiments done; starting Fix F runs" >> $LOG
BASE=/rtl/orfs/designs/nangate45/riscv_fix3
D=/rtl/orfs/designs/nangate45/riscv_fixF; mkdir -p $D
source /OpenROAD-flow-scripts/env.sh
cd /OpenROAD-flow-scripts/flow || exit 1
RPT=reports/nangate45/riscv_fixF/base/6_finish.rpt
RLOG=logs/nangate45/riscv_fixF/base/6_report.log
echo "variant,target_period_ns,period_min_ns,fmax_mhz,wns_ns,tns_ns,setup_viol,hold_viol,reg2reg_slack_ns,design_area_um2,seq_cells,total_power_w,status,runtime_s" > $CSV
sed 's|^set clk_period .*|set clk_period 1.00|' $BASE/constraint.sdc > $D/constraint.sdc

run_variant() {
  TAG=$1; shift
  sed -e 's|/rtl/rtl_fix3/|/rtl/rtl_fix4/|g' -e 's|riscv_fix3/constraint.sdc|riscv_fixF/constraint.sdc|' -e 's|^export DESIGN_NICKNAME = .*|export DESIGN_NICKNAME = riscv_fixF|' $BASE/config.mk > $D/config.mk
  for L in "$@"; do echo "$L" >> $D/config.mk; done
  echo "[$(date +%H:%M:%S)] START $TAG :: $*" >> $LOG
  START=$(date +%s); STATUS=OK
  make DESIGN_CONFIG=$D/config.mk clean_all > $OUT/fixF_$TAG.log 2>&1
  rm -f $RPT $RLOG
  make DESIGN_CONFIG=$D/config.mk >> $OUT/fixF_$TAG.log 2>&1 || STATUS=FLOW_FAIL
  RT=$(( $(date +%s) - START ))
  PMIN=""; FMAX=""; WNS=""; TNS=""; SV=""; HV=""; R2R=""; AREA=""; SEQ=""; POWER=""
  if [ -f $RPT ]; then
    PMIN=$(awk '/period_min/{print $4; exit}' $RPT); FMAX=$(awk '/period_min/{print $7; exit}' $RPT)
    WNS=$(awk '/^wns max/{print $3; exit}' $RPT); TNS=$(awk '/^tns max/{print $3; exit}' $RPT)
    SV=$(awk '/finish setup_violation_count/{f=1} f && /^setup violation count/{print $4; exit}' $RPT)
    HV=$(awk '/finish hold_violation_count/{f=1} f && /^hold violation count/{print $4; exit}' $RPT)
    R2R=$(awk '/finish report_checks -path_delay max reg to reg/{f=1} f && /slack \(/{print $1; exit}' $RPT)
    POWER=$(awk '/finish report_power/{f=1} f && /^Total /{print $5; exit}' $RPT)
    cp $RPT $OUT/6_finish_fixF_$TAG.rpt
  else STATUS=FLOW_FAIL; fi
  if [ -f $RLOG ]; then AREA=$(awk '/Design area/{print $3; exit}' $RLOG); SEQ=$(awk '/Sequential cell/{print $3; exit}' $RLOG); cp $RLOG $OUT/6_report_fixF_$TAG.log; fi
  [ -z "$PMIN" ] && STATUS=FLOW_FAIL
  if [ "$STATUS" = OK ] && [ -n "$WNS" ] && awk "BEGIN{exit !($WNS < 0)}"; then STATUS=TIMING_VIOL; fi
  echo "$TAG,1.00,$PMIN,$FMAX,$WNS,$TNS,$SV,$HV,$R2R,$AREA,$SEQ,$POWER,$STATUS,$RT" >> $CSV
  echo "[$(date +%H:%M:%S)] DONE $TAG status=$STATUS ${RT}s pmin=$PMIN fmax=$FMAX wns=$WNS tns=$TNS viol=$SV r2r=$R2R area=$AREA power=$POWER" >> $LOG
}
run_variant default
run_variant noadder "export ADDER_MAP_FILE ="
run_variant both    "export ADDER_MAP_FILE =" "export ABC_CLOCK_PERIOD_IN_PS = 850"
echo "FIXF_EXP_DONE $(date +%H:%M:%S)" >> $LOG
