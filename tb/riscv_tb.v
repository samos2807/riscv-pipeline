`timescale 1ns/1ps

module tb_riscv ();

reg clk;
reg rst_n;
wire [31:0] alu_check;

riscv_core uut (
    .clk(clk),
    .rst_n(rst_n),
    .alu_out_test(alu_check)
);

always #5 clk = ~clk;

integer pass_count;
integer fail_count;

task check_reg;
    input [4:0]  reg_num;
    input [31:0] expected;
    begin
        if (uut.u_regfile.rf[reg_num] === expected) begin
            $display("  [PASS] x%0d = %0d", reg_num, expected);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] x%0d = %0d (expected %0d)", reg_num,
                     uut.u_regfile.rf[reg_num], expected);
            fail_count = fail_count + 1;
        end
    end
endtask

initial begin
    clk = 0;
    rst_n = 0;
    pass_count = 0;
    fail_count = 0;

    #20;
    rst_n = 1;

    // Wait enough cycles for all instructions to complete through pipeline
    // 14 instructions + pipeline fill (4) + stalls (1) + branch penalty (2) + margin
    #300;

    $display("");
    $display("======================================");
    $display(" RISC-V Pipeline - Register Check");
    $display("======================================");

    // Test 1: EX-EX Forwarding
    $display("");
    $display("--- Test 1: EX-EX Forwarding ---");
    check_reg(1, 5);     // addi x1, x0, 5
    check_reg(2, 8);     // addi x2, x1, 3  (forwarded x1)

    // Test 2: MEM-EX Forwarding
    $display("");
    $display("--- Test 2: MEM-EX Forwarding ---");
    check_reg(3, 7);     // addi x3, x0, 7
    check_reg(4, 12);    // add  x4, x3, x1 (forwarded x3 from MEM/WB)

    // Test 3: Load-Use Hazard (stall + forwarding)
    $display("");
    $display("--- Test 3: Load-Use Stall ---");
    check_reg(5, 5);     // lw x5, 0(x0) = 5
    check_reg(6, 13);    // add x6, x5, x2 = 5+8 (stall then forward)

    // Test 4: Simple value
    $display("");
    $display("--- Test 4: Sequential ---");
    check_reg(7, 99);    // addi x7, x0, 99

    // Test 5: Branch NOT taken
    $display("");
    $display("--- Test 5: Branch NOT Taken ---");
    check_reg(8, 42);    // addi x8, x0, 42 (executed because branch not taken)

    // Test 6: Branch TAKEN (flush)
    $display("");
    $display("--- Test 6: Branch TAKEN (Flush) ---");
    check_reg(9,  0);    // x9 should stay 0 (instruction was flushed)
    check_reg(10, 1);    // addi x10, x0, 1 (branch target, should execute)

    $display("");
    $display("======================================");
    $display(" Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
    $display("======================================");

    if (fail_count == 0)
        $display(" ALL TESTS PASSED!");
    else
        $display(" SOME TESTS FAILED!");

    $display("");
    $finish;
end

// Pipeline state monitor (for waveform debugging)
always @(posedge clk) begin
    if (rst_n) begin
        $display("t=%0t | PC=%h | IF/ID_instr=%h | stall=%b flush=%b | fwdA=%b fwdB=%b | ALU=%0d",
                 $time, uut.pc_current, uut.if_id_instr,
                 uut.stall, uut.flush,
                 uut.forward_a, uut.forward_b,
                 $signed(uut.alu_result));
    end
end

endmodule
