module pc # (
parameter RESET_ADDR = 32'h00000000
)
(
input wire          clk,
input wire          rst_n,
input wire          en,
input wire [31:0]   pc_in,
output reg [31:0]   pc_out
);

always @(posedge clk or negedge rst_n) begin
     if (!rst_n) begin
        pc_out <= RESET_ADDR;
     end else if (en) begin
        pc_out <= pc_in;
     end
end
endmodule
        
  