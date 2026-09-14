// =====================================================================
//  riscv_diff_tb -- generic checker for any riscv_core variant.
//
//  Runs the program given by +prog=<hex> for +cycles=<n> cycles, then
//  dumps the complete architectural state (x1..x31 and the 64 data
//  memory words) to +state=<file> and the retirement stream (every
//  register-file write and every store, in order, no cycle stamps) to
//  +log=<file>. A Python reference model (gen_prog.py) produces the
//  expected versions of both files, so this bench needs no per-program
//  checks and works unchanged for the published RTL, the A/B RTL and
//  the final RTL.
// =====================================================================
`timescale 1ns/1ps

module riscv_diff_tb;

    reg         clk   = 1'b0;
    reg         rst_n = 1'b0;
    wire [31:0] instr_in;
    wire [31:0] pc_out;
    wire [31:0] alu_out_test;

    integer cyc   = 0;
    integer n_reg = 0;
    integer n_mem = 0;
    integer maxcyc;
    integer fh, fs, i;
    reg [1023:0] logfile, statefile;

    // Neither array has a reset. Zero both at t=0 so the reference model
    // (which starts from all-zero state) and the RTL agree.
    initial for (i = 0; i < 32; i = i + 1) uut.u_regfile.rf[i] = 32'b0;
    initial for (i = 0; i < 64; i = i + 1) uut.u_dmem.ram[i]   = 32'b0;

    riscv_core uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .instr_in     (instr_in),
        .pc_out       (pc_out),
        .alu_out_test (alu_out_test)
    );

    imem u_imem (
        .addr (pc_out),
        .inst (instr_in)
    );

    always #5 clk = ~clk;
    always @(posedge clk) cyc <= cyc + 1;

    // Retirement-stream monitor on the architectural write ports only.
    always @(posedge clk) begin
        if (rst_n === 1'b1) begin
            if (uut.u_regfile.we3 === 1'b1 && uut.u_regfile.a3 !== 5'd0) begin
                $fdisplay(fh, "x%0d <= 0x%08x", uut.u_regfile.a3, uut.u_regfile.wd3);
                n_reg = n_reg + 1;
            end
            if (uut.u_dmem.we === 1'b1) begin
                $fdisplay(fh, "MEM[%0d] <= 0x%08x", uut.u_dmem.a[31:2], uut.u_dmem.wd);
                n_mem = n_mem + 1;
            end
        end
    end

    initial begin
        if (!$value$plusargs("log=%s", logfile))     logfile   = "retire.log";
        if (!$value$plusargs("state=%s", statefile)) statefile = "state.txt";
        if (!$value$plusargs("cycles=%d", maxcyc))   maxcyc    = 2000;

        fh = $fopen(logfile, "w");
        fs = $fopen(statefile, "w");
        if (fh == 0 || fs == 0) begin
            $display("FAIL: cannot open output files");
            $finish;
        end

        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (maxcyc) @(posedge clk);

        for (i = 1; i < 32; i = i + 1) $fdisplay(fs, "x%0d %08x", i, uut.u_regfile.rf[i]);
        for (i = 0; i < 64; i = i + 1) $fdisplay(fs, "m%0d %08x", i, uut.u_dmem.ram[i]);
        $fdisplay(fs, "n_reg %0d", n_reg);
        $fdisplay(fs, "n_mem %0d", n_mem);
        $fclose(fh);
        $fclose(fs);
        $display("DONE cycles=%0d n_reg=%0d n_mem=%0d", maxcyc, n_reg, n_mem);
        $finish;
    end

endmodule
