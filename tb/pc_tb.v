`timescale 1ns/1ns
module pc_tb;

reg clk ;
reg rst_n;
wire [31:0] pc_out ;

pc u_pc (
.clk(clk),
.rst_n(rst_n),
.pc_out(pc_out)
);

initial begin
    clk = 0;
   forever #5 clk = ~ clk;
end

initial begin
    rst_n = 0;
    $display ("Time: %0t | Reset is ON", $time);
    #20;

    rst_n =1;
    $display ("Time: %0t | Reset is off _ Start counting", $time);
    #100;

    $display ("Time: %0t | Test Finished", $time);
    $finish;
end

always @(pc_out) begin
    $display("Time: %0t | PC Value: %h (Decimal: %0d)", $time, pc_out, pc_out);
end
endmodule