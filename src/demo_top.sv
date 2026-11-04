`timescale 1ns/1ps
module demo_top(input wire clock,input wire resetn,output wire led_ok,led_heartbeat);
 wire clk,rstn,valid,ready,write;wire [31:0] addr,wdata,rdata;wire [3:0] be;
 wire [6:0] read_index;wire [31:0] read_data;wire committed,failed,restart;
 demo_cpu cpu(.clock(clock),.reset(resetn),.zero(1'b0),.LED(),
   .io_clk(clk),.io_resetn(rstn),.io_valid(valid),.io_ready(ready),.io_write(write),
   .io_addr(addr),.io_wdata(wdata),.io_be(be),.io_rdata(rdata),.demo_restart(restart));
 crc_mmio peripheral(.clk(clk),.resetn(rstn),.valid(valid),.ready(ready),.write(write),
   .addr(addr),.wdata(wdata),.be(be),.rdata(rdata),.read_index(read_index),.read_data(read_data),
   .committed(committed),.failed(failed));
 vio_result vio(.clk(clk),.probe_in0(read_data),.probe_in1(committed),.probe_in2(failed),
   .probe_out0(read_index),.probe_out1(restart));
 reg [25:0] heartbeat;
 always @(posedge clk)if(!rstn)heartbeat<=0;else heartbeat<=heartbeat+1;
 assign led_heartbeat=~heartbeat[24];
 assign led_ok=~(committed && !failed);
endmodule
