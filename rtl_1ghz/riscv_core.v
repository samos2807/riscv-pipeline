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
wire [31:0] id_ex_pc_plus_4;
wire        ex_mispredict;
wire [31:0] ex_correct_pc;

// --- Static branch prediction (backward-taken), computed in ID ---
wire        id_is_branch;
wire        id_pred_taken;
wire [31:0] id_pred_target;

// --- MEM Stage ---
wire [31:0] mem_read_data;

// --- WB Stage ---
wire [31:0] wb_data;

// --- Forwarding ---
// Fix A: the selects are computed in ID and REGISTERED into ID/EX, so the
// rd comparators are no longer in the EX critical path.
wire [1:0]  next_forward_a;
wire [1:0]  next_forward_b;

// --- Hazard / Control ---
wire        stall_raw;     // raw hazard-unit output
wire        stall;         // suppressed while a redirect is in flight
wire        flush_if_id;   // squash the wrongly-fetched successor
wire        flush_id_ex;   // kill the instruction in ID
wire        flush_ex_mem;  // Fix B: kill the instruction in EX when a
                           //        registered redirect lands

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
reg         id_ex_pred_taken;
// Data
reg  [31:0] id_ex_pc;
reg  [31:0] id_ex_rd1;
reg  [31:0] id_ex_rd2;
reg  [31:0] id_ex_imm;
// Register addresses (for forwarding)
reg  [4:0]  id_ex_rs1;
reg  [4:0]  id_ex_rs2;
reg  [4:0]  id_ex_rd;
reg  [1:0]  id_ex_forward_a;
reg  [1:0]  id_ex_forward_b;
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
// Fix B: the branch redirect is registered here, cutting alu_zero -> PC.
reg         ex_mem_redirect;
reg  [31:0] ex_mem_redirect_pc;

// ----- MEM/WB -----
// Control
reg         mem_wb_reg_write;
// Data
reg  [31:0] mem_wb_wb_data;    // Fix C: write-back value, already selected in MEM
reg  [4:0]  mem_wb_rd;

// =============================================
// IF Stage
// =============================================
assign pc_plus_4 = pc_current + 32'd4;
// Redirect priority: a pending recovery always wins, because the ID
// instruction that produced id_pred_taken is itself being flushed.
// Fix B: the recovery address comes from a register, so nothing on the
// alu_zero -> PC path remains combinational.
assign pc_next   = ex_mem_redirect ? ex_mem_redirect_pc :
                   id_pred_taken   ? id_pred_target     :
                                     pc_plus_4;

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
    end else if (flush_if_id) begin
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
    .stall         (stall_raw)
);

// ---------------------------------------------------------------------
//  Static branch prediction: backward taken, forward not taken.
//
//  Everything here is driven from IF/ID register outputs, so the whole
//  predictor sits in parallel with the register-file read and never
//  touches the ALU, the forwarding muxes, or alu_zero.
//
//  imm_ext[31] is the branch displacement's sign bit, so it identifies a
//  backward branch directly -- no extra comparison needed.
//
//  Gated with ~stall: while a load-use interlock holds IF/ID, the branch
//  must stay put and must not redirect the PC or squash itself.
// ---------------------------------------------------------------------
// While a redirect is in flight everything in ID/EX is being killed, so the
// load-use interlock must not hold the PC and block the recovery fetch.
assign stall = stall_raw & ~ex_mem_redirect;

