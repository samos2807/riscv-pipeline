#!/bin/bash
# Sweep CORE_UTILIZATION x CTS_CLUSTER_SIZE for riscv_pipe
source /OpenROAD-flow-scripts/env.sh
cd /OpenROAD-flow-scripts/flow || exit 1

CFG=/rtl/orfs/designs/nangate45/riscv_pipe/config.mk
CSV=/rtl/sweep_pipe.csv
RPT=reports/nangate45/riscv_pipe/base/6_finish.rpt
RLOG=logs/nangate45/riscv_pipe/base/6_report.log
OUT=/rtl/sweep_logs
mkdir -p "$OUT"

echo "core_utilization,cts_cluster_size,period_min_ns,fmax_mhz,wns_ns,design_area_um2,utilization_pct,total_power_w,status,runtime_s" > "$CSV"

for UTIL in 70 76 82; do
  for CS in 20 40 60; do
    TAG="u${UTIL}_c${CS}"
    echo "=== [$(date +%H:%M:%S)] START $TAG ===" >> "$OUT/driver.log"

    sed -i "s|^export CORE_UTILIZATION = .*|export CORE_UTILIZATION = ${UTIL}|" "$CFG"
    sed -i "s|^export CTS_CLUSTER_SIZE = .*|export CTS_CLUSTER_SIZE = ${CS}|"  "$CFG"

    START=$(date +%s)
    STATUS=OK

    make DESIGN_CONFIG="$CFG" clean_all  > "$OUT/${TAG}.log" 2>&1
    rm -f "$RPT" "$RLOG"
    make DESIGN_CONFIG="$CFG"           >> "$OUT/${TAG}.log" 2>&1 || STATUS=FAIL

    RT=$(( $(date +%s) - START ))

    PMIN=""; FMAX=""; WNS=""; AREA=""; UPCT=""; POWER=""
    if [ -f "$RPT" ]; then
      PMIN=$(awk '/period_min/{print $4; exit}' "$RPT")
      FMAX=$(awk '/period_min/{print $7; exit}' "$RPT")
      WNS=$(awk '/^wns max/{print $3; exit}' "$RPT")
      POWER=$(awk '/finish report_power/{f=1} f && /^Total /{print $5; exit}' "$RPT")
    else
      STATUS=FAIL
    fi
    if [ -f "$RLOG" ]; then
      AREA=$(awk '/Design area/{print $3; exit}' "$RLOG")
      UPCT=$(awk '/Design area/{print $5; exit}' "$RLOG" | tr -d '%')
    fi
    [ -z "$PMIN" ] && STATUS=FAIL

    echo "${UTIL},${CS},${PMIN},${FMAX},${WNS},${AREA},${UPCT},${POWER},${STATUS},${RT}" >> "$CSV"
    cp "$RPT"  "$OUT/6_finish_${TAG}.rpt" 2>/dev/null
    cp "$RLOG" "$OUT/6_report_${TAG}.log" 2>/dev/null
    echo "=== [$(date +%H:%M:%S)] DONE $TAG status=$STATUS ${RT}s pmin=$PMIN fmax=$FMAX ===" >> "$OUT/driver.log"
  done
done
echo "SWEEP_DONE $(date +%H:%M:%S)" >> "$OUT/driver.log"
