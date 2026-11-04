`timescale 1ns / 1ps
`include "riscv_define.vh"


module EX_MEM(
	input flush,
	input clk,
	input reset,
	input [31:0]EX_ALUout,
	input [4:0]wb_addr,
	input wb_en,
	input [2:0]wb_Ctrl,
	input [3:0]instr_TYPE,
	input [31:0]ex_pc4,
	input stall,
	input loaden,
	input [2:0]load_ctrl,
	input ex_Forward_en1,
	input ex_Forward_en2,
	input [1:0]ex_Forward_SEL1,
	input stall_Load,
	input csr_fluah,
	input tri0 IO_source,
    input tri0 [31:0] IO_data,
    input [31:0]CSR_DATA,
	input [31:0]load_addr,
	
	output [31:0]MEM_ALUout_out,
	output [4:0]MEM_wb_addr_out,
	output WB_en_out,
	output [31:0]mem_pc4_out,
	output [2:0]WB_Ctrl_out,
	output [3:0]Instr_TYPE_out,
	output loaden_out,
	output ex_Forward_en1_o,
	output ex_Forward_en2_o,
	output [1:0]ex_Forward_SEL1_0,
	output IO_source_o,
    output [31:0] IO_data_o,
    output [31:0]CSR_DATA_o,
	output [2:0]load_ctrl_out,
	output [31:0]load_addr_o
    );
    
    reg [31:0] reg_load_addr;
    reg        reg_WB_en;
    reg [2:0]  reg_WB_Ctrl;
    reg [31:0] reg_ALUout;
    reg [4:0]  reg_WB_addr;
    reg [3:0]  reg_Instr_TYPE;
    reg        reg_Forward_en;
    reg [31:0] reg_mem_pc4;
    reg reg_loaden;
    reg [2:0]reg_load_ctrl_out;
    reg reg_ex_Forward_en1_o;
    reg reg_ex_Forward_en2_o;
    reg [31:0] reg_IO_data;
    reg reg_IO_source;
    reg [31:0] reg_CSR_DATA_o;
    reg [1:0] reg_ex_Forward_SEL1_0;
    
    
    always @ (posedge clk or negedge reset) begin
    	if (!reset) begin
        	reg_WB_en     <= 1'b0;
        	reg_WB_Ctrl   <= 3'b000;
        	reg_ALUout    <= 32'b0;
        	reg_WB_addr   <= 5'b00000;
        	reg_Instr_TYPE<= 4'b0000;
        	reg_mem_pc4   <= 32'h80000004;
    		reg_loaden <= 1'b0;
    		reg_load_ctrl_out <= 1'b0;
    		reg_ex_Forward_en1_o <= 1'b0;
    		reg_ex_Forward_en2_o <= 1'b0;
    		reg_ex_Forward_SEL1_0 <= 2'b11;	
    		reg_CSR_DATA_o <= 32'b0;
            reg_IO_source <= 1'b0;
            reg_IO_data <= 32'b0;
    		reg_load_addr <= 32'b0;
    	end
    	else if (flush || stall_Load || csr_fluah) begin
        	reg_WB_en     <= 1'b0;
        	reg_WB_Ctrl   <= 3'b000;
        	reg_ALUout    <= 32'b0;
        	reg_WB_addr   <= 5'b00000;
        	reg_Instr_TYPE<= 4'b0000;
        	reg_mem_pc4   <= 32'h80000004;
    		reg_loaden <= 1'b0;
    		reg_load_ctrl_out <= 1'b0;
    		reg_ex_Forward_en1_o <= 1'b0;
    		reg_ex_Forward_en2_o <= 1'b0;
    		reg_ex_Forward_SEL1_0 <= 2'b11;	
    		reg_CSR_DATA_o <= 32'b0;
            reg_IO_source <= 1'b0;
            reg_IO_data <= 32'b0;
    		reg_load_addr <= 32'b0;
    	end
    	else if (stall) begin 
    		reg_WB_en     <= reg_WB_en;
        	reg_WB_Ctrl   <= reg_WB_Ctrl;
        	reg_ALUout    <= reg_ALUout;
        	reg_WB_addr   <= reg_WB_addr;
        	reg_Instr_TYPE<= reg_Instr_TYPE;
        	reg_mem_pc4   <= reg_mem_pc4;
    		reg_loaden <= reg_loaden;
    		reg_load_ctrl_out <= reg_load_ctrl_out;
    		reg_ex_Forward_en1_o <= reg_ex_Forward_en1_o;
    		reg_ex_Forward_en2_o <= reg_ex_Forward_en2_o;
    		reg_ex_Forward_SEL1_0 <= reg_ex_Forward_SEL1_0;	
    		reg_CSR_DATA_o <= reg_CSR_DATA_o;
            reg_IO_source <= reg_IO_source;
            reg_IO_data <= reg_IO_data;
    		reg_load_addr <= reg_load_addr;
    	end
    	else begin
        	reg_WB_en     <= wb_en;
        	reg_WB_Ctrl   <= wb_Ctrl;
        	reg_ALUout    <= EX_ALUout;
        	reg_WB_addr   <= wb_addr;
        	reg_Instr_TYPE<= instr_TYPE;
        	reg_mem_pc4   <= ex_pc4;
    		reg_loaden <= loaden;
    		reg_load_ctrl_out <= load_ctrl;
    		reg_ex_Forward_en1_o <= ex_Forward_en1;
    		reg_ex_Forward_en2_o <= ex_Forward_en2;
    		reg_ex_Forward_SEL1_0 <= ex_Forward_SEL1;
    		reg_CSR_DATA_o <= CSR_DATA;
            reg_IO_source <= IO_source;
            reg_IO_data <= IO_data;
    		reg_load_addr <= load_addr;
    	end
end

// 输出赋值
	assign MEM_ALUout_out = reg_ALUout;
	assign MEM_wb_addr_out   = reg_WB_addr;
	assign WB_en_out         = reg_WB_en;
	assign WB_Ctrl_out       = reg_WB_Ctrl;
	assign Instr_TYPE_out    = reg_Instr_TYPE;
	assign mem_pc4_out       = reg_mem_pc4;
    	assign loaden_out = reg_loaden;
    	assign load_ctrl_out = reg_load_ctrl_out;
    	assign ex_Forward_en1_o = reg_ex_Forward_en1_o;
    	assign ex_Forward_en2_o = reg_ex_Forward_en2_o;
    	assign ex_Forward_SEL1_0 = reg_ex_Forward_SEL1_0;
    	assign IO_source_o = reg_IO_source;
    assign IO_data_o = reg_IO_data;
    assign CSR_DATA_o = reg_CSR_DATA_o;
    	assign load_addr_o = reg_load_addr;
endmodule
