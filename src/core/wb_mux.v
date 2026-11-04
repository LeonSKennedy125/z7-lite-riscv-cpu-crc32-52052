`timescale 1ns / 1ps
`include "riscv_define.vh"

module WB_MUX(
	input [2:0]WB_CTRL,
	input [31:0]ALU_Out,
	input [31:0]Load_Out,
	input [31:0]WB_pc4,
	input [31:0]WB_CSR,
    input tri0 MEM_IO,
    input tri0 [31:0] WB_IO,
	input [4:0]rd_addr,
	
	output [31:0]Data
	
    );
    
    assign Data = (rd_addr == 5'b00000) ? 32'b0 : 
              (WB_CTRL == `WB_ALUOUT) ? ALU_Out :
    		  (WB_CTRL == `WB_LOAD) ? (MEM_IO ? WB_IO : Load_Out) :
    		  (WB_CTRL == `WB_PC4) ? WB_pc4 :
    		  (WB_CTRL == `WB_CSR) ? WB_CSR :
    		  32'b0;
    
endmodule
