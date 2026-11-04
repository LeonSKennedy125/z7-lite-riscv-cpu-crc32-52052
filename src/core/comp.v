`timescale 1ns / 1ps
`include "riscv_define.vh"

module Comp(
	input [31:0]A,
	input [31:0]B,
	input [2:0]Comp_Ctrl,
	input Comp_en,
	
	output Comp_out
    );
    

	wire eq  = (A == B);
	wire slt = $signed(A) < $signed(B);
	wire sltu= (A < B);

	reg reg_Comp_out;	

	always @ * begin
		if (Comp_en) begin
			(* parallel_case *) case (Comp_Ctrl)
				3'b000:reg_Comp_out = eq;
			        3'b001:reg_Comp_out = ~eq;
			        3'b100:reg_Comp_out = slt;
			        3'b101:reg_Comp_out = ~slt;
			        3'b110:reg_Comp_out = sltu;
			        3'b111:reg_Comp_out = ~sltu;
			        3'b010:reg_Comp_out = slt;
			        3'b011:reg_Comp_out = sltu;		//SLT/SLTI
			        default:reg_Comp_out = 1'b0;		//SLTU/SLTIU
			endcase
		end
		else 
			reg_Comp_out = 1'b0;
	end
	
	assign Comp_out = reg_Comp_out;
	
endmodule
