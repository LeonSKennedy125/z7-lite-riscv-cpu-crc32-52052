`timescale 1ns/1ps
`include "riscv_define.vh"
module tb_memory;
 reg clk=0,reset=0,dtcm_en=0,Load_en=0;always #10 clk=~clk;
 reg [31:0] ex_addr=0,mem_addr=0,din=0;reg [3:0] wen=0;reg [2:0] Load_Ctrl=`LOAD_LW;
 wire [31:0] dout;
 MEM_DTCM dut(.*);
 reg [31:0] da=0,dd=0;reg [1:0]st=0;reg [2:0]ld=0;reg dl=0,ds=0,dr=1,dc=0;
 wire de,rh,mh,iv,wait_io;wire [3:0]dw;wire [31:0]ea,wd,id;
 integer lane;
 Store_Load decoder(.reset(1'b1),.instr_valid(1'b1),.stall(1'b0),.cancel(dc),.IO_ready(dr),
  .IO_rdata(32'h80000081),.Load_en(dl),.Load_Ctrl(ld),.Store_en(ds),.Store_Ctrl(st),
  .MEM_Addr(da),.D2(dd),.load_over(1'b1),.ex_addr(ea),.dtcm_data(wd),.dtcm_en(de),.wen(dw),
  .led(),.stall_Load(wait_io),.ram_hit(rh),.mmio_hit(mh),.IO_Wen(iv),.IO_WB(),.IO_write(),
  .IO_addr(),.IO_wdata(),.IO_data(id),.IO_load_ready(),.IO_be());
 task put(input [31:0] a,input [31:0] d,input [3:0] w);
 begin @(negedge clk);ex_addr=a;din=d;wen=w;dtcm_en=1;@(negedge clk);wen=0;dtcm_en=0;end endtask
 task get(input [31:0] a,input [2:0] mode,input [31:0] expected);
 begin
  @(negedge clk);ex_addr=a;mem_addr=a;dtcm_en=1;Load_Ctrl=mode;Load_en=1;wen=0;
  @(negedge clk);@(negedge clk);
  if(dout!==expected)$fatal(1,"RAM address=%08x mode=%0d got=%08x expected=%08x",a,mode,dout,expected);
  dtcm_en=0;Load_en=0;
 end endtask
 initial begin
  repeat(8)@(negedge clk);reset=1;
  put(32'h80100000,32'h12345678,15);put(32'h8010fffc,32'h89abcdef,15);
  get(32'h80100000,`LOAD_LW,32'h12345678);get(32'h8010fffc,`LOAD_LW,32'h89abcdef);
  get(32'h8010ffff,`LOAD_LB,32'hffffff89);get(32'h8010ffff,`LOAD_LBU,32'h89);
  get(32'h8010fffe,`LOAD_LH,32'hffff89ab);get(32'h8010fffe,`LOAD_LHU,32'h89ab);
  for(lane=0;lane<4;lane=lane+1)begin
   put(32'h80100000+lane,32'h81<<(lane*8),1<<lane);
   get(32'h80100000+lane,`LOAD_LB,32'hffffff81);
   get(32'h80100000+lane,`LOAD_LBU,32'h81);
  end
  get(32'h80100000,`LOAD_LW,32'h81818181);
  put(32'h80100000,32'h000080fe,3);get(32'h80100000,`LOAD_LH,32'hffff80fe);
  get(32'h80100000,`LOAD_LHU,32'h80fe);
  put(32'h8010fffe,32'h81230000,12);get(32'h8010fffe,`LOAD_LH,32'hffff8123);
  get(32'h8010fffe,`LOAD_LHU,32'h8123);
  put(32'h8010ffff,32'h7f000000,8);get(32'h8010ffff,`LOAD_LBU,32'h7f);
  put(32'h80100000,32'h12345678,15);put(32'h8010fffc,32'h89abcdef,15);
  put(32'h80110000,32'hdeadbeef,15);put(32'h800ffffc,32'hcafebabe,15);
  get(32'h80110000,`LOAD_LW,0);get(32'h800ffffc,`LOAD_LW,0);get(32'h80100000,`LOAD_LW,32'h12345678);
  get(32'h8010fffc,`LOAD_LW,32'h89abcdef);
  get(32'h80100001,`LOAD_LW,0);get(32'h80100001,`LOAD_LH,0);
  // Check that the first read edge still exposes the previous BRAM output.
  get(32'h80100000,`LOAD_LW,32'h12345678);
  @(negedge clk);ex_addr=32'h8010fffc;mem_addr=ex_addr;Load_Ctrl=`LOAD_LW;Load_en=1;dtcm_en=1;
  @(negedge clk);if(dout!==32'h12345678)$fatal(1,"RAM became visible before its second edge");
  @(negedge clk);if(dout!==32'h89abcdef)$fatal(1,"RAM missing second-edge output");Load_en=0;dtcm_en=0;
  @(negedge clk);reset=0;put(32'h80100000,32'hffffffff,15);@(negedge clk);reset=1;
  get(32'h80100000,`LOAD_LW,32'h12345678);
  ds=1;st=`STORE_SW;da=32'h8010fffc;dd=32'h89abcdef;#1;
  if(!rh || mh || !de || dw!=15 || ea!=da || wd!=dd)$fatal(1,"last aligned RAM word decode");
  for(lane=0;lane<4;lane=lane+1)begin
   da=32'h80100000+lane;st=`STORE_SB;dd=32'h81;#1;
   if(!de || dw!=(1<<lane) || wd!==(32'h81<<(8*lane)))$fatal(1,"byte store lane decode");
  end
  da=32'h8010fffe;st=`STORE_SH;dd=32'h8123;#1;
  if(!de || dw!=12 || wd!==32'h81230000)$fatal(1,"last aligned halfword store decode");
  da=32'h8010ffff;st=`STORE_SB;dd=32'h81;#1;
  if(!de || dw!=8 || wd!=32'h81000000)$fatal(1,"last byte store decode");
  st=`STORE_SH;#1;if(de || dw!=0)$fatal(1,"misaligned halfword store accepted");
  st=`STORE_SW;#1;if(de || dw!=0)$fatal(1,"misaligned word store accepted");
  da=32'h80110000;#1;if(rh || de || mh || dw!=0)$fatal(1,"RAM upper alias");
  da=32'h800ffffc;#1;if(rh || de || mh)$fatal(1,"RAM lower alias");
  da=32'h8020010c;#1;if(rh || de || !mh || !iv)$fatal(1,"CRC MMIO not decoded");
  dr=0;#1;if(!wait_io)$fatal(1,"MMIO missing wait");dc=1;#1;if(iv)$fatal(1,"cancel failed");
  dr=1;dc=0;ds=0;dl=1;ld=`LOAD_LB;#1;if(id!==32'hffffff81)$fatal(1,"MMIO signed load");
  ld=`LOAD_LBU;#1;if(id!==32'h81)$fatal(1,"MMIO unsigned load");
  $display("TEST_PASS MEMORY_64K boundaries widths misalignment reset");$finish;
 end
 initial begin #20000;$fatal(1,"RAM watchdog");end
endmodule
