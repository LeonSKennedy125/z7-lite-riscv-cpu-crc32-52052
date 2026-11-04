`timescale 1ns / 1ps
`include "riscv_define.vh"

module instr_minidecoder(
	input [31:0]instr,
	input [31:0]pc,
	
	output [31:0]pc_o,
	output Pre
    );
    
    reg [31:0]reg_pc;
    wire [31:0]b_imm_ext;
    wire [31:0]jal_imm_ext;
    wire [31:0]branch_predict;
    
    assign jal_imm_ext = {{12{instr[31]}},instr[19:12],instr[20],instr[30:21],1'b0};
    assign b_imm_ext = {{20{instr[31]}},instr[7],instr[30:25],instr[11:8],1'b0};
    					
    // Predict direction from the signed displacement, including address wrap.
    assign branch_predict = instr[31] ? pc + b_imm_ext : pc + 32'd4;
    
    assign Pre = (instr[6:0] == `OPCODE_B_TYPE) || (instr[6:0] == `OPCODE_JAL);
    
    always @ *
    	case (instr[6:0])
    		`OPCODE_B_TYPE: reg_pc = branch_predict;
    		`OPCODE_JAL: reg_pc = pc + jal_imm_ext;
    		default:reg_pc = pc;
    	endcase
    
    assign pc_o = reg_pc;
    
endmodule
