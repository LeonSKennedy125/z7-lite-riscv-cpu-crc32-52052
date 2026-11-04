`timescale 1ns / 1ps
`include "riscv_define.vh"



module Regfile(
	input clk,		//时钟
	input wen,		//写使能
	input [31:0]w_data,	//写数据
	input [4:0]w_addr,	//写地址
	input [4:0]r_addr1,	//读地址1
	input [4:0]r_addr2,	//读地址2
	input reset,		//复位
	input [31:0]wb_data,
	input [4:0]wb_addr,
	
	output wire [31:0]final_data1,//读出数据1
	output wire [31:0]final_data2,	//读出数据2
	output wire [31:0]x1,
	output wire [31:0]x10,
	output wire [31:0]x11,
	output wire [31:0]x12,
	output wire [31:0]x13,
	output wire [31:0]x14,
	output wire [31:0]x15,
	output wire [31:0]x16,
	output wire [31:0]x17,
	output wire [31:0]x18,
	output wire [31:0]x19,
	output wire [31:0]x20,
	output wire [31:0]x21,
	output wire [31:0]x22,
	output wire [31:0]x23,
	output wire [31:0]x24,
	output wire [31:0]x25,
	output wire [31:0]x26,
	output wire [31:0]x27,
	output wire [31:0]x28,
	output wire [31:0]x29,
	output wire [31:0]x30,
	output wire [31:0]x31
    );
    
    wire [31:0]data1;
    wire [31:0]data2;
    
    reg [31:0]rf[31:0]; //定义主寄存器
    integer i;
    always @ (posedge clk or negedge reset)
    begin
    	if (!reset)
    	begin
    		for (i = 0;i < 32;i = i + 1) //复位清零
    		rf[i] <= 0;
    	end
    	else if (wen)
    	begin
    		if (w_addr != 5'b0) //写入数据
    			rf[w_addr] <=  w_data;
    	end
    end
    
    assign data1 = (r_addr1 == 5'b0) ? 32'b0 : rf[r_addr1]; //读出数据1
    assign data2 = (r_addr2 == 5'b0) ? 32'b0 : rf[r_addr2]; //读出数据2
    
    assign final_data1 = (wb_addr != 5'b0 && wb_addr == r_addr1 && wen) ? wb_data : data1;
    assign final_data2 = (wb_addr != 5'b0 && wb_addr == r_addr2 && wen) ? wb_data : data2;
    
    assign x1 = rf[1];
    assign x10 = rf[10];
    assign x11 = rf[11];
    assign x12 = rf[12];
    assign x13 = rf[13];
    assign x14 = rf[14];
    assign x15 = rf[15];
    assign x16 = rf[16];
    assign x17 = rf[17];
    assign x18 = rf[18];
    assign x19 = rf[19];
    assign x20 = rf[20];
    assign x21 = rf[21];
    assign x22 = rf[22];
    assign x23 = rf[23];
    assign x24 = rf[24];
    assign x25 = rf[25];
    assign x26 = rf[26];
    assign x27 = rf[27];
    assign x28 = rf[28];
    assign x29 = rf[29];
    assign x30 = rf[30];
    assign x31 = rf[31];
endmodule
