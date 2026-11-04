`timescale 1ns/1ps
module tb_cpu;
 reg clock=0,resetn=0,restart=0;always #10 clock=~clock;
 wire clk,rstn,valid,ready,write,committed,failed;
 wire [31:0] addr,wdata,rdata,read_data;wire [3:0] be;
 reg [6:0] read_index=0;
 reg [31:0] expected[0:11],lengths[0:11],words[0:103];
 integer f,i,k,run_id;
 reg [31:0] symbols[0:3],bss_next;
 integer sessions=0,result_reads=0;
 demo_cpu cpu(.clock(clock),.reset(resetn),.zero(1'b0),.LED(),.demo_restart(restart),
  .io_clk(clk),.io_resetn(rstn),.io_valid(valid),.io_ready(ready),.io_write(write),
  .io_addr(addr),.io_wdata(wdata),.io_be(be),.io_rdata(rdata));
 crc_mmio peripheral(.clk(clk),.resetn(rstn),.valid(valid),.ready(ready),.write(write),
  .addr(addr),.wdata(wdata),.be(be),.rdata(rdata),.read_index(read_index),.read_data(read_data),
  .committed(committed),.failed(failed));
 // Observe real CPU stores: every BSS word must be cleared on every restart.
 always @(posedge clk)begin
  if(!rstn)begin bss_next=symbols[0];sessions=0;result_reads=0;end
  else begin
   if(cpu.MEM_DTCM_0.ram_access && |cpu.MEM_DTCM_0.wen && bss_next<symbols[1])begin
    if(cpu.MEM_DTCM_0.ex_addr!==bss_next || cpu.MEM_DTCM_0.wen!==15 || cpu.MEM_DTCM_0.din!==0)
     $fatal(1,"startup did not clear BSS in order addr=%08x expected=%08x",cpu.MEM_DTCM_0.ex_addr,bss_next);
    bss_next=bss_next+4;
   end
   if(valid && ready)begin
    if(write && addr==32'h80200100 && wdata==1)begin
     if(bss_next!==symbols[1])$fatal(1,"BSS not fully cleared");
     if(sessions==0)$display("CPU_BSS_PASS run=%0d words=%0d",run_id,(symbols[1]-symbols[0])/4);
     sessions=sessions+1;
    end
    if(!write && addr==32'h80200110)begin
     result_reads=result_reads+1;
     if(sessions==13)begin
      if(rdata===expected[11])$fatal(1,"modified data unexpectedly passed CRC");
      $display("CPU_MUTATION_DETECTED run=%0d got=%08x reference=%08x",run_id,rdata,expected[11]);
     end
     if(sessions==14)begin
      if(rdata!==expected[11])$fatal(1,"restored data CRC failed");
      $display("CPU_RESTORATION_PASS run=%0d crc=%08x",run_id,rdata);
     end
    end
   end
  end
 end
 task check_run;
  begin
   wait(committed===1'b1);#1;
   if(failed)$fatal(1,"CPU firmware reported failure at run %0d",run_id);
   for(i=0;i<104;i=i+1)begin read_index=i;#1;words[i]=read_data;end
   if(words[0]!=32'h43524331 || words[1]!=1 || words[2]!=50000000 || words[3]!=65536 || words[4]!=12 || words[5]!=0 || words[6]!=104 || words[7]!=7)$fatal(1,"invalid mailbox header");
   if(sessions!=14 || result_reads!=14)$fatal(1,"missing CRC calls or result reads");
   for(k=0;k<12;k=k+1)begin
    i=8+k*8;
    if(words[i]!=k || words[i+1]!=lengths[k] || words[i+2]!=expected[k] || words[i+3]!=expected[k] || words[i+4]!=expected[k])$fatal(1,"CPU CRC mismatch case=%0d got=%08x expected=%08x",k,words[i+4],expected[k]);
    if(words[i+5]==0 || words[i+6]==0 || words[i+7]>words[i+6])$fatal(1,"invalid measured cycles case=%0d",k);
   end
   if(words[20]!=32'hcbf43926)$fatal(1,"canonical CRC mismatch");
   $display("CPU_RUN_PASS run=%0d cases=12 errors=0",run_id);
  end
 endtask
 initial begin
  $readmemh("expected.hex",expected);$readmemh("lengths.hex",lengths);$readmemh("symbols.hex",symbols);
  repeat(20)@(posedge clock);@(negedge clock)resetn=1;
  for(run_id=0;run_id<3;run_id=run_id+1)begin
   check_run();
   f=$fopen($sformatf("mailbox_sim_run_%0d.hex",run_id),"w");
   for(i=0;i<104;i=i+1)$fdisplay(f,"%08x",words[i]);$fclose(f);
   if(run_id==0)begin
    f=$fopen("mailbox_sim.hex","w");for(i=0;i<104;i=i+1)$fdisplay(f,"%08x",words[i]);$fclose(f);
   end
   if(run_id<2)begin
    @(negedge clk)restart=1;repeat(20)@(posedge clk);@(negedge clk)restart=0;
    wait(committed===1'b0);
   end
  end
  $display("TEST_PASS CPU_7010_CRC three reset runs; simulation only");$finish;
 end
 initial begin #300000000;$fatal(1,"CPU watchdog pc=%08x reset=%b io=%b/%b addr=%08x",cpu.IBROM_0.pc,rstn,valid,ready,addr);end
endmodule
