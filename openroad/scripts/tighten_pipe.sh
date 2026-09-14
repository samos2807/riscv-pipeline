#!/bin/bash
# Clock-tightening sweep: push clk_period until it breaks, record how badly.
# Usage: tighten_pipe.sh <CORE_UTILIZATION> <CTS_CLUSTER_SIZE>
source /OpenROAD-flow-scripts/env.sh
cd /OpenROAD-flow-scripts/flow || exit 1

UTIL=$1
CS=$2
CFG=/rtl/orfs/designs/nangate45/riscv_pipe/config.mk
SDC=/rtl/orfs/designs/nangate45/riscv_pipe/constraint.sdc
CSV=/rtl/tighten_pipe.csv
RPT=reports/nangate45/riscv_pipe/base/6_finish.rpt
RLOG=logs/nangate45/riscv_pipe/base/6_report.log
OUT=/rtl/tighten_logs
mkdir -p "$OUT"

cp "$SDC" "$SDC.orig"

sed -i "s|^export CORE_UTILIZATION = .*|export CORE_UTILIZATION = ${UTIL}|" "$CFG"
sed -i "s|^export CTS_CLUSTER_SIZE = .*|export CTS_CLUSTER_SIZE = ${CS}|"  "$CFG"

echo "target_period_ns,period_min_ns,fmax_mhz,wns_ns,tns_ns,setup_viol,hold_viol,design_area_um2,utilization_pct,total_power_w,status,runtime_s" > "$CSV"

for P in 1.30 1.25 1.20 1.15 1.10; do
  TAG="p${P}"
  echo "=== [$(date +%H:%M:%S)] START $TAG (util=$UTIL cs=$CS) ===" >> "$OUT/driver.log"

  sed -i "s|^set clk_period .*|set clk_period ${P}|" "$SDC"

  START=$(date +%s)
  STATUS=OK
  make DESIGN_CONFIG="$CFG" clean_all  > "$OUT/${TAG}.log" 2>&1
  rm -f "$RPT" "$RLOG"
  make DESIGN_CONFIG="$CFG"           >> "$OUT/${TAG}.log" 2>&1 || STATUS=FLOW_FAIL
  RT=$(( $(date +%s) - START ))

  PMIN=""; FMAX=""; WNS=""; TNS=""; SV=""; HV=""; AREA=""; UPCT=""; POWER=""
  if [ -f "$RPT" ]; then
    PMIN=$(awk '/period_min/{print $4; exit}' "$RPT")
    FMAX=$(awk '/period_min/{print $7; exit}' "$RPT")
    WNS=$(awk '/^wns max/{print $3; exit}' "$RPT")
    TNS=$(awk '/^tns max/{print $3; exit}' "$RPT")
    SV=$(awk '/finish setup_violation_count/{f=1} f && /setup violation count/{print $4; exit}' "$RPT")
    HV=$(awk '/finish hold_violation_count/{f=1} f && /hold violation count/{print $4; exit}' "$RPT")
    POWER=$(awk '/finish report_power/{f=1} f && /^Total /{print $5; exit}' "$RPT")
  else
    STATUS=FLOW_FAIL
  fi
  if [ -f "$RLOG" ]; then
    AREA=$(awk '/Design area/{print $3; exit}' "$RLOG")
    UPCT=$(awk '/Design area/{print $5; exit}' "$RLOG" | tr -d '%')
  fi
  # timing-broken is a RESULT, not an error - label it distinctly
  if [ "$STATUS" = "OK" ] && [ -n "$WNS" ]; then
    if awk "BEGIN{exit !($WNS < 0)}"; then STATUS=TIMING_VIOL; fi
  fi

  echo "${P},${PMIN},${FMAX},${WNS},${TNS},${SV},${HV},${AREA},${UPCT},${POWER},${STATUS},${RT}" >> "$CSV"
  cp "$RPT"  "$OUT/6_finish_${TAG}.rpt" 2>/dev/null
  cp "$RLOG" "$OUT/6_report_${TAG}.log" 2>/dev/null
  echo "=== [$(date +%H:%M:%S)] DONE $TAG status=$STATUS ${RT}s pmin=$PMIN wns=$WNS tns=$TNS setup_viol=$SV ===" >> "$OUT/driver.log"
done

cp "$SDC.orig" "$SDC"
echo "TIGHTEN_DONE $(date +%H:%M:%S) (sdc restored to 1.36)" >> "$OUT/driver.log"
