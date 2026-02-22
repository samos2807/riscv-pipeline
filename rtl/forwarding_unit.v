module forwarding_unit (
    input wire [4:0] id_ex_rs1,
    input wire [4:0] id_ex_rs2,
    input wire [4:0] ex_mem_rd,
    input wire       ex_mem_reg_write,
    input wire [4:0] mem_wb_rd,
    input wire       mem_wb_reg_write,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

// forward_a / forward_b encoding:
// 2'b00 = no forwarding (use register file value from ID/EX)
// 2'b10 = forward from EX/MEM  (ALU result, 1 instr ahead)
// 2'b01 = forward from MEM/WB  (write-back data, 2 instr ahead)

always @(*) begin
    // Default: no forwarding
    forward_a = 2'b00;
    forward_b = 2'b00;

    // ---- Forward A (rs1 -> ALU input A) ----
    // EX hazard has priority over MEM hazard
    if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1))
        forward_a = 2'b10;
    else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1))
        forward_a = 2'b01;

    // ---- Forward B (rs2 -> ALU input B / store data) ----
    if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2))
        forward_b = 2'b10;
    else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2))
        forward_b = 2'b01;
end

endmodule
