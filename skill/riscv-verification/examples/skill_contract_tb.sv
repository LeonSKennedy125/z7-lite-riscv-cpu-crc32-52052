`timescale 1ns/1ps
`include "RISCV_DEFINE.vh"
// New tests only. Real DUT modules are compiled from the selected project.
// This is module-level evidence, not an instruction-stream/board acceptance.
module skill_contract_tb;
  reg clk=0, reset=0;
  always #5 clk=~clk;
  integer checks=0,failures=0;
  task check(input bit ok,input string message);
    checks++;
    if (!ok) begin failures++;$display("FAIL | %s",message);end
  endtask
  reg [31:0] a=0,b=0;
  reg [6:0] op=`ADD;
  reg [3:0] typ=`TYPE_R;
  reg [2:0] cc=0;
  wire cmp;
  wire [31:0] result, helper, address;
  Comp compare(.A(a),.B(b),.Comp_Ctrl(cc),.Comp_en(1'b1),.Comp_out(cmp));
  ALU alu(.A(a),.B(b),.ALU_Ctrl(op),.Instr_type(typ),.comp_out(cmp),
          .Alu_out(result),.branch_pc(helper),.MEM_Addr(address));
  task arithmetic(input [6:0] operation,input [31:0] av,bv,expected);
    a=av;b=bv;op=operation;#1;
    check(result===expected,$sformatf("ALU op=%0d A=%h B=%h expected=%h actual=%h",op,a,b,expected,result));
  endtask
  reg wen=0;
  reg [4:0] wa=0,r1=0,r2=0,bypass=0;
  reg [31:0] wd=0,bd=0;
  wire [31:0] q1,q2;
  Regfile registers(.clk(clk),.reset(reset),.wen(wen),.w_addr(wa),.w_data(wd),
    .r_addr1(r1),.r_addr2(r2),.wb_addr(bypass),.wb_data(bd),.final_data1(q1),.final_data2(q2));
  reg [31:0] instruction=0;
  wire [4:0] rs1,rs2,rd;
  wire [6:0] opcode,funct7,decoded_op;
  wire [2:0] funct3,loadctrl,wbctrl;
  wire [11:0] funct12;
  wire [3:0] dtype;
  wire loaden,storeen,wben;
  Decoder decoder(.id_instr(instruction),.r1_addr(rs1),.r2_addr(rs2),.w_addr(rd),
    .opcode(opcode),.func3(funct3),.func7(funct7),.func12(funct12),.instr_TYPE(dtype));
  Ctrl control(.opcode(opcode),.func3(funct3),.func7(funct7),.func12(funct12),
    .ALU_Ctrl(decoded_op),.Load_en(loaden),.Load_Ctrl(loadctrl),.Store_en(storeen),.WB_Ctrl(wbctrl),.wb_en(wben));
  reg [31:0] pc=32'h80000000,target=0;
  reg taken=0,exception=0;
  reg [3:0] branch_type=`TYPE_B;
  wire flush;
  wire [31:0] corrected,predicted;
  wire prediction;
  Branch_Ctrl branch(.instr_TYPE(branch_type),.Alu_out(target),.comp_out(taken),
    .ex_pc(pc),.Exception(exception),.ex_pc4(pc+4),.branch_target(corrected),.flush(flush));
  instr_minidecoder predict(.instr(instruction),.pc(pc),.pc_o(predicted),.Pre(prediction));
  reg load=0,store=0,ready=0,cancel=0,valid=1,stall=0,load_over=0;
  reg [2:0] lc=`LOAD_LW;
  reg [1:0] sc=`STORE_SW;
  reg [31:0] addr=32'h80100000,data=32'h89abcdef;
  wire [31:0] packed_data,io_data;
  wire [3:0] be,io_be;
  wire ram_hit,io_hit,wait_load,io_valid;
  Store_Load memory_request(.reset(reset),.instr_valid(valid),.stall(stall),.cancel(cancel),
    .IO_ready(ready),.IO_rdata(32'h89abcdef),.Load_en(load),.Load_Ctrl(lc),.Store_en(store),
    .Store_Ctrl(sc),.MEM_Addr(addr),.D2(data),.load_over(load_over),.dtcm_data(packed_data),
    .wen(be),.ram_hit(ram_hit),.mmio_hit(io_hit),.stall_Load(wait_load),.IO_Wen(io_valid),
    .IO_data(io_data),.IO_be(io_be));
  function [31:0] branch_word(input integer offset);
    reg [12:0] x;
    begin x=offset;branch_word={x[12],x[10:5],5'd2,5'd1,3'b000,x[4:1],x[11],7'b1100011};end
  endfunction
  initial begin
    #1;repeat(2)@(negedge clk);reset=1;
    arithmetic(`ADD,32'hffffffff,1,0);
    arithmetic(`SUB,0,1,32'hffffffff);
    arithmetic(`ALU_AND,32'hf0f0f0f0,32'h0ff00ff0,32'h00f000f0);
    arithmetic(`ALU_OR,32'hf0f0f0f0,32'h0ff00ff0,32'hfff0fff0);
    arithmetic(`ALU_XOR,32'hf0f0f0f0,32'h0ff00ff0,32'hff00ff00);
    arithmetic(`ALU_PASS,0,32'h81234000,32'h81234000);
    for(integer n=0;n<32;n++)begin
      arithmetic(`ALU_SLL,32'h80000001,n+32,32'h80000001<<n);
      arithmetic(`ALU_SRL,32'h80000001,n+32,32'h80000001>>n);
      arithmetic(`ALU_SRA,32'h80000001,n+32,$signed(32'h80000001)>>>n);
    end
    cc=2;arithmetic(`ALU_SLT,32'h80000000,1,1);
    cc=3;arithmetic(`ALU_SLTU,32'h80000000,1,0);
    typ=`TYPE_S;arithmetic(`ADD,32'h80100000,12,32'h8010000c);
    check(address===32'h8010000c,"full effective RAM address");
    arithmetic(`SUB,32'h80100000,4,32'h800ffffc);check(address===0,"no retained address helper");
    // Exercise both ports, every architectural register, and x0 exclusion.
    for(integer n=1;n<32;n++)begin
      @(negedge clk);wen=1;wa=n;wd=32'h9a000000+n;
      @(negedge clk);wen=0;r1=n;r2=n;#1;
      check(q1===32'h9a000000+n&&q2===32'h9a000000+n,"register write/read");
    end
    @(negedge clk);wen=1;wa=0;wd=32'hffffffff;
    @(negedge clk);wen=0;r1=0;r2=0;#1;check(q1===0&&q2===0,"x0 immutable");
    wen=1;bypass=7;bd=32'h12345678;r1=7;r2=7;#1;
    check(q1===bd&&q2===bd,"WB-to-ID bypass");wen=0;#1;
    check(q1===32'h9a000007,"disabled bypass does not overwrite stored value");
    for(integer n=0;n<8;n++)begin
      instruction=(n<<12)|32'h00000003;#1;
      if(n==0||n==1||n==2||n==4||n==5)check(loaden&&wbctrl==`WB_LOAD,"load decode class");
    end
    instruction=32'h007302b3;#1;check(rs1==6&&rs2==7&&rd==5&&decoded_op==`ADD,"R instruction fields");
    for(integer n=0;n<2;n++)begin
      target=n?pc-4:pc+8;instruction=branch_word(n?-4:8);#1;
      check(prediction&&predicted===(n?pc-4:pc+4),"BTFNT frontend");
      for(integer t=0;t<2;t++)begin
        taken=t;#1;check(flush===(t!=n),"branch correction qualifier");
        check(corrected===((t!=n)?(t?target:pc+4):0),"branch correction target");
      end
    end
    branch_type=`TYPE_JALR;target=32'h80000005;#1;check(flush&&corrected==32'h80000004,"JALR clears bit0");
    exception=1;#1;check(!flush,"accepted CSR redirect suppresses branch correction");
    store=1;sc=`STORE_SB;
    for(integer n=0;n<4;n++)begin
      addr=32'h80100000+n;#1;
      check(be===(1<<n)&&packed_data===(32'hef<<(8*n)),"SB byte enable and placement");
    end
    sc=`STORE_SH;addr=32'h80100002;#1;check(be==12&&packed_data==32'hcdef0000,"SH upper half");
    addr=32'h80100001;#1;check(be==0,"unaligned SH has no write strobe");
    sc=`STORE_SW;addr=32'h8013fffc;#1;check(ram_hit&&be==15,"RAM upper word");
    addr=32'h80140000;#1;check(!ram_hit&&be==0,"no RAM alias past 256KiB");
    store=0;load=1;addr=32'h80100000;load_over=0;#1;check(wait_load,"first RAM load cycle waits");
    load_over=1;#1;check(!wait_load,"registered BRAM load completes");
    addr=32'h80200040;ready=0;#1;check(io_hit&&io_valid&&wait_load,"MMIO request waits for ready");
    ready=1;lc=`LOAD_LB;#1;check(!wait_load&&io_data==32'hffffffef,"MMIO byte sign extension");
    lc=`LOAD_LBU;#1;check(io_data==32'hef,"MMIO byte zero extension");
    cancel=1;#1;check(!io_valid,"cancel prevents external transaction");
    cancel=0;valid=0;#1;check(!io_valid,"bubble prevents external transaction");
    $display("SKILL_CONTRACT_SUMMARY checks=%0d failures=%0d",checks,failures);
    $finish;
  end
  initial begin #20000;$fatal(1,"SKILL_CONTRACT_TIMEOUT");end
endmodule
