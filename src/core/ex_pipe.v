`timescale 1ns / 1ps


module EX_pipe(
	input clk,
	input reset,
	input flush,
	input stall,
	input [31:0]ALU_A,
	input [31:0]ALU_B,
	input [31:0]Comp_A,
	input [31:0]Comp_B,
	input [4:0]WB_Addr,
	input [3:0]Instr_TYPE,  //指令大类
    	input comp_en,
	input [6:0]ALU_Ctrl,
    	input [2:0]Comp_Ctrl,
    	input Load_en,
    	input [2:0]Load_Ctrl,
    	input Store_en,
    	input [1:0]Store_Ctrl,
    	input [2:0]WB_Ctrl,
    	input wb_en,
    	input Flush3,
    	input [31:0]id_pc,  //id地址
	input [31:0]id_pc4, //地址加四
	input [31:0]D2,
	input stall_Load,
    input tri0 io_load_ready,
	input csr_flush,
	input [11:0]csr_addr,
    	input instr_valid,
    	input [4:0]csr_imm,
	
   	output [31:0]ALU_A_O,
   	output [31:0]ALU_B_O,
    	output [31:0]Comp_A_O,
    	output [31:0]Comp_B_O,
    	output [4:0]WB_Addr_O,
    	output [3:0]Instr_TYPE_O,
    	output comp_en_O,
    	output [6:0]ALU_Ctrl_O,
    	output [2:0]Comp_Ctrl_O,
    	output Load_en_O,
    	output [2:0]Load_Ctrl_O,
    	output Store_en_O,
    	output [1:0]Store_Ctrl_O,
    	output [2:0]WB_Ctrl_O,
    	output wb_en_O,
    	output [31:0] pc_O,
    	output [31:0] pc4_O,
    	output [31:0]D2_O,
    	output load_over,
    	output [11:0]csr_addr_out,
    	output [4:0]csr_imm_out,
        output csr_valid,
        output csr_irq_safe
    );
	
	reg reg_load_over;
	reg [31:0]reg_ALU_A_O;
	reg [31:0]reg_ALU_B_O;
	reg [31:0]reg_Comp_A_O;
	reg [31:0]reg_Comp_B_O;
	reg [4:0]reg_WB_Addr_O;
	reg [3:0]reg_Instr_TYPE_O;
	reg reg_comp_en_O;
	reg [6:0]reg_ALU_Ctrl_O;
	reg [2:0]reg_Comp_Ctrl_O;
	reg reg_Load_en_O;
	reg [2:0]reg_Load_Ctrl_O;
	reg reg_Store_en_O;
	reg [1:0]reg_Store_Ctrl_O;
	reg [2:0]reg_WB_Ctrl_O;
	reg reg_wb_en_O;
	reg [31:0]reg_pc_O;
	reg [31:0]reg_pc4_O;
	reg[31:0]reg_D2_O;
	reg [11:0]reg_csr_addr;
    	reg [4:0]reg_csr_imm;
        reg reg_instr_valid;
    
    always @(posedge clk) begin
    	if (!reset) begin
        	reg_ALU_A_O       <= 32'b0;
        	reg_ALU_B_O       <= 32'b0;
        	reg_Comp_A_O      <= 32'b0;
        	reg_Comp_B_O      <= 32'b0;
        	reg_WB_Addr_O     <= 5'b0;
        	reg_Instr_TYPE_O  <= 4'b0;
        	reg_comp_en_O     <= 1'b0;
        	reg_ALU_Ctrl_O    <= 7'b0;
        	reg_Comp_Ctrl_O   <= 3'b0;
        	reg_Load_en_O     <= 1'b0;
        	reg_Load_Ctrl_O   <= 3'b0;
        	reg_Store_en_O    <= 1'b0;
        	reg_Store_Ctrl_O  <= 2'b0;
        	reg_WB_Ctrl_O     <= 2'b0;
        	reg_wb_en_O       <= 1'b0;
        	reg_pc_O          <= 32'h80000000;
        	reg_pc4_O         <= 32'h80000004;
        	reg_D2_O	  <= 32'b0;
        	reg_load_over     <= 1'b0;
        	reg_csr_addr      <= 12'b0;
            	reg_csr_imm       <= 5'b0;
                reg_instr_valid <= 1'b0;
    	end 
    	else if (flush || csr_flush) begin
        	reg_ALU_A_O       <= 32'b0;
        	reg_ALU_B_O       <= 32'b0;
        	reg_Comp_A_O      <= 32'b0;
        	reg_Comp_B_O      <= 32'b0;
        	reg_WB_Addr_O     <= 5'b0;
        	reg_Instr_TYPE_O  <= 4'b0;
        	reg_comp_en_O     <= 1'b0;
        	reg_ALU_Ctrl_O    <= 7'b0;
       		reg_Comp_Ctrl_O   <= 3'b0;
		reg_Load_en_O     <= 1'b0;
		reg_Load_Ctrl_O   <= 3'b0;
		reg_Store_en_O    <= 1'b0;
		reg_Store_Ctrl_O  <= 2'b0;
		reg_WB_Ctrl_O     <= 2'b0;
		reg_wb_en_O       <= 1'b0;
		reg_pc_O          <= 32'h80000000;
		reg_pc4_O         <= 32'h80000004;
		reg_D2_O	  <= 32'b0;
		reg_load_over     <= 1'b0;
		reg_csr_addr      <= 12'b0;
            	reg_csr_imm       <= 5'b0;
                reg_instr_valid <= 1'b0;
    	end 
    	else if (stall || stall_Load) begin
		reg_ALU_A_O       <= reg_ALU_A_O;
		reg_ALU_B_O       <= reg_ALU_B_O;
		reg_Comp_A_O      <= reg_Comp_A_O;
		reg_Comp_B_O      <= reg_Comp_B_O;
		reg_WB_Addr_O     <= reg_WB_Addr_O;
		reg_Instr_TYPE_O  <= reg_Instr_TYPE_O;
		reg_comp_en_O     <= reg_comp_en_O;
		reg_ALU_Ctrl_O    <= reg_ALU_Ctrl_O;
		reg_Comp_Ctrl_O   <= reg_Comp_Ctrl_O;
		reg_Load_en_O     <= reg_Load_en_O;
		reg_Load_Ctrl_O   <= reg_Load_Ctrl_O;
		reg_Store_en_O    <= reg_Store_en_O;
		reg_Store_Ctrl_O  <= reg_Store_Ctrl_O;
		reg_WB_Ctrl_O     <= reg_WB_Ctrl_O;
		reg_wb_en_O       <= reg_wb_en_O;
		reg_pc_O          <= reg_pc_O;
		reg_pc4_O         <= reg_pc4_O;
		reg_D2_O	  <= reg_D2_O;
		reg_load_over     <= stall_Load;
		reg_csr_addr      <= reg_csr_addr;
            	reg_csr_imm       <= reg_csr_imm;
                reg_instr_valid <= reg_instr_valid;
    	end
    	    	else if (Flush3) begin
        	reg_ALU_A_O       <= 32'b0;
        	reg_ALU_B_O       <= 32'b0;
        	reg_Comp_A_O      <= 32'b0;
        	reg_Comp_B_O      <= 32'b0;
        	reg_WB_Addr_O     <= 5'b0;
        	reg_Instr_TYPE_O  <= 4'b0;
        	reg_comp_en_O     <= 1'b0;
        	reg_ALU_Ctrl_O    <= 7'b0;
       		reg_Comp_Ctrl_O   <= 3'b0;
		reg_Load_en_O     <= 1'b0;
		reg_Load_Ctrl_O   <= 3'b0;
		reg_Store_en_O    <= 1'b0;
		reg_Store_Ctrl_O  <= 2'b0;
		reg_WB_Ctrl_O     <= 2'b0;
		reg_wb_en_O       <= 1'b0;
		reg_pc_O          <= 32'h80000000;
		reg_pc4_O         <= 32'h80000004;
		reg_D2_O	  <= 32'b0;
		reg_load_over     <= 1'b0;
		reg_csr_addr      <= 12'b0;
            	reg_csr_imm       <= 5'b0;
                reg_instr_valid <= 1'b0;
	end
    	else begin
		reg_ALU_A_O       <= ALU_A;
		reg_ALU_B_O       <= ALU_B;
		reg_Comp_A_O      <= Comp_A;
		reg_Comp_B_O      <= Comp_B;
		reg_WB_Addr_O     <= WB_Addr;
		reg_Instr_TYPE_O  <= Instr_TYPE;
		reg_comp_en_O     <= comp_en;
		reg_ALU_Ctrl_O    <= ALU_Ctrl;
		reg_Comp_Ctrl_O   <= Comp_Ctrl;
		reg_Load_en_O     <= Load_en;
		reg_Load_Ctrl_O   <= Load_Ctrl;
		reg_Store_en_O    <= Store_en;
		reg_Store_Ctrl_O  <= Store_Ctrl;
		reg_WB_Ctrl_O     <= WB_Ctrl;
		reg_wb_en_O       <= wb_en;
		reg_pc_O          <= id_pc;
		reg_pc4_O         <= id_pc4;
		reg_D2_O 	  <= D2;
		reg_load_over     <= 1'b0;
		reg_csr_addr      <= csr_addr;
            	reg_csr_imm       <= csr_imm ;
                reg_instr_valid <= instr_valid;
    	end
    end
    
	assign ALU_A_O       = reg_ALU_A_O;
	assign ALU_B_O       = reg_ALU_B_O;
	assign Comp_A_O      = reg_Comp_A_O;
	assign Comp_B_O      = reg_Comp_B_O;
	assign WB_Addr_O     = reg_WB_Addr_O;
	assign Instr_TYPE_O  = reg_Instr_TYPE_O;
	assign comp_en_O     = reg_comp_en_O;
	assign ALU_Ctrl_O    = reg_ALU_Ctrl_O;
	assign Comp_Ctrl_O   = reg_Comp_Ctrl_O;
	assign Load_en_O     = reg_Load_en_O;
	assign Load_Ctrl_O   = reg_Load_Ctrl_O;
	assign Store_en_O    = reg_Store_en_O;
	assign Store_Ctrl_O  = reg_Store_Ctrl_O;
	assign WB_Ctrl_O     = reg_WB_Ctrl_O;
	assign wb_en_O       = reg_wb_en_O;
	assign pc_O          = reg_pc_O;
	assign pc4_O         = reg_pc4_O;
	assign D2_O    	     = reg_D2_O;
	assign load_over     = reg_load_over;
	assign csr_addr_out  = reg_csr_addr;
	assign csr_imm_out  = reg_csr_imm;

        // A valid instruction reaches an IRQ boundary only when this stage
        // can advance; a two-cycle load must have completed its BRAM wait.
        assign csr_valid = reg_instr_valid;
        assign csr_irq_safe = csr_valid && !stall && !stall_Load &&
                              (!reg_Load_en_O || reg_load_over || io_load_ready);
endmodule

