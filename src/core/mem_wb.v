`timescale 1ns / 1ps
`include "riscv_define.vh"

module MEM_WB(
	input clk,
	input reset,
	input flush,
	input stall,
    input save, // Document 3.2: retain WB for EX0 load-use forwarding.
	input [2:0]WB_Ctrl,
	input [31:0]ALU_out,
	input [31:0]Load_out,
	input [31:0]mem_pc4,
	
	input [4:0]wb_addr,
	
	input [3:0]instr_TYPE,
	input Wen,
	input tri0 IO_source,
    input tri0 [31:0] IO_data,
    input [31:0]CSR_DATA,
	
	output [2:0]WB_CTRL_out,
	output [31:0]ALU_Out_out,
	output [31:0]Load_Out_out,
	output [31:0]WB_pc4_out,
	output [4:0]WB_addr_out,
	output [3:0]Instr_TYPE_out,
	output IO_source_o,
    output [31:0] IO_data_o,
    output [31:0]CSR_DATA_o,
    output Forward_valid,
	output Wen_out
    );
    
	reg [2:0] reg_WB_Ctrl;
	reg [31:0] reg_ALU_out;
	reg [31:0] reg_Load_out;
	reg [31:0] reg_WB_pc4;
	reg [4:0] reg_WB_addr;
	reg [3:0] reg_Instr_TYPE;
    	reg reg_Wen_out;
    	reg [31:0] reg_IO_data;
    reg reg_IO_source;
    reg [31:0] reg_CSR_DATA_o;
	
	always @ (posedge clk or negedge reset) begin
    		if (!reset) begin
        		reg_WB_Ctrl <= 2'b00;
        		reg_ALU_out <= 32'b0;
        		reg_Load_out <= 32'b0;
        		reg_WB_pc4 <= 32'h80000004;
        		reg_WB_addr <= 5'b00000;
        		reg_Instr_TYPE <= 4'b0000;
    			reg_Wen_out <= 1'b0;
    			reg_CSR_DATA_o <= 32'b0;
            reg_IO_source <= 1'b0;
            reg_IO_data <= 32'b0;
    		end
    		else if (flush) begin
        		reg_WB_Ctrl <= 2'b00;
        		reg_ALU_out <= 32'b0;
        		reg_Load_out <= 32'b0;
        		reg_WB_pc4 <= 32'h80000004;
        		reg_WB_addr <= 5'b00000;
        		reg_Instr_TYPE <= 4'b0000;
    			reg_Wen_out <= 1'b0;
    			reg_CSR_DATA_o <= 32'b0;
            reg_IO_source <= 1'b0;
            reg_IO_data <= 32'b0;
    		end
    		else if (stall || save) begin
        		reg_WB_Ctrl <= reg_WB_Ctrl;
        		reg_ALU_out <= reg_ALU_out;
        		reg_Load_out <= reg_Load_out;
        		reg_WB_pc4 <= reg_WB_pc4;
        		reg_WB_addr <= reg_WB_addr;
        		reg_Instr_TYPE <= reg_Instr_TYPE;
        		reg_Wen_out <= reg_Wen_out;
        		reg_CSR_DATA_o <= reg_CSR_DATA_o;
            reg_IO_source <= reg_IO_source;
            reg_IO_data <= reg_IO_data;
    		end
    		else begin
    			reg_WB_Ctrl <= WB_Ctrl;
        		reg_ALU_out <= ALU_out;
        		reg_Load_out <= Load_out;
        		reg_WB_pc4 <= mem_pc4;
        		reg_WB_addr <= wb_addr;
        		reg_Instr_TYPE <= instr_TYPE;
    			reg_Wen_out <= Wen;
    			reg_CSR_DATA_o <= CSR_DATA;
            reg_IO_source <= IO_source;
            reg_IO_data <= IO_data;
    		end
    		
	end

	assign IO_source_o = reg_IO_source;
    assign IO_data_o = reg_IO_data;
    assign CSR_DATA_o = reg_CSR_DATA_o;
	assign WB_CTRL_out = reg_WB_Ctrl;
	assign ALU_Out_out = reg_ALU_out;
	assign Load_Out_out = reg_Load_out;
	assign WB_pc4_out = reg_WB_pc4;
	assign WB_addr_out = reg_WB_addr;
	assign Instr_TYPE_out = reg_Instr_TYPE;
	// Hold delays the pending write. On release it commits once and this
    // register advances on the same edge. Forwarding does not use this pulse.
    assign Forward_valid = reset && !flush && reg_Wen_out;
    assign Wen_out = Forward_valid && !stall && !save;
	
endmodule
	
    

