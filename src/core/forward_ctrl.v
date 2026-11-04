`timescale 1ns / 1ps
`include "riscv_define.vh"

module Forward_Ctrl(
	input ex_Forward_en1,
	input ex_Forward_en2,
	input [1:0]ex_Forward_SEL,
	input mem_Forward_en1,
	input mem_Forward_en2,
	input [1:0]mem_Forward_SEL,
	input wb_Forward_en1,
	input wb_Forward_en2,
	input [1:0]wb_Forward_SEL,
	input [31:0]ex_aluout,
	input [31:0]mem_aluout,
	input [31:0]wb_aluout,
	input [31:0]ex_loadout,
	input [31:0]mem_loadout,
	input [31:0]wb_loadout,
	input [31:0]ex_pc4,
	input [31:0]mem_pc4,
	input [31:0]wb_pc4,
	input load_en1,
	input load_en2,
	input [1:0]load_SEL,
	input [31:0]ex_csr,
	input [31:0]mem_csr,
	input [31:0]wb_csr,
    input tri0 ex_io_source,
    input tri0 mem_io_source,
    input tri0 wb_io_source,
    input tri0 [31:0] ex_io_data,
    input tri0 [31:0] mem_io_data,
    input tri0 [31:0] wb_io_data,
	
	output retain_en1,
    output retain_en2,
    output Forward_en1,
	output Forward_en2,
	output [31:0]Forward_Data1,
	output [31:0]Forward_Data2
    );
    
    wire [31:0] ex_load_data = ex_io_source ? ex_io_data : ex_loadout;
    wire [31:0] mem_load_data = mem_io_source ? mem_io_data : mem_loadout;
    wire [31:0] wb_load_data = wb_io_source ? wb_io_data : wb_loadout;
    // Each source uses the youngest valid writer: EX > MEM > WB.
    // Captured load-use metadata may describe the previous EX0 instruction;
    // qualify it with the current MEM register match and never override EX.
    wire ready_load1 = load_en1 && load_SEL == `FW_Load &&
                       mem_Forward_en1 && mem_Forward_SEL == `FW_Load;
    wire ready_load2 = load_en2 && load_SEL == `FW_Load &&
                       mem_Forward_en2 && mem_Forward_SEL == `FW_Load;
    wire [31:0] ex_data = (ex_Forward_SEL == `FW_Load) ? ex_load_data :
                         (ex_Forward_SEL == `FW_Pc4) ? ex_pc4 :
                         (ex_Forward_SEL == `FW_CSR) ? ex_csr : ex_aluout;
    wire [31:0] mem_data = (mem_Forward_SEL == `FW_Load) ? mem_load_data :
                          (mem_Forward_SEL == `FW_Pc4) ? mem_pc4 :
                          (mem_Forward_SEL == `FW_CSR) ? mem_csr : mem_aluout;
    wire [31:0] wb_data = (wb_Forward_SEL == `FW_Load) ? wb_load_data :
                         (wb_Forward_SEL == `FW_Pc4) ? wb_pc4 :
                         (wb_Forward_SEL == `FW_CSR) ? wb_csr : wb_aluout;
    // A pending EX load is the youngest writer but its result is unavailable.
    // Cache every other valid resolved source in the held EX0 operand register
    // before MEM/WB drain. This also covers waits without a load-use match.
    assign retain_en1 = Forward_en1 && !(ex_Forward_en1 && ex_Forward_SEL == `FW_Load);
    assign retain_en2 = Forward_en2 && !(ex_Forward_en2 && ex_Forward_SEL == `FW_Load);
    assign Forward_en1 = ex_Forward_en1 || mem_Forward_en1 || wb_Forward_en1;
    assign Forward_en2 = ex_Forward_en2 || mem_Forward_en2 || wb_Forward_en2;
    assign Forward_Data1 = ex_Forward_en1 ? ex_data :
                           mem_Forward_en1 ? (ready_load1 ? mem_load_data : mem_data) :
                           wb_Forward_en1 ? wb_data : 32'b0;
    assign Forward_Data2 = ex_Forward_en2 ? ex_data :
                           mem_Forward_en2 ? (ready_load2 ? mem_load_data : mem_data) :
                           wb_Forward_en2 ? wb_data : 32'b0;
endmodule
