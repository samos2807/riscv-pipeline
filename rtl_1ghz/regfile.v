module regfile (
    input wire              clk,
    input wire              we3, // Enable to write
    input wire [4:0]        a1,
    input wire [4:0]        a2,
    input wire [4:0]        a3, // Addres to write
    input wire [31:0]       wd3, // Write data
    output wire [31:0]      rd1,
    output wire [31:0]      rd2          
);
    // Fix G: mem2reg makes yosys treat each row as an ordinary register, since
    // the rows are written on separate gated clocks (iverilog ignores it).
    (* mem2reg *) reg [31:0] rf [0:31] ;

    // Fix G: clock gating per row. A register receives a clock edge only in
    // the cycle it is written, through one integrated clock-gating cell per
    // row, instead of all 1024 flops being clocked every cycle and holding
    // their value through a per-bit feedback mux. The enable is the same
    // decode the write used before (we3 and a3 == row); x0 is never written.
    wire [31:0] row_clk;
    assign row_clk[0] = 1'b0;
    genvar i;
    generate
        for (i = 1; i < 32; i = i + 1) begin : g_row
            icg u_icg (.ck(clk), .e(we3 && (a3 == i)), .gck(row_clk[i]));
            always @(posedge row_clk[i])
                rf[i] <= wd3;
        end
    endgenerate

    // Read logic with write-first bypass
    // When WB writes and ID reads the same register in the same cycle,
    // the read gets the new (written) value
    assign rd1 = (a1 == 5'b0) ? 32'b0 :
                 (we3 && a3 == a1) ? wd3 : rf[a1];
    assign rd2 = (a2 == 5'b0) ? 32'b0 :
                 (we3 && a3 == a2) ? wd3 : rf[a2];
endmodule