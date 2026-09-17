# RISC-V 5-Stage Pipelined Processor — RTL to GDSII, then to 1 GHz

A 32-bit RISC-V core with a 5-stage pipeline (IF → ID → EX → MEM → WB), taken through
two complete physical design flows:

1. **Part 1 (February 2026)**: Cadence Genus / Innovus / Virtuoso / PVS on GPDK045.
   Closed a 100 MHz target at the slow corner with +222 ps of slack and zero DRC.
2. **Part 2 (September 2026)**: the same RTL on OpenROAD (Nangate45), pushed until it
   broke, then reworked round by round, without changing the architecture, until it
   closed 1 GHz post-route with zero violations of any type and 24 % less area.

| same flow, same PDK, same corner, same P&R settings | published RTL (`rtl/`) | reworked RTL (`rtl_1ghz/`) |
|---|---|---|
| Fmax, clean | 648.05 MHz | **1008.38 MHz** (+55.6 %) |
| standard-cell area | 32,808 µm² | **24,931 µm²** (−24.0 %) |
| die (DEF units are 2000 per µm) | 208.4 × 208.4 µm | 177.5 × 177.5 µm (−27.4 %) |
| post-route utilization | 77 % | 81 % |
| instances (no fill) | 10,444 | 6,570 |
| power (default activity) | 26.5 mW @ 648 MHz | **21.1 mW @ 1008 MHz** (−20.4 %) |
| energy per cycle | 40.9 pJ | 20.9 pJ (−49 %) |
| setup / hold / max-cap / slew / fanout violations | 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 |
| flip-flops | 3,446 | 3,413 + 95 clock gaters |

Every RTL change was verified against an independent reference model on a hazard
regression and 100 random programs, on the published RTL and on the final RTL
(303 runs, 0 failures, see [verif/RESULTS.md](verif/RESULTS.md)).

---

## Part 1 — Cadence flow on GPDK045 (February 2026)

### Pipeline

| Stage | Description |
|-------|-------------|
| IF    | Instruction Fetch — reads instruction from IMEM using PC |
| ID    | Instruction Decode — decodes opcode, reads register file |
| EX    | Execute — ALU computation, branch resolution |
| MEM   | Memory — read/write data memory |
| WB    | Write Back — writes result to register file |

### Hazard handling (published RTL)

| Hazard | Solution |
|--------|----------|
| EX-EX Data Hazard | Forwarding from EX/MEM register → ALU input |
| MEM-EX Data Hazard | Forwarding from MEM/WB register → ALU input |
| Load-Use Hazard | Stall (1 cycle) + bubble insertion + forwarding |
| Branch Hazard | Flush (2 cycles penalty) on taken branch |

### Supported instructions

R-type ADD SUB AND OR · I-type ADDI LW · S-type SW · B-type BEQ

### Flow and results

```
RTL (Verilog) → Vivado simulation (6 scenarios) → Genus synthesis (GPDK045 45 nm)
→ Virtuoso netlist import → Virtuoso Layout Suite XL → PVS / Innovus DRC (0 violations) → GDS
```

STA (Genus, slow corner 0.9 V / 125 °C): target 100 MHz, WNS +222 ps, TNS 0,
Fmax 102.3 MHz, cell area 33,064 µm², 3,413 flip-flops, 7,519 cells.
Critical path: EX/MEM register → forwarding MUX → ALU carry chain → PC register.

Tools: Xilinx Vivado, Cadence Genus 25.11, Cadence Virtuoso, Cadence Innovus, Cadence PVS.
Technology: GPDK045, gsclib045 SVT.

---

## Part 2 — OpenROAD on Nangate45: the same core to 1 GHz (September 2026)

### The rule

No architectural change: same 5-stage pipeline, same forwarding paths, same ISA. Only
the way the logic is implemented may change. One exception, disclosed: round 1 adds a
static backward-taken / forward-not-taken branch predictor and registers the branch
redirect, which changes the mispredict penalty from 2 to 3 cycles. IPC was not measured.

### The method

Push the clock until timing breaks → read the paths that broke → fix them in physical
design → push again. When physical design has nothing left, go back to the RTL and
shorten the critical path itself. Then push again.

### The rounds, from the post-route reports

Flow: OpenROAD-flow-scripts, Nangate45, typical corner (the only one the library
ships), utilization 76, CTS cluster 20, setup margin 0, post-route STA with extracted
parasitics. Area is standard-cell area. Power uses default switching activity.
One commit per round; the reports are in `openroad/results/`.

