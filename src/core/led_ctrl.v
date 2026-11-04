`timescale 1ns / 1ps


module LED_CTRL(
	input clk,
	input reset,
	input led,
	input [31:0]LED_Ctrl,
	
	output [4:0]LED_CTRL_o
    );
    
    reg [4:0] LED_State;
    
    always @ (posedge clk or negedge reset)
    	if (!reset)
    		LED_State <= 5'b0;
    	else if (led)
    		LED_State <= LED_Ctrl[4:0];
    	else 
    		LED_State <= LED_State;
    
    assign LED_CTRL_o = LED_State;
endmodule
