`timescale 1ns/1ps
// Faults affect only the STATUS read response in this testbench. Firmware,
// synthesizable DUT and the independently generated zlib golden stay unchanged.
module tb_cpu_faults #(parameter integer FAULT=1);
 reg clock=0,resetn=0;always #10 clock=~clock;
 wire clk,rstn,valid,ready,write,committed,failed;
 wire [31:0]addr,wdata,rdata,normal_rdata,read_data;wire[3:0]be;
 reg[6:0]read_index=0;
 reg[31:0]expected[0:11],lengths[0:11],symbols[0:3],words[0:103];
 reg inject=0,target_seen=0,poll_started=0;
 reg[31:0]poll_start=0,last_error=0;
 integer polls=0,aborts=0,error_stores=0,sessions=0,f,i,k;
 demo_cpu cpu(.clock(clock),.reset(resetn),.zero(1'b0),.LED(),.demo_restart(1'b0),
  .io_clk(clk),.io_resetn(rstn),.io_valid(valid),.io_ready(ready),.io_write(write),
  .io_addr(addr),.io_wdata(wdata),.io_be(be),.io_rdata(rdata));
 crc_mmio peripheral(.clk(clk),.resetn(rstn),.valid(valid),.ready(ready),.write(write),
  .addr(addr),.wdata(wdata),.be(be),.rdata(normal_rdata),.read_index(read_index),.read_data(read_data),
  .committed(committed),.failed(failed));
 assign rdata=(inject && addr==32'h80200104) ?
             (FAULT==1 ? normal_rdata & 32'hfffffffd : normal_rdata | 32'h4) : normal_rdata;
 always @(posedge clk)if(rstn)begin
  if(cpu.MEM_DTCM_0.ram_access && cpu.MEM_DTCM_0.wen==15 &&
     cpu.MEM_DTCM_0.ex_addr==symbols[2] && cpu.MEM_DTCM_0.din!=0)begin
   if(cpu.MEM_DTCM_0.din!==last_error+1)$fatal(1,"nonsequential firmware error store");
   last_error=cpu.MEM_DTCM_0.din;error_stores=error_stores+1;
   $display("FAULT_CPU_ERROR_STORE model=%0d address=%08x value=%0d time=%0t",FAULT,symbols[2],last_error,$time);
  end
  if(valid && ready)begin
   if(write && addr==32'h80200100 && wdata==1)begin
    sessions=sessions+1;
    if(!target_seen && peripheral.length_reg==9)begin
     inject<=1;target_seen=1;
     $display("FAULT_INJECTION_ARMED model=%0d target=123456789 unchanged_firmware=1 time=%0t",FAULT,$time);
    end
   end
   if(inject && !write && addr==32'h80200118 && !poll_started)begin
    poll_start=rdata;poll_started=1;
   end
   if(inject && !write && addr==32'h80200104)polls=polls+1;
   if(inject && write && addr==32'h80200100 && wdata==2)begin
    if(FAULT==1)begin
     if(!poll_started || (peripheral.ticks-poll_start)<32'h100000 || polls<2 || last_error!=1)
      $fatal(1,"timeout abort not backed by elapsed polling and CPU error increment");
     aborts=aborts+1;
     $display("FAULT_TIMEOUT_ABORT elapsed=%0d polls=%0d errors=%0d time=%0t",peripheral.ticks-poll_start,polls,last_error,$time);
    end
    inject<=0;
   end
  end
 end
 initial begin
  $readmemh("expected.hex",expected);$readmemh("lengths.hex",lengths);$readmemh("symbols.hex",symbols);
  repeat(20)@(posedge clock);@(negedge clock)resetn=1;
  wait(committed===1'b1);#1;
  for(i=0;i<104;i=i+1)begin read_index=i;#1;words[i]=read_data;end
  if(!target_seen || !failed || sessions!=14 || polls==0)$fatal(1,"firmware fault did not execute to completion");
  if(words[0]!==32'h43524331 || words[1]!==1 || words[2]!==50000000 || words[3]!==65536 ||
     words[4]!==12 || words[6]!==104 || words[7]!==7)$fatal(1,"fault run malformed header");
  if(words[5]!==((FAULT==1)?2:1) || words[5]!==last_error || error_stores!=words[5])
   $fatal(1,"expected real nonzero firmware error count got=%0d stores=%0d",words[5],error_stores);
  if(FAULT==1 && aborts!=1)$fatal(1,"missing timeout abort");
  for(k=0;k<12;k=k+1)begin
   i=8+k*8;
   if(words[i]!==k || words[i+1]!==lengths[k] || words[i+2]!==expected[k] || words[i+3]!==expected[k])
    $fatal(1,"fault affected independent/software golden case=%0d",k);
   if(words[i+4]!==((FAULT==1 && k==1)?0:expected[k]))$fatal(1,"unexpected hardware return case=%0d",k);
   if(words[i+5]==0 || words[i+6]==0 || words[i+7]>words[i+6])$fatal(1,"fault invalid cycles");
  end
  f=$fopen((FAULT==1)?"mailbox_fault_timeout.hex":"mailbox_fault_error.hex","w");
  for(i=0;i<104;i=i+1)$fdisplay(f,"%08x",words[i]);$fclose(f);
  $display("TEST_PASS CPU_FIRMWARE_FAULT model=%0d errors=%0d aborts=%0d polls=%0d; expected fault; simulation only",FAULT,words[5],aborts,polls);
  $finish;
 end
 initial begin #300000000;$fatal(1,"fault firmware watchdog model=%0d pc=%08x",FAULT,cpu.IBROM_0.pc);end
endmodule
module tb_cpu_fault_timeout;tb_cpu_faults #(.FAULT(1)) model();endmodule
module tb_cpu_fault_error;tb_cpu_faults #(.FAULT(2)) model();endmodule
