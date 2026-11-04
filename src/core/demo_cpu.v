//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2026.1 (win64) Build 6511674 Tue Jun 16 11:02:23 MDT 2026
//Date        : Thu Oct 15 16:22:47 2026
//Host        : LeonS running 64-bit major release  (build 9200)
//Command     : generate_target design_1.bd
//Design      : design_1
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

  
module demo_cpu
   (LED,
    clock,
    io_addr,
    io_be,
    io_clk,
    io_rdata,
    io_ready,
    io_resetn,
    io_valid,
    io_wdata,
    io_write,
    reset,
    zero,
    demo_restart);
    output [4:0]LED;
    input clock;
  output [31:0]io_addr;
  output [3:0]io_be;
  output io_clk;
  input [31:0]io_rdata;
  input io_ready;
  output [0:0]io_resetn;
  output io_valid;
  output [31:0]io_wdata;
  output io_write;
    input reset;
    input zero;
  input demo_restart;

  wire [31:0]ALU_0_Alu_out;
  wire [31:0]ALU_0_MEM_Addr;
  wire [31:0]ALU_0_branch_pc;
  wire [31:0]Branch_Ctrl_0_branch_target;
  wire Branch_Ctrl_0_flush;
  wire Comp_0_Comp_out;
  wire [6:0]Ctrl_0_ALU_Ctrl;
  wire [2:0]Ctrl_0_Comp_Ctrl;
  wire Ctrl_0_Comp_en;
  wire [2:0]Ctrl_0_Load_Ctrl;
  wire Ctrl_0_Load_en;
  wire [1:0]Ctrl_0_Store_Ctrl;
  wire Ctrl_0_Store_en;
  wire [2:0]Ctrl_0_WB_Ctrl;
  wire [1:0]Ctrl_0_reuse;
  wire Ctrl_0_wb_en;
  wire [11:0]Decoder_0_csr_addr;
  wire [4:0]Decoder_0_csr_imm;
  wire [11:0]Decoder_0_func12;
  wire [2:0]Decoder_0_func3;
  wire [6:0]Decoder_0_func7;
  wire [3:0]Decoder_0_instr_TYPE;
  wire Decoder_0_instr_valid;
  wire [6:0]Decoder_0_opcode;
  wire [4:0]Decoder_0_r1_addr;
  wire [4:0]Decoder_0_r2_addr;
  wire [4:0]Decoder_0_w_addr;
  wire [1:0]EX_Forward_0_ex_Forward_SEL1;
  wire EX_Forward_0_flush3;
  wire EX_Forward_0_stall;
  wire [31:0]EX_MEM_0_CSR_DATA_o;
  wire [31:0]EX_MEM_0_IO_data_o;
  wire EX_MEM_0_IO_source_o;
  wire [3:0]EX_MEM_0_Instr_TYPE_out;
  wire [31:0]EX_MEM_0_MEM_ALUout_out;
  wire [4:0]EX_MEM_0_MEM_wb_addr_out;
  wire [2:0]EX_MEM_0_WB_Ctrl_out;
  wire EX_MEM_0_WB_en_out;
  wire [1:0]EX_MEM_0_ex_Forward_SEL1_0;
  wire EX_MEM_0_ex_Forward_en1_o;
  wire EX_MEM_0_ex_Forward_en1_out;
  wire EX_MEM_0_ex_Forward_en2_o;
  wire EX_MEM_0_ex_Forward_en2_out;
  wire [31:0]EX_MEM_0_load_addr_o;
  wire [2:0]EX_MEM_0_load_ctrl_out;
  wire EX_MEM_0_loaden_out;
  wire [31:0]EX_MEM_0_mem_pc4_out;
  wire [31:0]EX_MUX_0_ALU_A;
  wire [31:0]EX_MUX_0_ALU_B;
  wire [31:0]EX_MUX_0_Comp_A;
  wire [31:0]EX_MUX_0_Comp_B;
  wire [31:0]EX_MUX_0_D2;
  wire [31:0]EX_pipe_0_ALU_A_O;
  wire [31:0]EX_pipe_0_ALU_B_O;
  wire [6:0]EX_pipe_0_ALU_Ctrl_O;
  wire [31:0]EX_pipe_0_Comp_A_O;
  wire [31:0]EX_pipe_0_Comp_B_O;
  wire [2:0]EX_pipe_0_Comp_Ctrl_O;
  wire [31:0]EX_pipe_0_D2_O;
  wire [3:0]EX_pipe_0_Instr_TYPE_O;
  wire [2:0]EX_pipe_0_Load_Ctrl_O;
  wire EX_pipe_0_Load_en_O;
  wire [1:0]EX_pipe_0_Store_Ctrl_O;
  wire EX_pipe_0_Store_en_O;
  wire [4:0]EX_pipe_0_WB_Addr_O;
  wire [2:0]EX_pipe_0_WB_Ctrl_O;
  wire EX_pipe_0_comp_en_O;
  wire [11:0]EX_pipe_0_csr_addr_out;
  wire [4:0]EX_pipe_0_csr_imm_out;
  wire EX_pipe_0_csr_irq_safe;
  wire EX_pipe_0_csr_valid;
  wire EX_pipe_0_load_over;
  wire [31:0]EX_pipe_0_pc4_O;
  wire [31:0]EX_pipe_0_pc_O;
  wire EX_pipe_0_wb_en_O;
  wire [31:0]Forward_Ctrl_0_Forward_Data1;
  wire [31:0]Forward_Ctrl_0_Forward_Data2;
  wire Forward_Ctrl_0_Forward_en1;
  wire Forward_Ctrl_0_Forward_en2;
  wire Forward_Ctrl_0_retain_en1;
  wire Forward_Ctrl_0_retain_en2;
  wire [31:0]IBROM_0_instr_o;
  wire [31:0]IBROM_0_pc_o;
  wire [6:0]ID_EX_0_ALU_Ctrl_out;
  wire [2:0]ID_EX_0_Comp_Ctrl_out;
  wire ID_EX_0_Comp_en_out;
  wire [31:0]ID_EX_0_D1_out;
  wire [31:0]ID_EX_0_D2_out;
  wire [31:0]ID_EX_0_IMM_out;
  wire [2:0]ID_EX_0_Load_Ctrl_out;
  wire ID_EX_0_Load_en_out;
  wire [4:0]ID_EX_0_R1_addr_out;
  wire [4:0]ID_EX_0_R2_addr_out;
  wire [1:0]ID_EX_0_Store_Ctrl_out;
  wire ID_EX_0_Store_en_out;
  wire [2:0]ID_EX_0_WB_Ctrl_out;
  wire [4:0]ID_EX_0_WB_addr_out;
  wire [11:0]ID_EX_0_csr_addr_out;
  wire [4:0]ID_EX_0_csr_imm_out;
  wire [31:0]ID_EX_0_ex_pc4_out;
  wire [31:0]ID_EX_0_ex_pc_out;
  wire [3:0]ID_EX_0_instr_TYPE_out;
  wire ID_EX_0_instr_valid_out;
  wire [1:0]ID_EX_0_reuse_out;
  wire ID_EX_0_wb_en_out;
  wire [31:0]IF_ID_0_id_instr;
  wire [31:0]IF_ID_0_id_pc;
  wire [31:0]IF_ID_0_id_pc4;
  wire [4:0]LED;
  wire [31:0]MEM_DTCM_0_dout;
  wire [1:0]MEM_Forward_0_mem_Forward_SEL;
  wire MEM_Forward_0_mem_Forward_en1;
  wire MEM_Forward_0_mem_Forward_en2;
  wire [31:0]MEM_WB_0_ALU_Out_out;
  wire [31:0]MEM_WB_0_CSR_DATA_o;
  wire MEM_WB_0_Forward_valid;
  wire [31:0]MEM_WB_0_IO_data_o;
  wire MEM_WB_0_IO_source_o;
  wire [3:0]MEM_WB_0_Instr_TYPE_out;
  wire [31:0]MEM_WB_0_Load_Out_out;
  wire [2:0]MEM_WB_0_WB_CTRL_out;
  wire [4:0]MEM_WB_0_WB_addr_out;
  wire [31:0]MEM_WB_0_WB_pc4_out;
  wire MEM_WB_0_Wen_out;
  wire [31:0]Regfile_0_data1;
  wire [31:0]Regfile_0_data2;
  wire [31:0]Regfile_0_x10;
  wire [31:0]Regfile_0_x11;
  wire [31:0]Regfile_0_x12;
  wire [31:0]Regfile_0_x13;
  wire [31:0]Regfile_0_x14;
  wire [31:0]Regfile_0_x15;
  wire [31:0]Regfile_0_x16;
  wire [31:0]Regfile_0_x17;
  wire [31:0]Regfile_0_x18;
  wire [31:0]Regfile_0_x19;
  wire [31:0]Regfile_0_x20;
  wire [31:0]Regfile_0_x21;
  wire [31:0]Regfile_0_x22;
  wire [31:0]Regfile_0_x23;
  wire [31:0]Regfile_0_x24;
  wire [31:0]Regfile_0_x25;
  wire [31:0]Regfile_0_x26;
  wire [31:0]Regfile_0_x27;
  wire [31:0]Regfile_0_x28;
  wire [31:0]Regfile_0_x29;
  wire [31:0]Regfile_0_x30;
  wire [31:0]Regfile_0_x31;
  wire Stall_0_Stall2;
  wire Store_Load_0_IO_WB;
  wire [31:0]Store_Load_0_IO_data;
  wire Store_Load_0_IO_load_ready;
  wire [31:0]Store_Load_0_dtcm_data;
  wire Store_Load_0_dtcm_en;
  wire [31:0]Store_Load_0_ex_addr;
  wire Store_Load_0_led;
  wire Store_Load_0_stall_Load;
  wire [3:0]Store_Load_0_wen;
  wire [1:0]WB_Forward_0_wb_Forward_SEL;
  wire WB_Forward_0_wb_Forward_en1;
  wire WB_Forward_0_wb_Forward_en2;
  wire [31:0]WB_MUX_0_Data;
  wire clk_wiz_0_locked;
  wire clock;
  wire cpu_reset_sync_0_reset;
  wire csr_top_0_cancel_current;
  wire [31:0]csr_top_0_csr_rdata;
  wire [31:0]csr_top_0_pc_o;
  wire csr_top_0_pc_o_en;
  wire [31:0]imm_gen_0_Imm;
  wire instr_minidecoder_0_Pre;
  wire [31:0]instr_minidecoder_0_pc_o;
  wire [31:0]io_addr;
  wire [3:0]io_be;
  wire io_clk;
  wire [31:0]io_rdata;
  wire io_ready;
  wire \^io_resetn ;
  wire io_valid;
  wire [31:0]io_wdata;
  wire io_write;
  wire [31:0]npc_0_npc;
  wire [31:0]npc_0_npc4;
  wire npc_0_npc_flag;
  wire npc_0_replay_redirect;
  wire [31:0]pc_judge_0_pc4_o;
  wire [31:0]pc_judge_0_pc_o;
  wire proc_sys_reset_0_mb_reset;
  wire reset;
  wire [0:0]reset_1;
  wire save_Load_use_0_save;
  wire [0:0]util_vector_logic_1_Res;
  wire zero;

  assign io_resetn[0] = \^io_resetn ;
  ALU ALU_0
       (.A(EX_pipe_0_ALU_A_O),
        .ALU_Ctrl(EX_pipe_0_ALU_Ctrl_O),
        .Alu_out(ALU_0_Alu_out),
        .B(EX_pipe_0_ALU_B_O),
        .Instr_type(EX_pipe_0_Instr_TYPE_O),
        .MEM_Addr(ALU_0_MEM_Addr),
        .branch_pc(ALU_0_branch_pc),
        .comp_out(Comp_0_Comp_out));
  Branch_Ctrl Branch_Ctrl_0
       (.Alu_out(ALU_0_branch_pc),
        .Exception(csr_top_0_pc_o_en),
        .branch_target(Branch_Ctrl_0_branch_target),
        .comp_out(Comp_0_Comp_out),
        .ex_pc(EX_pipe_0_pc_O),
        .ex_pc4(EX_pipe_0_pc4_O),
        .flush(Branch_Ctrl_0_flush),
        .instr_TYPE(EX_pipe_0_Instr_TYPE_O));
  Comp Comp_0
       (.A(EX_pipe_0_Comp_A_O),
        .B(EX_pipe_0_Comp_B_O),
        .Comp_Ctrl(EX_pipe_0_Comp_Ctrl_O),
        .Comp_en(EX_pipe_0_comp_en_O),
        .Comp_out(Comp_0_Comp_out));
  Ctrl Ctrl_0
       (.ALU_Ctrl(Ctrl_0_ALU_Ctrl),
        .Comp_Ctrl(Ctrl_0_Comp_Ctrl),
        .Comp_en(Ctrl_0_Comp_en),
        .Load_Ctrl(Ctrl_0_Load_Ctrl),
        .Load_en(Ctrl_0_Load_en),
        .Store_Ctrl(Ctrl_0_Store_Ctrl),
        .Store_en(Ctrl_0_Store_en),
        .WB_Ctrl(Ctrl_0_WB_Ctrl),
        .func12(Decoder_0_func12),
        .func3(Decoder_0_func3),
        .func7(Decoder_0_func7),
        .opcode(Decoder_0_opcode),
        .reuse(Ctrl_0_reuse),
        .wb_en(Ctrl_0_wb_en));
  Decoder Decoder_0
       (.csr_addr(Decoder_0_csr_addr),
        .csr_imm(Decoder_0_csr_imm),
        .func12(Decoder_0_func12),
        .func3(Decoder_0_func3),
        .func7(Decoder_0_func7),
        .id_instr(IF_ID_0_id_instr),
        .instr_TYPE(Decoder_0_instr_TYPE),
        .instr_valid(Decoder_0_instr_valid),
        .opcode(Decoder_0_opcode),
        .r1_addr(Decoder_0_r1_addr),
        .r2_addr(Decoder_0_r2_addr),
        .w_addr(Decoder_0_w_addr));
  EX_Forward EX_Forward_0
       (.ex_Forward_SEL1(EX_Forward_0_ex_Forward_SEL1),
        .ex_Forward_en1(EX_MEM_0_ex_Forward_en1_out),
        .ex_Forward_en2(EX_MEM_0_ex_Forward_en2_out),
        .ex_wb_addr(EX_pipe_0_WB_Addr_O),
        .flush3(EX_Forward_0_flush3),
        .id_rs1(ID_EX_0_R1_addr_out),
        .id_rs2(ID_EX_0_R2_addr_out),
        .instr_type(EX_pipe_0_Instr_TYPE_O),
        .stall(EX_Forward_0_stall),
        .wb_en(EX_pipe_0_wb_en_O));
  EX_MEM EX_MEM_0
       (.CSR_DATA(csr_top_0_csr_rdata),
        .CSR_DATA_o(EX_MEM_0_CSR_DATA_o),
        .EX_ALUout(ALU_0_Alu_out),
        .IO_data(Store_Load_0_IO_data),
        .IO_data_o(EX_MEM_0_IO_data_o),
        .IO_source(Store_Load_0_IO_WB),
        .IO_source_o(EX_MEM_0_IO_source_o),
        .Instr_TYPE_out(EX_MEM_0_Instr_TYPE_out),
        .MEM_ALUout_out(EX_MEM_0_MEM_ALUout_out),
        .MEM_wb_addr_out(EX_MEM_0_MEM_wb_addr_out),
        .WB_Ctrl_out(EX_MEM_0_WB_Ctrl_out),
        .WB_en_out(EX_MEM_0_WB_en_out),
        .clk(io_clk),
        .csr_fluah(csr_top_0_cancel_current),
        .ex_Forward_SEL1(EX_Forward_0_ex_Forward_SEL1),
        .ex_Forward_SEL1_0(EX_MEM_0_ex_Forward_SEL1_0),
        .ex_Forward_en1(EX_MEM_0_ex_Forward_en1_out),
        .ex_Forward_en1_o(EX_MEM_0_ex_Forward_en1_o),
        .ex_Forward_en2(EX_MEM_0_ex_Forward_en2_out),
        .ex_Forward_en2_o(EX_MEM_0_ex_Forward_en2_o),
        .ex_pc4(EX_pipe_0_pc4_O),
        .flush(zero),
        .instr_TYPE(EX_pipe_0_Instr_TYPE_O),
        .load_addr(ALU_0_MEM_Addr),
        .load_addr_o(EX_MEM_0_load_addr_o),
        .load_ctrl(EX_pipe_0_Load_Ctrl_O),
        .load_ctrl_out(EX_MEM_0_load_ctrl_out),
        .loaden(EX_pipe_0_Load_en_O),
        .loaden_out(EX_MEM_0_loaden_out),
        .mem_pc4_out(EX_MEM_0_mem_pc4_out),
        .reset(reset_1),
        .stall(zero),
        .stall_Load(Store_Load_0_stall_Load),
        .wb_Ctrl(EX_pipe_0_WB_Ctrl_O),
        .wb_addr(EX_pipe_0_WB_Addr_O),
        .wb_en(EX_pipe_0_wb_en_O));
  EX_MUX EX_MUX_0
       (.ALU_A(EX_MUX_0_ALU_A),
        .ALU_B(EX_MUX_0_ALU_B),
        .CTRL(zero),
        .Comp_A(EX_MUX_0_Comp_A),
        .Comp_B(EX_MUX_0_Comp_B),
        .D2(EX_MUX_0_D2),
        .DATA1(ID_EX_0_D1_out),
        .DATA2(ID_EX_0_D2_out),
        .Forward_Data1(Forward_Ctrl_0_Forward_Data1),
        .Forward_Data2(Forward_Ctrl_0_Forward_Data2),
        .Forward_en1(Forward_Ctrl_0_Forward_en1),
        .Forward_en2(Forward_Ctrl_0_Forward_en2),
        .Imm(ID_EX_0_IMM_out),
        .instr_TYPE(ID_EX_0_instr_TYPE_out),
        .pc(ID_EX_0_ex_pc_out),
        .reuse(ID_EX_0_reuse_out));
  EX_pipe EX_pipe_0
       (.ALU_A(EX_MUX_0_ALU_A),
        .ALU_A_O(EX_pipe_0_ALU_A_O),
        .ALU_B(EX_MUX_0_ALU_B),
        .ALU_B_O(EX_pipe_0_ALU_B_O),
        .ALU_Ctrl(ID_EX_0_ALU_Ctrl_out),
        .ALU_Ctrl_O(EX_pipe_0_ALU_Ctrl_O),
        .Comp_A(EX_MUX_0_Comp_A),
        .Comp_A_O(EX_pipe_0_Comp_A_O),
        .Comp_B(EX_MUX_0_Comp_B),
        .Comp_B_O(EX_pipe_0_Comp_B_O),
        .Comp_Ctrl(ID_EX_0_Comp_Ctrl_out),
        .Comp_Ctrl_O(EX_pipe_0_Comp_Ctrl_O),
        .D2(EX_MUX_0_D2),
        .D2_O(EX_pipe_0_D2_O),
        .Flush3(EX_Forward_0_flush3),
        .Instr_TYPE(ID_EX_0_instr_TYPE_out),
        .Instr_TYPE_O(EX_pipe_0_Instr_TYPE_O),
        .Load_Ctrl(ID_EX_0_Load_Ctrl_out),
        .Load_Ctrl_O(EX_pipe_0_Load_Ctrl_O),
        .Load_en(ID_EX_0_Load_en_out),
        .Load_en_O(EX_pipe_0_Load_en_O),
        .Store_Ctrl(ID_EX_0_Store_Ctrl_out),
        .Store_Ctrl_O(EX_pipe_0_Store_Ctrl_O),
        .Store_en(ID_EX_0_Store_en_out),
        .Store_en_O(EX_pipe_0_Store_en_O),
        .WB_Addr(ID_EX_0_WB_addr_out),
        .WB_Addr_O(EX_pipe_0_WB_Addr_O),
        .WB_Ctrl(ID_EX_0_WB_Ctrl_out),
        .WB_Ctrl_O(EX_pipe_0_WB_Ctrl_O),
        .clk(io_clk),
        .comp_en(ID_EX_0_Comp_en_out),
        .comp_en_O(EX_pipe_0_comp_en_O),
        .csr_addr(ID_EX_0_csr_addr_out),
        .csr_addr_out(EX_pipe_0_csr_addr_out),
        .csr_flush(csr_top_0_pc_o_en),
        .csr_imm(ID_EX_0_csr_imm_out),
        .csr_imm_out(EX_pipe_0_csr_imm_out),
        .csr_irq_safe(EX_pipe_0_csr_irq_safe),
        .csr_valid(EX_pipe_0_csr_valid),
        .flush(Branch_Ctrl_0_flush),
        .id_pc(ID_EX_0_ex_pc_out),
        .id_pc4(ID_EX_0_ex_pc4_out),
        .instr_valid(ID_EX_0_instr_valid_out),
        .io_load_ready(Store_Load_0_IO_load_ready),
        .load_over(EX_pipe_0_load_over),
        .pc4_O(EX_pipe_0_pc4_O),
        .pc_O(EX_pipe_0_pc_O),
        .reset(reset_1),
        .stall(zero),
        .stall_Load(Store_Load_0_stall_Load),
        .wb_en(ID_EX_0_wb_en_out),
        .wb_en_O(EX_pipe_0_wb_en_O));
  Forward_Ctrl Forward_Ctrl_0
       (.Forward_Data1(Forward_Ctrl_0_Forward_Data1),
        .Forward_Data2(Forward_Ctrl_0_Forward_Data2),
        .Forward_en1(Forward_Ctrl_0_Forward_en1),
        .Forward_en2(Forward_Ctrl_0_Forward_en2),
        .ex_Forward_SEL(EX_Forward_0_ex_Forward_SEL1),
        .ex_Forward_en1(EX_MEM_0_ex_Forward_en1_out),
        .ex_Forward_en2(EX_MEM_0_ex_Forward_en2_out),
        .ex_aluout(ALU_0_Alu_out),
        .ex_csr(csr_top_0_csr_rdata),
        .ex_io_data(Store_Load_0_IO_data),
        .ex_io_source(Store_Load_0_IO_WB),
        .ex_loadout(MEM_DTCM_0_dout),
        .ex_pc4(EX_pipe_0_pc4_O),
        .load_SEL(EX_MEM_0_ex_Forward_SEL1_0),
        .load_en1(EX_MEM_0_ex_Forward_en1_o),
        .load_en2(EX_MEM_0_ex_Forward_en2_o),
        .mem_Forward_SEL(MEM_Forward_0_mem_Forward_SEL),
        .mem_Forward_en1(MEM_Forward_0_mem_Forward_en1),
        .mem_Forward_en2(MEM_Forward_0_mem_Forward_en2),
        .mem_aluout(EX_MEM_0_MEM_ALUout_out),
        .mem_csr(EX_MEM_0_CSR_DATA_o),
        .mem_io_data(EX_MEM_0_IO_data_o),
        .mem_io_source(EX_MEM_0_IO_source_o),
        .mem_loadout(MEM_DTCM_0_dout),
        .mem_pc4(EX_MEM_0_mem_pc4_out),
        .retain_en1(Forward_Ctrl_0_retain_en1),
        .retain_en2(Forward_Ctrl_0_retain_en2),
        .wb_Forward_SEL(WB_Forward_0_wb_Forward_SEL),
        .wb_Forward_en1(WB_Forward_0_wb_Forward_en1),
        .wb_Forward_en2(WB_Forward_0_wb_Forward_en2),
        .wb_aluout(MEM_WB_0_ALU_Out_out),
        .wb_csr(MEM_WB_0_CSR_DATA_o),
        .wb_io_data(MEM_WB_0_IO_data_o),
        .wb_io_source(MEM_WB_0_IO_source_o),
        .wb_loadout(MEM_WB_0_Load_Out_out),
        .wb_pc4(MEM_WB_0_WB_pc4_out));
  IBROM IBROM_0
       (.clk(io_clk),
        .csr_flush(csr_top_0_pc_o_en),
        .flush(Branch_Ctrl_0_flush),
        .instr_o(IBROM_0_instr_o),
        .pc(pc_judge_0_pc_o),
        .pc4(pc_judge_0_pc4_o),
        .pc4_o(npc_0_npc4),
        .pc_o(IBROM_0_pc_o),
        .rst(reset_1),
        .stall(util_vector_logic_1_Res));
  ID_EX ID_EX_0
       (.ALU_Ctrl(Ctrl_0_ALU_Ctrl),
        .ALU_Ctrl_out(ID_EX_0_ALU_Ctrl_out),
        .Comp_Ctrl(Ctrl_0_Comp_Ctrl),
        .Comp_Ctrl_out(ID_EX_0_Comp_Ctrl_out),
        .Comp_en_out(ID_EX_0_Comp_en_out),
        .Ctrl(zero),
        .D1_out(ID_EX_0_D1_out),
        .D2_out(ID_EX_0_D2_out),
        .Data1(Regfile_0_data1),
        .Data2(Regfile_0_data2),
        .IMM_out(ID_EX_0_IMM_out),
        .Imm(imm_gen_0_Imm),
        .Instr_TYPE(Decoder_0_instr_TYPE),
        .Load_Ctrl(Ctrl_0_Load_Ctrl),
        .Load_Ctrl_out(ID_EX_0_Load_Ctrl_out),
        .Load_en(Ctrl_0_Load_en),
        .Load_en_out(ID_EX_0_Load_en_out),
        .R1_addr_out(ID_EX_0_R1_addr_out),
        .R2_addr_out(ID_EX_0_R2_addr_out),
        .Store_Ctrl(Ctrl_0_Store_Ctrl),
        .Store_Ctrl_out(ID_EX_0_Store_Ctrl_out),
        .Store_en(Ctrl_0_Store_en),
        .Store_en_out(ID_EX_0_Store_en_out),
        .WB_Ctrl(Ctrl_0_WB_Ctrl),
        .WB_Ctrl_out(ID_EX_0_WB_Ctrl_out),
        .WB_addr_out(ID_EX_0_WB_addr_out),
        .clk(io_clk),
        .comp_en(Ctrl_0_Comp_en),
        .csr_addr(Decoder_0_csr_addr),
        .csr_addr_out(ID_EX_0_csr_addr_out),
        .csr_fluah(csr_top_0_pc_o_en),
        .csr_imm(Decoder_0_csr_imm),
        .csr_imm_out(ID_EX_0_csr_imm_out),
        .ex_pc4_out(ID_EX_0_ex_pc4_out),
        .ex_pc_out(ID_EX_0_ex_pc_out),
        .flush(Branch_Ctrl_0_flush),
        .id_pc(IF_ID_0_id_pc),
        .id_pc4(IF_ID_0_id_pc4),
        .instr_TYPE_out(ID_EX_0_instr_TYPE_out),
        .instr_valid(Decoder_0_instr_valid),
        .instr_valid_out(ID_EX_0_instr_valid_out),
        .r1_addr(Decoder_0_r1_addr),
        .r2_addr(Decoder_0_r2_addr),
        .reset(reset_1),
        .retain_data1(Forward_Ctrl_0_Forward_Data1),
        .retain_data2(Forward_Ctrl_0_Forward_Data2),
        .retain_en1(Forward_Ctrl_0_retain_en1),
        .retain_en2(Forward_Ctrl_0_retain_en2),
        .reuse(Ctrl_0_reuse),
        .reuse_out(ID_EX_0_reuse_out),
        .stall(zero),
        .stall2(Stall_0_Stall2),
        .stall_Load(Store_Load_0_stall_Load),
        .w_addr(Decoder_0_w_addr),
        .wb_en(Ctrl_0_wb_en),
        .wb_en_out(ID_EX_0_wb_en_out));
  IF_ID IF_ID_0
       (.clk(io_clk),
        .csr_fluah(csr_top_0_pc_o_en),
        .flush(Branch_Ctrl_0_flush),
        .id_instr(IF_ID_0_id_instr),
        .id_pc(IF_ID_0_id_pc),
        .id_pc4(IF_ID_0_id_pc4),
        .instr(IBROM_0_instr_o),
        .pc(IBROM_0_pc_o),
        .pc4(npc_0_npc4),
        .reset(reset_1),
        .stall(Stall_0_Stall2),
        .stall_Load(Store_Load_0_stall_Load));
  LED_CTRL LED_CTRL_0
       (.LED_CTRL_o(LED),
        .LED_Ctrl(Store_Load_0_dtcm_data),
        .clk(io_clk),
        .led(Store_Load_0_led),
        .reset(reset_1));
  MEM_DTCM MEM_DTCM_0
       (.Load_Ctrl(EX_MEM_0_load_ctrl_out),
        .Load_en(EX_MEM_0_loaden_out),
        .clk(io_clk),
        .din(Store_Load_0_dtcm_data),
        .dout(MEM_DTCM_0_dout),
        .dtcm_en(Store_Load_0_dtcm_en),
        .ex_addr(Store_Load_0_ex_addr),
        .mem_addr(EX_MEM_0_load_addr_o),
        .reset(reset_1),
        .wen(Store_Load_0_wen));
  MEM_Forward MEM_Forward_0
       (.id_rs1(ID_EX_0_R1_addr_out),
        .id_rs2(ID_EX_0_R2_addr_out),
        .instr_type(EX_MEM_0_Instr_TYPE_out),
        .mem_Forward_SEL(MEM_Forward_0_mem_Forward_SEL),
        .mem_Forward_en1(MEM_Forward_0_mem_Forward_en1),
        .mem_Forward_en2(MEM_Forward_0_mem_Forward_en2),
        .mem_wb_addr(EX_MEM_0_MEM_wb_addr_out),
        .wb_en(EX_MEM_0_WB_en_out));
  MEM_WB MEM_WB_0
       (.ALU_Out_out(MEM_WB_0_ALU_Out_out),
        .ALU_out(EX_MEM_0_MEM_ALUout_out),
        .CSR_DATA(EX_MEM_0_CSR_DATA_o),
        .CSR_DATA_o(MEM_WB_0_CSR_DATA_o),
        .Forward_valid(MEM_WB_0_Forward_valid),
        .IO_data(EX_MEM_0_IO_data_o),
        .IO_data_o(MEM_WB_0_IO_data_o),
        .IO_source(EX_MEM_0_IO_source_o),
        .IO_source_o(MEM_WB_0_IO_source_o),
        .Instr_TYPE_out(MEM_WB_0_Instr_TYPE_out),
        .Load_Out_out(MEM_WB_0_Load_Out_out),
        .Load_out(MEM_DTCM_0_dout),
        .WB_CTRL_out(MEM_WB_0_WB_CTRL_out),
        .WB_Ctrl(EX_MEM_0_WB_Ctrl_out),
        .WB_addr_out(MEM_WB_0_WB_addr_out),
        .WB_pc4_out(MEM_WB_0_WB_pc4_out),
        .Wen(EX_MEM_0_WB_en_out),
        .Wen_out(MEM_WB_0_Wen_out),
        .clk(io_clk),
        .flush(zero),
        .instr_TYPE(EX_MEM_0_Instr_TYPE_out),
        .mem_pc4(EX_MEM_0_mem_pc4_out),
        .reset(reset_1),
        .save(save_Load_use_0_save),
        .stall(zero),
        .wb_addr(EX_MEM_0_MEM_wb_addr_out));
  Regfile Regfile_0
       (.clk(io_clk),
        .final_data1(Regfile_0_data1),
        .final_data2(Regfile_0_data2),
        .r_addr1(Decoder_0_r1_addr),
        .r_addr2(Decoder_0_r2_addr),
        .reset(reset_1),
        .w_addr(MEM_WB_0_WB_addr_out),
        .w_data(WB_MUX_0_Data),
        .wb_addr(MEM_WB_0_WB_addr_out),
        .wb_data(WB_MUX_0_Data),
        .wen(MEM_WB_0_Wen_out),
        .x10(Regfile_0_x10),
        .x11(Regfile_0_x11),
        .x12(Regfile_0_x12),
        .x13(Regfile_0_x13),
        .x14(Regfile_0_x14),
        .x15(Regfile_0_x15),
        .x16(Regfile_0_x16),
        .x17(Regfile_0_x17),
        .x18(Regfile_0_x18),
        .x19(Regfile_0_x19),
        .x20(Regfile_0_x20),
        .x21(Regfile_0_x21),
        .x22(Regfile_0_x22),
        .x23(Regfile_0_x23),
        .x24(Regfile_0_x24),
        .x25(Regfile_0_x25),
        .x26(Regfile_0_x26),
        .x27(Regfile_0_x27),
        .x28(Regfile_0_x28),
        .x29(Regfile_0_x29),
        .x30(Regfile_0_x30),
        .x31(Regfile_0_x31));
  Stall Stall_0
       (.Stall2(Stall_0_Stall2),
        .Stall_Ctrl2(EX_Forward_0_stall),
        .Stall_Ctrl3(zero));
  Store_Load Store_Load_0
       (.D2(EX_pipe_0_D2_O),
        .IO_WB(Store_Load_0_IO_WB),
        .IO_Wen(io_valid),
        .IO_addr(io_addr),
        .IO_be(io_be),
        .IO_data(Store_Load_0_IO_data),
        .IO_load_ready(Store_Load_0_IO_load_ready),
        .IO_rdata(io_rdata),
        .IO_ready(io_ready),
        .IO_wdata(io_wdata),
        .IO_write(io_write),
        .Load_Ctrl(EX_pipe_0_Load_Ctrl_O),
        .Load_en(EX_pipe_0_Load_en_O),
        .MEM_Addr(ALU_0_MEM_Addr),
        .Store_Ctrl(EX_pipe_0_Store_Ctrl_O),
        .Store_en(EX_pipe_0_Store_en_O),
        .cancel(csr_top_0_cancel_current),
        .dtcm_data(Store_Load_0_dtcm_data),
        .dtcm_en(Store_Load_0_dtcm_en),
        .ex_addr(Store_Load_0_ex_addr),
        .instr_valid(EX_pipe_0_csr_valid),
        .led(Store_Load_0_led),
        .load_over(EX_pipe_0_load_over),
        .reset(reset_1),
        .stall(zero),
        .stall_Load(Store_Load_0_stall_Load),
        .wen(Store_Load_0_wen));
  WB_Forward WB_Forward_0
       (.id_rs1(ID_EX_0_R1_addr_out),
        .id_rs2(ID_EX_0_R2_addr_out),
        .instr_type(MEM_WB_0_Instr_TYPE_out),
        .wb_Forward_SEL(WB_Forward_0_wb_Forward_SEL),
        .wb_Forward_en1(WB_Forward_0_wb_Forward_en1),
        .wb_Forward_en2(WB_Forward_0_wb_Forward_en2),
        .wb_en(MEM_WB_0_Forward_valid),
        .wb_wb_addr(MEM_WB_0_WB_addr_out));
  WB_MUX WB_MUX_0
       (.ALU_Out(MEM_WB_0_ALU_Out_out),
        .Data(WB_MUX_0_Data),
        .Load_Out(MEM_WB_0_Load_Out_out),
        .MEM_IO(MEM_WB_0_IO_source_o),
        .WB_CSR(MEM_WB_0_CSR_DATA_o),
        .WB_CTRL(MEM_WB_0_WB_CTRL_out),
        .WB_IO(MEM_WB_0_IO_data_o),
        .WB_pc4(MEM_WB_0_WB_pc4_out),
        .rd_addr(MEM_WB_0_WB_addr_out));
  clk50 clk_wiz_0
       (.clk_in1(clock),
        .clk_out1(io_clk),
        .locked(clk_wiz_0_locked),
        .resetn(reset));
  cpu_reset_control cpu_reset_sync_0
       (.clk(io_clk),
        .controller_reset(proc_sys_reset_0_mb_reset),
        .ext_resetn(reset),
        .io_resetn(\^io_resetn ),
        .locked(clk_wiz_0_locked),
        .reset(cpu_reset_sync_0_reset));
  csr_top csr_top_0
       (.alu_result(ALU_0_Alu_out),
        .branch_taken(Comp_0_Comp_out),
        .cancel_current(csr_top_0_cancel_current),
        .clk(io_clk),
        .csr_addr(EX_pipe_0_csr_addr_out),
        .csr_rdata(csr_top_0_csr_rdata),
        .imm(EX_pipe_0_csr_imm_out),
        .instr_type(EX_pipe_0_Instr_TYPE_O),
        .instr_valid(EX_pipe_0_csr_valid),
        .irq_safe(EX_pipe_0_csr_irq_safe),
        .opcode(EX_pipe_0_ALU_Ctrl_O),
        .pc(EX_pipe_0_pc_O),
        .pc4(EX_pipe_0_pc4_O),
        .pc_o(csr_top_0_pc_o),
        .pc_o_en(csr_top_0_pc_o_en),
        .rs1(EX_pipe_0_ALU_A_O),
        .rst(reset_1),
        .sys_exception({1'b0,1'b0,1'b0}),
        .sys_stall(Store_Load_0_stall_Load));

  imm_gen imm_gen_0
       (.Imm(imm_gen_0_Imm),
        .id_instr(IF_ID_0_id_instr),
        .instr_TYPE(Decoder_0_instr_TYPE));
  instr_minidecoder instr_minidecoder_0
       (.Pre(instr_minidecoder_0_Pre),
        .instr(IBROM_0_instr_o),
        .pc(IBROM_0_pc_o),
        .pc_o(instr_minidecoder_0_pc_o));
  npc npc_0
       (.Pre(instr_minidecoder_0_Pre),
        .clk(io_clk),
        .csr_pc_en(csr_top_0_pc_o_en),
        .current_pc(npc_0_npc),
        .flush(Branch_Ctrl_0_flush),
        .npc(npc_0_npc),
        .npc_flag(npc_0_npc_flag),
        .replay_redirect(npc_0_replay_redirect),
        .reset(reset_1),
        .right_pc(pc_judge_0_pc4_o),
        .stall(Stall_0_Stall2),
        .stall_Load(Store_Load_0_stall_Load));
  pc_judge pc_judge_0
       (.EM(csr_top_0_pc_o_en),
        .J_B(Branch_Ctrl_0_flush),
        .Pre(instr_minidecoder_0_Pre),
        .npc(npc_0_npc_flag),
        .pc4_o(pc_judge_0_pc4_o),
        .pc_Jump_Branch(Branch_Ctrl_0_branch_target),
        .pc_Predict(instr_minidecoder_0_pc_o),
        .pc_csr(csr_top_0_pc_o),
        .pc_npc(npc_0_npc),
        .pc_o(pc_judge_0_pc_o),
        .replay_redirect(npc_0_replay_redirect));
  rstip proc_sys_reset_0
       (.aux_reset_in(~demo_restart),
        .dcm_locked(clk_wiz_0_locked),
        .ext_reset_in(reset),
        .mb_debug_sys_rst(1'b0),
        .mb_reset(proc_sys_reset_0_mb_reset),
        .slowest_sync_clk(io_clk));
  save_Load_use save_Load_use_0
       (.clk(io_clk),
        .reset(reset_1),
        .save(save_Load_use_0_save),
        .stall1(Store_Load_0_stall_Load),
        .stall2(EX_Forward_0_stall));
  invip util_vector_logic_0
       (.Op1(cpu_reset_sync_0_reset),
        .Res(reset_1));
  orip util_vector_logic_1
       (.Op1(EX_Forward_0_stall),
        .Op2(Store_Load_0_stall_Load),
        .Res(util_vector_logic_1_Res));
endmodule
