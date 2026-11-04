`timescale 1ns / 1ps


module save_Load_use(
	input stall1,
	input stall2,
	input clk,
	input reset,
	
	output save
    );
    
    reg reg_save;
    
    always @ (posedge clk or negedge reset) begin
    	if (!reset)
    		reg_save <= 1'b0;
    	else if (stall1 && stall2)
    		reg_save <= 1'b1;
    	else 
    		reg_save <= 1'b0;
    end

    assign save = reg_save;

endmodule
