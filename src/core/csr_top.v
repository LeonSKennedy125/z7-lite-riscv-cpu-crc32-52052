`timescale 1ns/1ps
module csr_top(
 input clk,input rst,input [6:0] opcode,input [31:0] rs1,
 input [4:0] imm,input [11:0] csr_addr,input sys_stall,
 input [2:0] sys_exception,input [31:0] pc,
 input instr_valid,input irq_safe,
 input tri0 [3:0] instr_type,input tri0 [31:0] pc4,
 input tri0 [31:0] alu_result,input tri0 branch_taken,
 output cancel_current,
 output [31:0] pc_o,output [31:0] csr_rdata,output pc_o_en
);
 wire [31:0] wdata;
 wire [11:0] addr;
 wire wen,ecall,ebreak,mret;
 // Complete memory and control instructions; cancel ordinary ALU/CSR before
 // their state/writeback changes. Both choices form a precise IRQ boundary.
 wire irq_complete = (instr_type==4'd2)||(instr_type==4'd8)||
                     (instr_type==4'd3)||(instr_type==4'd4)||(instr_type==4'd5);
 wire [31:0] irq_resume_pc = (instr_type==4'd3) ? (branch_taken ? alu_result : pc4) :
                           (instr_type==4'd4) ? alu_result :
                           (instr_type==4'd5) ? {alu_result[31:1],1'b0} : pc4;
 csr_decode csr_decode(.opcode(opcode),.rs1(rs1),.imm(imm),.csr_addr(csr_addr),
  .csr_rdata(csr_rdata),.is_mret(mret),.is_ecall(ecall),.is_ebreak(ebreak),
  .wen(wen),.csr_rwaddr(addr),.csr_wdata(wdata));
 csr_regfile csr_regfile(.clk(clk),.rst(rst),.sys_stall(sys_stall),.sys_exception(sys_exception),
  .is_mret(mret),.is_ecall(ecall),.is_ebreak(ebreak),.pc(pc),.pc_o(pc_o),
  .wen(wen),.csr_rwaddr(addr),.csr_wdata(wdata),.csr_rdata(csr_rdata),.pc_o_en(pc_o_en),
  .instr_valid(instr_valid),.irq_safe(irq_safe),
  .irq_complete(irq_complete),.irq_resume_pc(irq_resume_pc),.cancel_current(cancel_current));
endmodule
