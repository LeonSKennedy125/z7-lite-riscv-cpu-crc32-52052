`timescale 1ns / 1ps
`include "riscv_define.vh"



module npc(
	input clk,			//时钟
	input reset,			//复位
	input [31:0]current_pc,
	input [31:0]right_pc,
	input flush,			//冲刷标志位
	input stall,			//阻塞标志位
	input Pre,
	input stall_Load,
	input csr_pc_en,
	
	output [31:0]npc,		//下一条指令的地址
	output npc_flag,
    output reg replay_redirect
    );
    
    reg [31:0]pc_reg;
    assign npc_flag = 1'b1;
    
    always @ (posedge clk)
    	begin
    		if (!reset) begin
                replay_redirect <= 1'b0;
    			pc_reg <= 32'h80000000;	//复位清零
    		end
            else if (csr_pc_en || flush) begin
                // right_pc is pc_judge.pc4_o. A stalled ROM has not read
                // this target, so save the target itself for replay.
                pc_reg <= (stall || stall_Load) ? right_pc - 32'd4 : right_pc;
                replay_redirect <= stall || stall_Load;
            end
    		else if (stall || stall_Load) begin
    			pc_reg <= pc_reg;
    		end
            else if (replay_redirect || Pre) begin
                pc_reg <= right_pc;
                replay_redirect <= 1'b0;
            end
            else begin
                pc_reg <= current_pc + 32'd4;
                replay_redirect <= 1'b0;
            end
    	end
    	
	assign npc = pc_reg;

endmodule
