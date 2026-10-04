# =============================================================
#  config.mk  --  riscv_core, nangate45, RTL-to-GDSII
#  Run with:
#    make DESIGN_CONFIG=/rtl/openroad/scripts/designs/nangate45/riscv_core/config.mk
#  (the repo is mounted at /rtl inside the container)
# =============================================================

export DESIGN_NAME   = riscv_core
export PLATFORM      = nangate45

# ---- RTL ----------------------------------------------------
# Plain Verilog-2001 -> use the default Yosys frontend.
# (Do NOT set SYNTH_HDL_FRONTEND = slang; none of this is SystemVerilog.)
export VERILOG_FILES = \
    /rtl/rtl_fix7/riscv_core.v \
    /rtl/rtl_fix7/pc.v \
    /rtl/rtl_fix7/imem.v \
    /rtl/rtl_fix7/dmem.v \
    /rtl/rtl_fix7/regfile.v \
    /rtl/rtl_fix7/decoder.v \
    /rtl/rtl_fix7/alu.v \
    /rtl/rtl_fix7/alu_decoder.v \
    /rtl/rtl_fix7/controller.v \
    /rtl/rtl_fix7/imm_gen.v

# ---- constraints --------------------------------------------
export SDC_FILE = /rtl/openroad/scripts/designs/nangate45/riscv_crit/constraint.sdc

# ---- floorplan / placement ----------------------------------
# Flop-array heavy (dmem + regfile map to FFs); give it room to route.
export PLACE_DENSITY_LB_ADDON = 0.20

# ---- timing driven-ness -------------------------------------
# Fix every failing endpoint, not just the worst 10%.
export TNS_END_PERCENT          = 100
export ABC_AREA = 0
export CTS_CLUSTER_DIAMETER = 50
export MIN_ROUTING_LAYER = metal4
export SETUP_SLACK_MARGIN = 0
export DESIGN_NICKNAME = riscv_crit
export VERILOG_FILES += /rtl/rtl_fix7/forwarding_unit.v /rtl/rtl_fix7/hazard_detection_unit.v
export SKIP_INCREMENTAL_REPAIR = 0
export HOLD_SLACK_MARGIN = 0.02
export CORE_UTILIZATION = 76
export CTS_CLUSTER_SIZE = 20
export VERILOG_FILES += /rtl/rtl_fix7/icg.v

# max-cap fix (2026-09-14): overfix capacitance in repair_design so the 7 NOR3 ICG-enable drivers are sized up before routing
export CAP_MARGIN = 30

# gater-enable driver upsizing before detailed route (2026-09-14), see /rtl/openroad/scripts/pre_droute_gater_enable.tcl
export PRE_DETAIL_ROUTE_TCL = /rtl/openroad/scripts/pre_droute_gater_enable.tcl

# section-4 experiment: NDR on the critical-path data nets before global route
export PRE_GLOBAL_ROUTE_TCL = /rtl/openroad/scripts/pre_grt_crit_ndr.tcl
