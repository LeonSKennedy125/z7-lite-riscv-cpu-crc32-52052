import csr_pkg::*;
module csr_regfile #(
 parameter [31:0] MTVEC=32'b0,
 parameter [31:0] misa=32'h40000100,
 parameter [31:0] mvendorid=32'h11451400,
 parameter [31:0] marchid=32'h11451400,
 parameter [31:0] mimpid=32'h11451400,
 parameter [31:0] mhartid=32'b0,
 parameter [31:0] mconfigptr=32'b0
)(
 input clk,input rst,input sys_stall,input [2:0] sys_exception,
 input is_mret,input is_ecall,input is_ebreak,
 input [31:0] pc,output logic [31:0] pc_o,
 input wen,input [11:0] csr_rwaddr,input [31:0] csr_wdata,
 output logic [31:0] csr_rdata,output logic pc_o_en,
 // Defaults preserve direct regfile test interfaces. Production wires both.
 input tri1 instr_valid,input tri1 irq_safe,
 input tri0 irq_complete,input tri0 [31:0] irq_resume_pc,
 output cancel_current
);
 mstatus_t mstatus='0;
 mtvec_t mtvec=MTVEC;
 mie_t mie='0;
 mip_t mip='0;
 logic [31:0] mscratch='0,mepc='0,mtval='0;
 mcause_t mcause='0;
 logic [63:0] mcycle_all='0;
 logic mcountinhibit_cy=0;
 // Explicit placeholders: no retirement/HPM verification is claimed.
 localparam [31:0] minstret=0,minstreth=0;
 wire [2:0] enabled_irq={mip.meip&&mie.meie,mip.msip&&mie.msie,mip.mtip&&mie.mtie};
 wire interrupt_active=mstatus.mie&&(|enabled_irq)&&irq_safe;
 wire exception_active=is_ecall||is_ebreak||interrupt_active;
 wire accept=rst&&instr_valid&&!sys_stall;
 wire take_exception=accept&&exception_active;
 wire take_mret=accept&&!exception_active&&is_mret;
 assign cancel_current = take_mret || (take_exception &&
                         (is_ecall || is_ebreak || !irq_complete));
 logic [31:0] trap_cause;
 always_comb begin
  trap_cause=0;
  if(is_ebreak)trap_cause=32'h00000003;
  else if(is_ecall)trap_cause=32'h0000000b;
  else if(enabled_irq[2])trap_cause=32'h8000000b;
  else if(enabled_irq[1])trap_cause=32'h80000003;
  else if(enabled_irq[0])trap_cause=32'h80000007;
 end
 // Full addresses and defaults prevent aliases and combinational state.
 always_comb begin
  csr_rdata=0;
  case(csr_rwaddr)
   12'h301:csr_rdata=misa;
   12'hf11:csr_rdata=mvendorid;
   12'hf12:csr_rdata=marchid;
   12'hf13:csr_rdata=mimpid;
   12'hf14:csr_rdata=mhartid;
   12'hf15:csr_rdata=mconfigptr;
   12'h300:csr_rdata=mstatus;
   12'h305:csr_rdata=mtvec;
   12'h304:csr_rdata=mie;
   12'h344:csr_rdata=mip;
   12'h340:csr_rdata=mscratch;
   12'h341:csr_rdata=mepc;
   12'h342:csr_rdata=mcause;
   12'h343:csr_rdata=mtval;
   12'hb00:csr_rdata=mcycle_all[31:0];
   12'hb80:csr_rdata=mcycle_all[63:32];
   12'hb02:csr_rdata=minstret;
   12'hb82:csr_rdata=minstreth;
   12'h320:csr_rdata={31'b0,mcountinhibit_cy};
   default:csr_rdata=0;
  endcase
 end
 always_comb begin
  pc_o=0;pc_o_en=0;
  if(take_exception)begin
   pc_o={mtvec.base,2'b00};
   if(mtvec.mode==1&&trap_cause[31])pc_o=pc_o+{trap_cause[29:0],2'b00};
   pc_o_en=1;
  end else if(take_mret)begin pc_o=mepc;pc_o_en=1;end
 end
 // Synchronous CSR reset/write follows figure 4-4. Phase02 synchronizes release.
 always_ff @(posedge clk)begin
  if(!rst)begin
   mstatus<='0;mtvec<=MTVEC;mie<='0;mip<='0;
   mscratch<=0;mepc<=0;mcause<='0;mtval<=0;
   mcycle_all<=0;mcountinhibit_cy<=0;
  end else begin
   if(!mcountinhibit_cy)mcycle_all<=mcycle_all+64'd1;
   // Capture sticky requests during stalls; an asserted source wins software clear.
   if(accept&&wen&&!exception_active&&!is_mret&&csr_rwaddr==12'h344)
    mip<=(csr_wdata&32'h888)|(sys_exception[2]?32'h800:0)|
          (sys_exception[1]?32'h8:0)|(sys_exception[0]?32'h80:0);
   else begin
    mip.meip<=mip.meip||sys_exception[2];
    mip.msip<=mip.msip||sys_exception[1];
    mip.mtip<=mip.mtip||sys_exception[0];
   end
   if(take_exception)begin
    mstatus.mpp<=2'b11;mstatus.mpie<=mstatus.mie;mstatus.mie<=0;
    // A completed memory/control instruction resumes at its resolved next PC.
    // Canceled CSR/ALU and synchronous traps retain the interrupted/faulting PC.
    mepc<=(!is_ecall&&!is_ebreak&&irq_complete) ?
           {irq_resume_pc[31:2],2'b00} : {pc[31:2],2'b00};
    mcause<=trap_cause;mtval<=0;
   end else if(take_mret)begin
    mstatus.mpp<=2'b11;mstatus.mie<=mstatus.mpie;mstatus.mpie<=1;
   end else if(accept&&wen)begin
    case(csr_rwaddr)
     12'h300:mstatus<=csr_wdata&32'h00001888;
     12'h305:mtvec<={csr_wdata[31:2],(csr_wdata[1:0]==1?2'b01:2'b00)};
     12'h304:mie<=csr_wdata&32'h00000888;
     12'h340:mscratch<=csr_wdata;
     12'h341:mepc<={csr_wdata[31:2],2'b00};
     12'h342:mcause<=csr_wdata;
     12'h343:mtval<=csr_wdata;
     12'h320:mcountinhibit_cy<=csr_wdata[0];
     default:;
    endcase
   end
  end
 end
endmodule
