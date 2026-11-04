module csr_decode(
 input [6:0] opcode,input [31:0] rs1,
 // Bits 19:15: register NUMBER for register forms, uimm otherwise.
 input [4:0] imm,input [11:0] csr_addr,input [31:0] csr_rdata,
 output is_mret,output is_ecall,output is_ebreak,
 output logic wen,output [11:0] csr_rwaddr,output logic [31:0] csr_wdata
);
 parameter CSRRW=7'd22,CSRRS=7'd23,CSRRC=7'd24;
 parameter CSRRWI=7'd25,CSRRSI=7'd26,CSRRCI=7'd27;
 parameter MRET=7'd21,ECALL=7'd19,EBREAK=7'd20;
 assign is_mret=opcode==MRET;
 assign is_ecall=opcode==ECALL;
 assign is_ebreak=opcode==EBREAK;
 assign csr_rwaddr=csr_addr;
 always_comb begin
  wen=0;csr_wdata=0;
  case(opcode)
   CSRRW:begin wen=1;csr_wdata=rs1;end
   CSRRS:begin wen=imm!=0;csr_wdata=csr_rdata|rs1;end
   CSRRC:begin wen=imm!=0;csr_wdata=csr_rdata&~rs1;end
   CSRRWI:begin wen=1;csr_wdata={27'b0,imm};end
   CSRRSI:begin wen=imm!=0;csr_wdata=csr_rdata|{27'b0,imm};end
   CSRRCI:begin wen=imm!=0;csr_wdata=csr_rdata&~{27'b0,imm};end
   default:;
  endcase
 end
endmodule
