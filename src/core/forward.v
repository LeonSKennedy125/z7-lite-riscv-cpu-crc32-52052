`timescale 1ns / 1ps
`include "riscv_define.vh"

module EX_Forward(
	input [4:0]id_rs1,
	input [4:0]id_rs2,
	input [4:0]ex_wb_addr,
	input [3:0]instr_type,
    input wb_en, // Valid producer, independent of a held WB commit pulse.
	
	output wire ex_Forward_en1,
	output wire ex_Forward_en2,
	output wire [1:0]ex_Forward_SEL1,
	output wire stall,
	output wire flush3
    );
    
    wire stall_wire;
    
    //rs1
    assign ex_Forward_en1 = (wb_en && ex_wb_addr != 5'b0 && ex_wb_addr == id_rs1) ? 1'b1 : 1'b0;
    //rs2
    assign ex_Forward_en2 = (wb_en && ex_wb_addr != 5'b0 && ex_wb_addr == id_rs2) ? 1'b1 : 1'b0;
    //前递数据选择
    assign ex_Forward_SEL1 = (instr_type == `TYPE_LW) ? `FW_Load :
    			     (instr_type == `TYPE_JAL || instr_type == `TYPE_JALR) ? `FW_Pc4 : 
    			     (instr_type == `TYPE_CSR) ? `FW_CSR : `FW_Aluout;
    			     
    assign stall_wire = ({instr_type,ex_Forward_en1} == 5'b10001) ? 1'b1 :
    		   ({instr_type,ex_Forward_en2} == 5'b10001) ? 1'b1 : 1'b0;
    		   
    assign stall = stall_wire;
    assign flush3 = stall_wire;
    
endmodule
