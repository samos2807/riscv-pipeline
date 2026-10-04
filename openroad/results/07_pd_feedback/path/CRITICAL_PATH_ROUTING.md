# Critical path: picture, breakdown, wire share, routing skeleton, clock mesh

Date: 2026-10-04. Sections 3, 4 and 5 of the PD feedback.

Sources:

| data | file / command |
|---|---|
| worst reg-to-reg path, cells, coordinates, nets | `orfs/path_info.tcl` → `path_published.txt`, `path_final.txt` (this folder) |
| same path with wire R = C = 0 (pin caps only) | `orfs/path_zero_rc.tcl` → `path_zero_rc_*.txt` |
| per-cell delays | `report_checks -fields {fanout capacitance slew}` inside the files above |
| picture | `images_png/worst_path_hires_final.png` (0.03 µm/px, whole die, `gui::show_worst_path`), cropped and captioned as `images_png/critical_path_zoom.png` |
| NDR experiment | `orfs/pre_grt_crit_ndr.tcl`, logs `fix_logs/crit_ndr*.log`, reports `reports/crit_ndr/` |

## 3. The picture

`critical_path_zoom.png`: a 54 × 46 µm window of the 177 µm die. Red is the data path,
cyan the launch clock branch, green the capture clock branch, magenta the cells on the
path; the GUI legend colours, stated in the caption. The launch flop is at the left
(cyan enters it), the path runs right and down through the operand mux and the adder,
and ends at the capture flop top right (green enters it). The red segments are short:
the 20 cells sit within ~35 × 30 µm, which is the visual form of the number in the next
section, 4 % wire.

## 3b. Path breakdown by cell family (ns)

Published RTL, 1.55 ns clock, path `mem_wb_rd[1] → … → u_pc.pc_out[20]`, 32 cells:

| segment | cells | delay |
|---|---|---|
| launch clock latency | 3 CLKBUF | 0.223 |
| FF clk → Q | DFFR_X1 | 0.113 |
| forwarding compare + select | OR4, OAI221, NOR3, NOR2, MUX2, OAI21 | 0.247 |
| ALU adder (ripple of HA / XNOR / AOI / OAI) | 13 cells | 0.656 |
| branch resolve (zero detect) + PC mux | NOR4, NAND4, NOR2, MUX2, AOI22 | 0.279 |
| buffers inserted by the flow | 7 BUF | 0.212 |
| **data path** | | **1.509** |
| setup + slack | | 0.035 + 0.007 |

Final RTL, 1.00 ns clock, path `id_ex_sel_b[2] → … → ex_mem_alu_result[27]`, 20 cells:

| segment | cells | delay |
|---|---|---|
| launch clock latency | 7 CLKBUF (incl. 3 delay buffers) | 0.258 |
| FF clk → Q | DFFR_X1 | 0.101 |
| one-hot operand select (AND-OR) | BUF, AOI22, NAND3 | 0.101 |
| ALU adder (OR tree + HA / XNOR / AOI / OAI chain, 2 BUF) | 16 cells | 0.744 |
| branch / PC | – (registered away in round 1) | 0 |
| **data path** | | **0.948** |
| setup + slack | | 0.037 + 0.008 |

Two walls disappeared (forwarding compare, branch resolve), the select stage went from
0.25 to 0.10 ns, and what remains is the adder: 78 % of the data path. That is the
next lever (parallel-prefix adder, or an EX split), not routing.

## 4. Wire share and the routing-skeleton question

Measured by re-timing the same path with no parasitics and wire R = C = 0, so only
cell delays and pin capacitances remain:

| | published | final |
|---|---|---|
| data path with SPEF | 1.509 ns | 0.948 ns |
| data path with zero wire RC | 1.427 ns | 0.907 ns |
| **wire contribution** | 0.082 ns (5.4 %) | **0.041 ns (4.3 %)** |
| clock latency with SPEF / zero RC | 0.223 / 0.137 | 0.258 / 0.212 |

So on the final design a routing skeleton on high metals can recover at most 41 ps,
and only if every wire on the path became ideal. A realistic skeleton (preroute on
metal 6–8, router drops to the pins on metal 1–3) keeps the via stacks at both ends of
every one of the 19 nets, which on 20 adjacent cells is where most of the 41 ps
already is. The upper bound on Fmax from this lever is 1.21 → 1.17 ns, about +3 %;
the adder lever is worth ten times that.

Experiment run anyway, to have a number instead of an estimate: the 19 data nets of the
path were given a non-default rule before global routing (`pre_grt_crit_ndr.tcl`,
PRE_GLOBAL_ROUTE_TCL hook, flow restarted from global route on the identical
placement and CTS).

- Attempt 1, the clock rule (2× width, 2× spacing, `CTS_NDR_0`) on the 19 nets:
  global routing aborted, `GRT-0183 heap underflow during 3D maze routing` on a gated
  clock net. The 95 NDR clock nets already sit at the limit of what this router handles
  at 81 % utilization; 19 more NDR nets in the same region tipped it over.
- Attempt 2, a width-only rule (2× width, default spacing, `CRIT_W2`) on the 19 nets,
  40 min route, 0 DRC, 0 violations of any type (`reports/crit_ndr/6_finish.rpt`):

  | | final (baseline) | final + NDR on the 19 critical nets |
  |---|---|---|
  | original path `id_ex_sel_b[2] → ex_mem_alu_result[27]`, data arrival | 1.206 ns | 1.196 ns (**−10 ps**) |
  | worst path after the change | the same | moved to bit 30: `id_ex_sel_b[1] → ex_mem_alu_result[30]`, 1.203 ns |
  | period_min / Fmax | 0.99 ns / 1008.4 MHz | 0.99 ns / 1012.9 MHz (**+0.4 %**) |
  | cell area / power | 24,931 µm² / 21.1 mW | 24,940 µm² / 21.1 mW |

  10 ps recovered out of the 41 ps wire ceiling, and the gain stops there because the
  next bit of the same adder is 7 ps behind: a routing fix on one path exposes its 31
  siblings. Pushing further would mean NDR on all ~600 adder nets, which is where
  attempt 1 showed the router gives up.

Conclusion for the feedback item: the critical path of this design is logic-bound,
not wire-bound; manual high-metal routing is the right tool when wire RC is 20–40 % of
a path, and here it is 4 %.

## 5. Clock mesh / grid

Not implementable in this flow, and the measured skew says it would not pay:

- OpenROAD has no clock-mesh synthesis; TritonCTS builds buffered trees only. A mesh
  (multi-driven net, shorted buffer outputs) is also outside what OpenSTA can time:
  multi-driver nets are not supported by its delay calculator, so even a hand-built
  mesh in the DEF could not be analysed for skew in the same flow. Mesh analysis needs
  a SPICE-level or dedicated clock-mesh tool.
- What a mesh fixes is skew and OCV sensitivity. Measured skew: 11 ps on the published
  tree, 51 ps flop-to-flop on the gated tree, out of a 990 ps period. The critical path
  slack is +8 ps. Recovering, say, 40 of the 51 ps would be worth 4 % of Fmax at a
  cost of a permanently switching grid, which at this design's 1.5–5.5 mW clock power
  would erase most of the ICG saving.
- An H-tree skeleton (a balanced trunk on high metals, trees below it) is the version
  of the idea that fits a tree-based flow. TritonCTS already builds an H-tree-like
  top level; the gated design's 51 ps comes from the 95 independent subtrees below the
  gaters, not from the trunk. The fix for that is clustering the gaters (CLOCK_TREE.md),
  not a grid.
