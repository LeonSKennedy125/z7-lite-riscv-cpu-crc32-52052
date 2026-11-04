`timescale 1ns / 1ps
`include "riscv_define.vh"

module ALU(
    input [31:0]A,
    input [31:0]B,
    input [6:0]ALU_Ctrl,
    input [3:0]Instr_type,
    input comp_out,
    
    output [31:0]Alu_out,
    output [31:0]branch_pc,
    output [31:0]MEM_Addr
    );
    
    wire [31:0]addout;
    wire [31:0]subout;
    wire [31:0]andout;
    wire [31:0]orout;
    wire [31:0]xorout;
    wire [31:0]sllout;
    wire [31:0]srlout;
    wire [31:0]sraout;
    wire [31:0]Pass;
    
    assign addout = A + B;
    assign subout = A - B;
    assign andout = A & B;
    assign orout = A | B;
    assign xorout = A ^ B;
    assign sllout = A[31:0] << $unsigned(B[4:0]);
    assign srlout = $unsigned(A[31:0]) >> $unsigned(B[4:0]);
    assign sraout = $signed(A[31:0]) >>> $signed(B[4:0]);
    assign Pass = B;
    
    reg [31:0]reg_ALUOUT;
    reg [31:0]reg_branch_pc;
    reg [31:0]reg_Store_Addr;
    reg [31:0]reg_Load_Addr;
    
    always @ * begin
        // Helpers are only valid for ADD; never retain a previous instruction.
        reg_ALUOUT = Pass;
        reg_branch_pc = 32'b0;
        reg_Store_Addr = 32'b0;
        reg_Load_Addr = 32'b0;
     	(* parallel_case *) case (ALU_Ctrl) 
     		`ADD: begin reg_ALUOUT = addout;
     		      reg_branch_pc = addout;
     		      reg_Store_Addr = addout;
     		      reg_Load_Addr = addout;
     		 end
     		`SUB: reg_ALUOUT = subout;
     		`ALU_AND: reg_ALUOUT = andout;
     		`ALU_OR: reg_ALUOUT = orout;
     		`ALU_XOR: reg_ALUOUT = xorout;
     		`ALU_SLL: reg_ALUOUT = sllout;
     		`ALU_SRL: reg_ALUOUT = srlout;
     		`ALU_SRA: reg_ALUOUT = sraout;
     		`ALU_SLT: reg_ALUOUT = {{31{1'b0}},comp_out};
     		`ALU_SLTU: reg_ALUOUT = {{31{1'b0}},comp_out};
     		default: begin reg_ALUOUT = Pass;
     			       reg_branch_pc = 32'b0;
     			       reg_Store_Addr = 32'b0;
     			       reg_Load_Addr = 32'b0;
     		end
     	endcase
    end
    
    assign Alu_out = reg_ALUOUT;
    assign branch_pc = (Instr_type == `TYPE_B || Instr_type == `TYPE_JALR) ? reg_branch_pc : 32'b0;
    assign MEM_Addr = (Instr_type == `TYPE_S) ? reg_Store_Addr : 
    		      (Instr_type == `TYPE_LW) ? reg_Load_Addr : 32'b0;
  
    
endmodule
