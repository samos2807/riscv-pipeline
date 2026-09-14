module regfile (
    input wire              clk,
    input wire              we3, // Enable to write
    input wire [4:0]        a1,
    input wire [4:0]        a2,
    input wire [4:0]        a3, // Addres to write
    input wire [31:0]       wd3, // Write data
    output wire [31:0]      rd1,
    output wire [31:0]      rd2          
);
    reg [31:0] rf [0:31] ;
    // Write logic
    always @(posedge clk) begin
        if (we3 && (a3 != 5'b0)) begin // Write if En is high and  target is not register 0
            rf[a3] <= wd3;
        end
    end

    // Read logic with write-first bypass
    // When WB writes and ID reads the same register in the same cycle,
    // the read gets the new (written) value
    assign rd1 = (a1 == 5'b0) ? 32'b0 :
                 (we3 && a3 == a1) ? wd3 : rf[a1];
    assign rd2 = (a2 == 5'b0) ? 32'b0 :
                 (we3 && a3 == a2) ? wd3 : rf[a2];
endmodule