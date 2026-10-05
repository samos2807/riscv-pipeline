// =====================================================================
//  riscv_pipe_tb -- self-checking regression for the 5-stage riscv_core
//                   in rtl_pipelined/.
//
//  This core takes its instruction through the instr_in PORT and exposes
//  pc_out, so the testbench closes the fetch loop itself:
//      pc_out -> imem.addr        imem.inst -> instr_in
//
//  Build with -d LOOP_PROG so imem selects the backward-branch loop, which
//  is what actually exercises the static predictor. (The default imem
//  program has only forward branches and leaves the predictor idle.)
//
//  Produces:
//    * console: cycle-stamped retirement trace + PASS/FAIL
//    * retire.log: the retirement stream WITHOUT cycle numbers, so runs
//      with and without the prediction / Fix A / Fix B changes can be
//      diffed directly. Those runs retire the SAME events on DIFFERENT
//      cycles, so the log compares order and value only.
//
//  The 2-stage version of this bench is kept at riscv_pipe_tb.v.orig.
// =====================================================================
`timescale 1ns/1ps

module riscv_pipe_tb;

    reg         clk   = 1'b0;
    reg         rst_n = 1'b0;
    wire [31:0] instr_in;
    wire [31:0] pc_out;
    wire [31:0] alu_out_test;

    integer errors = 0;
    integer cyc    = 0;
    integer n_reg  = 0;   // regfile retirement events
    integer n_mem  = 0;   // store events
    integer fh;

    // The regfile has no reset, so never-written registers read X in
    // simulation. Zero the array at t=0 so the never-written checks hold.
    integer ri;
    initial for (ri = 0; ri < 32; ri = ri + 1) uut.u_regfile.rf[ri] = 32'b0;

    riscv_core uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .instr_in     (instr_in),
        .pc_out       (pc_out),
        .alu_out_test (alu_out_test)
    );

    // Instruction memory lives outside the core on this variant.
    imem u_imem (
        .addr (pc_out),
        .inst (instr_in)
    );

    always #5 clk = ~clk;
    always @(posedge clk) cyc <= cyc + 1;

    // -----------------------------------------------------------------
    //  Retirement-stream monitor.
    //  Watches the architectural write ports only, so it is unaffected by
    //  how many pipeline stages there are or where branches resolve.
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n === 1'b1) begin
            if (uut.u_regfile.we3 === 1'b1 && uut.u_regfile.a3 !== 5'd0) begin
                $display("[%0d] RETIRE x%0d <= 0x%08x",
                         cyc, uut.u_regfile.a3, uut.u_regfile.wd3);
                $fdisplay(fh, "x%0d <= 0x%08x",
                          uut.u_regfile.a3, uut.u_regfile.wd3);
                n_reg = n_reg + 1;
            end
            if (uut.u_dmem.we === 1'b1) begin
                $display("[%0d] STORE  MEM[%0d] <= 0x%08x",
                         cyc, uut.u_dmem.a[31:2], uut.u_dmem.wd);
                $fdisplay(fh, "MEM[%0d] <= 0x%08x",
                          uut.u_dmem.a[31:2], uut.u_dmem.wd);
                n_mem = n_mem + 1;
            end
        end
    end

    task chk;
        input [8*8:1] nm;
        input [31:0]  got;
        input [31:0]  exp;
        begin
            if (got !== exp) begin
                $display("FAIL: %0s = 0x%08x, expected 0x%08x", nm, got, exp);
                errors = errors + 1;
            end else begin
                $display("  ok  %0s = 0x%08x", nm, got);
            end
        end
    endtask

    task chk_int;
        input [8*8:1] nm;
        input integer got;
        input integer exp;
        begin
            if (got !== exp) begin
                $display("FAIL: %0s = %0d, expected %0d", nm, got, exp);
                errors = errors + 1;
            end else begin
                $display("  ok  %0s = %0d", nm, got);
            end
        end
    endtask

    // safety net so a hang cannot look like a pass
    initial begin
        #100000;
        $display("FAIL: timeout, testbench never reached its checks");
        $finish;
    end

    initial begin
        fh = $fopen("retire.log", "w");
        if (fh == 0) begin
            $display("FAIL: cannot open retire.log for writing");
            $finish;
        end

        rst_n = 1'b0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        // The loop needs ~111 cycles before the changes and ~92 after, so
        // 200 covers both without the window itself masking a difference.
        repeat (200) @(posedge clk);

        $display("---- architectural state ----");
        chk("x1", uut.u_regfile.rf[1], 32'h00000014);   // loop counter = 20
        chk("x2", uut.u_regfile.rf[2], 32'h00000014);   // loop bound   = 20
        chk("x3", uut.u_regfile.rf[3], 32'h00000001);   // set after the loop exits
        chk("x4", uut.u_regfile.rf[4], 32'h00000000);   // never written
        chk("x5", uut.u_regfile.rf[5], 32'h00000000);

        // 1 (x1<=0) + 1 (x2<=20) + 20 (x1<=1..20) + 1 (x3<=1)
        chk_int("n_reg", n_reg, 23);
        chk_int("n_mem", n_mem, 0);

        $fclose(fh);
        if (errors == 0)
            $display("=== PASS === 23 retirement events written to retire.log");
        else
            $display("=== FAIL: %0d error(s) ===", errors);
        $finish;
    end

endmodule
