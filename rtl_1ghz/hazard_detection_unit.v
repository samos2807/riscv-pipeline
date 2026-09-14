module hazard_detection_unit (
    input wire [4:0] if_id_rs1,
    input wire [4:0] if_id_rs2,
    input wire [4:0] id_ex_rd,
    input wire       id_ex_mem_to_reg,
    output reg       stall
);

// Load-use hazard: a load instruction in EX stage (ID/EX) is followed
// by a dependent instruction in ID stage (IF/ID).
// Action: stall PC and IF/ID for 1 cycle, insert bubble into ID/EX.
// After the stall, forwarding from MEM/WB handles the data.

always @(*) begin
    if (id_ex_mem_to_reg && (id_ex_rd != 5'b0) &&
        ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)))
        stall = 1'b1;
    else
        stall = 1'b0;
end

endmodule