| Round | Change | Type | Clock | Fmax | Cell area µm² | Power mW | Violations |
|---|---|---|---|---|---|---|---|
| 0 | published RTL | flow only | 1.55 ns | 648.05 | 32,808 | 26.5 | 0 |
| 0 | published RTL, pushed | flow only | 1.42 ns | 655.55 (broken) | 33,144 | 29.3 | 234 setup |
| 1 | Fix A: forwarding selects decided in ID and registered. Fix B: branch redirect registered in EX/MEM, static predictor | RTL | 1.36 ns | 742.84 | 33,354 | 31.1 | 0 |
| 1 | P&R sweep, 9 runs util × CTS cluster | flow only | 1.36 ns | 731 – 743 | | | 0 |
| 1 | tighten 1.30 → 1.10 ns: critical-path arrival stays 1.46 – 1.50 ns | flow only | 1.30 ns | 750 (broken) | 33,478 | 32.8 | 10 setup |
| 2 | Fix C: write-back value selected in MEM, one MEM/WB data register (−33 flops). Fix D: debug pin from a flop | RTL | 1.25 ns | 804.60 | 33,045 | 32.9 | 0 |
| 3 | Fix E: BEQ on a dedicated equality comparator instead of ALU subtract + zero detect | RTL | 1.10 ns | 925.31 | 33,027 | 36.8 | 0 |
| 3 | synthesis knobs: adder map off (worse), ABC period 850 ps (no effect) | flow only | 1.00 ns | 925 / 961 (broken) | | | 11 / 12 setup |
| 4 | Fix F: nested-ternary 4:1 mux — worse, synthesis rebuilt the chain | RTL | 1.00 ns | 900 (broken) | 33,397 | 41.7 | 21 setup |
| 4 | Fix F2: one-hot registered selects, AND-OR operand muxes | RTL | 1.00 ns | 1011.85 | 33,131 | 40.4 | 0 |
| 4 | F2 pushed | flow only | 0.95 ns | 1057.66 | 33,230 | 42.6 | 0 |
| 5a | Fix G: one clock gater per row of the register file (31) and data memory (64) | RTL | 1.00 ns | 977 (one path −0.02) | 24,994 | 23.2 | 1 setup, 1 max-cap |
| 5a | Fix G | RTL | 1.05 ns | 969.28 | 24,865 | 22.1 | 1 max-cap |
| 5a | Fix G, utilization 82 | flow only | 1.00 ns | fails global routing | | | |
| 5b | Fix H: data-memory read as one-hot AND-OR instead of a 64:1 mux tree | RTL | 1.00 ns | 1007.55 | 24,770 | 20.9 | **7 max-cap** |
| 5b | Fix H, CAP_MARGIN 30 (pre-route over-fix of capacitance) | flow only | 1.00 ns | 1007.84 | 24,924 | 21.1 | 2 max-cap |
| 5b | Fix H, gater-enable drivers upsized to X4 by hand before routing | flow only | 1.00 ns | 1010.15 | 25,134 | 21.3 | 2 max-cap, 1 max-slew (upstream decode nets) |
| 5b | Fix H, CAP_MARGIN 30, one more repair_design after repair_timing (pre-route hook) | flow only | 1.00 ns | **1008.38** | **24,931** | **21.1** | **0 of any type** |

What each wall taught: the 9-run sweep moved timing 1.5 %, and tightening the clock
never shortened the critical path, so the limit was logic depth (about 30 levels),
not placement. Two of the three flow-side synthesis experiments were no-ops and one
was worse. The first mux rewrite was worse because synthesis rebuilt the same
priority chain from nested ternaries; the one-hot AND-OR form worked because the tool
cannot re-serialize it. Denser placement failed global routing outright once the 95
gated clock nets carried non-default rules. The last 7 violations were capacitance,
not timing: the NOR3_X1 gates driving the clock-gater enable pins carried 17–23 fF
against a 16 fF limit. Measuring the loads at the global-route stage showed the
estimate already at 22.9 fF, so it was not an estimation error: the flow runs
repair_design and then repair_timing at that stage, the enable paths are
clock-gating-check paths within 0.03 ns of the period, and repair_timing's work on
them leaves the drivers overloaded with nothing checking capacitance afterwards. A
pre-route hook ([openroad/scripts/pre_droute_gater_enable.tcl](openroad/scripts/pre_droute_gater_enable.tcl))
runs the flow's own repair_design once more after repair_timing: 2 resizes and 4
buffers, then zero violations of any type after routing. A post-route ECO and a
hand upsizing were tried first and both failed, for reasons recorded in the script.

Critical paths, from the reg-to-reg reports: published RTL 32 cells from `mem_wb_rd`
through the forwarding compare, the ALU and the branch loop to `pc` (the path Part 1
documented); after round 1, 27 cells `mem_wb_mem_to_reg → ex_mem_redirect`; final,
20 cells `id_ex_sel_b → ALU adder → ex_mem_alu_result`, 1.21 ns, +0.01 ns slack.

### Verification

`verif/` holds a generic testbench that dumps the full architectural state and the
retirement stream, a hex-loading instruction memory, and a Python reference model of
the 8 instructions that generates random programs and predicts the result. The
hazard regression (RAW at distance 1–3, load-use, store with forwarded base and data,
x0 writes, taken and not-taken branches, a backward loop, load feeding a branch) and
100 random programs pass on the published RTL, on the round-1 RTL and on the final
RTL, with identical retirement streams across the three. A mutant with EX forwarding
disabled fails every program.

```
bash verif/run_verif.sh out 100 1 rtl rtl_1ghz
```

### Limits

Post-route, typical corner only; Nangate45 ships no other corner, so there is no
multi-corner signoff. No gate-level or SDF simulation. Power comes from default
switching activity. rv32ui cannot run on an 8-instruction core. The remaining
critical path is the ALU carry chain at +0.01 ns; going faster needs a parallel-prefix
adder or a split EX stage, which would break the rule.

### Repository layout

```
rtl/                 published RTL (Part 1), unchanged
rtl_1ghz/            reworked RTL (Part 2), one commit per round in the history
verif/               reference-model regression (testbench, generator, results)
openroad/configs/    ORFS config + SDC per round
openroad/scripts/    sweep / tighten drivers
openroad/results/    CSVs and post-route 6_finish.rpt reports per round
openroad/images/     layouts at the same scale, critical path, clock tree
tb/ scripts/ picture/   Part 1 testbenches, Cadence scripts, Cadence screenshots
```

Reproduce: see [openroad/README.md](openroad/README.md).

---

## References

- Patterson & Hennessy — *Computer Organization and Design*
- Weste & Harris — *CMOS VLSI Design*
