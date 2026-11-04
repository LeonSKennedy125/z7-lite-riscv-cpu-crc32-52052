`timescale 1ns / 1ps
`include "riscv_define.vh"

module pc_judge(
	input [31:0] pc_npc,
	input [31:0] pc_Predict,
	input [31:0] pc_Jump_Branch,
	input [31:0] pc_csr,
	input npc,
	input Pre,
	input J_B,
	input EM,
    input replay_redirect,
	
	output [31:0]pc_o,
	output [31:0]pc4_o
	
    );
    
    reg [31:0] reg_pc;
    
    always @ * begin
        reg_pc = 32'h80000000;
        if (J_B) reg_pc = pc_Jump_Branch;
        else if (EM) reg_pc = pc_csr;
        else if (replay_redirect) reg_pc = pc_npc;
        else if (Pre) reg_pc = pc_Predict;
        else if (npc) reg_pc = pc_npc;
    end
    
    assign pc_o = reg_pc;
    assign pc4_o = reg_pc + 32'd4;
    
endmodule
