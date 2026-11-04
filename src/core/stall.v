`timescale 1ns / 1ps


module Stall(
	input Stall_Ctrl2,
	input Stall_Ctrl3,
	
	output Stall1,
	output Stall2
    );
    
    assign Stall_Ctrl3 = 1'b0;
    assign Stall2 = (Stall_Ctrl2) ? 1'b1 : 1'b0;
    
endmodule