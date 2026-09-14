#!/bin/bash
# run_verif.sh <out_dir> [n_random] [seed] [rtl dirs...]
# Runs the hazard regression + n random programs on every RTL variant,
# checks each against the Python reference model, and cross-diffs the
# retirement streams between variants. Needs iverilog and python3.
#   example (repo root):  bash verif/run_verif.sh /tmp/v 100 1 rtl rtl_1ghz
OUT=$(realpath -m "$1"); N=${2:-50}; SEED=${3:-1}; shift 3 2>/dev/null
RTLS=${@:-"rtl rtl_1ghz"}
V=$(cd "$(dirname "$0")" && pwd)
RTLS=$(for r in $RTLS; do realpath "$r"; done)
mkdir -p "$OUT" && cd "$OUT" || exit 1

python3 $V/gen_prog.py gen "$OUT/programs" "$N" "$SEED" || exit 1

total=0; fail=0
for RTLP in $RTLS; do
  RTL=$(basename "$RTLP")
  SRC=$(ls "$RTLP"/*.v | grep -v '/imem\.v$')
  iverilog -g2005 -o "$OUT/sim_$RTL" -s riscv_diff_tb $V/riscv_diff_tb.v $V/imem_hex.v $SRC || { echo "COMPILE FAIL $RTL"; exit 1; }
  pf=0; ff=0
  for P in "$OUT"/programs/*/; do
    n=$(basename "$P")
    vvp "$OUT/sim_$RTL" +prog="$P/prog.hex" +cycles="$(cat "$P/cycles")" \
        +log="$P/retire_$RTL.log" +state="$P/state_$RTL.txt" > "$P/run_$RTL.txt" 2>&1
    if python3 $V/gen_prog.py check "$P/expected.txt" "$P/state_$RTL.txt" "$P/retire_exp.log" "$P/retire_$RTL.log" > "$P/check_$RTL.txt"; then
      pf=$((pf+1))
    else
      ff=$((ff+1)); echo "FAIL $RTL $n"; cat "$P/check_$RTL.txt" | head -5
    fi
  done
  echo "=== $RTL: $pf pass, $ff fail"
  total=$((total+pf+ff)); fail=$((fail+ff))
done

echo "=== cross-RTL retirement streams"
set -- $(for r in $RTLS; do basename "$r"; done)
for P in "$OUT"/programs/*/; do
  for R in "$@"; do
    cmp -s "$P/retire_$1.log" "$P/retire_$R.log" || echo "DIFF $(basename $P): $1 vs $R"
  done
done
echo "=== TOTAL: $total runs, $fail failures"
[ $fail -eq 0 ] && touch "$OUT/VERIF_PASS"
