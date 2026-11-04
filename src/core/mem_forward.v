`timescale 1ns / 1ps
`include "riscv_define.vh"


module MEM_Forward(
	input [4:0]id_rs1,
	input [4:0]id_rs2,
	input [4:0]mem_wb_addr,
	input [3:0]instr_type,
    input wb_en, // Valid producer, independent of a held WB commit pulse.
	
	output wire mem_Forward_en1,
	output wire mem_Forward_en2,
	output wire [1:0]mem_Forward_SEL
    );
    //rs1
    assign mem_Forward_en1 = (wb_en && mem_wb_addr != 5'b0 && mem_wb_addr == id_rs1) ? 1'b1 : 1'b0;
    //rs2
    assign mem_Forward_en2 = (wb_en && mem_wb_addr != 5'b0 && mem_wb_addr == id_rs2) ? 1'b1 : 1'b0;
    
    //前递数据选择
    assign mem_Forward_SEL = (instr_type == `TYPE_LW) ? `FW_Load :
    			     (instr_type == `TYPE_JAL || instr_type == `TYPE_JALR) ? `FW_Pc4 : 
    			     (instr_type == `TYPE_CSR) ? `FW_CSR : `FW_Aluout;

endmodule
