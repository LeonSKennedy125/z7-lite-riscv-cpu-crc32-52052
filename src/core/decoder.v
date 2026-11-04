`timescale 1ns / 1ps
`include "riscv_define.vh"


module Decoder (
    input  [31:0] id_instr,       // 指令
    
    output [4:0]r1_addr,   // 输出：rs1地址
    output [4:0]r2_addr,   // 输出：rs2地址
    output [4:0]w_addr,    // 输出：rd地址
    output [6:0]opcode,     // 输出：操作码
    output [2:0]func3,     // 输出：功能码3
    output [6:0]func7,     // 输出：功能码7
    output [11:0]func12,   // 输出：功能码12
    output [3:0]instr_TYPE, //指令类型 
    output instr_valid,
    output [4:0]csr_imm,
    output [11:0]csr_addr
);

//提取固定字段
	assign opcode = id_instr[6:0];
	assign func3 = id_instr[14:12];
	assign func7 = id_instr[31:25];

//判断指令类型
	wire R_type = (opcode == 7'b0110011);
	wire I_type  = (opcode == 7'b0010011) || (opcode == 7'b0000011) || (opcode == 7'b1100111);
	wire S_type = (opcode == 7'b0100011);
	wire B_type = (opcode == 7'b1100011);
	wire J_type = (opcode == 7'b1101111);
	wire U_type = (opcode == 7'b0110111) || (opcode == 7'b0010111);
	wire JALR_type = (opcode == 7'b1100111);
	wire AUIPC_type = (opcode == 7'b0010111);
	wire i_type = (opcode == 7'b0010011);
	wire LW_type = (opcode == 7'b0000011);
	wire LUI_type = (opcode == 7'b0110111);
	wire SYS_type = (opcode == 7'b1110011);  // 系统类指令总入口
	wire CSR_type = SYS_type & (func3 != 3'b000);  // func3≠000是CSR指令
	wire EM_type = SYS_type & (func3 == 3'b000);  // func3=000是ECALL/EBREAK/MRET

//提取rs1/rs2/rd地址（按指令类型）
	assign r1_addr = (R_type || I_type || S_type || B_type || (CSR_type && !func3[2]) || JALR_type) ? id_instr[19:15] : 5'b0;
	assign r2_addr = (R_type || S_type || B_type) ? id_instr[24:20] : 5'b0;
	assign w_addr  = (R_type || I_type || J_type || U_type || CSR_type || JALR_type) ? id_instr[11:7] : 5'b0;
	assign func12 = (EM_type) ? id_instr[31:20] : 12'b0;
	assign csr_addr = (CSR_type) ? id_instr[31:20] : 12'b0;
	assign csr_imm = (CSR_type) ? id_instr[19:15] : 5'b0;
	
	assign instr_TYPE = (B_type) ? `TYPE_B : 
			    (J_type) ? `TYPE_JAL :
			    (JALR_type) ? `TYPE_JALR :
			    (AUIPC_type) ? `TYPE_AUIPC :
			    (R_type) ? `TYPE_R :
			    (S_type) ? `TYPE_S :
			    (i_type) ? `TYPE_I :
			    (LUI_type) ? `TYPE_LUI : 
			    (CSR_type) ? `TYPE_CSR :
			    (EM_type) ? `TYPE_EM : `TYPE_LW;
			    
	
// Cleared IF/ID instructions are bubbles; no new illegal-instruction trap.
assign instr_valid = (id_instr != 32'b0);
endmodule