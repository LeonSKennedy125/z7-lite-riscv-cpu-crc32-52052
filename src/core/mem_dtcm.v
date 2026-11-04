`timescale 1ns / 1ps
`include "riscv_define.vh"
`include "cpu_memory_map.vh"

module MEM_DTCM(
	input clk,
    input reset, // CPU-domain active-low reset; RAM contents are retained.
	input [31:0]ex_addr, 	 //ex，取aluout,读写地址
	input [31:0]mem_addr,	 //mem，读出后根据这个选择字节拓展
	input [31:0]din,         //ex，取rs2
	input dtcm_en,		//ex
	input Load_en,		//mem
    	input [3:0]wen,		//ex
    	input [2:0]Load_Ctrl,	//mem
	
	output [31:0]dout	//mem
    );

	wire [31:0]data_out;
	reg [31:0]data;
	wire [13:0]addr;
	
	wire ex_ram_hit = (ex_addr >= `CPU_RAM_BASE && ex_addr <= `CPU_RAM_LAST);
    wire mem_ram_hit = (mem_addr >= `CPU_RAM_BASE && mem_addr <= `CPU_RAM_LAST);
    wire ram_access = reset && dtcm_en && ex_ram_hit;
    wire [31:0] ram_offset = ex_addr - `CPU_RAM_BASE;
    assign addr = ex_ram_hit ? ram_offset[15:2] : 14'b0;
	
    // Preserve the specified primitive output registers and two-edge read.
    (* DONT_TOUCH = "TRUE" *) DTCM u_DTCM (
    	.clka(clk),
    	.addra(addr),
    	.dina(din),
    	.douta(data_out),
    	.ena(ram_access),
    	.wea(ram_access ? wen : 4'b0000)
    );
    
    always @ * begin
    // 仅在Load操作时生效（读操作）
    data = 32'b0;
    if (reset && Load_en && mem_ram_hit) begin
        case (Load_Ctrl)
            `LOAD_LB: begin  // 字节，有符号扩展
                 case (mem_addr[1:0])
                    2'b00: data = {{24{data_out[7]}},  data_out[7:0]};
                    2'b01: data = {{24{data_out[15]}}, data_out[15:8]};
                    2'b10: data = {{24{data_out[23]}}, data_out[23:16]};
                    2'b11: data = {{24{data_out[31]}}, data_out[31:24]};
                endcase
            end

            `LOAD_LH: begin  // 半字，有符号扩展
                 case (mem_addr[1:0])
                    2'b00: data = {{16{data_out[15]}}, data_out[15:0]};
                    2'b10: data = {{16{data_out[31]}}, data_out[31:16]};
                    default: data = 32'b0;  // 非对齐地址，默认输出0
                endcase
            end

            `LOAD_LW: begin  // 字，无扩展
                if (mem_addr[1:0] == 2'b00) begin
                    data = data_out;
                end else begin
                    data = 32'b0;  // 地址未对齐，默认输出0
                end
            end

            `LOAD_LBU: begin // 字节，无符号扩展
                case (mem_addr[1:0])
                    2'b00: data = {24'b0, data_out[7:0]};
                    2'b01: data = {24'b0, data_out[15:8]};
                    2'b10: data = {24'b0, data_out[23:16]};
                    2'b11: data = {24'b0, data_out[31:24]};
                endcase
            end

            `LOAD_LHU: begin // 半字，无符号扩展
                 case (mem_addr[1:0])
                    2'b00: data = {16'b0, data_out[15:0]};
                    2'b10: data = {16'b0, data_out[31:16]};
                    default: data = 32'b0;  // 非对齐地址，默认输出0
                endcase
            end

            default: begin    // 非Load指令/无效控制码
                data = 32'b0;
            end
        endcase
    	end 
    	else begin
        // 非Load操作（Store/无访存），内部寄存器置0
        	data = 32'b0;
    	end
end

// 模块输出dout直接映射内部扩展后的data
    assign dout = data;
    
endmodule
