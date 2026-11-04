`timescale 1ns/1ps
module tb_crc;
 reg clk=0,resetn=0,valid=0,write=0;always #10 clk=~clk;
 reg [31:0] addr=0,wdata=0;reg [3:0] be=15;wire ready;wire [31:0]rdata,read_data;
 reg [6:0]read_index=0;wire committed,failed;
 crc_mmio dut(.*);
 reg [31:0] expected[0:11],lengths[0:11];reg [7:0] bytes[0:4095];
 reg [31:0] x,v,w,saved;integer k,i,j,n,checks=0;
 task wr(input [31:0] a,input [31:0] d,input [3:0] lanes=15);
 begin
  @(negedge clk);addr=a;wdata=d;be=lanes;write=1;valid=1;
  @(posedge clk);while(!ready)@(posedge clk);
  @(negedge clk);valid=0;write=0;be=15;
 end endtask
 task rd(input [31:0] a,output [31:0] d);
 begin
  @(negedge clk);addr=a;be=15;write=0;valid=1;
  @(posedge clk);while(!ready)@(posedge clk);d=rdata;
  @(negedge clk);valid=0;
 end endtask
 task expect_reg(input [31:0]a,input [31:0]d);
 reg [31:0]q;begin rd(a,q);if(q!==d)$fatal(1,"REG %08x got=%08x expected=%08x",a,q,d);checks++;end endtask
 task start(input [31:0]count);
 begin wr(32'h80200100,2);wr(32'h80200108,count);wr(32'h80200100,1);end endtask
 initial begin
  $readmemh("expected.hex",expected);$readmemh("lengths.hex",lengths);
  repeat(5)@(negedge clk);resetn=1;
  for(k=0;k<12;k=k+1)begin
   n=lengths[k];x=32'h13579bdf;
   for(i=0;i<n;i=i+1)begin x=x^(x<<13);x=x^(x>>17);x=x^(x<<5);bytes[i]=x[7:0];end
   if(k==1)for(i=0;i<9;i=i+1)bytes[i]=8'h31+i;
   start(n);
   for(i=0;i<n;i=i+4)begin
    w=0;for(j=0;j<4;j=j+1)if(i+j<n)w=w|({24'b0,bytes[i+j]}<<(8*j));
    wr(32'h8020010c,w);
   end
   repeat(8)@(negedge clk);expect_reg(32'h80200104,2);expect_reg(32'h80200110,expected[k]);
   $display("CRC_VECTOR_PASS case=%0d length=%0d crc=%08x",k,n,expected[k]);
  end
  // A new completed job starts without reset or ABORT; canonical tail is 1 byte.
  wr(32'h80200108,9);wr(32'h80200100,1);
  wr(32'h8020010c,32'h34333231);wr(32'h8020010c,32'h38373635);wr(32'h8020010c,32'hffffff39);
  repeat(8)@(negedge clk);expect_reg(32'h80200110,expected[1]);
  // Alter one actual payload bit, observe rejection by the unchanged golden,
  // then restore the payload and require the original golden again.
  bytes[17]=bytes[17]^1;
  for(k=0;k<2;k=k+1)begin
   start(4096);
   for(i=0;i<4096;i=i+4)begin
    w=0;for(j=0;j<4;j=j+1)w=w|({24'b0,bytes[i+j]}<<(8*j));
    wr(32'h8020010c,w);
   end
   repeat(8)@(negedge clk);rd(32'h80200110,v);
   if(k==0 && v===expected[11])$fatal(1,"modified payload matched golden");
   if(k==1 && v!==expected[11])$fatal(1,"restored payload failed golden");
   $display("CRC_PAYLOAD_CONTROL modified=%0d crc=%08x golden=%08x",k==0,v,expected[11]);
   bytes[17]=bytes[17]^1;checks++;
  end
  // Rejected configuration changes preserve a running job.
  start(8);wr(32'h80200108,999);wr(32'h80200100,1);expect_reg(32'h80200108,8);expect_reg(32'h80200104,5);
  wr(32'h80200100,2);expect_reg(32'h80200104,0);
  // Malformed width, idle DATA, and holes acknowledge without hanging.
  wr(32'h80200108,9,1);expect_reg(32'h80200104,4);wr(32'h80200100,2);
  wr(32'h8020010c,1);expect_reg(32'h80200104,4);wr(32'h80200100,2);
  wr(32'h80200120,1);expect_reg(32'h80200104,4);wr(32'h80200100,2);
  // Withdraw an uncompleted write while a prior word is processing.
  start(8);wr(32'h8020010c,32'h04030201);
  @(negedge clk);addr=32'h8020010c;wdata=32'h08070605;write=1;valid=1;
  #1;if(ready!==0)$fatal(1,"missing DATA backpressure");
  @(negedge clk);valid=0;write=0;repeat(8)@(negedge clk);
  if(dut.remaining!==4)$fatal(1,"withdrawn DATA produced side effect");checks++;
  wr(32'h80200100,3);expect_reg(32'h80200104,0);
  // Reset cancels pending data and permits a fresh canonical run.
  start(4);wr(32'h8020010c,32'h04030201);resetn=0;repeat(3)@(negedge clk);resetn=1;
  expect_reg(32'h80200104,0);start(0);expect_reg(32'h80200110,0);
  // Explicit state injection exercises the 32-bit modulo tick boundary.
  force dut.ticks=32'hfffffffc;@(negedge clk);release dut.ticks;
  rd(32'h80200118,saved);repeat(8)@(negedge clk);rd(32'h80200118,v);
  if((v-saved)>32'd32 || (v-saved)<32'd8)$fatal(1,"tick wrap delta");checks++;
  // Mailbox freezes atomically at COMMIT.
  wr(32'h80200200,32'h43524331);wr(32'h80200214,0);wr(32'h8020011c,1);
  if(!committed || failed)$fatal(1,"mailbox commit failed");
  read_index=0;#1;if(read_data!==32'h43524331)$fatal(1,"mailbox readback failed");
  wr(32'h80200200,0);#1;if(read_data!==32'h43524331)$fatal(1,"frozen mailbox changed");checks++;
  $display("TEST_PASS CRC_MMIO checks=%0d vectors=12",checks);$finish;
 end
 initial begin #3000000;$fatal(1,"CRC unit watchdog");end
endmodule
