`timescale 1ns/1ns

module core_tb;

reg clk;
reg rst_n;

riscv_core u_core (
.clk(clk),
.rst_n(rst_n)
);

always #5 clk = ~clk;

initial begin
    clk = 0;
    rst_n = 0;

    #20;
    rst_n = 1;

    #200;
    $finish;
end
endmodule