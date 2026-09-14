// Simulation-only instruction memory: 64 words loaded from a hex file
// given as +prog=<file>. Every word not covered by the file is a halt
// (beq x0,x0,0), so a program that runs off its end spins in place.
// Same ports as the synthesizable imem.v so the core does not change.
module imem (
    input  wire [31:0] addr,
    output wire [31:0] inst
);
    reg [31:0] mem [0:63];
    reg [1023:0] hexfile;
    integer i;

    initial begin
        for (i = 0; i < 64; i = i + 1) mem[i] = 32'h00000063;
        if (!$value$plusargs("prog=%s", hexfile)) begin
            $display("FAIL: +prog=<hexfile> not given");
            $finish;
        end
        $readmemh(hexfile, mem);
    end

    assign inst = mem[addr[7:2]];
endmodule
