`timescale 1ns / 1ps
`include "riscv_define.vh"


module Branch_Ctrl(
	input [3:0]instr_TYPE,	//ex阶段指令类型
	input [31:0]Alu_out,	//正确地址
	input comp_out,	//比较结果，是否跳转
	input [31:0]ex_pc,	//ex阶段代码的pc
	input Exception,	//异常
	input [31:0]ex_pc4,
	
	output [31:0]branch_target,	//正确地址递给npc
	output flush			//冲刷标志位
    );
    
    reg [1:0]predict_state;	//预测状态（对/不对）
    reg reg_flush;
    reg [31:0]reg_branch_target;
    wire [31:0]branch_offset = Alu_out - ex_pc;
    wire predicted_taken = branch_offset[31];
    
    always @ *
    	begin
    		(* parallel_case *) case (instr_TYPE)
    			`TYPE_JAL: predict_state = `PREDICT_R;	//jal必然正确
    			
    			`TYPE_JALR: predict_state = `PREDICT_W2;	//jalr必然错误
    			
    			`TYPE_B: predict_state = (predicted_taken && (comp_out == `NOTJUMP)) ? `PREDICT_W1 :
    						 (!predicted_taken && (comp_out == `JUMP)) ? `PREDICT_W2 : `PREDICT_R;	//判断b是否正确
    							
    			default: predict_state = `PREDICT_R;	//其余都正确（顺序读取）
    		endcase
    	end
    //区分两种错误是因为与其让ALU额外计算PC＋4这一数值，不如直接从IF阶段引出PC+4传递到此
   always @ * begin
    	(* parallel_case *) case (predict_state)
    		`PREDICT_W1: reg_flush = 1'b1;
    		`PREDICT_W2: reg_flush = 1'b1;
    		default: reg_flush = 1'b0;
    	endcase
    end
    
    always @ * begin
    	(* parallel_case *) case (predict_state)
    		`PREDICT_W1: reg_branch_target = ex_pc4;
    		`PREDICT_W2: reg_branch_target = (instr_TYPE == `TYPE_JALR) ? {Alu_out[31:1], 1'b0} : Alu_out;
    		default: reg_branch_target = 32'b0;
    	endcase
    end
    
    assign branch_target = reg_branch_target;
    // The branch still completes (including its link), but an accepted IRQ
    // redirects fetch to the handler instead of applying its normal correction.
    assign flush = reg_flush && !Exception;
endmodule
