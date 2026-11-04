`timescale 1ns / 1ps
`include "riscv_define.vh"

module EX_MUX(
	input [31:0]DATA1,
	input [31:0]DATA2,
	input [31:0]Imm,
	input [31:0]pc,
	input CTRL,
	input Forward_en1,
	input Forward_en2,
	input [31:0]Forward_Data1,
	input [31:0]Forward_Data2,
	input [3:0]instr_TYPE,
	input [1:0]reuse,
	
	
	output [31:0]ALU_A,
	output [31:0]ALU_B,
	output [31:0]Comp_A,
	output [31:0]Comp_B,
	output [31:0]D2
);
    
    	wire [31:0]final_D1;
    	wire [31:0]final_D2;
    
    	assign final_D1 = (Forward_en1) ? Forward_Data1 : DATA1;
    	assign final_D2 = (Forward_en2) ? Forward_Data2 : DATA2;
    	
    	assign ALU_A = ((instr_TYPE == `TYPE_JAL) || (instr_TYPE == `TYPE_AUIPC) || (instr_TYPE == `TYPE_B)) ? pc : final_D1;
    	assign ALU_B = (instr_TYPE == `TYPE_R) ? final_D2 : Imm;
    	
    	assign Comp_A = (instr_TYPE == `TYPE_B || reuse == `SLTR || reuse == `SLTI) ? final_D1 : 32'b0;  //复用处理SLT/SLTU/SLTI/SLTUI
    	assign Comp_B = (instr_TYPE == `TYPE_B || reuse == `SLTR) ? final_D2 :
    			(reuse == `SLTI) ? Imm : 32'b0;
    			
    	assign D2 = (Forward_en2) ? Forward_Data2 : DATA2;
    	
endmodule
