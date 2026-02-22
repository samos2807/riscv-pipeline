
module alu (
    input wire [31:0] a,
    input wire [31:0] b, 
    input wire [3:0] alu_ctrl,
    output reg [31:0] result,
    output wire zero
);




always @(*) begin
    case (alu_ctrl)
        4'b0000: result = a + b;
        4'b1000: result = a - b;
        4'b0111: result = a & b;
        4'b0110: result = a | b;
        4'b0101: result = ~a;
        default: result = 32'b0; 
    endcase
end

assign zero = (result ==32'b0) ? 1'b1 : 1'b0;
    
endmodule