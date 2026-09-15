# Verification report: the riscv_core optimization story vs the actual runs

Date: 2026-09-14. Every number below was read from a report or CSV in this workspace or
in the `riscv` container, or produced by a simulation run today. Nothing is from memory.
"Cannot verify" means no log, report, or CSV of that run survives.

## 1. Table of rounds, from the run artifacts

No git commits exist for this work: `C:\Users\samos\riscv_core` is not a git repository and
github.com/samos2807/riscv-pipeline has 4 commits, all dated 2026-02-22. The "artifact"
column replaces the commit column. Cell area = ORFS "Design area" (standard-cell area, um2).
Util = post-route utilization from the same line. All runs: Nangate45, typical corner,
CORE_UTILIZATION 76, CTS_CLUSTER_SIZE 20, SETUP_SLACK_MARGIN 0 unless noted.

| # | RTL state | Change type | Artifact (date) | Target ns | pmin ns | Fmax MHz | WNS | setup/hold viol | cell area | util | power mW |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | published GitHub RTL (== rtl_github, == rtl_pipelined/*.orig, diff = 0) | flow only | sweep_github2.csv, fix_logs/6_finish_gh_p1.55.rpt (Sep 9) | 1.55 | 1.54 | 648.05 | 0.00 | 0 / 0 | 32808 | 77% | 26.5 |
| 0b | same, pushed | flow only | sweep_github.csv (Sep 9) | 1.42 | 1.53 | 655.55 | -0.11 | 234 / 0 | 33144 | | 29.3 |
| 0c | same | flow only | sweep_github.csv | 1.36 | FLOW_FAIL (GRT congestion) | | | | | | |
| A/B | + Fix A (registered forwarding selects), Fix B (registered branch redirect), static backward-taken predictor. Done 2026-09-03, before the Claude Code sessions | RTL | best_pipe_743/ (Sep 4; util 75, cluster 40, margin 0.02) | 1.36 | 1.35 | 742.99 | 0.00 | 0 / 0 | ~33.4k | | 30.6 |
| 1 | A/B RTL, P&R sweep util {70,76,82} x cluster {20,40,60}, margin 0 | flow only | sweep_pipe.csv, best_baseline/ (Sep 5-6) | 1.36 | 1.35 | 742.84 | 0.00 | 0 / 0 | 33354 | 77% | 31.1 |
| 1b | A/B RTL, tighten | flow only | tighten_pipe.csv (Sep 6) | 1.30 / 1.10 | 1.33 / 1.37 | 750 / 731 | -0.03 / -0.27 | 10 / 33, hold 0 | 33478 / 33942 | 78% | 32.8 / 39.3 |
| 2 | + Fix C (write-back mux retimed before MEM/WB), Fix D (debug pin from EX/MEM flop) | RTL | fix_logs/tighten_fix2.csv (Sep 7) | 1.25 | 1.24 | 804.60 | 0.00 | 0 / 0 | 33045 | | 32.9 |
| 3 | + Fix E (BEQ equality comparator) | RTL | fix_logs/tighten_fix3.csv (Sep 7) | 1.10 | 1.08 | 925.31 | 0.00 | 0 / 0 | 33027 | | 36.8 |
| 3b | same, pushed | flow only | tighten_fix3b.csv | 1.05 / 1.00 | 1.05 / 1.04 | 951.6 / 960.9 | -0.00 / -0.04 | 1 / 12 | 33165 / 33225 | | 38.8 / 40.8 |
| 4a | C+D+E, ADDER_MAP_FILE off / ABC_CLOCK_PERIOD 850 | flow only | fix_logs/adder_exp.csv | 1.00 | 1.08 / 1.04 | 925 / 961 | -0.08 / -0.04 | 11 / 12 | 33393 / 33225 | | 39.8 / 40.8 |
| 4b | + Fix F (nested-ternary 4:1 mux), abandoned | RTL | fix_logs/fixF_exp.csv | 1.00 | 1.11 | 900.45 | -0.11 | 21 / 0 | 33397 | | 41.7 |
| 4c | + Fix F2 (one-hot AND-OR operand muxes) | RTL | fix_logs/tighten_fixF2.csv, best_fix5_1ghz/ | 1.00 | 0.99 | 1011.85 | 0.00 | 0 / 0 | 33131 | 77% | 40.4 |
| 4d | F2 pushed | flow only | tighten_fixF2b.csv, best_fix5_1057/ | 0.95 / 0.90 | 0.95 / 0.93 | 1057.7 / 1072.4 | 0.00 / -0.03 | 0 / 8 | 33230 / 33546 | | 42.6 / 45.1 |
| 5a | + Fix G (95 ICGs: regfile rows 1..31, dmem rows 0..63) | RTL | fix_logs/tighten_fixG.csv | 1.00 | 1.02 | 977.25 | -0.02 | 1 / 0 | 24994 | | 23.2 |
| 5b | G, util 82 | flow only | fix_logs/gated_util.csv | 1.00 | FLOW_FAIL (GRT-0116 congestion) | | | | | | |
| 5c | G | flow only | fix_logs/tighten_fixG3.csv, best_fix6_gated/ | 1.05 | 1.03 | 969.28 | 0.00 | 0 / 0 (1 max-cap) | 24865 | | 22.1 |
| 5d | + Fix H (one-hot AND-OR dmem read) = FINAL | RTL | fix_logs/tighten_fixH.csv, best_fix7_1ghz_gated/ (Sep 7, re-run Sep 9 identical) | 1.00 | 0.99 | 1007.55 | 0.00 | 0 / 0 (**7 max-cap**) | 24770 | 81% | 20.9 |

