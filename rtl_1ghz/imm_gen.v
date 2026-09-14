module imm_gen (
    input wire          [31:0] inst,
    output reg          [31:0] imm
);

wire [6:0] opcode = inst[6:0]; //command type


always @(*) begin
    case (opcode)
        7'b0010011, //addi
        7'b0000011: //Load
        imm = {{20{inst[31]}}, inst[31:20]};

        7'b0100011:
        imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};

        7'b1100011: 
        imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};

        7'b1100111: // Jump
        imm = {{20{inst[31]}}, inst[31:20]};

        default: imm = 32'b0;
    endcase
end   
endmodule