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
    /rtl/rtl_1ghz/riscv_core.v \
    /rtl/rtl_1ghz/pc.v \
    /rtl/rtl_1ghz/imem.v \
    /rtl/rtl_1ghz/dmem.v \
    /rtl/rtl_1ghz/regfile.v \
    /rtl/rtl_1ghz/decoder.v \
    /rtl/rtl_1ghz/alu.v \
    /rtl/rtl_1ghz/alu_decoder.v \
    /rtl/rtl_1ghz/controller.v \
    /rtl/rtl_1ghz/imm_gen.v

# ---- constraints --------------------------------------------
export SDC_FILE = /rtl/openroad/configs/riscv_fix2/constraint.sdc

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
export DESIGN_NICKNAME = riscv_fix2
export VERILOG_FILES += /rtl/rtl_1ghz/forwarding_unit.v /rtl/rtl_1ghz/hazard_detection_unit.v
export SKIP_INCREMENTAL_REPAIR = 0
export HOLD_SLACK_MARGIN = 0.02
export CORE_UTILIZATION = 76
export CTS_CLUSTER_SIZE = 20