Pre-A/B pipelined runs of Sep 2-3 (541 MHz, 608 MHz at 1.7 ns, pmin 1.56, util 55/85): no CSV,
report, or log survives. The container's riscv_pipe logs were overwritten on Sep 6 and Sep 9.
The only surviving artifact is `reports/nangate45/riscv_pipe/base/congestion.rpt` dated
2026-09-02 19:23, which confirms a global-routing congestion failure that day but not the
utilization value. Cannot verify 541 / 608 / 1.56 / util 55 / util 85 from logs.

Simple (non-pipelined) core, for the record: baseline_2p5/ (Aug 12) 448.21 MHz;
best_717/ and final_716mhz/ (Sep 2) 716.77 MHz; best_726/ (Sep 2) 726.60 MHz at util 85.

## 2. Baseline definition and final comparison

Baseline = the RTL published at github.com/samos2807/riscv-pipeline, all 12 files fetched
today and diffed against /rtl/rtl_github and /rtl/rtl_pipelined/*.orig: zero differences
(whitespace and CR ignored). Run in the identical flow and settings as the final point.

| | published RTL | final (A..H) | change |
|---|---|---|---|
| Fmax clean | 648.05 MHz | 1007.55 MHz | +55.5% |
| target period | 1.55 ns | 1.00 ns | |
| cell area (Design area) | 32808 um2 | 24770 um2 | -24.5% |
| die (DIEAREA) | 416.74 x 416.74 um | 354.98 x 354.98 um | -27.5% |
| synthesis chip area | 32368 um2 | 23405 um2 | -27.7% |
| flip-flops | 3446 (3072 DFF + 371 DFFR + 3 DFFS) | 3413 + 95 CLKGATE | |
| power | 26.5 mW @ 648 MHz | 20.9 mW @ 1008 MHz | -21% |
| energy per cycle | 40.9 pJ | 20.7 pJ | -49% |
| setup / hold violations | 0 / 0 | 0 / 0 | |
| max-cap / slew / fanout | 0 / 0 / 0 | **7** / 0 / 0 | see point 11 |
| reg-to-reg critical path | mem_wb_rd[1] -> ... -> u_pc.pc_out[20], 32 cells, 1.73 ns | id_ex_sel_b[2] -> ALU -> ex_mem_alu_result[27], 24 cells, 1.21 ns | |

## 3. Verification

- Runner: /rtl/sim_work/run_tb.sh, iverilog 11, testbench /rtl/tb/riscv_pipe_tb.v.
- Monitor: architectural write ports only (regfile we3/a3/wd3 and dmem we/a/wd), written
  to retire.log in order, independent of pipeline timing.
- Programs: "default" (demo program, 10 retirement events) and LOOP_PROG (23 events:
  loop with a forward not-taken BEQ and a backward taken BEQ, halt at end). The HAZARD_PROG
  regression exists only in the single-cycle rtl/imem.v and was NOT run on the pipelined
  designs. There is no ISA regression and no gate-level simulation.
- Golden traces were generated on Sep 7 from the A/B RTL. Every fix directory
  sim_work/fix1..fix7 holds SIM_PASS and retire logs identical to golden.
- Today: the published RTL (rtl_github, with the testbench-side halt imem) was simulated.
  Its retirement traces in both programs are identical to golden (md5 match after stripping
  cycle stamps). So "bit-identical to the original" holds from the published RTL through the
  final RTL, for these two programs.

## 4. Answers to points 1-11

1. **What is 648.** The published pipelined RTL, in this flow, util 76, 1.55 ns target, clean.
   It is not the simple core (that one gave 448 / 717 / 727 MHz in its own runs). 541 and 608
   are unverifiable, but they are the same RTL at an earlier, looser P&R setup, consistent with
   this RTL breaking at 1.42 ns (pmin 1.53) at util 76. 648 -> 1008 compares the same RTL
   lineage and does not violate the rule on pipeline depth, forwarding, or ISA. Use 648.
2. **743 is not "physical only".** Confirmed. best_pipe_743 (Sep 4) and the Sep 5-6 sweep both
   ran rtl_pipelined/riscv_core.v dated Sep 3, which already contains Fix A, Fix B and the
   predictor. Pure published RTL stops at 648. Correct order: published 648 -> A/B 743 (RTL,
   Sep 3) -> P&R sweep on A/B gave 1.5% spread and a locked critical path (flow, Sep 5-6)
   -> C+D 805 -> E 925 -> F2 1008 (1058 at 0.95) -> G gating -> H 1008 gated.
3. **Real order.** See table. Commit column not available; artifacts with dates instead.
4. **Power.** -43% = Fix G vs Fix F2, both at 1.00 ns target: 40.4 -> 23.2 mW (-42.6%).
   -21% = final 20.9 mW at 1.00 ns vs published 26.5 mW at 1.55 ns, different clock rates; per
   cycle it is -49%. 30.6 mW at 743 = best_pipe_743 (margin 0.02, util 75); 31.1 mW in the
   margin-0 sweep. Power at 541: no log. Breakdown published: 62.5% sequential, 20.6% clock;
   final: 38.5% sequential, 11.0% clock, 50.5% combinational. Power is from default switching
   activity, not a VCD.
5. **Area.** "Design area" is standard-cell area, not die. Both runs use CORE_UTILIZATION 76.
   Cell area -24.5%, die -27.5%, synthesis area -27.7%. Post-route utilization is 77% vs 81%
   (the final has more clock and hold buffers on 95 gated nets), so the saving is logic, not
   packing: combinational cells 9309 -> 5002. The util-55 base is irrelevant to this comparison.
6. **Write-back.** Fix C is retiming, not a stage move. The mux
   `mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result` moved from after the MEM/WB
   register to before it (`mem_wb_wb_data <= ex_mem_mem_to_reg ? mem_read_data : ex_mem_alu_result`).
   MEM/WB holds one 32-bit value instead of two; the register-file write still happens in WB.
7. **ICG per row.** Row = one 32-bit word. Register file rows x1..x31 (31 ICGs, x0 excluded)
   plus data memory rows 0..63 (64 ICGs) = 95 CLKGATE_X1, confirmed by synth_stat.
   89% = 3072 array flops (64x32 + 32x32) / 3446 flops in the published netlist = 89.1%.
8. **64:1 mux.** It is the data memory (dmem, 64 words), read as `ram[a[31:2]]`, not the
   register file. The regfile is 32 entries with two read ports (2 x 32:1) and was not changed
   apart from gating. Write "data memory" in the post.
9. **31-stage path.** Verified: 32 cells from mem_wb_rd[1] through the forwarding compare,
   ALU, and branch loop to u_pc.pc_out[20], exactly the README's documented path. Worth one
   line in the post. After A/B: 27 cells (mem_wb_mem_to_reg -> ex_mem_redirect). After F2:
   21 cells. Final: 24 cells (id_ex_sel_b[2] -> adder -> ex_mem_alu_result[27]).
10. **PDK.** Nangate45 (PLATFORM = nangate45 in every config), typical corner, the only
    library shipped. Add it to the post.
11. **Hold and other checks.** Hold is checked post-route in every run: hold_viol = 0 in
    every CSV, hold buffers present, worst hold slack MET. BUT the final netlist has 7
    max-capacitance violations: six NOR3_X1 cells driving dmem ICG enable pins at 17.3-20.5 fF
    against a 16.0 fF limit, and one NOR3_X4 at 65.5 vs 63.3 fF. Slew and fanout are clean.
    The published-RTL run has zero of any kind; the gated run at 1.05 ns has one. "Zero
    violations" in the post is only true for setup and hold. Either write "0 setup, 0 hold"
    or fix the 7 max-cap violations (upsize those drivers / repair_design) and re-run
    before claiming zero.

## 5. Architectural-change rule: one exception to disclose

The reworked RTL contains, since Sep 3: a static backward-taken / forward-not-taken branch
predictor decided in ID, and a registered branch redirect that changes the mispredict penalty
from 2 cycles (published: flush IF/ID + ID/EX) to 3 cycles (flush IF/ID, ID/EX, EX/MEM).
Pipeline depth, forwarding paths, and ISA are unchanged. "Same hazard handling" is not
strictly true. IPC was not measured (both programs retire the same 23 events, timing not
compared). Either state the predictor in the post or limit the rule to "same pipeline, same
forwarding, same ISA".

## 7. Resolution (2026-09-15)

- **Max-capacitance violations: fixed in the flow, RTL unchanged.** Measured on the
  global-route database, the enable net of u_dmem.g_row[0] already carried 22.88 fF
  (routed: 22.75 fF), so the pre-route estimate was accurate. Cause: ORFS runs
  repair_design then repair_timing at the global-route stage and never re-checks
  capacitance; the clock-gating-check paths are within 0.03 ns of the period, and
  repair_timing leaves the NOR3_X1 enable drivers overloaded. Fix: a
  PRE_DETAIL_ROUTE_TCL hook that runs repair_design once more after repair_timing
  (2 resizes, 4 buffers). Attempts that failed and why: CAP_MARGIN 30 alone (2 left,
  the margin acts on the estimate, not the cause); post-route ECO (this OpenROAD
  cannot re-read its routed pin wires for an incremental reroute); hand upsizing of
  the 94 drivers to X4 (fixed the enables, overloaded the two shared decode nets, and
  any repair after a manual swap fails on inconsistent parasitics); the hook with the
  30 percent margin (18 buffers, detailed routing stuck for 11 hours on 2 DRC
  violations). The final hook uses a 10 percent margin.
- **Final run** (riscv_final, 1.00 ns, util 76, CAP_MARGIN 30 + hook), post-route
  with extracted parasitics: 1008.38 MHz, wns 0.00, worst setup slack +0.01, worst hold
  +0.07, max-cap slack +0.011 fF, max-slew slack +0.39, 0 violators of any type,
  0 DRC, 0 antenna, cell area 24931 um2 (81 percent utilization), die 354.98 um,
  power 21.1 mW (seq 7.95 / comb 10.9 / clock 2.30), 3413 flops + 95 CLKGATE_X1,
  critical path id_ex_sel_b[2] -> adder -> ex_mem_alu_result[27], 20 data-path cells.
  vs published RTL: +55.6 percent fmax, -24.0 percent cell area, -27.4 percent die,
  -20.4 percent power, -49 percent energy per cycle. The max-cap slack is positive by
  0.011 fF: clean by the report, with no margin to spare.
- **Verification: extended and passed.** Reference model from the spec, hazard
  program with a backward not-taken branch added, 100 random programs with forward
  taken/not-taken and backward taken/not-taken branches (482 / 282 / 323 / 155
  dynamic events) and 330 load-use pairs. 303 runs on the published, round-1 and
  final RTL: 0 failures, identical retirement streams. Mutant with forwarding
  disabled: fails every program. rv32ui: not runnable on 8 instructions.
- **The "no architectural change" exception** (static predictor + registered redirect,
  penalty 2 -> 3 cycles) is disclosed in the README and in the round-1 commit.
- **Repository**: one commit per round on github.com/samos2807/riscv-pipeline, with
  the RTL of that round in rtl_1ghz/, the ORFS config, the driver scripts, the CSVs
  and the post-route reports, plus the verification package and the layout images.

## 6. Post claims that must change

- "Round 1, physical only: 743" -> 743 already includes Fix A/B; the published RTL is 648.
- "0 violations" -> "0 setup, 0 hold" (7 max-cap remain) or fix them first.
- "same hazard handling" -> drop, or disclose predictor + registered redirect.
- "mux 64:1" -> "data memory read mux, 64 words".
- Add: Nangate45; the 31/32-cell path matching the README; power is default activity.
- Verification claim: "bit-identical retirement trace on two test programs", not an ISA suite.
