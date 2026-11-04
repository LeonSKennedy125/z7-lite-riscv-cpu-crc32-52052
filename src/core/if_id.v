`timescale 1ns / 1ps
`include "riscv_define.vh"

module IF_ID(
	input clk,		//时钟
	input reset,		//复位
	input [31:0]instr,	//if指令
	input [31:0]pc,		//if地址
	input [31:0]pc4,	//if地址加四
	input flush,		//冲刷标志位
	input stall,		//阻塞标志位
	input stall_Load,
	input csr_fluah,
	
	output wire [31:0]id_instr,	//id指令
	output wire [31:0]id_pc,	//id地址
	output wire [31:0]id_pc4	//id地址加四
    );
    
    reg [31:0]reg_id_instr;
    reg [31:0]reg_id_pc;
    reg [31:0]reg_id_pc4;
    
    always @ (posedge clk or negedge reset) 
    	begin
    		if (!reset) begin
    			reg_id_instr <= 32'b0;
    			reg_id_pc <= 32'h80000000;
    			reg_id_pc4 <= 32'h80000004;
    		end
    		else if (flush || csr_fluah) begin
    			reg_id_instr <= 32'b0;
    			reg_id_pc <= 32'h80000000;
    			reg_id_pc4 <= 32'h80000004;
    		end
    		else if (stall || stall_Load) begin
    			reg_id_instr <= reg_id_instr;
    			reg_id_pc <= reg_id_pc;
    			reg_id_pc4 <= reg_id_pc4;
    		end
    		else begin
    			reg_id_instr <= instr;
    			reg_id_pc <= pc;
    			reg_id_pc4 <= pc4;
    		end
    	end
    
    assign id_instr = reg_id_instr;
    assign id_pc = reg_id_pc;
    assign id_pc4 = reg_id_pc4;
    
endmodule
