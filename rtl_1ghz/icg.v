// ============================================================
//  icg -- integrated clock-gating cell wrapper (Fix G)
//
//  gck is a copy of ck that only pulses while e was 1 during the
//  preceding low phase of ck. The enable is captured by a latch that is
//  transparent while ck is low, so e may change freely after the rising
//  edge without producing a glitch on gck.
//
//  Synthesis (yosys defines SYNTHESIS): the nangate45 library cell
//  CLKGATE_X1, which the liberty marks as clock_gating_integrated_cell,
//  so CTS builds the tree through it and STA runs clock-gating checks
//  on e.
//  Simulation: an equivalent behavioral model of the same latch + AND.
// ============================================================
module icg (
    input  wire ck,
    input  wire e,
    output wire gck
);

`ifdef SYNTHESIS
    CLKGATE_X1 u_icg (.CK(ck), .E(e), .GCK(gck));
`else
    reg en_l;
    always @(ck or e)
        if (!ck) en_l = e;          // transparent-low latch
    assign gck = ck & en_l;
`endif

endmodule
