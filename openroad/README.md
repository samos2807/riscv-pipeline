# OpenROAD flow (ORFS, Nangate45)

Every result in the second part of this repository was produced with
OpenROAD-flow-scripts inside the `openroad/orfs` Docker image, with this repository
mounted at `/rtl`. Platform: nangate45 (NanGate 45 nm open cell library, typical
corner, the only corner it ships). Settings common to every run unless a config
says otherwise: CORE_UTILIZATION 76, CTS_CLUSTER_SIZE 20, SETUP_SLACK_MARGIN 0,
PLACE_DENSITY_LB_ADDON 0.20, post-route STA with extracted parasitics.

```
docker run -d --name riscv -v <this repo>:/rtl openroad/orfs:latest sleep infinity
docker exec riscv bash -c "source /OpenROAD-flow-scripts/env.sh && cd /OpenROAD-flow-scripts/flow && \
   make DESIGN_CONFIG=/rtl/openroad/configs/riscv_final/config.mk"
```

- `configs/<round>/`: the ORFS config.mk and constraint.sdc used for that round's
  headline result. `riscv_gh` builds `rtl/` (the published core); every other config
  builds `rtl_1ghz/` as it stood at that commit.
- `scripts/`: the sweep and tighten drivers that produced the CSVs.
- `results/<round>/`: the CSVs and the post-route `6_finish.rpt` reports (timing,
  power, area, check_types) of each round. `design_area_um2` is standard-cell area.
