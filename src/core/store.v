`timescale 1ns / 1ps
`include "riscv_define.vh"
`include "cpu_memory_map.vh"


module Store_Load(
	input tri1 reset,
    input tri1 instr_valid,
    input tri0 stall,
    input tri0 cancel,
    input tri1 IO_ready,
    input tri0 [31:0] IO_rdata,
    input Load_en,
    	input [2:0]Load_Ctrl,
    	input Store_en,
    	input [1:0]Store_Ctrl, 
    	input [31:0]MEM_Addr,
    	input [31:0]D2,
    	input load_over,
    	
    	output [31:0]ex_addr,
    	output [31:0]dtcm_data,
    	output dtcm_en,
    	output [3:0]wen,
    	output led,
    	output stall_Load,
        // CPU-side request candidates only; no external acceptance protocol.
        output ram_hit,
        output mmio_hit,
        output IO_Wen,
        output IO_WB,
        output IO_write,
        output [31:0] IO_addr,
        output [31:0] IO_wdata,
        output [31:0] IO_data,
        output IO_load_ready,
        output [3:0] IO_be
    );
    
    reg [3:0]DTCM_be;		//字节使能
    reg [31:0]DTCM_wdata;	//写入数据
    
    always @ * begin
    if (Store_en) begin
        // 默认值
        DTCM_be    = 4'b0000;
        DTCM_wdata = 32'b0;
        
        case (Store_Ctrl)
            `STORE_SB: begin 	// 字节存储：解析ALU_out生成字节使能+数据移位
                case (MEM_Addr[1:0])
                    2'b00: begin 
                    	DTCM_be = 4'b0001; 
                    	DTCM_wdata = {24'b0, D2[7:0]}; 
                    end
                    2'b01: begin 
                    	DTCM_be = 4'b0010; 
                    	DTCM_wdata = {16'b0, D2[7:0], 8'b0}; 
                    end
                    2'b10: begin 
                    	DTCM_be = 4'b0100; 
                    	DTCM_wdata = {8'b0, D2[7:0], 16'b0}; 
                    end
                    2'b11: begin 
                    	DTCM_be = 4'b1000; 
                    	DTCM_wdata = {D2[7:0], 24'b0}; 
                    end
                endcase
            end
            `STORE_SH: begin 	// 半字存储
                case (MEM_Addr[1:0])
                    2'b00: begin 
                    	DTCM_be = 4'b0011; 
                    	DTCM_wdata = {16'b0, D2[15:0]}; 
                    end
                    2'b10: begin 
                    	DTCM_be = 4'b1100; 
                    	DTCM_wdata = {D2[15:0], 16'b0}; 
                    end
                    default: begin 
                    	DTCM_be = 4'b0000; 
                    	DTCM_wdata = 32'b0; 
                    end // 非对齐地址
                endcase
            end
            `STORE_SW: begin 	// 字存储（必须对齐）
                if (MEM_Addr[1:0] == 2'b00) begin
                    DTCM_be    = 4'b1111;
                    DTCM_wdata = D2;
                end 
                else begin
                    DTCM_be    = 4'b0000;
                    DTCM_wdata = 32'b0;
                end
            end
        endcase
    end 
    else if (Load_en) begin
    	DTCM_be = 4'b0000;
    	DTCM_wdata = 32'b0;
    end
    else begin
        DTCM_be    = 4'b0000;
        DTCM_wdata = 32'b0;
    end
end
    
    // Keep full byte addresses through EX1 and EX_MEM. Only MEM_DTCM
    // converts a decoded RAM request into a 16-bit BRAM word index.
    assign ram_hit = (MEM_Addr >= `CPU_RAM_BASE && MEM_Addr <= `CPU_RAM_LAST);
    assign mmio_hit = (MEM_Addr == `CPU_MMIO_DIGITS ||
                       MEM_Addr == `CPU_MMIO_LED ||
                       MEM_Addr == `CPU_MMIO_COUNTER ||
                       (MEM_Addr >= 32'h80200100 && MEM_Addr <= 32'h802003ff));
    wire load_kind = (Load_Ctrl == `LOAD_LB || Load_Ctrl == `LOAD_LH ||
                      Load_Ctrl == `LOAD_LW || Load_Ctrl == `LOAD_LBU ||
                      Load_Ctrl == `LOAD_LHU);
    // Ready completes one transaction on the CPU edge; there is no earlier
    // acceptance or outstanding response. Wait is independent of cancel to
    // avoid a combinational cycle through CSR sys_stall/cancel_current.
    wire io_candidate = IO_WB || IO_write;
    wire io_active = reset && instr_valid && !stall && io_candidate;
    assign stall_Load = (ram_hit && Load_en && !load_over) ||
                        (io_active && !IO_ready);
    assign ex_addr = MEM_Addr;
    assign dtcm_en = ram_hit && ((Load_en && load_kind) || (Store_en && |DTCM_be));
    assign dtcm_data = DTCM_wdata;
    assign wen = ram_hit ? DTCM_be : 4'b0000;

    // The document names exact MMIO register addresses, not register windows.
    // IO_WB is a one-bit source flag, never the 32-bit bus return value.
    assign IO_WB = mmio_hit && Load_en && load_kind;
    assign IO_write = mmio_hit && Store_en && |DTCM_be;
    assign IO_Wen = io_active && !cancel;
    assign IO_addr = MEM_Addr;
    assign IO_wdata = DTCM_wdata;
    assign IO_be = IO_write ? DTCM_be : IO_WB ?
                   ((Load_Ctrl == `LOAD_LB || Load_Ctrl == `LOAD_LBU) ? 4'b0001 :
                    (Load_Ctrl == `LOAD_LH || Load_Ctrl == `LOAD_LHU) ? 4'b0011 : 4'b1111) : 4'b0000;
    // Format bus reads before capturing them with the load's rd/control.
    // Exact documented MMIO addresses are aligned; retain explicit checks.
    reg [31:0] io_formatted;
    wire [31:0] io_shifted = IO_rdata >> (8 * MEM_Addr[1:0]);
    always @* begin
        io_formatted = 32'b0;
        case (Load_Ctrl)
            `LOAD_LB: io_formatted = {{24{io_shifted[7]}},io_shifted[7:0]};
            `LOAD_LBU: io_formatted = {24'b0,io_shifted[7:0]};
            `LOAD_LH: if (!MEM_Addr[0]) io_formatted = {{16{io_shifted[15]}},io_shifted[15:0]};
            `LOAD_LHU: if (!MEM_Addr[0]) io_formatted = {16'b0,io_shifted[15:0]};
            `LOAD_LW: if (MEM_Addr[1:0] == 0) io_formatted = IO_rdata;
            default: io_formatted = 32'b0;
        endcase
    end
    assign IO_data = IO_WB ? io_formatted : 32'b0;
    // Readiness (not cancellation) determines whether the IRQ boundary is
    // safe. CSR completes memory operations before redirecting the front end.
    assign IO_load_ready = IO_WB && IO_ready;
    // LED is accessed exclusively through the same MMIO completion event.
    assign led = 1'b0;
    
endmodule
