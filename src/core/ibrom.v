`timescale 1ns / 1ps
`include "riscv_define.vh"

module IBROM(
	input clk,
	input rst,
	input stall,
    input flush,
    input csr_flush,
	input [31:0] pc,
	input [31:0] pc4,
	
	output [31:0]instr_o,
	output [31:0]pc_o,
	output [31:0]pc4_o
    );
    
    wire [11:0] pc_in = pc[13:2];
    wire en = rst && !stall;
    wire [31:0] instr_raw;
    reg fetched_valid;
    // A retained BRAM output must not enter ID after a warm reset.
    always @(posedge clk) begin
        if (!rst) fetched_valid <= 1'b0;
        else if ((flush || csr_flush) && stall) fetched_valid <= 1'b0;
        else if (en) fetched_valid <= 1'b1;
    end
    assign instr_o = fetched_valid ? instr_raw : 32'b0;
    
    reg [31:0] reg_pc_o;
    reg [31:0] reg_pc4_o;
    
    I_ROM u_I_ROM (
    	.addra(pc_in),
    	.clka(clk),
    	.douta(instr_raw),
    	.ena(en)
    );
    
    always @ (posedge clk) begin
    	if (!rst) begin
    		reg_pc_o <= 32'h80000000;
    		reg_pc4_o <= 32'h80000004;
    	end
    	else if (stall) begin
    		reg_pc_o <= reg_pc_o;
    		reg_pc4_o <= reg_pc4_o;
    	end
    	else begin
    		reg_pc_o <= pc;
    		reg_pc4_o <= pc4;
    	end
    end
    
    assign pc_o = reg_pc_o;
    assign pc4_o = reg_pc4_o;
    
endmodule
