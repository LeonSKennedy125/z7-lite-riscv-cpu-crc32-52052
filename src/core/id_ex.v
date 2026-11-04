`timescale 1ns / 1ps
`include "riscv_define.vh"

module ID_EX(
    input clk,          //时钟
    input reset,        //复位
    input [4:0]w_addr,  //wb地址
    input [31:0]id_pc,  //id地址
    input [31:0]id_pc4, //地址加四
    input flush,        //冲刷标志位
    input stall,        //阻塞标志位
    input [31:0]Data1,  //rs1读出数据
    input [31:0]Data2,  //rs2读出数据
    input [31:0]Imm,    //立即数
    input Ctrl,         //控制
    input [4:0]r1_addr, //rs1地址
    input [4:0]r2_addr, //rs2地址
    input [3:0]Instr_TYPE,  //指令大类
    input comp_en,
    input [6:0]ALU_Ctrl,
    input [2:0]Comp_Ctrl,
    input [1:0]reuse,
    input Load_en,
    input [2:0]Load_Ctrl,
    input Store_en,
    input [1:0]Store_Ctrl,
    input [2:0]WB_Ctrl,
    input wb_en,
    input stall2,
    input stall_Load,
    input tri0 retain_en1,
    input tri0 retain_en2,
    input tri0 [31:0] retain_data1,
    input tri0 [31:0] retain_data2,
    input csr_fluah,
    input [11:0]csr_addr,
    input instr_valid,
    input [4:0]csr_imm,
    
    output wire [4:0]WB_addr_out,       //写回地址
    output wire[31:0]ex_pc_out,         //ex地址
    output wire [31:0]ex_pc4_out,       //地址加四
    output wire [31:0]D1_out,           //rs1读出数据
    output wire [31:0]D2_out,           //rs2读出数据
    output wire [31:0]IMM_out,          //立即数
    output wire CTRL_out,
    output wire [4:0]R1_addr_out,
    output wire [4:0]R2_addr_out,
    output wire [3:0]instr_TYPE_out,
    output wire Comp_en_out,
    output wire [6:0]ALU_Ctrl_out,
    output wire [2:0]Comp_Ctrl_out,
    output wire [1:0]reuse_out,
    output wire Load_en_out,
    output wire [2:0]Load_Ctrl_out,
    output wire Store_en_out,
    output wire [1:0]Store_Ctrl_out,
    output wire [2:0]WB_Ctrl_out,
    output wire wb_en_out,
    output wire [11:0]csr_addr_out,
    output wire instr_valid_out,
    output wire [4:0]csr_imm_out
);

    
    reg [4:0] reg_WB_addr;
    reg [31:0] reg_ex_pc;
    reg [31:0] reg_ex_pc4;
    reg [31:0] reg_Data1;
    reg [31:0] reg_Data2;
    reg [31:0] reg_IMM;
    reg [31:0] reg_Ctrl;
    reg [4:0] reg_r1_addr;
    reg [4:0] reg_r2_addr;
    reg [3:0] reg_Instr_TYPE;
    reg reg_comp_en;
    reg [4:0] reg_ALU_Ctrl;
    reg [2:0] reg_Comp_Ctrl;
    reg [1:0] reg_reuse;
    reg reg_Load_en;
    reg [2:0] reg_Load_Ctrl;
    reg reg_Store_en;
    reg [1:0] reg_Store_Ctrl;
    reg [2:0] reg_WB_Ctrl;
    reg reg_wb_en;
    reg [11:0]reg_csr_addr;
    reg [4:0]reg_csr_imm;
    reg reg_instr_valid;

    always @ (posedge clk) 
    begin
        if (!reset) begin
            reg_WB_addr <= 5'b0;
            reg_ex_pc <= 32'h80000000;
            reg_ex_pc4 <= 32'h80000004;
            reg_Data1 <= 32'b0;
            reg_Data2 <= 32'b0;
            reg_IMM <= 32'b0;
            reg_Ctrl <= 32'b0;
            reg_r1_addr <= 5'b0;
            reg_r2_addr <= 5'b0;
            reg_Instr_TYPE <= 4'b0;
            reg_comp_en <= 1'b0;
            reg_ALU_Ctrl <= 7'b0;
            reg_Comp_Ctrl <= 3'b0;
            reg_reuse <= 3'b0;
            reg_Load_en <= 1'b0;
            reg_Load_Ctrl <= 3'b0;
            reg_Store_en <= 1'b0;
            reg_Store_Ctrl <= 2'b0;
            reg_WB_Ctrl <= 2'b0;
            reg_wb_en <= 1'b0;
            reg_csr_addr <= 12'b0;
            reg_csr_imm <= 5'b0;
            reg_instr_valid <= 1'b0;
        end
        else if (flush || csr_fluah) begin
            reg_WB_addr <= 5'b0;
            reg_ex_pc <= 32'h80000000;
            reg_ex_pc4 <= 32'h80000004;
            reg_Data1 <= 32'b0;
            reg_Data2 <= 32'b0;
            reg_IMM <= 32'b0;
            reg_Ctrl <= 32'b0;
            reg_r1_addr <= 5'b0;
            reg_r2_addr <= 5'b0;
            reg_Instr_TYPE <= 4'b0;
            reg_comp_en <= 1'b0;
            reg_ALU_Ctrl <= 7'b0;
            reg_Comp_Ctrl <= 3'b0;
            reg_reuse <= 3'b0;
            reg_Load_en <= 1'b0;
            reg_Load_Ctrl <= 3'b0;
            reg_Store_en <= 1'b0;
            reg_Store_Ctrl <= 2'b0;
            reg_WB_Ctrl <= 2'b0;
            reg_wb_en <= 1'b0;
            reg_csr_addr <= 12'b0;
            reg_csr_imm <= 5'b0;
            reg_instr_valid <= 1'b0;
        end
        else if (stall || stall2 || stall_Load) begin
            reg_WB_addr <= reg_WB_addr;
            reg_ex_pc <= reg_ex_pc;
            reg_ex_pc4 <= reg_ex_pc4;
            reg_Data1 <= retain_en1 ? retain_data1 : reg_Data1;
            reg_Data2 <= retain_en2 ? retain_data2 : reg_Data2;
            reg_IMM <= reg_IMM;
            reg_Ctrl <= reg_Ctrl;
            reg_r1_addr <= reg_r1_addr;
            reg_r2_addr <= reg_r2_addr;
            reg_Instr_TYPE <= reg_Instr_TYPE;
            reg_comp_en <= reg_comp_en;
            reg_ALU_Ctrl <= reg_ALU_Ctrl;
            reg_Comp_Ctrl <= reg_Comp_Ctrl;
            reg_reuse <= reg_reuse;
            reg_Load_en <= reg_Load_en;
            reg_Load_Ctrl <= reg_Load_Ctrl;
            reg_Store_en <= reg_Store_en;
            reg_Store_Ctrl <= reg_Store_Ctrl;
            reg_WB_Ctrl <= reg_WB_Ctrl;
            reg_wb_en <= reg_wb_en;
            reg_csr_addr <= reg_csr_addr;
            reg_csr_imm <= reg_csr_imm;
            reg_instr_valid <= reg_instr_valid;
        end
        else begin
            reg_WB_addr <= w_addr;
            reg_ex_pc <= id_pc;
            reg_ex_pc4 <= id_pc4;
            reg_Data1 <= Data1;
            reg_Data2 <= Data2;
            reg_IMM <= Imm;
            reg_Ctrl <= Ctrl;
            reg_r1_addr <= r1_addr;
            reg_r2_addr <= r2_addr;
            reg_Instr_TYPE <= Instr_TYPE;
            reg_comp_en <= comp_en;
            reg_ALU_Ctrl <= ALU_Ctrl;
            reg_Comp_Ctrl <= Comp_Ctrl;
            reg_reuse <= reuse;
            reg_Load_en <= Load_en;
            reg_Load_Ctrl <= Load_Ctrl;
            reg_Store_en <= Store_en;
            reg_Store_Ctrl <= Store_Ctrl;
            reg_WB_Ctrl <= WB_Ctrl;
            reg_wb_en <= wb_en;
            reg_csr_addr <= csr_addr;
            reg_csr_imm <= csr_imm;
            reg_instr_valid <= instr_valid;
        end
    end

    assign WB_addr_out = reg_WB_addr;
    assign ex_pc_out = reg_ex_pc;
    assign ex_pc4_out = reg_ex_pc4;
    assign D1_out = reg_Data1;
    assign D2_out = reg_Data2;
    assign IMM_out = reg_IMM;
    assign R1_addr_out = reg_r1_addr;
    assign R2_addr_out = reg_r2_addr;
    assign instr_TYPE_out = reg_Instr_TYPE;
    assign Comp_en_out = reg_comp_en;
    assign ALU_Ctrl_out = reg_ALU_Ctrl;
    assign Comp_Ctrl_out = reg_Comp_Ctrl;
    assign reuse_out = reg_reuse;
    assign Load_en_out = reg_Load_en;
    assign Load_Ctrl_out = reg_Load_Ctrl;
    assign Store_en_out = reg_Store_en;
    assign Store_Ctrl_out = reg_Store_Ctrl;
    assign WB_Ctrl_out = reg_WB_Ctrl;
    assign wb_en_out = reg_wb_en;
    assign csr_addr_out = reg_csr_addr;
    assign csr_imm_out = reg_csr_imm;

assign instr_valid_out = reg_instr_valid;
endmodule
