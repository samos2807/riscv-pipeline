// ============================================================
// RISC-V 5-Stage Pipelined Processor
// Stages: IF -> ID -> EX -> MEM -> WB
// Features: Data Forwarding, Load-Use Hazard Detection (Stall),
//           Branch resolution in EX stage (2-cycle penalty)
// ============================================================
module riscv_core (
    input wire          clk,
    input wire          rst_n,
    input wire  [31:0]  instr_in,
    output wire [31:0]  pc_out,
    output wire [31:0]  alu_out_test
);

// =============================================
// Wire / Signal Declarations
// =============================================

// --- IF Stage ---
wire [31:0] pc_current;
wire [31:0] pc_next;
wire [31:0] pc_plus_4;
wire [31:0] instruction;

// --- ID Stage (decoder / controller / regfile / imm_gen outputs) ---
wire [6:0]  opcode;
wire [4:0]  rd;
wire [2:0]  funct3;
wire [4:0]  rs1;
wire [4:0]  rs2;
wire [6:0]  funct7;

wire [31:0] reg_rd1;
wire [31:0] reg_rd2;
wire [31:0] imm_ext;

wire        reg_write_en;
wire        alu_src;
wire        mem_write;
wire        mem_to_reg;
wire        branch;
wire [1:0]  alu_op;

// --- EX Stage ---
wire [3:0]  alu_ctrl;
wire [31:0] alu_result;
wire        alu_zero;
wire [31:0] alu_input_a;
wire [31:0] alu_input_b;
wire [31:0] forwarded_rs2;
wire [31:0] branch_target;
wire        branch_taken;

// --- MEM Stage ---
wire [31:0] mem_read_data;

// --- WB Stage ---
wire [31:0] wb_data;

// --- Forwarding ---
wire [1:0]  forward_a;
wire [1:0]  forward_b;

// --- Hazard / Control ---
wire        stall;
wire        flush;

// =============================================
// Pipeline Registers
// =============================================

// ----- IF/ID -----
reg [31:0]  if_id_pc;
reg [31:0]  if_id_instr;

// ----- ID/EX -----
// Control
reg         id_ex_reg_write;
reg         id_ex_mem_to_reg;
reg         id_ex_mem_write;
reg         id_ex_branch;
reg         id_ex_alu_src;
reg  [1:0]  id_ex_alu_op;
// Data
reg  [31:0] id_ex_pc;
reg  [31:0] id_ex_rd1;
reg  [31:0] id_ex_rd2;
reg  [31:0] id_ex_imm;
// Register addresses (for forwarding)
reg  [4:0]  id_ex_rs1;
reg  [4:0]  id_ex_rs2;
reg  [4:0]  id_ex_rd;
// ALU decoder fields
reg  [2:0]  id_ex_funct3;
reg         id_ex_funct7_5;
reg         id_ex_op_5;

// ----- EX/MEM -----
// Control
reg         ex_mem_reg_write;
reg         ex_mem_mem_to_reg;
reg         ex_mem_mem_write;
// Data
reg  [31:0] ex_mem_alu_result;
reg  [31:0] ex_mem_write_data;
reg  [4:0]  ex_mem_rd;

// ----- MEM/WB -----
// Control
reg         mem_wb_reg_write;
reg         mem_wb_mem_to_reg;
// Data
reg  [31:0] mem_wb_alu_result;
reg  [31:0] mem_wb_mem_data;
reg  [4:0]  mem_wb_rd;

// =============================================
// IF Stage
// =============================================
assign pc_plus_4 = pc_current + 32'd4;
assign pc_next   = branch_taken ? branch_target : pc_plus_4;

pc u_pc (
    .clk   (clk),
    .rst_n (rst_n),
    .en    (~stall),
    .pc_in (pc_next),
    .pc_out(pc_current)
);

assign instruction = instr_in;
assign pc_out      = pc_current;

// =============================================
// IF/ID Pipeline Register
// =============================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        if_id_pc    <= 32'b0;
        if_id_instr <= 32'h00000013; // NOP
    end else if (flush) begin
        if_id_pc    <= 32'b0;
        if_id_instr <= 32'h00000013; // NOP
    end else if (!stall) begin
        if_id_pc    <= pc_current;
        if_id_instr <= instruction;
    end
    // stall: hold current values
end

// =============================================
// ID Stage
// =============================================
decoder u_decoder (
    .inst  (if_id_instr),
    .opcode(opcode),
    .rd    (rd),
    .funct3(funct3),
    .rs1   (rs1),
    .rs2   (rs2),
    .funct7(funct7)
);

controller u_controller (
    .opcode   (opcode),
    .reg_write(reg_write_en),
    .alu_src  (alu_src),
    .mem_write(mem_write),
    .mem_to_reg(mem_to_reg),
    .branch   (branch),
    .alu_op   (alu_op)
);

regfile u_regfile (
    .clk(clk),
    .we3(mem_wb_reg_write),   // write from WB stage
    .a1 (rs1),
    .a2 (rs2),
    .a3 (mem_wb_rd),          // write-back destination
    .wd3(wb_data),            // write-back data
    .rd1(reg_rd1),
    .rd2(reg_rd2)
);

imm_gen u_imm_gen (
    .inst(if_id_instr),
    .imm (imm_ext)
);

// Hazard Detection Unit
hazard_detection_unit u_hazard (
    .if_id_rs1     (rs1),
    .if_id_rs2     (rs2),
    .id_ex_rd      (id_ex_rd),
    .id_ex_mem_to_reg(id_ex_mem_to_reg),
    .stall         (stall)
);

