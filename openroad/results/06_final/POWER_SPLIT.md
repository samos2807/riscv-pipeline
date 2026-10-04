# Power split: leakage vs dynamic, before and after (OpenROAD, Nangate45, typical)

Date: 2026-10-04. Source files, all post-route with the design's own extracted SPEF:

| design | database | parasitics | report |
|---|---|---|---|
| published RTL (before) | `results/nangate45/riscv_gh/base/6_final.odb` | `riscv_gh/base/6_final.spef` | `power_published.log` (this folder) |
| final RTL (after) | `best_final_1ghz/layout/6_final.odb` | `best_final_1ghz/layout/6_final.spef` | `power_final.log` (this folder) |

Script: `orfs/power_split.tcl` (OpenSTA `report_power`, same engine and same default
activity assumptions as the flow's `6_finish.rpt`; the at-own-clock rows reproduce the
6_finish numbers exactly). Liberty: NangateOpenCellLibrary_typical.lib. No VCD: switching
activity is OpenSTA's default, so the dynamic numbers are relative, not absolute.

Leakage in the Nangate45 liberty is per-cell static power (`leakage_power` groups), summed
over instances. It depends only on cell count, cell size and state, not on the clock.
Dynamic = internal (cell-internal switching, including the flop clock pins) + switching
(net capacitance charging).

## Per-group breakdown (mW)

| design @ clock | group | internal | switching | **leakage** | total | share |
|---|---|---|---|---|---|---|
| published @ 1.55 ns (648 MHz) | sequential | 15.9 | 0.34 | 0.265 | 16.5 | 62.5 % |
| | combinational | 1.60 | 2.57 | 0.300 | 4.47 | 16.9 % |
| | clock | 1.50 | 3.96 | 0.007 | 5.46 | 20.6 % |
| | **total** | **19.0** | **6.86** | **0.572** | **26.5** | |
| published @ 1.00 ns (timing fails, power only) | total | 28.3 | 9.21 | 0.572 | 38.1 | |
| final @ 1.00 ns (1008 MHz) | sequential | 6.75 | 0.93 | 0.272 | 7.95 | 37.7 % |
| | combinational | 4.06 | 6.61 | 0.189 | 10.9 | 51.4 % |
| | clock | 1.07 | 1.21 | 0.026 | 2.30 | 10.9 % |
| | **total** | **11.9** | **8.75** | **0.488** | **21.1** | |
| final @ 1.55 ns (same clock as before) | sequential | 5.12 | 0.73 | 0.272 | 6.12 | 37.4 % |
| | combinational | 3.35 | 5.22 | 0.189 | 8.76 | 53.5 % |
| | clock | 0.69 | 0.78 | 0.026 | 1.49 | 9.1 % |
| | **total** | **9.16** | **6.73** | **0.488** | **16.4** | |

## Leakage vs dynamic, the two components separated

| | before (published) | after (final) | change |
|---|---|---|---|
| instances (no fill / tap) | 13,890 | 10,553 | −24 % |
| flip-flops | 3,446 | 3,413 | −1 % |
| clock gaters | 0 | 95 | |
| buffers (BUF + CLKBUF) | 1,150 | 1,573 | +37 % |
| standard-cell area | 32,808 µm² | 24,931 µm² | −24 % |
| **leakage** (clock-independent) | 0.572 mW | 0.488 mW | **−15 %** |
| leakage share of total | 2.2 % | 2.3 % | |
| **dynamic @ 1.55 ns** (same clock) | 25.9 mW | 15.9 mW | **−39 %** |
| **dynamic @ 1.00 ns** (same clock) | 37.5 mW | 20.6 mW | **−45 %** |
| total @ own Fmax | 26.5 mW @ 648 MHz | 21.1 mW @ 1008 MHz | −20 % |
| energy per cycle @ own Fmax | 40.9 pJ | 20.9 pJ | −49 % |
| energy per cycle @ 1.55 ns | 41.1 pJ | 25.4 pJ | −38 % |

## Reading

1. **Leakage is 2 % of the total at this corner.** Nangate45 typical, 1.1 V, 25 °C. The
   area reduction did lower it, −15 %, but less than the −24 % in cell area: the gated
   design has 37 % more buffers (clock tree on 95 gated nets plus hold fixes) and the X4
   drivers from the max-cap repair, which leak more per cell. Shrinking the block is a
   leakage lever in principle; here it moves 0.08 mW. The headline power result is
   dynamic.
2. **Dynamic fell 39 % at the same clock.** All of it in the sequential and clock groups:
   sequential internal 15.9 → 5.1 mW (flop clock-pin and data toggling stopped on the
   3,040 array flops that are now gated), clock net 5.46 → 1.49 mW (gaters hold the
   gated branches still). This is the ICG effect, measured at equal frequency, so it is
   not frequency scaling.
3. **Combinational dynamic went up**, 4.2 → 8.6 mW at 1.55 ns. Three contributors, in
   order of likely size: the one-hot AND-OR read path of the data memory (64 AND terms
   plus OR tree, each toggling under default activity), the AND-OR operand muxes, and the
   enable decode of 95 gaters. Under default activity every input toggles at the same
   rate, which overstates a structure that in a real program is mostly idle. This is the
   one line where a VCD-driven power run could move the result by a few mW either way.
4. **What is not here.** Cadence Genus/Innovus power for the February design: the Genus
   script (`scripts/syn_genus.tcl`) wrote `syn_output/power_report.txt`, but no copy
   survives on disk and the Cadence license has expired, so the Cadence side cannot be
   produced now. GPDK045 and Nangate45 are different libraries at different corners
   anyway (slow 0.9 V 125 °C vs typical 1.1 V 25 °C), so a before/after inside one tool
   is the only comparison that isolates the design change. That is the one above.

## Reproduce

```
PS_ODB=<odb> PS_SDC=<sdc> PS_SPEF=<spef> PS_TAG=<name> PS_PERIODS="1.55 1.00" \
  make DESIGN_CONFIG=/rtl/openroad/configs/riscv_final/config.mk run \
       RUN_SCRIPT=/rtl/openroad/scripts/power_split.tcl
```