assign id_is_branch   = (opcode == 7'b1100011);
assign id_pred_target = if_id_pc + imm_ext;
assign id_pred_taken  = id_is_branch & imm_ext[31] & ~stall;

// A correctly predicted taken branch still costs one bubble: the successor
// was already fetched by the time ID decoded the branch.
assign flush_if_id    = ex_mem_redirect | id_pred_taken;
assign flush_id_ex    = ex_mem_redirect;
assign flush_ex_mem   = ex_mem_redirect;

// Fix A: selects for the instruction that will be in EX next cycle.
// Next cycle EX/MEM is this cycle ID/EX, and next cycle MEM/WB is this
// cycle EX/MEM, so the same EX-over-MEM priority order is preserved.
forwarding_unit u_forwarding (
    .rs1             (rs1),
    .rs2             (rs2),
    .id_ex_rd        (id_ex_rd),
    .id_ex_reg_write (id_ex_reg_write),
    .ex_mem_rd       (ex_mem_rd),
    .ex_mem_reg_write(ex_mem_reg_write),
    .next_forward_a  (next_forward_a),
    .next_forward_b  (next_forward_b)
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
        id_ex_pred_taken<= 1'b0;
        id_ex_pc        <= 32'b0;
        id_ex_rd1       <= 32'b0;
        id_ex_rd2       <= 32'b0;
        id_ex_imm       <= 32'b0;
        id_ex_rs1       <= 5'b0;
        id_ex_rs2       <= 5'b0;
        id_ex_rd        <= 5'b0;
        id_ex_forward_a <= 2'b00;
        id_ex_forward_b <= 2'b00;
        id_ex_funct3    <= 3'b0;
        id_ex_funct7_5  <= 1'b0;
        id_ex_op_5      <= 1'b0;
    end else if (flush_id_ex || stall) begin
        // Insert bubble: zero all control signals
        id_ex_reg_write <= 1'b0;
        id_ex_mem_to_reg<= 1'b0;
        id_ex_mem_write <= 1'b0;
        id_ex_branch    <= 1'b0;
        id_ex_alu_src   <= 1'b0;
        id_ex_alu_op    <= 2'b00;
        id_ex_pred_taken<= 1'b0;
        id_ex_pc        <= 32'b0;
        id_ex_rd1       <= 32'b0;
        id_ex_rd2       <= 32'b0;
        id_ex_imm       <= 32'b0;
        id_ex_rs1       <= 5'b0;
        id_ex_rs2       <= 5'b0;
        id_ex_rd        <= 5'b0;
        id_ex_forward_a <= 2'b00;
        id_ex_forward_b <= 2'b00;
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
        id_ex_pred_taken<= id_pred_taken;
        id_ex_pc        <= if_id_pc;
        id_ex_rd1       <= reg_rd1;
        id_ex_rd2       <= reg_rd2;
        id_ex_imm       <= imm_ext;
        id_ex_rs1       <= rs1;
        id_ex_rs2       <= rs2;
        id_ex_rd        <= rd;
        id_ex_forward_a <= next_forward_a;
        id_ex_forward_b <= next_forward_b;
        id_ex_funct3    <= funct3;
        id_ex_funct7_5  <= funct7[5];
        id_ex_op_5      <= opcode[5];
    end
end

// =============================================
// EX Stage
// =============================================

// Forwarding muxes
assign alu_input_a = (id_ex_forward_a == 2'b10) ? ex_mem_alu_result :
                     (id_ex_forward_a == 2'b01) ? wb_data :
                     id_ex_rd1;

assign forwarded_rs2 = (id_ex_forward_b == 2'b10) ? ex_mem_alu_result :
                        (id_ex_forward_b == 2'b01) ? wb_data :
                        id_ex_rd2;

// ALU source mux: immediate or forwarded rs2
assign alu_input_b = id_ex_alu_src ? id_ex_imm : forwarded_rs2;

// Branch target and decision
assign branch_target   = id_ex_pc + id_ex_imm;
assign id_ex_pc_plus_4 = id_ex_pc + 32'd4;

// Recovery address. The select is id_ex_pred_taken -- a REGISTERED signal --
// so this mux resolves early and stays off the alu_zero path:
//   predicted taken, actually not taken -> fall through to pc+4
//   predicted not taken, actually taken -> go to the branch target
assign ex_correct_pc   = id_ex_pred_taken ? id_ex_pc_plus_4 : branch_target;

// Only the misprediction signal itself is late off alu_zero, and it now
// ends at a register (Fix B) rather than driving the PC mux directly.
// Suppressed while an older redirect is landing: the instruction in EX is
// wrong-path and must not raise a second, competing redirect.
assign ex_mispredict   = id_ex_branch & (alu_zero ^ id_ex_pred_taken)
                                      & ~ex_mem_redirect;

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

// Test output
assign alu_out_test = ex_mem_alu_result;   // Fix D: observe the EX/MEM flop (same value, 1 cycle later) so the pin is a flop-to-port path, not the raw ALU output

// =============================================
// EX/MEM Pipeline Register
// =============================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ex_mem_reg_write   <= 1'b0;
        ex_mem_mem_to_reg  <= 1'b0;
        ex_mem_mem_write   <= 1'b0;
        ex_mem_alu_result  <= 32'b0;
        ex_mem_write_data  <= 32'b0;
        ex_mem_rd          <= 5'b0;
        ex_mem_redirect    <= 1'b0;
        ex_mem_redirect_pc <= 32'b0;
    end else begin
        // The redirect is recovery state, not pipeline payload, so it is
        // captured unconditionally; ex_mispredict is already suppressed
        // while an older redirect is landing.
        ex_mem_redirect    <= ex_mispredict;
        ex_mem_redirect_pc <= ex_correct_pc;

        if (flush_ex_mem) begin
            // The instruction in EX this cycle is wrong-path. Killing it
            // here is what makes the registered redirect cost 3 cycles
            // rather than 2 -- in particular it stops a wrong-path store.
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
        mem_wb_wb_data    <= 32'b0;
        mem_wb_rd         <= 5'b0;
    end else begin
        mem_wb_reg_write  <= ex_mem_reg_write;
        // Fix C: choose the write-back value here, in MEM, instead of in WB.
        // MEM/WB then holds the final value, so the EX forwarding muxes, the
        // register-file write port and its write-first bypass all see a flop
        // output rather than a mux fed by mem_wb_mem_to_reg. This also drops
        // 32 flops (one data register instead of two) and the mem_to_reg flop.
        mem_wb_wb_data    <= ex_mem_mem_to_reg ? mem_read_data : ex_mem_alu_result;
        mem_wb_rd         <= ex_mem_rd;
    end
end

// =============================================
// WB Stage
// =============================================
assign wb_data = mem_wb_wb_data;   // Fix C: no mux in WB

endmodule
