# Clock tree: structure, latency and skew, before and after

Date: 2026-10-04. Post-route databases with extracted SPEF, propagated clocks.

Sources:

| data | file / command |
|---|---|
| tree structure (sinks, clustering, levels, buffers) | `logs/nangate45/<design>/base/4_1_cts.log` (TritonCTS) |
| skew and latency | `orfs/clock_report.tcl`: `report_clock_skew -setup/-hold`, `report_clock_latency`, `report_clock_min_period` (OpenSTA) |
| per-sink latency | `orfs/latency_dump.tcl`: `report_checks` for every endpoint, capture-clock "clock network delay (propagated)" parsed into `latency_<design>.txt` |
| images | `images_png/clock_published.png`, `clock_final.png` (clock nets + clock-tree cells only, 0.08 µm/px), `clock_side_by_side.png` |
| raw outputs | `clock_published.txt`, `clock_final.txt`, `paths_*.txt` in this folder |

## Structure (from the CTS log and the netlist)

| | published | final |
|---|---|---|
| clock nets | 1 (`clk`) | 1 root (`clk` to 95 ICGs) + 1 register net (`clk_regs`, 373 sinks) + 95 gated nets (`*.u_icg.gck`, 32 sinks each) |
| sinks | 3,446 flops | 3,413 flops + 95 ICGs |
| leaf clustering | 173 clusters of up to 20 sinks, 50 µm diameter | root tree: 15-sink stop; each gated net: 32 sinks, 2 levels, no leaf buffers |
| levels | 4 | root 4 + 2 per gated subtree |
| clock buffers (CLKBUF_X*) | 449 | 901 (+ 3 delay buffers on `clk_regs`) |
| average sink wire length | 341 µm | 72–85 µm per gated net |

## Latency and skew (OpenSTA, propagated)

| | published | final |
|---|---|---|
| network latency, min – max (rise) | 0.217 – 0.228 ns | 0.249 – 0.300 ns (flops), 0.130 – 0.150 ns (ICGs) |
| `report_clock_skew -setup` | **0.010 ns** | 0.127 ns (flop → ICG pair), **0.051 ns** flop → flop |
| `report_clock_skew -hold` | 0.010 ns | 0.127 ns (same pair) |
| period_min / fmax | 1.54 ns / 648 MHz | 0.99 ns / 1008 MHz |

Per-sink capture latency (from `latency_*.txt`, output ports excluded):

| group | published: n, min–max, mean ± sd | final: n, min–max, mean ± sd |
|---|---|---|
| memory arrays (dmem + regfile) | 3,072, 0.220–0.230, 0.222 ± 0.004 | 3,040, 0.250–0.300, 0.271 ± 0.007 |
| pipeline registers | 374, 0.220–0.230 | 373, 0.250–0.260 |
| ICG clock pins | – | 95, 0.130–0.150, 0.140 ± 0.004 |
| histogram, 10 ps bins | 0.22: 2699, 0.23: 747 | 0.25: 149, 0.26: 893, 0.27: 1550, 0.28: 781, 0.29: 38, 0.30: 2 |

## Reading

1. **The published tree is as balanced as this flow gets.** 3,446 sinks within an 11 ps
   window, one tree, four levels. There is nothing for a clock mesh to fix here: skew is
   1 % of the 1.54 ns period.
2. **The gated tree is a two-tier structure by construction.** The root tree reaches the
   95 ICGs early (0.13–0.15 ns), each ICG then drives its own 32-flop subtree, and the
   373 ungated pipeline registers get a separate net with three delay buffers inserted
   by CTS so that they land in the same window as the gated flops (0.25–0.26 vs
   0.25–0.30 ns). The 0.127 ns "skew" OpenSTA reports is flop-to-ICG, which is the
   intended tier difference; the flop-to-flop skew that matters for setup is 51 ps.
3. **Skew grew from 11 to 51 ps.** The gated subtrees are built independently per net
   (32 sinks, 2 levels), so their latencies differ by the subtree's own wire and buffer
   spread, and the root-to-ICG insertion is not re-balanced across the 95 gaters
   (`-balance_levels` is obsolete in this OpenROAD and was a no-op when tried). 51 ps is
   5 % of the 0.99 ns period; the critical path has +8 ps of slack, so the skew is not
   what limits Fmax, the adder is.
4. **Cost of the gating on the clock network:** 901 vs 449 clock buffers, 95 extra NDR
   nets (the vertical magenta lines in the layout images), and the latency went up by
   ~0.05 ns because the gaters add a level. Against that, clock-net power dropped from
   5.46 to 1.49 mW at the same frequency (POWER_SPLIT.md).

## What would reduce the 51 ps

- Clustering the 95 gaters by location and building one balanced tree below each
  cluster instead of 95 independent 2-level subtrees. TritonCTS does not do this on its
  own; it would be a custom CTS script.
- A clock mesh or H-tree skeleton (feedback item 5): see CRITICAL_PATH_ROUTING.md,
  section 5, for why it is not implementable in this flow and what it would buy.
