# =============================================================
#  config.mk  --  riscv_core, nangate45, RTL-to-GDSII
#  Run with:
#    make DESIGN_CONFIG=/rtl/orfs/designs/nangate45/riscv_core/config.mk
#  (the repo is mounted at /rtl inside the container)
# =============================================================

export DESIGN_NAME   = riscv_core
export PLATFORM      = nangate45

# ---- RTL ----------------------------------------------------
# Plain Verilog-2001 -> use the default Yosys frontend.
# (Do NOT set SYNTH_HDL_FRONTEND = slang; none of this is SystemVerilog.)
export VERILOG_FILES = \
    /rtl/rtl/riscv_core.v \
    /rtl/rtl/pc.v \
    /rtl/rtl/imem.v \
    /rtl/rtl/dmem.v \
    /rtl/rtl/regfile.v \
    /rtl/rtl/decoder.v \
    /rtl/rtl/alu.v \
    /rtl/rtl/alu_decoder.v \
    /rtl/rtl/controller.v \
    /rtl/rtl/imm_gen.v

# ---- constraints --------------------------------------------
export SDC_FILE = /rtl/openroad/configs/riscv_gh/constraint.sdc

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
export DESIGN_NICKNAME = riscv_gh
export VERILOG_FILES += /rtl/rtl/forwarding_unit.v /rtl/rtl/hazard_detection_unit.v
export SKIP_INCREMENTAL_REPAIR = 0
export HOLD_SLACK_MARGIN = 0.02
export CORE_UTILIZATION = 76
export CTS_CLUSTER_SIZE = 20
