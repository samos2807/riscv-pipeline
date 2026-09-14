module alu_decoder (
    input wire          op_5,
    input wire [2:0]    funct3,
    input wire          funct7_5,
    input wire [1:0]    alu_op,
    output reg [3:0]    alu_ctrl 
);


always @(*) begin
    case (alu_op)
        2'b01 : alu_ctrl = 4'b1000;

        default: begin
            case (funct3)
               3'b000 : begin
                if (alu_op == 2'b10 && funct7_5) 
                    alu_ctrl = 4'b1000;
                    else
                    alu_ctrl = 4'b0000;
                end

                3'b111 : alu_ctrl = 4'b0111;
                3'b110 : alu_ctrl = 4'b0110;
                3'b100 : alu_ctrl = 4'b0101;
                default: alu_ctrl = 4'b0000;
            endcase
        end
    endcase
end
    
endmodule