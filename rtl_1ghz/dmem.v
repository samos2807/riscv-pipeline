module dmem (
    input wire               clk,
    input wire                we,
    input wire          [31:0] a,
    input wire          [31:0] wd,
    output wire         [31:0] rd
);


// Fix G: mem2reg makes yosys treat each row as an ordinary register, since
// the rows are written on separate gated clocks (iverilog ignores it).
(* mem2reg *) reg [31:0] ram [0:63];

// Fix H: read as a one-hot AND-OR instead of a 64:1 mux tree -- the same
// restructuring F2 applied to the ALU operand muxes. The row select is
// decoded from the address once, each row is ANDed with its select, and the
// 64 terms are OR-reduced in three 4-way levels (AOI/NAND trees) instead of
// six MUX2 levels in series. Same value for every in-range address; an
// out-of-range read, undefined before, now returns the row aliased by a[7:2].
wire [63:0]      rsel;
wire [64*32-1:0] t0;
wire [16*32-1:0] t1;
wire [4*32-1:0]  t2;
genvar j;
generate
    for (j = 0; j < 64; j = j + 1) begin : g_rd0
        assign rsel[j]        = (a[7:2] == j);
        assign t0[32*j +: 32] = {32{rsel[j]}} & ram[j];
    end
    for (j = 0; j < 16; j = j + 1) begin : g_rd1
        assign t1[32*j +: 32] = t0[128*j +: 32] | t0[128*j+32 +: 32] |
                                t0[128*j+64 +: 32] | t0[128*j+96 +: 32];
    end
    for (j = 0; j < 4; j = j + 1) begin : g_rd2
        assign t2[32*j +: 32] = t1[128*j +: 32] | t1[128*j+32 +: 32] |
                                t1[128*j+64 +: 32] | t1[128*j+96 +: 32];
    end
endgenerate
assign rd = t2[0 +: 32] | t2[32 +: 32] | t2[64 +: 32] | t2[96 +: 32];

// Fix G: one clock-gating cell per row; a row is clocked only in the cycle
// it is the store target. The decode is the same one the write enable used
// before (a store to an address beyond the array is still ignored); it now
// feeds the gate enable instead of 2048 per-bit feedback muxes.
wire        in_range = (a[31:8] == 24'b0);
wire [63:0] row_clk;
genvar i;
generate
    for (i = 0; i < 64; i = i + 1) begin : g_row
        icg u_icg (.ck(clk), .e(we && in_range && (a[7:2] == i)), .gck(row_clk[i]));
        always @(posedge row_clk[i])
            ram[i] <= wd;
    end
endgenerate

    
endmodule