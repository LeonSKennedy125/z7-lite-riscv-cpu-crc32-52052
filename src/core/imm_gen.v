`timescale 1ns / 1ps
`include "riscv_define.vh"


module imm_gen(
	input [31:0]id_instr,	//id阶段指令
	input [3:0]instr_TYPE,	//立即数拓展控制
	output [31:0]Imm	//立即数输出
    );
    
    wire [31:0]Imm_I;
    wire [31:0]Imm_R;
    wire [31:0]Imm_U;
    wire [31:0]Imm_J;
    wire [31:0]Imm_B;
    wire [31:0]Imm_S;
    
    assign Imm_R = 32'b0; 
    assign Imm_I = {{20{id_instr[31]}}, id_instr[31:20]};
    assign Imm_U = {id_instr[31:12], 12'b0};
    assign Imm_S = {{20{id_instr[31]}}, id_instr[31:25], id_instr[11:7]};
    assign Imm_J = {{12{id_instr[31]}}, id_instr[19:12], id_instr[20], id_instr[30:21], 1'b0};
    assign Imm_B = {{20{id_instr[31]}}, id_instr[7], id_instr[30:25], id_instr[11:8], 1'b0};
    
    assign Imm = (instr_TYPE == `TYPE_I || instr_TYPE == `TYPE_JALR || instr_TYPE == `TYPE_LW) ? Imm_I :
    		 (instr_TYPE == `TYPE_LUI || instr_TYPE == `TYPE_AUIPC) ? Imm_U :
    		 (instr_TYPE == `TYPE_JAL) ? Imm_J :
    		 (instr_TYPE == `TYPE_S) ? Imm_S :
    		 (instr_TYPE == `TYPE_R) ? Imm_R : Imm_B;
    
endmodule
