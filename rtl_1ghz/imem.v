module imem (
input wire [31:0] addr,
output reg [31:0] inst
);

always @(*) begin
`ifdef LOOP_PROG
    // -----------------------------------------------------------------
    //  Backward-branch loop, for exercising the static predictor.
    //  Select with -d LOOP_PROG.
    //    0x00 addi x1,x0,0
    //    0x04 addi x2,x0,20
    //    0x08 beq  x1,x2,+12   forward  -> predicted not taken
    //    0x0c addi x1,x1,1
    //    0x10 beq  x0,x0,-8    backward -> predicted taken
    //    0x14 nop
    //    0x18 addi x3,x0,1
    //  Expected: x1=20, x2=20, x3=1, 23 retirement events.
    // -----------------------------------------------------------------
    case (addr[7:2])
        6'd0:  inst = 32'h00000093;  // addi x1, x0, 0
        6'd1:  inst = 32'h01400113;  // addi x2, x0, 20
        6'd2:  inst = 32'h00208663;  // beq  x1, x2, +12
        6'd3:  inst = 32'h00108093;  // addi x1, x1, 1
        6'd4:  inst = 32'hfe000ce3;  // beq  x0, x0, -8
        6'd5:  inst = 32'h00000013;  // nop
        6'd6:  inst = 32'h00100193;  // addi x3, x0, 1
        6'd7:  inst = 32'h00000063;  // beq  x0, x0, 0   (halt: spin here, prevents imem wrap)
        default: inst = 32'h00000013; // NOP
    endcase
`else
    case (addr[7:2])
        6'd0:  inst = 32'h00500093;  // addi x1, x0, 5
        6'd1:  inst = 32'h00308113;  // addi x2, x1, 3
        6'd2:  inst = 32'h00700193;  // addi x3, x0, 7
        6'd3:  inst = 32'h00000013;  // nop
        6'd4:  inst = 32'h00118233;  // add  x4, x3, x1
        6'd5:  inst = 32'h00102023;  // sw   x1, 0(x0)
        6'd6:  inst = 32'h00002283;  // lw   x5, 0(x0)
        6'd7:  inst = 32'h00228333;  // add  x6, x5, x2
        6'd8:  inst = 32'h06300393;  // addi x7, x0, 99
        6'd9:  inst = 32'h00208463;  // beq  x1, x2, +8
        6'd10: inst = 32'h02a00413;  // addi x8, x0, 42
        6'd11: inst = 32'h00000463;  // beq  x0, x0, +8
        6'd12: inst = 32'h04d00493;  // addi x9, x0, 77 (FLUSHED)
        6'd13: inst = 32'h00100513;  // addi x10, x0, 1
        6'd14: inst = 32'h00000063;  // beq  x0, x0, 0   (halt: spin here, prevents imem wrap)
        default: inst = 32'h00000013; // NOP
    endcase
`endif
end

endmodule
