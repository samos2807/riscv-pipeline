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

 assign rd = ram[a[31:2]];

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