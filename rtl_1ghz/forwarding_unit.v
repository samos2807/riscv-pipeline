module forwarding_unit (
    // Source registers of the instruction currently in ID -- the one that
    // will be in EX next cycle.
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    // ID/EX this cycle becomes EX/MEM next cycle
    input wire [4:0] id_ex_rd,
    input wire       id_ex_reg_write,
    // EX/MEM this cycle becomes MEM/WB next cycle
    input wire [4:0] ex_mem_rd,
    input wire       ex_mem_reg_write,
    output reg [1:0] next_forward_a,
    output reg [1:0] next_forward_b
);

// Fix A: this used to compare id_ex_rs1/rs2 against ex_mem_rd and mem_wb_rd
// combinationally inside EX, which put a 5-bit comparator and a priority
// encoder directly in front of the ALU -- the reason mem_wb_rd was the
// critical-path startpoint.
//
// The same decision can be made one cycle earlier, because the pipeline
// registers shift deterministically:
//     next EX/MEM == this ID/EX
//     next MEM/WB == this EX/MEM
// The result is registered into id_ex_forward_a/b, so in EX the select is
// already a flop output and only the forwarded DATA is combinational.
//
// EX-over-MEM priority is preserved: id_ex_* is tested before ex_mem_*.
//
// Bubbles need no special handling here -- when ID/EX takes a bubble the
// registered selects are zeroed along with the rest of the stage.

// next_forward_* encoding:
// 2'b00 = no forwarding (use the ID/EX register-file value)
// 2'b10 = forward from EX/MEM (ALU result, 1 instruction ahead)
// 2'b01 = forward from MEM/WB (write-back data, 2 instructions ahead)

always @(*) begin
    next_forward_a = 2'b00;
    next_forward_b = 2'b00;

    // ---- Forward A (rs1 -> ALU input A) ----
    if (id_ex_reg_write && (id_ex_rd != 5'b0) && (id_ex_rd == rs1))
        next_forward_a = 2'b10;
    else if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == rs1))
        next_forward_a = 2'b01;

    // ---- Forward B (rs2 -> ALU input B / store data) ----
    if (id_ex_reg_write && (id_ex_rd != 5'b0) && (id_ex_rd == rs2))
        next_forward_b = 2'b10;
    else if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == rs2))
        next_forward_b = 2'b01;
end

endmodule