// =============================================
// ID/EX Pipeline Register
// =============================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        id_ex_reg_write <= 1'b0;
        id_ex_mem_to_reg<= 1'b0;
        id_ex_mem_write <= 1'b0;
        id_ex_branch    <= 1'b0;
        id_ex_alu_src   <= 1'b0;
        id_ex_alu_op    <= 2'b00;
        id_ex_pc        <= 32'b0;
        id_ex_rd1       <= 32'b0;
        id_ex_rd2       <= 32'b0;
        id_ex_imm       <= 32'b0;
        id_ex_rs1       <= 5'b0;
        id_ex_rs2       <= 5'b0;
        id_ex_rd        <= 5'b0;
        id_ex_funct3    <= 3'b0;
        id_ex_funct7_5  <= 1'b0;
        id_ex_op_5      <= 1'b0;
    end else if (flush || stall) begin
        // Insert bubble: zero all control signals
        id_ex_reg_write <= 1'b0;
        id_ex_mem_to_reg<= 1'b0;
        id_ex_mem_write <= 1'b0;
        id_ex_branch    <= 1'b0;
        id_ex_alu_src   <= 1'b0;
        id_ex_alu_op    <= 2'b00;
        id_ex_pc        <= 32'b0;
        id_ex_rd1       <= 32'b0;
        id_ex_rd2       <= 32'b0;
        id_ex_imm       <= 32'b0;
        id_ex_rs1       <= 5'b0;
        id_ex_rs2       <= 5'b0;
        id_ex_rd        <= 5'b0;
        id_ex_funct3    <= 3'b0;
        id_ex_funct7_5  <= 1'b0;
        id_ex_op_5      <= 1'b0;
    end else begin
        id_ex_reg_write <= reg_write_en;
        id_ex_mem_to_reg<= mem_to_reg;
        id_ex_mem_write <= mem_write;
        id_ex_branch    <= branch;
        id_ex_alu_src   <= alu_src;
        id_ex_alu_op    <= alu_op;
        id_ex_pc        <= if_id_pc;
        id_ex_rd1       <= reg_rd1;
        id_ex_rd2       <= reg_rd2;
        id_ex_imm       <= imm_ext;
        id_ex_rs1       <= rs1;
        id_ex_rs2       <= rs2;
        id_ex_rd        <= rd;
        id_ex_funct3    <= funct3;
        id_ex_funct7_5  <= funct7[5];
        id_ex_op_5      <= opcode[5];
    end
end

// =============================================
// EX Stage
// =============================================

// Forwarding muxes
assign alu_input_a = (forward_a == 2'b10) ? ex_mem_alu_result :
                     (forward_a == 2'b01) ? wb_data :
                     id_ex_rd1;

assign forwarded_rs2 = (forward_b == 2'b10) ? ex_mem_alu_result :
                        (forward_b == 2'b01) ? wb_data :
                        id_ex_rd2;

// ALU source mux: immediate or forwarded rs2
assign alu_input_b = id_ex_alu_src ? id_ex_imm : forwarded_rs2;

// Branch target and decision
assign branch_target = id_ex_pc + id_ex_imm;
assign branch_taken  = id_ex_branch & alu_zero;
assign flush         = branch_taken;

// ALU Decoder
alu_decoder u_alu_decoder (
    .op_5    (id_ex_op_5),
    .funct3  (id_ex_funct3),
    .funct7_5(id_ex_funct7_5),
    .alu_op  (id_ex_alu_op),
    .alu_ctrl(alu_ctrl)
);

// ALU
alu u_alu (
    .a       (alu_input_a),
    .b       (alu_input_b),
    .alu_ctrl(alu_ctrl),
    .result  (alu_result),
    .zero    (alu_zero)
);

// Forwarding Unit
forwarding_unit u_forwarding (
    .id_ex_rs1      (id_ex_rs1),
    .id_ex_rs2      (id_ex_rs2),
    .ex_mem_rd      (ex_mem_rd),
    .ex_mem_reg_write(ex_mem_reg_write),
    .mem_wb_rd      (mem_wb_rd),
    .mem_wb_reg_write(mem_wb_reg_write),
    .forward_a      (forward_a),
    .forward_b      (forward_b)
);

// Test output
assign alu_out_test = alu_result;

// =============================================
// EX/MEM Pipeline Register
// =============================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ex_mem_reg_write  <= 1'b0;
        ex_mem_mem_to_reg <= 1'b0;
        ex_mem_mem_write  <= 1'b0;
        ex_mem_alu_result <= 32'b0;
        ex_mem_write_data <= 32'b0;
        ex_mem_rd         <= 5'b0;
    end else begin
        ex_mem_reg_write  <= id_ex_reg_write;
        ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        ex_mem_mem_write  <= id_ex_mem_write;
        ex_mem_alu_result <= alu_result;
        ex_mem_write_data <= forwarded_rs2;
        ex_mem_rd         <= id_ex_rd;
    end
end

// =============================================
// MEM Stage
// =============================================
dmem u_dmem (
    .clk(clk),
    .we (ex_mem_mem_write),
    .a  (ex_mem_alu_result),
    .wd (ex_mem_write_data),
    .rd (mem_read_data)
);

// =============================================
// MEM/WB Pipeline Register
// =============================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_wb_reg_write  <= 1'b0;
        mem_wb_mem_to_reg <= 1'b0;
        mem_wb_alu_result <= 32'b0;
        mem_wb_mem_data   <= 32'b0;
        mem_wb_rd         <= 5'b0;
    end else begin
        mem_wb_reg_write  <= ex_mem_reg_write;
        mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
        mem_wb_alu_result <= ex_mem_alu_result;
        mem_wb_mem_data   <= mem_read_data;
        mem_wb_rd         <= ex_mem_rd;
    end
end

// =============================================
// WB Stage
// =============================================
assign wb_data = mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result;

endmodule
