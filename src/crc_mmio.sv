`timescale 1ns/1ps
module crc_mmio(
 input wire clk, resetn, valid, write,
 input wire [31:0] addr,wdata,
 input wire [3:0] be,
 output reg ready,
 output reg [31:0] rdata,
 input wire [6:0] read_index,
 output wire [31:0] read_data,
 output reg committed,
 output wire failed
);
 reg [31:0] length_reg,remaining,crc,result,ticks,elapsed,buffer_word;
 reg [2:0] buffered;
 reg busy,done,error;
 reg [31:0] legacy_digits,legacy_led;
 (* ram_style="distributed" *) reg [31:0] mailbox[0:127];
 assign read_data=committed ? mailbox[read_index] : 32'b0;
 assign failed=committed && mailbox[5]!=0;
 wire aligned=addr[1:0]==0;
 wire in_mailbox=addr>=32'h80200200 && addr<=32'h802003fc && aligned;
 wire full_width=be==4'b1111;
 wire transfer=resetn && valid && ready;
 wire abort_now=transfer && write && full_width && addr==32'h80200100 && wdata[1];
 function automatic [31:0] step_byte(input [31:0] c,input [7:0] b);
   reg [31:0] t;integer i;
   begin t=c^{24'b0,b};for(i=0;i<8;i=i+1)t=(t>>1)^(t[0]?32'hedb88320:0);step_byte=t;end
 endfunction
 always @* begin
   // Capacity depends only on registered state, never on VALID or CPU control.
   // Other register accesses may wait up to four cycles while the word drains.
   ready=(buffered==0);
   rdata=0;
   if(in_mailbox)rdata=committed?mailbox[addr[8:2]]:0;
   else case(addr)
     32'h80200020:rdata=legacy_digits;
     32'h80200040:rdata=legacy_led;
     32'h80200050:rdata=ticks;
     32'h80200104:rdata={29'b0,error,done,busy};
     32'h80200108:rdata=length_reg;
     32'h80200110:rdata=result;
     32'h80200114:rdata=elapsed;
     32'h80200118:rdata=ticks;
     default:rdata=0;
   endcase
 end
 always @(posedge clk) begin
   if(!resetn)begin
     length_reg<=0;remaining<=0;crc<=32'hffffffff;result<=0;ticks<=0;elapsed<=0;
     buffer_word<=0;buffered<=0;busy<=0;done<=0;error<=0;committed<=0;legacy_digits<=0;legacy_led<=0;
   end else begin
     ticks<=ticks+1;
     if(busy)elapsed<=elapsed+1;
     if(busy && buffered!=0 && !abort_now)begin
       crc<=step_byte(crc,buffer_word[7:0]);buffer_word<=buffer_word>>8;
       buffered<=buffered-1;remaining<=remaining-1;
       if(remaining==1)begin busy<=0;done<=1;result<=step_byte(crc,buffer_word[7:0])^32'hffffffff;end
     end
     if(transfer)begin
       if(addr==32'h80200020 && write)begin
         for(integer j=0;j<4;j=j+1)if(be[j])legacy_digits[j*8+:8]<=wdata[j*8+:8];
       end else if(addr==32'h80200040 && write)begin
         for(integer j=0;j<4;j=j+1)if(be[j])legacy_led[j*8+:8]<=wdata[j*8+:8];
       end else if(addr==32'h80200050)begin
         // Legacy counter is read-only in this newly defined demo system.
       end else if(!aligned || !full_width)error<=1;
       else if(in_mailbox)begin
         if(write && !committed)mailbox[addr[8:2]]<=wdata;
         else if(write)error<=1;
       end else if(write)begin
         case(addr)
           32'h80200100:begin
             if(wdata[1])begin busy<=0;done<=0;error<=0;buffered<=0;remaining<=0;result<=0;elapsed<=0;crc<=32'hffffffff;end
             else if(wdata==1 && !busy)begin
               crc<=32'hffffffff;result<=0;buffered<=0;remaining<=length_reg;elapsed<=0;error<=0;
               busy<=length_reg!=0;done<=length_reg==0;
             end else error<=1;
           end
           32'h80200108:if(!busy)length_reg<=wdata;else error<=1;
           32'h8020010c:if(busy)begin buffer_word<=wdata;buffered<=remaining>=4?4:remaining[2:0];end else error<=1;
           32'h8020011c:if(!committed && !busy && wdata==1)committed<=1;else error<=1;
           default:error<=1;
         endcase
       end else begin
         case(addr)
           32'h80200104,32'h80200108,32'h80200110,32'h80200114,32'h80200118:begin end
           default:error<=1;
         endcase
       end
     end
   end
 end
endmodule
